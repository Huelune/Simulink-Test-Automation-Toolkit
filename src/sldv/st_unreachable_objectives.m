function [objectives, counts] = st_unreachable_objectives(sldvData, coverageFilterMode, cfg)
%ST_UNREACHABLE_OBJECTIVES Decision outcomes SLDV proved unreachable in the CUT.
%
% [objectives, counts] = st_unreachable_objectives(sldvData, coverageFilterMode)
% reads sldvData.Objectives and the ModelObjects entry each one points at
% (modelObjectIdx). Decision objectives whose status is Unsatisfiable or
% Unsatisfiable under approximation give one row each, in the table
% st_build_defect_iterations takes:
%   Sid           ModelObjects.designSid when the data has one, else sid
%   BlockType     ModelObjects.typeDesc
%   RelativePath  ModelObjects.slPath without its first two elements, the
%                 analysis root and the CUT. A '/' inside a name stays '//'
%                 and a newline stays: the criteria callback finds the
%                 harness block by this path.
%   OutcomeIndex  Objectives.outcomeValue
%   OutcomeText   Objectives.descr (label when descr is empty)
%   Approximate   true for Unsatisfiable under approximation
%
% The CUT's own objectives (an slPath of two elements) are dropped. So are
% the outcomes the row's coverage filter removes, which that test case is
% not responsible for (COVERAGEFILTERMODE):
%   OFF, ""      nothing
%   SUBSYSTEM    a subsystem directly below the CUT (its Enable, Trigger...)
%   ALL_CONTENT  that, and every block below the CUT's direct children
%
% COUNTS: Decision (every Decision objective), Unsatisfiable and Approximate
% (before anything is dropped), Undecided (counted, never kept),
% FilteredByCvf and CutItself (dropped). With CFG, data that has no
% Objectives or ModelObjects logs a WARN; the table is empty either way.

if nargin < 2, coverageFilterMode = ""; end
if nargin < 3, cfg = []; end
counts = struct('Decision', 0, 'Unsatisfiable', 0, 'Approximate', 0, ...
    'Undecided', 0, 'FilteredByCvf', 0, 'CutItself', 0);
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


function value = field_text(s, name)
value = "";
if isfield(s, name) && ~isempty(s.(name))
    value = string(s.(name));
end
end
