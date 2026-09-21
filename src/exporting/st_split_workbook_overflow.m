function [output, overflow, rowNotes] = st_split_workbook_overflow( ...
        input, sheet, overflow, primaryColumns, noteColumn, cfg)
%ST_SPLIT_WORKBOOK_OVERFLOW Move oversized cells into an overflow sheet.
% A worksheet cell holds at most 32767 characters and 253 line breaks. Text
% beyond either limit is stored as numbered rows on the overflow sheet and
% the cell keeps a reference to them.
%
%   primaryColumns  Columns whose first chunk stays in the cell, so the
%                   sheet still reads normally. The reference goes to
%                   rowNotes instead. Other columns keep only the reference.
%   noteColumn      Column that collects rowNotes, or "" to leave the
%                   merging to the caller. The column itself is never split
%                   by the cell pass; it is split after the merge.
%   cfg             Config for st_log, or [] for no logging.
if nargin < 4 || isempty(primaryColumns), primaryColumns = strings(0,1); end
if nargin < 5, noteColumn = ""; end
if nargin < 6, cfg = []; end
primaryColumns = string(primaryColumns);
output = input;
headers = string(input.Properties.VariableNames);
noteIndex = [];
if strlength(string(noteColumn)) > 0
    noteIndex = find(headers == string(noteColumn), 1);
end
rowNotes = strings(height(input),1);
for row = 1:height(input)
    for col = 1:width(input)
        if col == noteIndex, continue; end
        value = input{row,col};
        % Numeric cells cannot overflow the text limits. Preserve their types,
        % especially MaxTime NaN, which writetable writes as an empty cell.
        % string(NaN) is missing and char(missing) throws in MATLAB.
        if isnumeric(value) || islogical(value), continue; end
        textValue = string(value);
        if ismissing(textValue)
            if isstring(value), output{row,col} = ""; end
            continue;
        end
        text = char(textValue);
        if numel(text) <= 32767 && sum(text == newline) <= 253, continue; end
        [overflow, firstPart, reference] = store_overflow( ...
            overflow, sheet, row, headers(col), text);
        primary = any(primaryColumns == headers(col));
        if primary
            output{row,col} = firstPart;
            rowNotes(row) = join_notes( ...
                rowNotes(row), headers(col) + " " + reference);
        else
            output{row,col} = reference;
        end
        if ~isempty(cfg)
            st_log(cfg, 'WARN', ...
                'Workbook cell overflow | Sheet=%s | Row=%d | Column=%s | PrimaryPreview=%d | Reference=%s', ...
                sheet, row + 1, headers(col), primary, reference);
        end
    end
end
if isempty(noteIndex), return; end
for row = 1:height(output)
    existing = string(output{row,noteIndex});
    if ismissing(existing), existing = ""; end
    combined = join_notes(rowNotes(row), existing);
    rowNotes(row) = combined;
    text = char(combined);
    if numel(text) <= 32767 && sum(text == newline) <= 253
        output{row,noteIndex} = combined;
        continue;
    end
    [overflow, firstPart, reference] = store_overflow( ...
        overflow, sheet, row, headers(noteIndex), text);
    output{row,noteIndex} = reference + " | " + firstPart;
    if ~isempty(cfg)
        st_log(cfg, 'WARN', ...
            'Workbook note overflow | Sheet=%s | Row=%d | Reference=%s', ...
            sheet, row + 1, reference);
    end
end
end


function [overflow, firstPart, reference] = store_overflow(overflow, sheet, row, column, text)
start = 1;
part = 0;
firstRow = size(overflow,1) + 2;
firstPart = "";
while start <= numel(text)
    last = min(start + 29999, numel(text));
    breaks = find(text(start:last) == newline);
    if numel(breaks) > 250, last = start + breaks(250) - 1; end
    % Do not split a UTF-16 surrogate pair between continuation rows.
    if last < numel(text) && double(text(last)) >= 55296 && double(text(last)) <= 56319
        last = last - 1;
    end
    part = part + 1;
    chunk = string(text(start:last));
    if part == 1, firstPart = chunk; end
    overflow(end+1,:) = [string(sheet) string(row+1) ...
        string(column) string(part) chunk]; %#ok<AGROW>
    start = last + 1;
end
reference = string(sprintf('[OverflowDetails!E%d:E%d]', ...
    firstRow, size(overflow,1)+1));
end


function value = join_notes(a, b)
parts = [string(a); string(b)];
value = strjoin(parts(strlength(parts) > 0), ' | ');
end
