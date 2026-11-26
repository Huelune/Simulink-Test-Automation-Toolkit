function [manifest, movedFrom] = st_rebase_standalone_manifest(manifest, pipelineRoot)
%ST_REBASE_STANDALONE_MANIFEST Point a moved run's recorded paths at where it is now.
%
% [manifest, movedFrom] = st_rebase_standalone_manifest(manifest, pipelineRoot)
%
% A pipeline manifest records absolute paths under the PipelineRoot the run
% was made in. When the run folder has been moved or copied, every
% top-level text field of the manifest and of each target that lies under
% the recorded root is rewritten under pipelineRoot, in memory only. Paths
% outside the recorded root (the bundle, say) stay as they are. movedFrom
% is the recorded root, or '' when the folder is where it was made or the
% manifest records no root. Nothing on disk is read or written.
movedFrom = '';
if ~isfield(manifest, 'PipelineRoot') || strlength(string(manifest.PipelineRoot)) == 0
    return;
end
recorded = st_absolute_path(manifest.PipelineRoot);
actual = st_absolute_path(pipelineRoot);
if strcmpi(recorded, actual)
    return;
end
movedFrom = recorded;
manifest = rebase_fields(manifest, recorded, actual);
if isfield(manifest, 'Targets') && isstruct(manifest.Targets)
    targets = manifest.Targets;
    for k = 1:numel(targets)
        targets(k) = rebase_fields(targets(k), recorded, actual);
    end
    manifest.Targets = targets;
end
end


function item = rebase_fields(item, recorded, actual)
names = fieldnames(item);
for i = 1:numel(names)
    value = item.(names{i});
    if ischar(value) && ~isempty(value)
        item.(names{i}) = rebase(value, recorded, actual);
    end
end
end


function value = rebase(value, recorded, actual)
% Only absolute paths: a word such as 'OK' would resolve against the
% current folder, which may lie inside the recorded root.
try
    if ~java.io.File(value).isAbsolute(), return; end
    path = st_absolute_path(value);
catch
    return;
end
if strcmpi(path, recorded)
    value = actual;
elseif startsWith(lower(path), lower([recorded filesep]))
    value = fullfile(actual, path(numel(recorded) + 2:end));
end
end
