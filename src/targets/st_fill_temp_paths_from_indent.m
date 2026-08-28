function R = st_fill_temp_paths_from_indent(overwriteExisting)
%ST_FILL_TEMP_PATHS_FROM_INDENT Build temporary CUTPath from Excel indentation.
%
% This helper reads the native Excel IndentLevel of each CUTName cell in
% TestManagement.xlsx / Targets and converts the visual hierarchy into one
% path string per row.
%
% Important:
% - CUTName text is preserved exactly, including trailing whitespace.
% - No space characters or '-' prefixes are parsed from CUTName.
% - The hierarchy source is the Excel cell's native IndentLevel property.
% - This is only a temporary path builder. It does not infer or search for
%   the correct duplicated Subsystem in the Simulink model.
% - If indentation is wrong, correct CUTPath manually afterward.
% - Disabled rows still participate in hierarchy construction so a child
%   can inherit a disabled parent row's hierarchy.
%
% Usage:
%   R = st_fill_temp_paths_from_indent();
%   R = st_fill_temp_paths_from_indent(true);
%   R = st_fill_temp_paths_from_indent(false);

baseCfg = st_config();

if ~baseCfg.HasRuntimeTarget || ...
        isempty(baseCfg.ModelFile) || ...
        ~isfile(baseCfg.ModelFile)

    st_select_target_model(false);
end

cfg = st_require_runtime_target();

if nargin < 1
    overwriteExisting = cfg.IndentPathOverwriteExisting;
else
    overwriteExisting = logical(overwriteExisting);
end


%% ============================================================
% Read Targets values
%% ============================================================

if ~isfile(cfg.ManagementExcel)
    error('Management Excel not found: %s', cfg.ManagementExcel);
end

raw = ...
    readcell( ...
        cfg.ManagementExcel, ...
        'Sheet', cfg.ManagementSheet);

if isempty(raw) || size(raw,1) < 2
    error('Targets sheet is empty: %s', cfg.ManagementSheet);
end

headers = string(raw(1,:));

idxCUTName = ...
    st_indent_find_column( ...
        headers, ...
        {'CUTName','ModelName','모델명','CUT','대상모델명'});

idxCUTPath = ...
    st_indent_find_column( ...
        headers, ...
        {'CUTPath','Path','path','경로','모델경로'});

idxEnabled = ...
    st_indent_find_column_optional( ...
        headers, ...
        {'Enabled','사용','사용여부','활성','활성화'});

rowCount = size(raw,1) - 1;

cutPathColumn = raw(2:end, idxCUTPath);

for k = 1:numel(cutPathColumn)

    if st_indent_cell_is_missing(cutPathColumn{k})
        cutPathColumn{k} = '';
    end
end


%% ============================================================
% Read native Excel IndentLevel
%% ============================================================

indentLevels = ...
    st_indent_read_levels( ...
        cfg.ManagementExcel, ...
        cfg.ManagementSheet, ...
        idxCUTName, ...
        rowCount);


%% ============================================================
% Result buffers
%% ============================================================

ExcelRow = zeros(rowCount,1);
CUTName = strings(rowCount,1);
IndentLevel = nan(rowCount,1);
ExistingPath = strings(rowCount,1);
TemporaryRelativePath = strings(rowCount,1);
TemporaryPath = strings(rowCount,1);
WrittenPath = strings(rowCount,1);
Status = strings(rowCount,1);
Message = strings(rowCount,1);
Timestamp = strings(rowCount,1);


%% ============================================================
% Convert indentation hierarchy to one-line paths
%% ============================================================

stackIndent = [];
stackName = {};

fprintf('\n');
fprintf('============================================\n');
fprintf('Temporary CUTPath From Excel IndentLevel\n');
fprintf('Model     : %s\n', cfg.TopModel);
fprintf('Sheet     : %s\n', cfg.ManagementSheet);
fprintf('Overwrite : %d\n', overwriteExisting);
fprintf('============================================\n');

