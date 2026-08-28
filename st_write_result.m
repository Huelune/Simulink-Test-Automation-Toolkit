function st_write_result(resultName, T)
%ST_WRITE_RESULT Persist a result table without modifying TestManagement.
%
% The management workbook is an input-only source in the normal workflow.
% Result tables are optional, standalone INI reports under
% cfg.ResultReportDir; no CSV/XLSX file is opened or written here.

cfg = st_config();

if ~logical(cfg.SaveResultFiles)
    return;
end

if ~istable(T)
    error('Result %s must be supplied as a table.', char(string(resultName)));
end

if ~isfolder(cfg.ResultReportDir)
    mkdir(cfg.ResultReportDir);
end

resultName = char(string(resultName));
reportPath = fullfile(cfg.ResultReportDir, [resultName '.ini']);
temporaryPath = [tempname(cfg.ResultReportDir) '.ini'];
cleanupTemporary = onCleanup(@() delete_file_quiet(temporaryPath));

fileId = fopen(temporaryPath, 'w', 'n', 'UTF-8');
if fileId < 0
    error('Cannot create result report: %s', temporaryPath);
end
closeFile = onCleanup(@() fclose_quiet(fileId));

fprintf(fileId, '; Simulink model test automation result\n');
fprintf(fileId, '[Result]\n');
fprintf(fileId, 'Name=%s\n', ini_value(resultName));
fprintf(fileId, 'GeneratedAt=%s\n', ini_value(char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss.SSS'))));
fprintf(fileId, 'Rows=%d\n', height(T));
fprintf(fileId, 'Columns=%s\n\n', ini_value(strjoin(T.Properties.VariableNames, ',')));

for row = 1:height(T)
    fprintf(fileId, '[Row%d]\n', row);
    for column = 1:width(T)
        name = T.Properties.VariableNames{column};
        fprintf(fileId, '%s=%s\n', name, ini_value(T{row, column}));
    end
    fprintf(fileId, '\n');
end

clear closeFile;

[moved, message] = movefile(temporaryPath, reportPath, 'f');
if ~moved
    error('Cannot replace result report %s: %s', reportPath, message);
end

clear cleanupTemporary;
end


function text = ini_value(value)

if iscell(value)
    values = cellfun(@ini_value, value(:), 'UniformOutput', false);
    text = ['{' strjoin(values, ',') '}'];
elseif isstring(value)
    text = char(strjoin(value(:).', ','));
elseif ischar(value)
    text = value;
elseif islogical(value)
    text = char(strjoin(string(value(:).'), ','));
elseif isnumeric(value)
    text = mat2str(value);
elseif isdatetime(value) || isduration(value) || iscategorical(value)
    text = char(string(value));
else
    try
        text = char(string(value));
    catch
        text = ['<' class(value) '>'];
    end
end

text = strrep(text, '\', '\\');
text = strrep(text, sprintf('\r\n'), '\n');
text = strrep(text, sprintf('\n'), '\n');
end


function fclose_quiet(fileId)

if fileId >= 0
    fclose(fileId);
end
end


function delete_file_quiet(filePath)

if isfile(filePath)
    delete(filePath);
end
end
