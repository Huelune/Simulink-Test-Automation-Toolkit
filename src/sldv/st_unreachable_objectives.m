function [objectives, counts] = st_unreachable_objectives(sldvData, coverageFilterMode, cutName, cfg)
%ST_UNREACHABLE_OBJECTIVES Decision outcomes SLDV proved unreachable in the CUT.
%
% [objectives, counts] = st_unreachable_objectives(sldvData, coverageFilterMode, cutName)
% reads sldvData.Objectives and the ModelObjects entry each one points at
% (modelObjectIdx). Decision objectives whose status is Unsatisfiable or
% Unsatisfiable under approximation give one row each, in the table
% st_build_defect_iterations takes:
%   Sid           ModelObjects.designSid when the data has one, else sid
%   BlockType     ModelObjects.typeDesc
%   RelativePath  ModelObjects.slPath without its first two elements, the
%                 analysis root and the CUT. A '/' inside a name stays '//'
%                 and a newline stays: the criteria callback finds the
%                 harness block by this path. The second element of a kept
%                 objective must be CUTNAME (the target row's CUTName, as
%                 measured on real data), compared with '//' read as '/' and
%                 whitespace folded; any other raises
%                 simtest:SldvObjectiveOutsideCut, because its relative path
%                 would name a block of something else.
%   OutcomeIndex  Objectives.outcomeValue
%   OutcomeText   Objectives.descr (label when descr is empty)
%   Approximate   true for Unsatisfiable under approximation
%
% Unsatisfiable outcomes are dropped, each counted once, in this order:
%   Stateflow      the model object has a Stateflow object number
%                  (sfObjNum > 0; Stateflow, MATLAB Function): the criteria
%                  callback finds blocks by path. sfObjType cannot tell:
%                  R2025b fills it for every object, sfObjNum is -1 outside
%   CutItself      the CUT's own objectives (an slPath of two elements)
%   FilteredByCvf  what the row's coverage filter removes, which that test
%                  case is not responsible for (COVERAGEFILTERMODE):
%     OFF, ""      nothing
%     SUBSYSTEM    a subsystem directly below the CUT (its Enable, Trigger...)
%     ALL_CONTENT  that, and every block below the CUT's direct children
%
% COUNTS: Decision (every Decision objective), Unsatisfiable and Approximate
% (before anything is dropped), Undecided (counted, never kept), and the
% three drops above. With CFG, data that has no
% Objectives or ModelObjects logs a WARN; the table is empty either way.
% The error and the WARN carry no names: st_get_sldv_profile turns the
% error into DefectStatus READ_FAILED and prints nothing.
% Called without arguments it returns the empty table and zero counts, the
% profile defaults.

if nargin < 1, sldvData = []; end
if nargin < 2, coverageFilterMode = ""; end
if nargin < 3, cutName = ""; end
if nargin < 4, cfg = []; end
counts = struct('Decision', 0, 'Unsatisfiable', 0, 'Approximate', 0, ...
    'Undecided', 0, 'FilteredByCvf', 0, 'CutItself', 0, 'Stateflow', 0);
sid = strings(0, 1);
blockType = strings(0, 1);
relativePath = strings(0, 1);
outcomeIndex = zeros(0, 1);
outcomeText = strings(0, 1);
approximate = false(0, 1);

if ~isstruct(sldvData) || ~isfield(sldvData, 'Objectives') || ...
        ~isfield(sldvData, 'ModelObjects')
    if ~isempty(cfg)
        st_log(cfg, 'WARN', ['[UnreachableDefect] SLDV data has no Objectives ' ...
            'or ModelObjects | No defect iterations | Regenerate the SLDV data']);
    end
else
    filterMode = upper(strtrim(string(coverageFilterMode)));
    cutKey = folded_name(cutName);
    objects = sldvData.ModelObjects;
    for k = 1:numel(sldvData.Objectives)
        objective = sldvData.Objectives(k);
        if ~strcmpi(strtrim(char(objective.type)), 'Decision'), continue; end
        counts.Decision = counts.Decision + 1;
        status = strtrim(string(objective.status));
        isApproximate = startsWith(status, "Unsatisfiable", 'IgnoreCase', true) && ...
            contains(status, "approximation", 'IgnoreCase', true);
        if isApproximate
            counts.Approximate = counts.Approximate + 1;
        elseif strcmpi(status, "Unsatisfiable")
            counts.Unsatisfiable = counts.Unsatisfiable + 1;
        else
            if startsWith(status, "Undecided", 'IgnoreCase', true)
                counts.Undecided = counts.Undecided + 1;
            end
            continue;
        end

        object = objects(objective.modelObjectIdx);
        % Each drop below ends with continue, so an outcome is counted once.
        % shortcut: Stateflow 내부 결과는 결함으로 만들지 않는다, Stateflow 분기 목록을 설계할 때 넣는다
        if stateflow_number(object) > 0
            counts.Stateflow = counts.Stateflow + 1;
            continue;
        end
        % A '/' inside a block name is written '//' in a Simulink path.
        parts = regexp(char(object.slPath), '(?<!/)/(?!/)', 'split');
        if numel(parts) <= 2
            counts.CutItself = counts.CutItself + 1;
            continue;
        end
        typeDesc = field_text(object, 'typeDesc');
        directSubsystem = numel(parts) == 3 && ...
            contains(typeDesc, "subsystem", 'IgnoreCase', true);
        if (any(filterMode == ["SUBSYSTEM" "ALL_CONTENT"]) && directSubsystem) || ...
                (filterMode == "ALL_CONTENT" && numel(parts) > 3)
            counts.FilteredByCvf = counts.FilteredByCvf + 1;
            continue;
        end

        if folded_name(parts{2}) ~= cutKey
            error('simtest:SldvObjectiveOutsideCut', ['An SLDV objective path ' ...
                'does not run through the CUT | Regenerate the SLDV data of this target']);
        end

        id = field_text(object, 'designSid');
        if id == "", id = field_text(object, 'sid'); end
        outcome = field_text(objective, 'descr');
        if outcome == "", outcome = field_text(objective, 'label'); end
        sid(end+1, 1) = id; %#ok<AGROW>
        blockType(end+1, 1) = typeDesc; %#ok<AGROW>
        relativePath(end+1, 1) = strjoin(string(parts(3:end)), "/"); %#ok<AGROW>
        outcomeIndex(end+1, 1) = double(objective.outcomeValue); %#ok<AGROW>
        outcomeText(end+1, 1) = outcome; %#ok<AGROW>
        approximate(end+1, 1) = isApproximate; %#ok<AGROW>
    end
end

objectives = table(sid, blockType, relativePath, outcomeIndex, outcomeText, ...
    approximate, 'VariableNames', {'Sid','BlockType','RelativePath', ...
    'OutcomeIndex','OutcomeText','Approximate'});
end


function key = folded_name(name)
% A '/' in a block name is '//' in slPath but '/' in the CUTName column; a
% newline or doubled space in a name is compared as one space.
key = strtrim(regexprep(replace(string(name), "//", "/"), '\s+', ' '));
end


function number = stateflow_number(s)
number = -1;
if isfield(s, 'sfObjNum') && isnumeric(s.sfObjNum) && isscalar(s.sfObjNum)
    number = double(s.sfObjNum);
end
end


function value = field_text(s, name)
value = "";
if isfield(s, name) && ~isempty(s.(name))
    value = string(s.(name));
end
end
