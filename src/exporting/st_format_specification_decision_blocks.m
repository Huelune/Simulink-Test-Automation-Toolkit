function [specification, details, outcomeReasons] = st_format_specification_decision_blocks(specification, cfg, outcomeLookup)
%ST_FORMAT_SPECIFICATION_DECISION_BLOCKS Make the main list readable in Excel.
% The main DecisionBlocks cell contains a block Name line followed by a
% "D<number> [T/F]Type (expression)" line. The main cell prints T/F for every
% branch kind so the sheet reads uniformly as "a branch lives here".
% DecisionBlockDetails keeps the specific Outcome token together with the
% structured fields and one JSON object per row, so downstream processing
% does not depend on parsing the display.
%
% The final document passes OUTCOMELOOKUP (st_final_document_decision_outcomes).
% A two-way branch then shows what the row's test actually took: [T], [F],
% [T/F] or [-]. OUTCOMEREASONS says, per row, why a [T/F] was left in place.
% The specification export passes no lookup and its output is unchanged.
if nargin < 2, cfg = []; end
if nargin < 3, outcomeLookup = []; end
mainOutcome = "T/F";
outcomeReasons = repmat("", height(specification), 1);
headers = {'TestSpecificationRow','TestCaseName','CUTPath','Decision', ...
    'Outcome','BlockType','Name','Expression','Path','JSON','ReadStatus','Message'};
rows = strings(0, numel(headers));
displayCatalog = table(strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'BlockType','DisplayType','MainExpression'});
try
    fullCatalog = st_specification_decision_catalog();
    displayCatalog = fullCatalog(:, {'BlockType','DisplayType','MainExpression'});
    log_message(cfg, 'DEBUG', ...
        'Specification decision block display catalog loaded | Types=%d', ...
        height(displayCatalog));
catch ME
    log_message(cfg, 'WARN', ...
        'Specification decision block display catalog unavailable | %s | BlockType passthrough', ...
        ME.message);
end
unknownTypes = strings(0,1);
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

    % One block can contribute several branches, so the Name line is written
    % once per block and the D lines below it follow branch order.
    labels = repmat(mainOutcome, numel(decoded), 1);
    if ~isempty(outcomeLookup)
        [labels, outcomeReasons(row)] = outcome_labels(cfg, decoded, labels, ...
            cutPath, testCaseName, table_text(specification, row, "Iteration명"), ...
            outcomeLookup);
    end
    lines = strings(0,1);
    previousPath = string(missing);
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
            [displayType, knownType, showExpression] = ...
                display_type(blockType, displayCatalog);
            if ~knownType && ~any(unknownTypes == blockType)
                unknownTypes(end+1,1) = blockType; %#ok<AGROW>
                log_message(cfg, 'WARN', ...
                    'Specification decision block type not in catalog | Row=%d | Decision=%s | BlockType=%s', ...
                    row + 1, decision, blockType);
            end
            if ismissing(previousPath) || path ~= previousPath
                lines(end+1,1) = displayName; %#ok<AGROW>
            end
            previousPath = path;
            entry = decision + " [" + labels(k) + "]" + displayType;
            if showExpression
                entry = entry + " " + parenthesize(expression);
            end
            lines(end+1,1) = entry; %#ok<AGROW>
            rows(end+1,:) = detail_row(row, testCaseName, cutPath, decision, ...
                outcome, blockType, name, expression, path, itemJson, ...
                readStatus, message); %#ok<AGROW>
            blockCount = blockCount + 1;
        catch ME
            % The path may be the field that failed, so the next item cannot
            % assume it still belongs to the same block.
            previousPath = string(missing);
            lines(end+1,1) = "<JSON 항목 파싱 실패>"; %#ok<AGROW>
            lines(end+1,1) = decision + " <JSON 항목 파싱 실패>"; %#ok<AGROW>
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

function [labels, reason] = outcome_labels(cfg, decoded, labels, cutPath, ...
        testCaseName, iterationName, outcomeLookup)
% A block's D lines are paired with its recorded decisions by position, so
% a block whose counts differ keeps [T/F]: pairing anyway would put one
% branch's result on another.
reason = "";
paths = strings(numel(decoded), 1);
for k = 1:numel(decoded)
    paths(k) = json_optional_text(decoded(k), 'Path');
end
unavailable = false;
mismatch = false;
for path = unique(paths(strlength(paths) > 0), 'stable').'
    items = find(paths == path);
    try
        found = outcomeLookup(testCaseName, iterationName, ...
            st_cut_relative_path(path, cutPath));
    catch ME
        log_message(cfg, 'WARN', ...
            'Decision outcome lookup failed | Case=%s | Path=%s | %s', ...
            testCaseName, path, ME.message);
        continue;
    end
    if ~found.UnitFound
        unavailable = true;
        continue;
    end
    if isempty(found.Counts)
        continue;
    end
    if size(found.Counts, 1) ~= numel(items)
        mismatch = true;
        log_message(cfg, 'WARN', ...
            'Decision outcome count mismatch | Case=%s | Path=%s | Lines=%d | Decisions=%d', ...
            testCaseName, path, numel(items), size(found.Counts, 1));
        continue;
    end
    for j = 1:numel(items)
        labels(items(j)) = outcome_label(found.Counts(j,:));
    end
end
% Built without strjoin of an empty array, so no flag leaves "".
codes = ["DECISION_OUTCOME_UNAVAILABLE", "DECISION_OUTCOME_MISMATCH"];
if unavailable && mismatch
    reason = codes(1) + " | " + codes(2);
elseif unavailable
    reason = codes(1);
elseif mismatch
    reason = codes(2);
end
end


function label = outcome_label(counts)
tookTrue = counts(1) > 0;
tookFalse = counts(2) > 0;
if tookTrue && tookFalse
    label = "T/F";
elseif tookTrue
    label = "T";
elseif tookFalse
    label = "F";
else
    label = "-";
end
end


function [value, known, showExpression] = display_type(blockType, displayCatalog)
% An unknown type prints its own name and its expression, so re-formatting a
% workbook written by an older catalog keeps working instead of failing the
% row or silently dropping what it said.
index = find(string(displayCatalog.BlockType) == string(blockType), 1);
known = ~isempty(index);
showExpression = true;
if known
    value = string(displayCatalog.DisplayType(index));
    showExpression = string(displayCatalog.MainExpression(index)) ~= "HIDE";
else
    value = string(blockType);
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
