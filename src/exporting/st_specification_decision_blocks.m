function [text, count, note] = st_specification_decision_blocks( ...
        cutPath, cfg, finder, nameReader, descriptorReader, catalogReader)
%ST_SPECIFICATION_DECISION_BLOCKS Export static control-decision candidates as JSON.
% Each JSON array item contains BlockType, the actual block Name, full
% Simulink Path, branch outcome kind, and saved-parameter expression.
% Only direct child blocks of the CUT are searched.
% This is a static inventory, not the number of compiled coverage objectives.
% The scanned block types and their outcome tokens come from
% st_specification_decision_catalog, which is the only place either is defined.
if nargin < 3
    finder = @find_system;
end
if nargin < 4
    nameReader = @read_name;
end
if nargin < 5
    descriptorReader = @st_specification_decision_descriptor;
end
if nargin < 6
    catalogReader = @st_specification_decision_catalog;
end
try
    catalog = catalogReader();
    blockTypes = string(catalog.BlockType);
    outcomeDefaults = string(catalog.Outcome);
    if isempty(blockTypes)
        error('simtest:SpecificationDecisionCatalog', ...
            'Decision block catalog has no block type.');
    end
    st_log(cfg, 'DEBUG', ...
        'Specification decision catalog loaded | Types=%d | Explicit=%d | Implicit=%d', ...
        numel(blockTypes), sum(string(catalog.Kind) == "EXPLICIT"), ...
        sum(string(catalog.Kind) == "IMPLICIT"));
catch ME
    st_log(cfg, 'WARN', 'Specification decision catalog unavailable | CUT=%s | %s', ...
        cutPath, ME.message);
    error('simtest:SpecificationDecisionCatalog', ...
        'Decision block catalog is unavailable: %s', ME.message);
end
records = strings(0,7); % BlockType, Name, Path, Outcome, Expression, Status, Message
notes = strings(0,1);
st_log(cfg, 'INFO', 'Specification decision block scan start | CUT=%s | SearchDepth=1 | Types=%d', ...
    cutPath, numel(blockTypes));
for k = 1:numel(blockTypes)
    blockType = blockTypes(k);
    st_log(cfg, 'DEBUG', 'Specification decision block type scan start | CUT=%s | BlockType=%s | Outcome=%s', ...
        cutPath, blockType, outcomeDefaults(k));
    try
        paths = string(finder(char(cutPath), ...
            'SearchDepth', 1, 'Type', 'Block', 'BlockType', char(blockType)));
        paths = paths(:);
        paths = paths(strlength(paths) > 0);
        paths = unique(paths);
        names = strings(numel(paths),1);
        outcomes = strings(numel(paths),1);
        expressions = strings(numel(paths),1);
        statuses = repmat("OK", numel(paths), 1);
        messages = strings(numel(paths),1);
        for n = 1:numel(paths)
            try
                name = string(nameReader(char(paths(n))));
                if ~isscalar(name) || ismissing(name) || strlength(name) == 0
                    error('simtest:SpecificationDecisionBlockName', ...
                        'Block Name must be one nonempty value.');
                end
                names(n) = name;
            catch ME
                notes(end+1,1) = string(sprintf('%s Name: %s', paths(n), ME.message)); %#ok<AGROW>
                st_log(cfg, 'WARN', 'Specification decision block name read failed | Path=%s | %s', ...
                    paths(n), ME.message);
            end
            try
                [outcomes(n), expressions(n)] = ...
                    descriptorReader(char(paths(n)), char(blockType));
            catch ME
                outcomes(n) = outcomeDefaults(k);
                expressions(n) = "조건식 읽기 실패";
                statuses(n) = "WARN";
                messages(n) = string(ME.message);
                notes(end+1,1) = string(sprintf('%s Expression: %s', ...
                    paths(n), ME.message)); %#ok<AGROW>
                st_log(cfg, 'WARN', ...
                    'Specification decision block expression read failed | Path=%s | BlockType=%s | Outcome=%s | %s', ...
                    paths(n), blockType, outcomeDefaults(k), ME.message);
            end
        end
        records = [records; repmat(blockType, numel(paths), 1) names paths ...
            outcomes expressions statuses messages]; %#ok<AGROW>
        st_log(cfg, 'DEBUG', 'Specification decision block type scan end | CUT=%s | BlockType=%s | Count=%d', ...
            cutPath, blockType, numel(paths));
    catch ME
        message = string(sprintf('%s: %s', blockType, ME.message));
        notes(end+1,1) = message; %#ok<AGROW>
        st_log(cfg, 'WARN', 'Specification decision block type scan failed | CUT=%s | BlockType=%s | %s', ...
            cutPath, blockType, ME.message);
    end
end
if isempty(records)
    text = "[]";
    count = 0;
else
    records = unique(records, 'rows');
    records = sortrows(records, [3 1]);
    count = size(records,1);
    items = strings(count,1);
    for k = 1:count
        item = struct('BlockType', char(records(k,1)), ...
            'Name', char(records(k,2)), 'Path', char(records(k,3)), ...
            'Outcome', char(records(k,4)), ...
            'Expression', char(records(k,5)), ...
            'ExpressionStatus', char(records(k,6)), ...
            'Message', char(records(k,7)));
        items(k) = string(jsonencode(item));
    end
    text = "[" + newline + strjoin(items, "," + newline) + newline + "]";
end
note = strjoin(notes, ' | ');
st_log(cfg, 'INFO', 'Specification decision block scan end | CUT=%s | Count=%d | Warnings=%d', ...
    cutPath, count, numel(notes));
end

function name = read_name(path)
name = get_param(path, 'Name');
end
