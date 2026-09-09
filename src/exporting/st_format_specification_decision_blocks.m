function [specification, details] = st_format_specification_decision_blocks(specification, cfg)
%ST_FORMAT_SPECIFICATION_DECISION_BLOCKS Make the main list readable in Excel.
% The main DecisionBlocks cell contains a block Name line followed by a
% "D<number> [outcome]Type (expression)" line. DecisionBlockDetails retains
% structured fields and one JSON object per row so downstream processing
% does not depend on parsing the display.
if nargin < 2, cfg = []; end
headers = {'TestSpecificationRow','TestCaseName','CUTPath','Decision', ...
    'Outcome','BlockType','Name','Expression','Path','JSON','ReadStatus','Message'};
rows = strings(0, numel(headers));
columnNames = string(specification.Properties.VariableNames);
decisionIndex = find(columnNames == "DecisionBlocks", 1);
log_message(cfg, 'INFO', ...
    'Specification decision block formatting start | Rows=%d | HasColumn=%d', ...
    height(specification), ~isempty(decisionIndex));
if isempty(decisionIndex)
    details = array2table(rows, 'VariableNames', headers);
    log_message(cfg, 'INFO', ...
        'Specification decision block formatting end | Blocks=0 | Failures=0');
    return;
end

blockCount = 0;
failureCount = 0;
for row = 1:height(specification)
    raw = string(specification{row, decisionIndex});
    if ismissing(raw) || strlength(raw) == 0, raw = "[]"; end
    testCaseName = table_text(specification, row, "테스트 케이스명");
    cutPath = table_text(specification, row, "CUTPath");
    try
        decoded = jsondecode(char(raw));
        if ~isempty(decoded) && ~isstruct(decoded)
            error('simtest:SpecificationDecisionJSONShape', ...
                'DecisionBlocks JSON must be an array of objects.');
        end
    catch ME
        specification{row, decisionIndex} = "<DecisionBlocks JSON 파싱 실패>";
        rows(end+1,:) = detail_row(row, testCaseName, cutPath, "", ...
            "", "", "", "", "", raw, "FAIL", string(ME.message)); %#ok<AGROW>
        failureCount = failureCount + 1;
        log_message(cfg, 'WARN', ...
            'Specification decision block JSON parse failed | Row=%d | Case=%s | CUT=%s | %s', ...
            row + 1, testCaseName, cutPath, ME.message);
        continue;
    end

    if isempty(decoded)
        specification{row, decisionIndex} = "";
        rows(end+1,:) = detail_row(row, testCaseName, cutPath, "", ...
            "", "", "", "", "", "[]", "OK", ""); %#ok<AGROW>
        continue;
    end

    lines = strings(2 * numel(decoded),1);
    for k = 1:numel(decoded)
        decision = "D" + string(k);
        itemJson = string(jsonencode(decoded(k)));
        try
            blockType = json_text(decoded(k), 'BlockType');
            name = json_text(decoded(k), 'Name');
            path = json_text(decoded(k), 'Path');
            outcome = json_text(decoded(k), 'Outcome');
            expression = json_text(decoded(k), 'Expression');
            readStatus = json_text(decoded(k), 'ExpressionStatus');
            message = json_optional_text(decoded(k), 'Message');
            displayName = regexprep(strtrim(name), '\s+', ' ');
            displayType = decision_type(blockType);
            lines(2*k-1) = displayName;
            lines(2*k) = decision + " [" + outcome + "]" + ...
                displayType + " " + parenthesize(expression);
            rows(end+1,:) = detail_row(row, testCaseName, cutPath, decision, ...
                outcome, blockType, name, expression, path, itemJson, ...
                readStatus, message); %#ok<AGROW>
            blockCount = blockCount + 1;
        catch ME
            lines(2*k-1) = "<JSON 항목 파싱 실패>";
            lines(2*k) = decision + " <JSON 항목 파싱 실패>";
            rows(end+1,:) = detail_row(row, testCaseName, cutPath, decision, ...
                "", "", "", "", "", itemJson, "FAIL", string(ME.message)); %#ok<AGROW>
            failureCount = failureCount + 1;
            log_message(cfg, 'WARN', ...
                'Specification decision block item parse failed | Row=%d | Case=%s | Decision=%s | %s', ...
                row + 1, testCaseName, decision, ME.message);
        end
    end
    specification{row, decisionIndex} = strjoin(lines, newline);
end
details = array2table(rows, 'VariableNames', headers);
log_message(cfg, 'INFO', ...
    'Specification decision block formatting end | Blocks=%d | Failures=%d', ...
    blockCount, failureCount);
end

function row = detail_row(tableRow, testCaseName, cutPath, decision, ...
        outcome, blockType, name, expression, path, json, status, message)
row = [string(tableRow + 1) string(testCaseName) string(cutPath) ...
    string(decision) string(outcome) string(blockType) string(name) ...
    string(expression) string(path) string(json) string(status) string(message)];
end

function value = table_text(input, row, column)
index = find(string(input.Properties.VariableNames) == string(column), 1);
if isempty(index)
    value = "";
    return;
end
value = string(input{row,index});
if ismissing(value), value = ""; end
end

function value = json_text(item, field)
if ~isfield(item, field)
    error('simtest:SpecificationDecisionJSONField', ...
        'DecisionBlocks JSON item is missing %s.', field);
end
value = string(item.(field));
if ~isscalar(value) || ismissing(value) || strlength(value) == 0
    error('simtest:SpecificationDecisionJSONField', ...
        'DecisionBlocks JSON item %s must be one nonempty text value.', field);
end
end

function value = json_optional_text(item, field)
if ~isfield(item, field)
    value = "";
    return;
end
value = string(item.(field));
if ~isscalar(value) || ismissing(value)
    value = "";
end
end

function value = decision_type(blockType)
if blockType == "If"
    value = "IF";
else
    value = blockType;
end
end

function value = parenthesize(expression)
expression = strtrim(string(expression));
if startsWith(expression, "(") && endsWith(expression, ")")
    value = expression;
else
    value = "(" + expression + ")";
end
end

function log_message(cfg, level, format, varargin)
if isempty(cfg), return; end
st_log(cfg, level, format, varargin{:});
end
