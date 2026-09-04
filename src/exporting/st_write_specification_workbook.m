function st_write_specification_workbook(specification, details, outputFile)
%ST_WRITE_SPECIFICATION_WORKBOOK Write wrapped XLSX with lossless cell overflow.
% Use native XLSX writing and OpenXML styles; Excel/ActiveX is not required.
if isfile(outputFile)
    error('simtest:SpecificationOutputExists', 'Output already exists: %s', outputFile);
end
overflow = strings(0,5);
[specification, overflow] = split_cells(specification, 'TestSpecification', overflow);
[details, overflow] = split_cells(details, 'AssessmentDetails', overflow);
overflow = array2table(overflow, 'VariableNames', {'Sheet','ExcelRow','Column','Part','Text'});
tables = {specification, details, overflow};
sheets = {'TestSpecification', 'AssessmentDetails', 'OverflowDetails'};
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

function [output, overflow] = split_cells(input, sheet, overflow)
output = input;
for row = 1:height(input)
    for col = 1:width(input)
        text = char(string(input{row,col}));
        % Excel also limits the number of line feeds per cell to 253.
        if numel(text) <= 32767 && sum(text == newline) <= 253, continue; end
        part = 0;
        start = 1;
        firstRow = size(overflow,1) + 2;
        while start <= numel(text)
            last = min(start + 29999, numel(text));
            breaks = find(text(start:last) == newline);
            if numel(breaks) > 250, last = start + breaks(250) - 1; end
            % Do not split a UTF-16 surrogate pair between continuation rows.
            if last < numel(text) && double(text(last)) >= 55296 && double(text(last)) <= 56319
                last = last - 1;
            end
            part = part + 1;
            overflow(end+1,:) = [string(sheet) string(row+1) ...
                string(input.Properties.VariableNames{col}) string(part) string(text(start:last))]; %#ok<AGROW>
            start = last + 1;
        end
        output{row,col} = string(sprintf('[OverflowDetails!E%d:E%d]', ...
            firstRow, size(overflow,1)+1));
    end
end
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
        if startsWith(headers(col), "verify 내용") || ismember(headers(col), ...
                ["input 시나리오 내용","비고","OriginalAction","Transitions", ...
                "VerifySummary","Message","Text"])
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
