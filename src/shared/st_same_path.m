function same = st_same_path(left, right)
%ST_SAME_PATH Compare canonical local file paths without creating files.
same = false;
if isempty(left) || isempty(right), return; end
left = st_absolute_path(left); right = st_absolute_path(right);
if ispc, same = strcmpi(left,right); else, same = strcmp(left,right); end
end
