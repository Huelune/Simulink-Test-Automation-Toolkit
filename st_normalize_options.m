function c = st_normalize_options(v)
%ST_NORMALIZE_OPTIONS Normalize a get_param options result to cellstr.

if isempty(v)
    c = {};
elseif iscell(v)
    c = cellfun(@char, v(:), 'UniformOutput', false);
elseif isstring(v)
    c = cellstr(v(:));
elseif ischar(v)
    if size(v,1) > 1
        c = cellstr(v);
    else
        c = {v};
    end
else
    c = cellstr(string(v(:)));
end

c = c(~cellfun(@isempty, c));
end
