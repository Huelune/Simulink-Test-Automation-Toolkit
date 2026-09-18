function st_apply_workbook_wrap_styles(package, columnWidths, options)
%ST_APPLY_WORKBOOK_WRAP_STYLES Wrap text, size columns and inject formulas.
% Works on an unzipped xlsx package so no Excel or ActiveX is required.
%
%   columnWidths  Cell array indexed by worksheet number. columnWidths{n}
%                 holds one width per column of xl/worksheets/sheetN.xml.
%                 [] leaves that sheet's own columns in place.
%   options       Optional struct. Every field defaults to doing nothing,
%                 so a two-argument call only wraps and sizes.
%     Formulas    Struct array with fields Sheet (worksheet name), Cell
%                 (an A1 reference), Formula (the text with no leading =),
%                 CachedValue (double) and Percent (logical). The cached
%                 value matters: LibreOffice does not recalculate an xlsx
%                 on open by default, so a formula without one reads blank.
%     LogConfig   Config for st_log, or [] for no logging.
if nargin < 3 || isempty(options), options = struct(); end
formulas = option_value(options, 'Formulas', struct([]));
cfg = option_value(options, 'LogConfig', []);

[wrappedOffset, percentIndex] = apply_styles(package, needs_percent(formulas));
apply_sheets(package, columnWidths, wrappedOffset, percentIndex, formulas, cfg);
if ~isempty(formulas)
    request_full_calculation(package);
end
drop_stale_calculation_chain(package, cfg);
end


function [wrappedOffset, percentIndex] = apply_styles(package, wantPercent)
% Clone every cell format and give the clone wrapped alignment, so the
% wrapped twin of format k is format k + wrappedOffset. A percent format is
% appended after the clones, which leaves that arithmetic untouched.
styleFile = fullfile(package, 'xl', 'styles.xml');
doc = xmlread(styleFile);
xfs = doc.getElementsByTagName('cellXfs').item(0);
styles = xfs.getElementsByTagName('xf');
wrappedOffset = styles.getLength();
for i = 0:wrappedOffset-1
    style = styles.item(i).cloneNode(true);
    set_wrapped_alignment(doc, style);
    xfs.appendChild(style);
end
percentIndex = -1;
appended = 0;
if wantPercent
    % numFmtId 10 is the built-in 0.00%. Built-in ids are implied, so no
    % numFmt element may be declared for them.
    percentStyle = styles.item(wrappedOffset).cloneNode(true);
    percentStyle.setAttribute('numFmtId', '10');
    percentStyle.setAttribute('applyNumberFormat', '1');
    xfs.appendChild(percentStyle);
    percentIndex = 2*wrappedOffset;
    appended = 1;
end
xfs.setAttribute('count', num2str(2*wrappedOffset + appended));
xmlwrite(styleFile, doc);
end


function set_wrapped_alignment(doc, style)
alignments = style.getElementsByTagName('alignment');
if alignments.getLength() == 0
    alignment = doc.createElementNS( ...
        doc.getDocumentElement().getNamespaceURI(), 'alignment');
    style.appendChild(alignment);
else
    alignment = alignments.item(0);
end
alignment.setAttribute('wrapText', '1');
alignment.setAttribute('vertical', 'top');
style.setAttribute('applyAlignment', '1');
end


function apply_sheets(package, columnWidths, wrappedOffset, percentIndex, formulas, cfg)
byFile = sheet_formula_map(package, formulas);
byName = containers.Map('KeyType', 'char', 'ValueType', 'char');
if isa(columnWidths, 'containers.Map')
    byName = worksheet_names(package);
end
files = dir(fullfile(package, 'xl', 'worksheets', 'sheet*.xml'));
for n = 1:numel(files)
    file = fullfile(files(n).folder, files(n).name);
    sheet = xmlread(file);
    shift_cell_styles(sheet, wrappedOffset);
    clear_row_heights(sheet);
    widths = widths_for(columnWidths, byName, files(n).name);
    if ~isempty(widths)
        rebuild_columns(sheet, widths);
    end
    % Formulas set the style index outright, so they must run after the
    % shift that moves every other cell onto its wrapped twin.
    if isKey(byFile, files(n).name)
        inject_formulas(sheet, byFile(files(n).name), percentIndex, file, cfg);
    end
    xmlwrite(file, sheet);
end
end