for dataRow = 1:rowCount

    excelRow = dataRow + 1;
    ExcelRow(dataRow) = excelRow;

    % Preserve CUTName whitespace exactly. A trailing space may be part of
    % the actual Simulink block name.
    cutName = ...
        st_indent_cell_text( ...
            raw{excelRow, idxCUTName});

    CUTName(dataRow) = string(cutName);

    % Preserve an existing CUTPath exactly for the same reason.
    currentPath = ...
        st_indent_cell_text( ...
            raw{excelRow, idxCUTPath});

    ExistingPath(dataRow) = string(currentPath);

    indentLevel = indentLevels(dataRow);
    IndentLevel(dataRow) = indentLevel;

    enabled = true;

    if ~isempty(idxEnabled)

        enabled = ...
            st_indent_enabled_value( ...
                raw{excelRow, idxEnabled});
    end

    if isempty(strtrim(cutName))

        Status(dataRow) = 'SKIP_EMPTY_NAME';
        Message(dataRow) = 'CUTName is empty';
        Timestamp(dataRow) = st_indent_timestamp();

        continue;
    end

    if ~isfinite(indentLevel) || ...
            indentLevel < 0 || ...
            floor(indentLevel) ~= indentLevel

        Status(dataRow) = 'INVALID_INDENT';
        Message(dataRow) = 'Excel IndentLevel is invalid';
        Timestamp(dataRow) = st_indent_timestamp();

        continue;
    end

    %% Keep only preceding rows that are true indentation ancestors.
    keepCount = numel(stackIndent);

    while keepCount > 0 && ...
            stackIndent(keepCount) >= indentLevel

        keepCount = keepCount - 1;
    end

    stackIndent = stackIndent(1:keepCount);
    stackName = stackName(1:keepCount);

    %% Build one-line relative and full paths.
    relativeComponents = ...
        [stackName {cutName}];

    escapedRelative = ...
        cell(size(relativeComponents));

    for c = 1:numel(relativeComponents)

        escapedRelative{c} = ...
            st_indent_escape_block_name( ...
                relativeComponents{c});
    end

    relativePath = ...
        strjoin( ...
            escapedRelative, ...
            '/');

    fullPath = ...
        [st_indent_escape_block_name(cfg.TopModel) '/' relativePath];

    TemporaryRelativePath(dataRow) = string(relativePath);
    TemporaryPath(dataRow) = string(fullPath);

    %% Decide whether CUTPath is written.
    shouldWrite = true;

    if cfg.OnlyEnabled && ~enabled

        shouldWrite = false;
        Status(dataRow) = 'SKIP_DISABLED';
        Message(dataRow) = ...
            'Used as indentation hierarchy context only';
    end

    if shouldWrite && ...
            ~overwriteExisting && ...
            ~isempty(strtrim(currentPath))

        shouldWrite = false;
        Status(dataRow) = 'SKIP_EXISTING';
        Message(dataRow) = 'Existing CUTPath preserved';
    end

    if shouldWrite

        cutPathColumn{dataRow} = fullPath;
        WrittenPath(dataRow) = string(fullPath);
        Status(dataRow) = 'TEMP_WRITTEN';
        Message(dataRow) = ...
            'Built from Excel native IndentLevel';

    else

        WrittenPath(dataRow) = string(currentPath);
    end

    %% Current row is available as an ancestor for following deeper rows.
    stackIndent(end+1) = indentLevel; %#ok<AGROW>
    stackName{end+1} = cutName; %#ok<AGROW>

    Timestamp(dataRow) = ...
        st_indent_timestamp();

    fprintf( ...
        '[%d] indent=%d | %s | %s\n', ...
        excelRow, ...
        indentLevel, ...
        relativePath, ...
        char(Status(dataRow)));
end


%% ============================================================
% Write CUTPath only
%% ============================================================

range = ...
    sprintf( ...
        '%s2:%s%d', ...
        st_indent_excel_column_name(idxCUTPath), ...
        st_indent_excel_column_name(idxCUTPath), ...
        rowCount + 1);

writecell( ...
    cutPathColumn, ...
    cfg.ManagementExcel, ...
    'Sheet', cfg.ManagementSheet, ...
    'Range', range);


%% ============================================================
% Result table
%% ============================================================

R = table( ...
    ExcelRow, ...
    CUTName, ...
    IndentLevel, ...
    ExistingPath, ...
    TemporaryRelativePath, ...
    TemporaryPath, ...
    WrittenPath, ...
    Status, ...
    Message, ...
    Timestamp);

