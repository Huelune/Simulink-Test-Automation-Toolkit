function [specification, details] = st_write_specification_workbook(specification, details, outputFile, cfg)
%ST_WRITE_SPECIFICATION_WORKBOOK Write wrapped XLSX with overflow references.
% Use native XLSX writing and OpenXML styles; Excel/ActiveX is not required.
if nargin < 4, cfg = []; end
if isfile(outputFile)
    error('simtest:SpecificationOutputExists', 'Output already exists: %s', outputFile);
end
overflow = strings(0,5);
usage = st_specification_usage_table(cfg);
[specification, decisionDetails] = ...
    st_format_specification_decision_blocks(specification, cfg);
[usage, overflow] = st_split_workbook_overflow( ...
    usage, '사용법', overflow, strings(0,1), "비고", cfg);
headers = string(specification.Properties.VariableNames);
if ~any(headers == "비고")
    error('simtest:SpecificationNoteColumn', ...
        'TestSpecification requires a 비고 column for overflow references.');
end
% These columns still have to read normally when they overflow, so their
% first chunk stays in the cell and only the reference moves to 비고.
primary = headers(headers == "input 시나리오 내용" | ...
    startsWith(headers, "verify 내용"));
[specification, overflow] = st_split_workbook_overflow( ...
    specification, 'TestSpecification', overflow, primary, "비고", cfg);
[details, overflow] = st_split_workbook_overflow( ...
    details, 'AssessmentDetails', overflow, strings(0,1), "비고", cfg);
[decisionDetails, overflow] = st_split_workbook_overflow( ...
    decisionDetails, 'DecisionBlockDetails', overflow, strings(0,1), "비고", cfg);
overflow = array2table(overflow, ...
    'VariableNames', {'Sheet','ExcelRow','Column','Part','Text'});
tables = {usage, specification, details, decisionDetails, overflow};
sheets = {'사용법', 'TestSpecification', 'AssessmentDetails', ...
    'DecisionBlockDetails', 'OverflowDetails'};
for i = 1:numel(tables)
    if height(tables{i}) > 1048575
        error('simtest:SpecificationRowLimit', 'Excel row limit exceeded: %s', sheets{i});
    end
    if width(tables{i}) > 16384
        error('simtest:SpecificationColumnLimit', 'Excel column limit exceeded: %s', sheets{i});
    end
end
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work, 's')); %#ok<NASGU>
book = fullfile(work, 'specification.xlsx');
widths = cell(1, numel(tables));
for i = 1:numel(tables)
    writetable(tables{i}, book, 'Sheet', sheets{i}, 'UseExcel', false);
    widths{i} = column_widths(string(tables{i}.Properties.VariableNames));
end
package = fullfile(work, 'package');
unzip(book, package);
st_apply_workbook_wrap_styles(package, widths);
archive = fullfile(work, 'wrapped.zip');
entries = dir(package);
names = {entries.name};
names = names(~ismember(names, {'.','..'}));
zip(archive, names, package);
folder = fileparts(outputFile);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
% No partially written workbook is published if writing or formatting fails.
if isfile(outputFile)
    error('simtest:SpecificationOutputExists', 'Output appeared during export: %s', outputFile);
end
[ok, message] = movefile(archive, outputFile);
if ~ok, error('simtest:SpecificationWrite', '%s', message); end
end


function widths = column_widths(headers)
% Give paths and long content readable widths. Order matters: the rules
% overlap and the last matching one wins.
widths = zeros(1, numel(headers));
for col = 1:numel(headers)
    w = 26;
    if ismember(headers(col), ["구분","직접실행"]), w = 18; end
    if headers(col) == "실행파일", w = 38; end
    if startsWith(headers(col), "verify 내용") || ismember(headers(col), ...
            ["input 시나리오 내용","DecisionBlocks","비고","OriginalAction","Transitions", ...
            "VerifySummary","Message","Name","Expression","Path","JSON","Text", ...
            "역할","사용시점","대표사용법"])
        w = 60;
    end
    widths(col) = w;
end
end