function widths = widths_for(columnWidths, byName, fileName)
% A cell array is indexed by the sheetN.xml number, which assumes the write
% order. A map is keyed by sheet name and does not.
widths = [];
if isa(columnWidths, 'containers.Map')
    if ~isKey(byName, fileName), return; end
    name = byName(fileName);
    if isKey(columnWidths, name), widths = columnWidths(name); end
    return;
end
if ~iscell(columnWidths), return; end
number = sscanf(fileName, 'sheet%d.xml');
if ~isempty(number) && number <= numel(columnWidths)
    widths = columnWidths{number};
end
end


function byName = worksheet_names(package)
byName = containers.Map('KeyType', 'char', 'ValueType', 'char');
located = sheet_files(package);
names = keys(located);
for i = 1:numel(names)
    byName(located(names{i})) = names{i};
end
end


function shift_cell_styles(sheet, wrappedOffset)
cells = sheet.getElementsByTagName('c');
for k = 0:cells.getLength()-1
    cellNode = cells.item(k);
    old = str2double(char(cellNode.getAttribute('s')));
    if isnan(old), old = 0; end
    cellNode.setAttribute('s', num2str(old + wrappedOffset));
end
end


function clear_row_heights(sheet)
% Let Excel calculate row heights and give paths/content readable widths.
rows = sheet.getElementsByTagName('row');
for k = 0:rows.getLength()-1
    rows.item(k).removeAttribute('ht');
    rows.item(k).removeAttribute('customHeight');
end
end


function rebuild_columns(sheet, widths)
columns = sheet.getElementsByTagName('cols');
if columns.getLength() > 0
    cols = columns.item(0);
    cols.getParentNode().removeChild(cols);
end
namespace = sheet.getDocumentElement().getNamespaceURI();
cols = sheet.createElementNS(namespace, 'cols');
for col = 1:numel(widths)
    item = sheet.createElementNS(namespace, 'col');
    item.setAttribute('min', num2str(col));
    item.setAttribute('max', num2str(col));
    item.setAttribute('width', num2str(widths(col)));
    item.setAttribute('customWidth', '1');
    cols.appendChild(item);
end
data = sheet.getElementsByTagName('sheetData').item(0);
data.getParentNode().insertBefore(cols, data);
end


function byFile = sheet_formula_map(package, formulas)
%SHEET_FORMULA_MAP Group the requested formulas by worksheet file.
byFile = containers.Map('KeyType', 'char', 'ValueType', 'any');
if isempty(formulas), return; end
located = sheet_files(package);
for i = 1:numel(formulas)
    name = char(string(formulas(i).Sheet));
    if ~isKey(located, name)
        error('simtest:WorkbookSheetMissing', ...
            'Worksheet not found in the workbook: %s', name);
    end
    key = located(name);
    if isKey(byFile, key)
        byFile(key) = [byFile(key) formulas(i)];
    else
        byFile(key) = formulas(i);
    end
end
end


function located = sheet_files(package)
% Resolve a worksheet name to its file name through the workbook
% relationships, rather than trusting sheetN.xml numbering to follow the
% order the sheets were written. The file name is the key because dir and
% fullfile can spell the same path differently.
located = containers.Map('KeyType', 'char', 'ValueType', 'char');
relationships = containers.Map('KeyType', 'char', 'ValueType', 'char');
rels = xmlread(fullfile(package, 'xl', '_rels', 'workbook.xml.rels'));
items = rels.getElementsByTagName('Relationship');
for i = 0:items.getLength()-1
    node = items.item(i);
    relationships(char(node.getAttribute('Id'))) = ...
        char(node.getAttribute('Target'));
end
book = xmlread(fullfile(package, 'xl', 'workbook.xml'));
sheets = book.getElementsByTagName('sheet');
for i = 0:sheets.getLength()-1
    node = sheets.item(i);
    id = char(node.getAttribute('r:id'));
    if ~isKey(relationships, id), continue; end
    parts = strsplit(strrep(relationships(id), char(92), '/'), '/');
    located(char(node.getAttribute('name'))) = char(parts{end});
end
end


function inject_formulas(sheet, entries, percentIndex, file, cfg)
refs = string({entries.Cell});
found = false(1, numel(entries));
namespace = sheet.getDocumentElement().getNamespaceURI();
cells = sheet.getElementsByTagName('c');
for k = 0:cells.getLength()-1
    node = cells.item(k);
    index = find(refs == string(char(node.getAttribute('r'))), 1);
    if isempty(index), continue; end
    found(index) = true;
    write_formula_cell(sheet, namespace, node, entries(index), percentIndex);
