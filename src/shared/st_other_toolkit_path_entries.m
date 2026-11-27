function entries = st_other_toolkit_path_entries(rootDir, pathEntries, setupFiles)
%ST_OTHER_TOOLKIT_PATH_ENTRIES MATLAB path entries that belong to another toolkit clone.
%
% entries = st_other_toolkit_path_entries(rootDir, pathEntries, setupFiles)
%
% setupFiles is which('st_setup', '-all'). Each folder holding st_setup.m,
% VERSION.txt and src, other than rootDir, is another toolkit clone (one
% per model) or a bundle or test copy of one. Its path entries, at or below
% that folder, are returned so st_setup can take them off: left behind this
% clone's, a function only the other clone has would still run. Entries at
% or below rootDir are kept even when rootDir sits inside the other clone
% (a git worktree does).
%
% Only a git checkout (rootDir holds .git, a folder or a worktree's file)
% takes anything off. A bundle's workspace or a test copy has no .git and
% returns nothing: the standalone bundle runner deletes its short workspace
% and then still calls toolkit functions, which the clone behind it
% supplies (2026-11-27, st_log undefined at the end of a standalone run).
entries = cell(1, 0);
if ~isfolder(fullfile(rootDir, '.git')) && ~isfile(fullfile(rootDir, '.git'))
    return;
end
others = {};
for k = 1:numel(cellstr(setupFiles))
    folder = fileparts(char(string(setupFiles(k))));
    if strcmpi(folder, rootDir) || ~isfile(fullfile(folder, 'VERSION.txt')) || ...
            ~isfolder(fullfile(folder, 'src'))
        continue;
    end
    others{end+1} = folder; %#ok<AGROW>
end
pathEntries = cellstr(pathEntries);
pick = false(size(pathEntries));
for k = 1:numel(others)
    pick = pick | cellfun(@(entry) under(entry, others{k}), pathEntries);
end
pick = pick & ~cellfun(@(entry) under(entry, rootDir), pathEntries);
entries = pathEntries(pick);
end


function flag = under(entry, folder)
flag = strcmpi(entry, folder) || startsWith(lower(entry), lower([folder filesep]));
end
