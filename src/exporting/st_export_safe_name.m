function value = st_export_safe_name(value)
%ST_EXPORT_SAFE_NAME Convert a label to a portable file or folder name.

value = regexprep(char(string(value)), '[^A-Za-z0-9_-]+', '_');
value = regexprep(value, '^_+|_+$', '');
if isempty(value)
    value = 'item';
end
if numel(value) > 80
    value = value(1:80);
end
end