end
if all(found), return; end
% The writer creates these cells itself, so a missing one is a defect and
% would publish a document whose percentages never recalculate.
missingRefs = strjoin(cellstr(refs(~found)), ', ');
if ~isempty(cfg)
    st_log(cfg, 'ERROR', ...
        'Workbook formula cell missing | File=%s | Cells=%s', file, missingRefs);
end
error('simtest:WorkbookFormulaCellMissing', ...
    'Formula target cells are missing from %s: %s', file, missingRefs);
end


function write_formula_cell(sheet, namespace, node, entry, percentIndex)
% A formula cell must carry no type attribute: t="s" would make Excel read
% the result as a shared string index. The f element must precede v.
node.removeAttribute('t');
previous = node.getElementsByTagName('f');
while previous.getLength() > 0
    node.removeChild(previous.item(0));
end
formula = sheet.createElementNS(namespace, 'f');
formula.appendChild(sheet.createTextNode(char(string(entry.Formula))));
cached = sprintf('%.15g', entry.CachedValue);
values = node.getElementsByTagName('v');
if values.getLength() > 0
    value = values.item(0);
    while value.hasChildNodes()
        value.removeChild(value.getFirstChild());
    end
    value.appendChild(sheet.createTextNode(cached));
    node.insertBefore(formula, value);
else
    value = sheet.createElementNS(namespace, 'v');
    value.appendChild(sheet.createTextNode(cached));
    node.appendChild(formula);
    node.appendChild(value);
end
if entry.Percent && percentIndex >= 0
    node.setAttribute('s', num2str(percentIndex));
end
end


function request_full_calculation(package)
% In the CT_Workbook sequence calcPr follows sheets and definedNames. MATLAB
% writes none of the elements that would have to come after it.
file = fullfile(package, 'xl', 'workbook.xml');
doc = xmlread(file);
root = doc.getDocumentElement();
existing = root.getElementsByTagName('calcPr');
if existing.getLength() > 0
    node = existing.item(0);
else
    node = doc.createElementNS(root.getNamespaceURI(), 'calcPr');
    anchor = first_child_named(root, {'oleSize', 'customWorkbookViews', ...
        'pivotCaches', 'smartTagPr', 'smartTagTypes', 'webPublishing', ...
        'fileRecoveryPr', 'webPublishObjects', 'extLst'});
    if isempty(anchor)
        root.appendChild(node);
    else
        root.insertBefore(node, anchor);
    end
end
node.setAttribute('calcId', '0');
node.setAttribute('fullCalcOnLoad', '1');
xmlwrite(file, doc);
end


function anchor = first_child_named(root, names)
anchor = [];
children = root.getChildNodes();
for i = 0:children.getLength()-1
    node = children.item(i);
    if node.getNodeType() ~= 1, continue; end
    if any(strcmp(char(node.getNodeName()), names))
        anchor = node;
        return;
    end
end
end


function drop_stale_calculation_chain(package, cfg)
% MATLAB writes no formulas, so a calculation chain should not exist. One
% left by another writer would point at cells that no longer hold formulas,
% which Excel reports as unreadable content.
file = fullfile(package, 'xl', 'calcChain.xml');
if ~isfile(file), return; end
delete(file);
remove_matching_node(fullfile(package, '[Content_Types].xml'), ...
    'Override', 'PartName', '/xl/calcChain.xml');
remove_matching_node(fullfile(package, 'xl', '_rels', 'workbook.xml.rels'), ...
    'Relationship', 'Target', 'calcChain.xml');
if ~isempty(cfg)
    st_log(cfg, 'WARN', 'Workbook calculation chain removed | File=%s', file);
end
end


function remove_matching_node(file, tag, attribute, suffix)
if ~isfile(file), return; end
doc = xmlread(file);
items = doc.getElementsByTagName(tag);
for i = items.getLength()-1:-1:0
    node = items.item(i);
    if endsWith(char(node.getAttribute(attribute)), suffix)
        node.getParentNode().removeChild(node);
    end
end
xmlwrite(file, doc);
end


function value = option_value(options, name, fallback)
value = fallback;
if isstruct(options) && isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
end
end


function tf = needs_percent(formulas)
tf = false;
for i = 1:numel(formulas)
    if formulas(i).Percent
        tf = true;
        return;
    end
end
end
