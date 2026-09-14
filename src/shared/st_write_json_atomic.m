function st_write_json_atomic(file, value)
%ST_WRITE_JSON_ATOMIC Write JSON with staged replacement.
folder = fileparts(file);
if ~isfolder(folder), mkdir(folder); end
temporary = [tempname(folder) '.json'];
cleanup = onCleanup(@() remove_file(temporary)); %#ok<NASGU>
id = fopen(temporary,'w','n','UTF-8');
if id < 0, error('simtest:JsonWriteFailed','Cannot write %s',file); end
closer = onCleanup(@() fclose(id));
fprintf(id,'%s\n',jsonencode(value,'PrettyPrint',true));
clear closer;
[ok,message] = movefile(temporary,file,'f');
if ~ok, error('simtest:JsonWriteFailed','%s',message); end
end

function remove_file(file)
if isfile(file), delete(file); end
end
