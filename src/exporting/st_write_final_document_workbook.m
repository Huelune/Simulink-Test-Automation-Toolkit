function document = st_write_final_document_workbook(document, coverage, metadata, outputFile, cfg, usage)
%ST_WRITE_FINAL_DOCUMENT_WORKBOOK Publish the customer workbook atomically.
% Writes native XLSX and patches OpenXML, so no Excel or ActiveX is needed.
% The customer sheet has six literal hyphen headers that repeat, which no
% MATLAB table can carry as variable names, so every sheet is written with
% writecell from an explicit header row.
if nargin < 6, usage = []; end
if isfile(outputFile)
    error('simtest:FinalDocumentOutputExists', 'Output already exists: %s', outputFile);
end
naText = string(config_value(cfg, 'FinalDocumentNAText', 'N/A'));
overflow = strings(0,5);

% An overflowing customer cell still keeps its first chunk, so the sheet
% reads normally and only the reference moves to the result sheet.
[document.Sheet1, overflow, rowNotes] = st_split_workbook_overflow( ...
    document.Sheet1, 'TestCase', overflow, ...
    ["Description","Action","ExpectedResult","OutputValue"], "", cfg);
document.Results = merge_overflow_notes(document.Results, rowNotes);
[document.Results, overflow] = st_split_workbook_overflow( ...
    document.Results, 'TestResults', overflow, strings(0,1), "", cfg);

[coverageCells, formulas] = coverage_cells(coverage, naText);
sheets = {'TestCase', 'Coverage', 'TestResults', 'OverflowDetails', 'Metadata'};
payloads = {table_to_cells(document.Sheet1, document.DisplayHeaders), ...
    coverageCells, table_to_cells(document.Results, {}), ...
    overflow_cells(overflow), table_to_cells(metadata, {})};
widths = containers.Map();
widths('TestCase') = [26 8 8 14 60 60 60 8 8 8 8 60 12 38];
widths('Coverage') = [26 18 18 16 18 18 16];
widths('TestResults') = [8 26 26 26 12 10 60 60 12];
widths('OverflowDetails') = [18 12 26 8 60];
widths('Metadata') = [32 80];
if ~isempty(usage)
    sheets{end+1} = '사용법';
    payloads{end+1} = table_to_cells(usage, {});
    widths('사용법') = [18 38 18 60 60 60];
end
check_excel_limits(payloads, sheets);

st_log(cfg, 'INFO', 'Final document workbook write start | Sheets=%d | File=%s', ...
    numel(sheets), outputFile);
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work, 's')); %#ok<NASGU>
book = fullfile(work, 'final_document.xlsx');
for i = 1:numel(sheets)
    writecell(payloads{i}, book, 'Sheet', sheets{i}, 'UseExcel', false);
end
package = fullfile(work, 'package');
unzip(book, package);
options = struct('Formulas', formulas, 'LogConfig', cfg);
st_apply_workbook_wrap_styles(package, widths, options);
archive = fullfile(work, 'wrapped.zip');
entries = dir(package);
names = {entries.name};
names = names(~ismember(names, {'.','..'}));
zip(archive, names, package);
folder = fileparts(outputFile);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
% No partially written workbook is published if writing or formatting fails.
if isfile(outputFile)
    error('simtest:FinalDocumentOutputExists', 'Output appeared during export: %s', outputFile);
end
[ok, message] = movefile(archive, outputFile);
if ~ok, error('simtest:FinalDocumentWrite', '%s', message); end
st_log(cfg, 'INFO', 'Final document workbook write end | File=%s', outputFile);
end


function value = config_value(cfg, name, fallback)
value = fallback;
if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
    value = cfg.(name);
end
end


function check_excel_limits(payloads, sheets)
for i = 1:numel(payloads)
    if size(payloads{i}, 1) > 1048576
        error('simtest:FinalDocumentRowLimit', 'Excel row limit exceeded: %s', sheets{i});
    end
    if size(payloads{i}, 2) > 16384
        error('simtest:FinalDocumentColumnLimit', 'Excel column limit exceeded: %s', sheets{i});
    end
