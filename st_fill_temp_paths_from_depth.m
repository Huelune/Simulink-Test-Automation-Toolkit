function R = st_fill_temp_paths_from_depth(overwriteExisting)
%ST_FILL_TEMP_PATHS_FROM_DEPTH Compatibility wrapper.
%
% The previous v0.9 implementation interpreted a numeric Depth column.
% The intended behavior is to read the native Excel indentation of CUTName.
% Use st_fill_temp_paths_from_indent for new code.

warning( ...
    ['st_fill_temp_paths_from_depth is deprecated. ' ...
     'Using Excel native IndentLevel via st_fill_temp_paths_from_indent.']);

if nargin < 1
    R = st_fill_temp_paths_from_indent();
else
    R = st_fill_temp_paths_from_indent(overwriteExisting);
end

end
