function st_write_json_atomic(path, value)
%ST_WRITE_JSON_ATOMIC Replace a UTF-8 JSON file through a temporary file.

folder = fileparts(path);
if ~isfolder(folder), mkdir(folder); end
temporary = [tempname(folder) '.json'];
cleanup = onCleanup(@() delete_if_present(temporary)); %#ok<NASGU>
fileId = fopen(temporary, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:JsonWriteFailed', 'Cannot open JSON output: %s', path);
end
fileCleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(value, 'PrettyPrint', true));
clear fileCleanup;
[ok, message] = movefile(temporary, path, 'f');
if ~ok
    error('simtest:JsonWriteFailed', ...
        'Cannot replace JSON output %s: %s', path, message);
end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end