end
end


function results = merge_overflow_notes(results, rowNotes)
% The customer form has no remarks column, so an overflow reference goes to
% the result sheet next to the row it belongs to.
count = min(height(results), numel(rowNotes));
for i = 1:count
    if strlength(rowNotes(i)) == 0, continue; end
    existing = string(results.('확인 사유')(i));
    if ismissing(existing), existing = ""; end
    parts = [existing; rowNotes(i)];
    results.('확인 사유')(i) = strjoin(parts(strlength(parts) > 0), ' | ');
    results.('확인 필요')(i) = "Y";
end
end


function [cells, formulas] = coverage_cells(coverage, naText)
% The numerator and the denominator each get their own cell and the
% percentage is a real formula, so the reader can check the arithmetic.
headers = {'CUT', 'Execution Executed', 'Execution Total', 'Execution (%)', ...
    'Decision Executed', 'Decision Total', 'Decision (%)'};
count = height(coverage.Rows);
cells = cell(count + 1, numel(headers));
cells(1,:) = headers;
formulas = empty_formula_struct();
for i = 1:count
    row = i + 1;
    cells{row,1} = char(coverage.Rows.CUT(i));
    [cells(row,2:4), formulas] = metric_cells(formulas, row, 'B', 'C', 'D', ...
        coverage.Rows.ExecutionExecuted(i), coverage.Rows.ExecutionTotal(i), naText);
    [cells(row,5:7), formulas] = metric_cells(formulas, row, 'E', 'F', 'G', ...
        coverage.Rows.DecisionExecuted(i), coverage.Rows.DecisionTotal(i), naText);
end
end


function formulas = empty_formula_struct()
formulas = struct('Sheet', {}, 'Cell', {}, 'Formula', {}, ...
    'CachedValue', {}, 'Percent', {});
end


function [values, formulas] = metric_cells(formulas, row, executedColumn, totalColumn, percentColumn, executed, total, naText)
% A zero denominator is the normal state when the filter removed every
% objective, so it is N/A rather than a division error.
if isnan(executed) || isnan(total) || total <= 0
    values = {char(naText), char(naText), char(naText)};
    return;
end
values = {executed, total, executed/total};
formulas(end+1) = struct( ...
    'Sheet', 'Coverage', ...
    'Cell', sprintf('%s%d', percentColumn, row), ...
    'Formula', sprintf('%s%d/%s%d', executedColumn, row, totalColumn, row), ...
    'CachedValue', executed/total, ...
    'Percent', true); %#ok<AGROW>
end


function cells = overflow_cells(overflow)
headers = {'Sheet', 'ExcelRow', 'Column', 'Part', 'Text'};
cells = cell(size(overflow,1) + 1, numel(headers));
cells(1,:) = headers;
for row = 1:size(overflow,1)
    for col = 1:size(overflow,2)
        cells{row+1,col} = cell_value(overflow(row,col));
    end
end
end


function cells = table_to_cells(T, displayHeaders)
% writecell has no variable-name rules, so duplicated and hyphen headers
% survive and each cell keeps its own type.
if isempty(displayHeaders)
    displayHeaders = T.Properties.VariableNames;
end
cells = cell(height(T) + 1, width(T));
cells(1,:) = displayHeaders;
for row = 1:height(T)
    for col = 1:width(T)
        cells{row+1,col} = cell_value(T{row,col});
    end
end
end


function value = cell_value(item)
% Missing text and NaN both have to reach Excel as an empty cell. Numbers
% stay numbers so that Pre Condition round-trips as a double.
if iscell(item), item = item{1}; end
if isnumeric(item) || islogical(item)
    value = double(item);
    if isempty(value) || isnan(value), value = ''; end
    return;
end
text = string(item);
if isempty(text) || ismissing(text)
    value = '';
    return;
end
value = char(text);
end
