function [items, kept] = st_old_standalone_items(root)
%ST_OLD_STANDALONE_ITEMS What under the standalone root a clean start may delete.
%
% [items, kept] = st_old_standalone_items(root)
%
% items is a table of Path and Kind for the entries directly under root that
% the toolkit made:
%   RUN     a pipeline run folder (it holds pipeline-manifest.json)
%   TREE    a team submission tree (it holds nothing but the three category
%           folders, at least one of them)
%   LATEST  the latest.json pointer
% kept counts every other entry; they are left alone. A missing root gives
% no items. Nothing is deleted here.
items = table(strings(0, 1), strings(0, 1), 'VariableNames', {'Path', 'Kind'});
kept = 0;
if ~isfolder(root), return; end
categories = {'테스트 케이스', '테스트 보고서', '프로젝트'};
entries = dir(root);
entries = entries(~ismember({entries.name}, {'.', '..'}));
for k = 1:numel(entries)
    path = string(fullfile(root, entries(k).name));
    kind = "";
    if entries(k).isdir
        children = dir(path);
        children = children(~ismember({children.name}, {'.', '..'}));
        if isfile(fullfile(path, 'pipeline-manifest.json'))
            kind = "RUN";
        elseif ~isempty(children) && all([children.isdir]) && all(ismember({children.name}, categories))
            kind = "TREE";
        end
    elseif strcmpi(entries(k).name, 'latest.json')
        kind = "LATEST";
    end
    if kind == ""
        kept = kept + 1;
    else
        items(end+1, :) = {path, kind}; %#ok<AGROW>
    end
end
end
