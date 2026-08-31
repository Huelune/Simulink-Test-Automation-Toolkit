function relative = st_export_relative_path(path, root)
%ST_EXPORT_RELATIVE_PATH Return PATH relative to ROOT or fail safely.

path = canonical_path(path);
root = canonical_path(root);
comparisonPath = path;
comparisonRoot = root;
if ispc
    comparisonPath = lower(comparisonPath);
    comparisonRoot = lower(comparisonRoot);
end

if strcmp(comparisonPath, comparisonRoot)
    relative = '';
    return;
end
prefix = comparisonRoot;
if isempty(prefix) || prefix(end) ~= filesep
    prefix = [prefix filesep];
end
if ~startsWith(comparisonPath, prefix)
    error('simtest:PathOutsideExportRoot', ...
        'Path is outside the export root: %s', path);
end
relative = path(numel(prefix)+1:end);
end

function value = canonical_path(value)
value = char(java.io.File(char(string(value))).getCanonicalPath());
end
