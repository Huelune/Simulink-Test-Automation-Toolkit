function path = st_absolute_path(value)
%ST_ABSOLUTE_PATH Canonicalize an explicit path without creating it.
value = string(value);
if ~isscalar(value) || ismissing(value) || strlength(strtrim(value)) == 0
    error('simtest:PathRequired', 'A non-empty scalar path is required.');
end
path = char(java.io.File(char(value)).getCanonicalPath());
end
