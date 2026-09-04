function expressions = st_indexed_expressions(baseName, dims, forceIndex)
%ST_INDEXED_EXPRESSIONS MATLAB column-major subscripts used by bus verifies.
if nargin < 3, forceIndex = false; end
dims = double(dims(:).');
if isempty(dims), dims = [1 1]; end
if any(~isfinite(dims) | dims < 1 | mod(dims, 1) ~= 0)
    error('simtest:InvalidDimensions', 'Dimensions must be positive integers.');
end
width = prod(dims);
if width == 1 && ~forceIndex
    expressions = {char(baseName)};
    return;
end
expressions = cell(width, 1);
for k = 1:width
    subs = cell(1, numel(dims));
    if numel(dims) == 1
        subs{1} = k;
    else
        [subs{:}] = ind2sub(dims, k);
    end
    indices = cellfun(@num2str, subs, 'UniformOutput', false);
    expressions{k} = sprintf('%s(%s)', baseName, strjoin(indices, ','));
end
end
