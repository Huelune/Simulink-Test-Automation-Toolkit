function st_atomic_save(path, value)
%ST_ATOMIC_SAVE Replace a MAT file only after its complete staging write.
folder = fileparts(path);
if ~isfolder(folder), mkdir(folder); end
temporary = [tempname(folder) '.mat'];
cleanup = onCleanup(@() remove_temporary(temporary)); %#ok<NASGU>
save(temporary, '-struct', 'value');
[ok, message] = movefile(temporary, path, 'f');
if ~ok, error('simtest:SettingsWriteFailed', '%s', message); end
end

function remove_temporary(path)
if isfile(path), delete(path); end
end
