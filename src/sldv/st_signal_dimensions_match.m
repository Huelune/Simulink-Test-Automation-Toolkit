function tf = st_signal_dimensions_match(actual, expected, dataType)
%ST_SIGNAL_DIMENSIONS_MATCH Compare signal dimensions for input reuse.

actual = double(actual(:).');
expected = double(expected(:).');

if isequal(actual, expected)
    tf = true;
    return;
end

% Signal Editor accepts row/column representations of the same non-scalar
% one-dimensional array of buses. Keep all numeric and true matrix signals
% strict so that only the observed bus-vector orientation difference passes.
tf = strcmpi(char(string(dataType)), 'bus') && ...
    numel(actual) == 2 && numel(expected) == 2 && ...
    prod(actual) > 1 && prod(actual) == prod(expected) && ...
    any(actual == 1) && any(expected == 1);
end
