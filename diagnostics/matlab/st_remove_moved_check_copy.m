function [removed, folder] = st_remove_moved_check_copy(cfg)
%ST_REMOVE_MOVED_CHECK_COPY Delete the copy st_check_moved_run_folder makes.
%
% [removed, folder] = st_remove_moved_check_copy(cfg)
%
% folder is <standalone root>_moved_check, next to the standalone root.
% Models loaded from it close without saving (they are copies), its MATLAB
% path entries come off, then it is deleted. The caller clears Test Manager
% first, since Test Manager may keep the copy's test file open. removed is
% false when there was no copy. If the folder is still there afterwards it
% raises simtest:MovedCheckCopyNotRemoved; the message carries no path.
folder = [regexprep(st_absolute_path(cfg.StandaloneCoverageRootDir), '[\\/]+$', '') '_moved_check'];
removed = false;
if ~isfolder(folder), return; end
models = find_system('type', 'block_diagram');
for k = 1:numel(models)
    try
        if under(get_param(models{k}, 'FileName'), folder), close_system(models{k}, 0); end
    catch
        % Already closed with a model that used it.
    end
end
entries = strsplit(path, pathsep);
inside = entries(cellfun(@(entry) under(entry, folder), entries));
if ~isempty(inside), rmpath(inside{:}); end
[done, ~] = rmdir(folder, 's');
if ~done || isfolder(folder)
    error('simtest:MovedCheckCopyNotRemoved', ...
        'The copy could not be deleted (a file in it is open elsewhere?).');
end
removed = true;
end


function flag = under(value, folder)
flag = strcmpi(value, folder) || startsWith(lower(value), lower([folder filesep]));
end
