function [deleted, failed] = st_delete_harness_inputs(harnessNames, folders)
%ST_DELETE_HARNESS_INPUTS Delete the Signal Editor input MATs of the named Harnesses.
%
% [deleted, failed] = st_delete_harness_inputs(harnessNames, folders)
%
% sltest.harness.create writes <Harness>_HarnessInputs.mat into the current
% folder, and the Signal Editor stage may add a _prepared sibling. Deleting
% the Harness leaves them, so a rebuild from nothing deletes every
% <Harness>_HarnessInputs*.mat of the given names in the given folders
% (each folder once). Other files, the workbook's own data files included,
% are never matched. Returns how many were deleted and how many could not be.
deleted = 0;
failed = 0;
folders = unique(string(folders(:)), 'stable');
folders = folders(strlength(folders) > 0 & arrayfun(@isfolder, folders));
for f = 1:numel(folders)
    for h = 1:numel(harnessNames)
        name = char(string(harnessNames(h)));
        if isempty(strtrim(name)), continue; end
        found = dir(fullfile(char(folders(f)), [name '_HarnessInputs*.mat']));
        for k = 1:numel(found)
            path = fullfile(found(k).folder, found(k).name);
            try
                delete(path);
                if isfile(path), failed = failed + 1; else, deleted = deleted + 1; end
            catch
                failed = failed + 1;
            end
        end
    end
end
end