try

    st_write_result( ...
        cfg.IndentPathResultSheet, ...
        R);

catch ME

    warning( ...
        'Could not write IndentPathResult log: %s', ...
        ME.message);
end

fprintf('\n');
fprintf('============================================\n');
fprintf('Temporary CUTPath generation complete\n');
fprintf('Result sheet : %s\n', cfg.IndentPathResultSheet);
fprintf('Written      : %d\n', sum(strcmp(Status, 'TEMP_WRITTEN')));
fprintf('Preserved    : %d\n', sum(strcmp(Status, 'SKIP_EXISTING')));
fprintf('============================================\n');

end


function levels = st_indent_read_levels( ...
    excelFile, ...
    sheetName, ...
    cutNameColumn, ...
    rowCount)

levels = nan(rowCount,1);
excel = [];
workbook = [];

try

    excel = ...
        actxserver('Excel.Application');

    excel.Visible = false;
    excel.DisplayAlerts = false;

    workbook = ...
        excel.Workbooks.Open( ...
            excelFile, ...
            0, ...
            true);

    worksheet = ...
        workbook.Worksheets.Item(sheetName);

    for dataRow = 1:rowCount

        excelRow = dataRow + 1;

        value = ...
            worksheet.Cells.Item( ...
                excelRow, ...
                cutNameColumn).IndentLevel;

        levels(dataRow) = ...
            double(value);
    end

    workbook.Close(false);
    workbook = [];

    excel.Quit();
    delete(excel);
    excel = [];

catch ME

    if ~isempty(workbook)

        try
            workbook.Close(false);
        catch
        end
    end

    if ~isempty(excel)

        try
            excel.Quit();
        catch
        end

        try
            delete(excel);
        catch
        end
    end

    error( ...
        ['Could not read native Excel IndentLevel. ' ...
         'Microsoft Excel desktop is required. Original error: %s'], ...
        ME.message);
end

end


function idx = st_indent_find_column(headers, aliases)

idx = ...
    st_indent_find_column_optional( ...
        headers, ...
        aliases);

if isempty(idx)

    error( ...
        'Required Excel column not found. Accepted names: %s', ...
        strjoin(aliases, ', '));
end

end


function idx = st_indent_find_column_optional(headers, aliases)

idx = [];
normalizedHeaders = lower(strtrim(headers));

for i = 1:numel(aliases)

    alias = ...
        lower( ...
            strtrim( ...
                string(aliases{i})));

    match = ...
        find( ...
            normalizedHeaders == alias, ...
            1, ...
            'first');

    if ~isempty(match)

        idx = match;
        return;
    end
end

end


function text = st_indent_cell_text(value)

if st_indent_cell_is_missing(value)

    text = '';
    return;
end

if ischar(value)

    text = value;

elseif isstring(value)

    if isempty(value) || ismissing(value)
        text = '';
    else
        text = char(value(1));
    end

else

    text = char(string(value));
end

end


function tf = st_indent_cell_is_missing(value)

tf = isempty(value);

if tf
    return;
end

try

    missingMask = ismissing(value);
    tf = all(missingMask(:));

catch

    tf = false;
end

end


function tf = st_indent_enabled_value(value)

if st_indent_cell_is_missing(value)

    tf = false;
    return;
end

if islogical(value)

    tf = value(1);

elseif isnumeric(value)

    tf = ...
        isfinite(value(1)) && ...
        value(1) ~= 0;

else

    s = ...
        lower( ...
            strtrim( ...
                string(value)));

    tf = ...
        ismember( ...
            s, ...
            {'true','1','yes','y','on','사용','o'});
end

end


function out = st_indent_escape_block_name(value)

out = ...
    strrep( ...
        char(value), ...
        '/', ...
        '//');

end


function name = st_indent_excel_column_name(index)

name = '';

while index > 0

    remainder = ...
        mod(index - 1, 26);

    name = ...
        [char(65 + remainder) name]; %#ok<AGROW>

    index = ...
        floor((index - 1) / 26);
end

end


function value = st_indent_timestamp()

value = ...
    string( ...
        datestr( ...
            now, ...
            'yyyy-mm-dd HH:MM:SS'));

end
