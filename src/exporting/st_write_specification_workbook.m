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
[usage, overflow] = split_cells( ...
    usage, '사용법', overflow, cfg, false);
[specification, overflow] = split_cells( ...
    specification, 'TestSpecification', overflow, cfg, true);
[details, overflow] = split_cells( ...
    details, 'AssessmentDetails', overflow, cfg, false);
[decisionDetails, overflow] = split_cells( ...
    decisionDetails, 'DecisionBlockDetails', overflow, cfg, false);
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
for i = 1:numel(tables)
    writetable(tables{i}, book, 'Sheet', sheets{i}, 'UseExcel', false);
end
package = fullfile(work, 'package');
unzip(book, package);
wrap_styles(package, tables);
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

function [output, overflow] = split_cells(input, sheet, overflow, cfg, keepFirstForPrimary)
output = input;
headers = string(input.Properties.VariableNames);
noteIndex = find(headers == "비고", 1);
if keepFirstForPrimary && isempty(noteIndex)
    error('simtest:SpecificationNoteColumn', ...
        'TestSpecification requires a 비고 column for overflow references.');
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
        primary = keepFirstForPrimary && ...
            (headers(col) == "input 시나리오 내용" || startsWith(headers(col), "verify 내용"));
        if primary
            output{row,col} = firstPart;
            rowNotes(row) = join_notes(rowNotes(row), headers(col) + " " + reference);
        else
            output{row,col} = reference;
        end
        if ~isempty(cfg)
            st_log(cfg, 'WARN', ...
                'Specification cell overflow | Sheet=%s | Row=%d | Column=%s | PrimaryPreview=%d | Reference=%s', ...
                sheet, row + 1, headers(col), primary, reference);
        end
    end
end
if isempty(noteIndex), return; end
for row = 1:height(output)
    existing = string(output{row,noteIndex});
    if ismissing(existing), existing = ""; end
    combined = join_notes(rowNotes(row), existing);
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
            'Specification note overflow | Sheet=%s | Row=%d | Reference=%s', ...
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

function wrap_styles(package, tables)
styleFile = fullfile(package, 'xl', 'styles.xml');
doc = xmlread(styleFile);
xfs = doc.getElementsByTagName('cellXfs').item(0);
styles = xfs.getElementsByTagName('xf');
count = styles.getLength();
for i = 0:count-1
    style = styles.item(i).cloneNode(true);
    alignments = style.getElementsByTagName('alignment');
    if alignments.getLength() == 0
        alignment = doc.createElementNS(doc.getDocumentElement().getNamespaceURI(), 'alignment');
        style.appendChild(alignment);
    else
        alignment = alignments.item(0);
    end
    alignment.setAttribute('wrapText', '1');
    alignment.setAttribute('vertical', 'top');
    style.setAttribute('applyAlignment', '1');
    xfs.appendChild(style);
end
xfs.setAttribute('count', num2str(2*count));
xmlwrite(styleFile, doc);
files = dir(fullfile(package, 'xl', 'worksheets', 'sheet*.xml'));
for n = 1:numel(files)
    sheetNumber = sscanf(files(n).name, 'sheet%d.xml');
    headers = string(tables{sheetNumber}.Properties.VariableNames);
    file = fullfile(files(n).folder, files(n).name);
    sheet = xmlread(file);
    cells = sheet.getElementsByTagName('c');
    for k = 0:cells.getLength()-1
        cellNode = cells.item(k);
        old = str2double(char(cellNode.getAttribute('s')));
        if isnan(old), old = 0; end
        cellNode.setAttribute('s', num2str(old + count));
    end
    % Let Excel calculate row heights and give paths/content readable widths.
    rows = sheet.getElementsByTagName('row');
    for k = 0:rows.getLength()-1
        rows.item(k).removeAttribute('ht');
        rows.item(k).removeAttribute('customHeight');
    end
    columns = sheet.getElementsByTagName('cols');
    if columns.getLength() > 0
        cols = columns.item(0);
        cols.getParentNode().removeChild(cols);
    end
    namespace = sheet.getDocumentElement().getNamespaceURI();
    cols = sheet.createElementNS(namespace, 'cols');
    for col = 1:numel(headers)
        item = sheet.createElementNS(namespace, 'col');
        item.setAttribute('min', num2str(col));
        item.setAttribute('max', num2str(col));
        w = 26;
        if ismember(headers(col), ["구분","직접실행"]), w = 18; end
        if headers(col) == "실행파일", w = 38; end
        if startsWith(headers(col), "verify 내용") || ismember(headers(col), ...
                ["input 시나리오 내용","DecisionBlocks","비고","OriginalAction","Transitions", ...
                "VerifySummary","Message","Name","Expression","Path","JSON","Text", ...
                "역할","사용시점","대표사용법"])
            w = 60;
        end
        item.setAttribute('width', num2str(w));
        item.setAttribute('customWidth', '1');
        cols.appendChild(item);
    end
    data = sheet.getElementsByTagName('sheetData').item(0);
    data.getParentNode().insertBefore(cols, data);
    xmlwrite(file, sheet);
end
end
