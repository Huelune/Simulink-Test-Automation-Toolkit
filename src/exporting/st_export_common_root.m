function root = st_export_common_root(paths)
%ST_EXPORT_COMMON_ROOT Return a directory containing every supplied file.

if ischar(paths)
    paths = {paths};
else
    paths = cellstr(string(paths(:)));
end
paths = paths(~cellfun('isempty', paths));
if isempty(paths)
    error('simtest:EmptyExportPaths', ...
        'At least one path is required.');
end

canonical = cellfun(@canonical_path, paths, 'UniformOutput', false);
root = fileparts(canonical{1});
while ~all(cellfun(@(p) is_under_root(p, root), canonical))
    parent = fileparts(root);
    if isempty(parent) || strcmp(parent, root)
        error('simtest:NoCommonExportRoot', ...
            'Cannot determine a common dependency root.');
    end
    root = parent;
end
end

function tf = is_under_root(path, root)
path = comparable_path(path);
root = comparable_path(root);
prefix = root;
if isempty(prefix) || prefix(end) ~= filesep
    prefix = [prefix filesep];
end
tf = strcmp(path, root) || startsWith(path, prefix);
end

function value = comparable_path(value)
value = canonical_path(value);
if ispc
    value = lower(value);
end
end

function value = canonical_path(value)
value = char(java.io.File(char(string(value))).getCanonicalPath());
end
