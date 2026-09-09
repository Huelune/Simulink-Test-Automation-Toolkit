function [signature, names, types, dimensions] = st_dataset_signature(dataset)
%ST_DATASET_SIGNATURE Return ordered Dataset input interface metadata.
if ~isa(dataset, 'Simulink.SimulationData.Dataset') || ~isscalar(dataset)
    error('simtest:InvalidDataset', ...
        'Expected one Simulink.SimulationData.Dataset.');
end

n = dataset.numElements;
rawNames = getElementNames(dataset);
names = cellstr(string(rawNames(:)));
if numel(names) ~= n
    error('simtest:DatasetElementNameCount', ...
        'Dataset element-name count differs from numElements.');
end

signature = strings(n,1);
types = cell(n,1);
dimensions = cell(n,1);
for i = 1:n
    names{i} = strtrim(names{i});
    if isempty(names{i})
        error('simtest:DatasetElementNameEmpty', ...
            'Dataset element %d has an empty Name.', i);
    end

    element = dataset.getElement(i);
    value = element;
    if isa(element, 'Simulink.SimulationData.Signal')
        value = element.Values;
    end

    [valueText, valueType, valueDimensions] = value_signature(value);
    signature(i) = string(sprintf('%s|%s', names{i}, valueText));
    types{i} = valueType;
    dimensions{i} = valueDimensions;
end

if numel(unique(string(names))) ~= numel(names)
    error('simtest:DuplicateDatasetElementNames', ...
        'Dataset contains duplicate element names: [%s]', strjoin(names, ', '));
end
end

function [text, dataType, dimensions] = value_signature(value)
if isa(value, 'timeseries')
    data = value.Data;
    dims = size(data);
    if ~isempty(value.Time) && isprop(value, 'IsTimeFirst') && ...
            value.IsTimeFirst && ~isempty(dims)
        dims = dims(2:end);
    elseif ~isempty(value.Time) && ~isempty(dims) && ...
            dims(end) == numel(value.Time)
        dims = dims(1:end-1);
    elseif ~isempty(value.Time) && ~isempty(dims) && ...
            dims(1) == numel(value.Time)
        dims = dims(2:end);
    end
    dataType = value_data_type(data);
    dimensions = normalize_signal_dimensions(dims);
    text = sprintf('timeseries|%s|%s', dataType, mat2str(dimensions));
elseif istimetable(value)
    data = value.Variables;
    dims = size(data);
    dims = dims(2:end);
    dataType = value_data_type(data);
    dimensions = normalize_signal_dimensions(dims);
    text = sprintf('timetable|%s|%s', dataType, mat2str(dimensions));
else
    dataType = value_data_type(value);
    dimensions = normalize_signal_dimensions(size(value));
    text = sprintf('%s|%s', dataType, mat2str(dimensions));
end
end

function type = value_data_type(value)
if isa(value, 'embedded.fi')
    type = 'fixed';
elseif isstruct(value)
    type = 'bus';
else
    type = class(value);
end
end

function dims = normalize_signal_dimensions(dims)
dims = double(dims(:).');
if isempty(dims) || all(dims == 1)
    dims = 1;
end
end
