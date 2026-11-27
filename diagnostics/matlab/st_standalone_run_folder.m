function [outputRoot, pipelineId, how] = st_standalone_run_folder(folder)
%ST_STANDALONE_RUN_FOLDER Turn a chosen folder into the opener's OutputRoot and PipelineId.
%
% [outputRoot, pipelineId, how] = st_standalone_run_folder(folder)
%
% A standalone pipeline run folder holds pipeline-manifest.json: its parent
% is the OutputRoot and its name the PipelineId. The standalone root holds
% latest.json and stands for its latest run (PipelineId 'LATEST'). A folder
% picker easily lands one level off, so a folder inside a run folder stands
% for that run, and a folder holding exactly one run folder for that one.
% HOW says which: RUN, ROOT, INSIDE or HOLDS.
%
% A team submission tree (only the three category folders) holds no
% manifest and cannot be opened. Error messages carry no path, since the
% caller may print them.
if ~(ischar(folder) || isstring(folder)) || strlength(strtrim(string(folder))) == 0 ...
        || ~isfolder(folder)
    error('simtest:StandaloneFolderMissing', 'The chosen folder does not exist.');
end
folder = st_absolute_path(folder);
how = 'RUN';
run = '';
if isfile(fullfile(folder, 'pipeline-manifest.json'))
    run = folder;
elseif isfile(fullfile(folder, 'latest.json'))
    outputRoot = folder;
    pipelineId = 'LATEST';
    how = 'ROOT';
    return;
else
    run = enclosing_run(folder);
    how = 'INSIDE';
    if isempty(run)
        run = only_child_run(folder);
        how = 'HOLDS';
    end
end
if isempty(run)
    error('simtest:StandaloneFolderUnknown', ...
        'The folder is neither a standalone run folder nor the standalone root.');
end
[outputRoot, name, extension] = fileparts(run);
pipelineId = [name extension];
end


function run = enclosing_run(folder)
% Walks up from FOLDER; a team tree on the way stops it.
run = '';
current = folder;
while true
    if isfile(fullfile(current, 'pipeline-manifest.json'))
        run = current;
        return;
    end
    if is_team_tree(current)
        error('simtest:StandaloneFolderTeamTree', ...
            'A team submission tree holds no pipeline manifest.');
    end
    parent = fileparts(current);
    if isempty(parent) || strcmp(parent, current), return; end
    current = parent;
end
end


function run = only_child_run(folder)
run = '';
children = dir(folder);
children = children([children.isdir] & ~ismember({children.name}, {'.', '..'}));
runs = {};
for k = 1:numel(children)
    path = fullfile(folder, children(k).name);
    if isfile(fullfile(path, 'pipeline-manifest.json')), runs{end+1} = path; end %#ok<AGROW>
end
if numel(runs) > 1
    error('simtest:StandaloneFolderSeveralRuns', ...
        'The folder holds %d run folders. Choose one of them.', numel(runs));
end
if isscalar(runs), run = runs{1}; end
end


function tree = is_team_tree(folder)
% The same test as st_old_standalone_items' TREE.
children = dir(folder);
children = children(~ismember({children.name}, {'.', '..'}));
tree = ~isempty(children) && all([children.isdir]) && ...
    all(ismember({children.name}, {'테스트 케이스', '테스트 보고서', '프로젝트'}));
end
