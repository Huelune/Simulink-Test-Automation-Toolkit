function meta = st_inspect_mat_data( ...
        dataFile, cutName, tmaxResolution, matVariableName, cfg)
%ST_INSPECT_MAT_DATA Inspect ordinary Dataset variables in a MAT file.
% Variables are selected explicitly or sorted by name. The returned schema
% matches the metadata consumed after SLDV source parsing.
if nargin < 4
    matVariableName = '';
end
if nargin < 5
    cfg = [];
end

timerValue = tic;
requested = strtrim(string(matVariableName));
if ~isscalar(requested) || ismissing(requested)
    error('simtest:InvalidMatVariableName', ...
        'MatVariableName must be one text value.');
end

dataFile = char(string(dataFile));
st_log(cfg, 'INFO', '[MAT] Dataset inspection start | File=%s', dataFile);
st_log(cfg, 'DEBUG', '[MAT] Variable inventory start | File=%s', dataFile);
variables = whos('-file', dataFile);
st_log(cfg, 'DEBUG', '[MAT] Variable inventory end | Count=%d', ...
    numel(variables));
available = sort(string({variables.name}).');
if strlength(requested) > 0
    if ~any(available == requested)
        error('simtest:MatVariableMissing', ...
            'MatVariableName not found: %s | File=%s', ...
            char(requested), dataFile);
    end
    candidates = requested;
else
    candidates = available;
end

datasetNames = strings(0,1);
datasets = cell(0,1);
for i = 1:numel(candidates)
    name = candidates(i);
    st_log(cfg, 'TRACE', '[MAT] Variable load start | Name=%s', char(name));
    loaded = load(dataFile, char(name));
    st_log(cfg, 'TRACE', '[MAT] Variable load end | Name=%s', char(name));
    value = loaded.(char(name));
    if isa(value, 'Simulink.SimulationData.Dataset') && ...
            isscalar(value) && value.numElements > 0
        datasetNames(end+1,1) = name; %#ok<AGROW>
        datasets{end+1,1} = value; %#ok<AGROW>
    elseif strlength(requested) > 0
        error('simtest:MatVariableNotDataset', ...
            ['MatVariableName must contain one nonempty scalar ' ...
             'Simulink.SimulationData.Dataset: %s'], char(requested));
    end
end

if isempty(datasetNames)
    error('simtest:MatDatasetMissing', ...
        'MAT file contains no nonempty scalar Dataset variables: %s', dataFile);
end

st_log(cfg, 'INFO', '[MAT] Dataset variables=[%s]', ...
    char(strjoin(datasetNames, ', ')));

n = numel(datasets);
endTimes = zeros(n,1);
parameterCounts = zeros(n,1);
scenarioNames = cell(n,1);
originalNames = cellstr(datasetNames);
inputNames = cell(0,1);
inputTypes = cell(0,1);
inputDimensions = cell(0,1);

for i = 1:n
    dataset = datasets{i};
    variable = datasetNames(i);
    st_log(cfg, 'DEBUG', '[MAT %d/%d] Variable=%s', ...
        i, n, char(variable));
    [~, names, types, dimensions] = st_dataset_signature(dataset);
    endTimes(i) = dataset_end_time(dataset, char(variable));

    if i == 1
        inputNames = names;
        inputTypes = types;
        inputDimensions = dimensions;
    elseif ~same_interface( ...
            names, types, dimensions, ...
            inputNames, inputTypes, inputDimensions)
        error('simtest:MatScenarioInterfaceMismatch', ...
            ['MAT Dataset variable %s input interface differs from %s. ' ...
             'All MAT scenarios must have identical count, order, names, ' ...
             'data types, and dimensions.'], ...
            char(variable), char(datasetNames(1)));
    end

    scenarioNames{i} = st_scenario_name(cutName, i);
    st_log(cfg, 'DEBUG', '[MAT %d/%d] Inputs=%d', i, n, numel(names));
    for inputIndex = 1:numel(names)
        st_log(cfg, 'TRACE', ...
            '[MAT %d/%d] Input[%d] name=%s type=%s dims=%s', ...
            i, n, inputIndex, names{inputIndex}, types{inputIndex}, ...
            mat2str(dimensions{inputIndex}));
    end
    st_log(cfg, 'DEBUG', '[MAT %d/%d] EndTime=%.17g', ...
        i, n, endTimes(i));
end

meta = struct();
meta.SourceIndices = (1:n).';
meta.EndTimes = endTimes;
meta.RawTmax = max(endTimes);
meta.Tmax = st_quantize_sldv_tmax(meta.RawTmax, tmaxResolution);
meta.ParameterCounts = parameterCounts;
meta.ScenarioNames = scenarioNames;
meta.OriginalNames = originalNames;
meta.InputNames = inputNames;
meta.InputTypes = inputTypes;
meta.InputDimensions = inputDimensions;
meta.IgnoredInputNames = cell(0,1);
st_log(cfg, 'INFO', ...
    '[MAT] Dataset inspection end | Scenarios=%d | Tmax=%.17g | Elapsed=%.3f', ...
    n, meta.Tmax, toc(timerValue));
end

function tf = same_interface( ...
        names, types, dimensions, referenceNames, referenceTypes, ...
        referenceDimensions)
tf = isequal(string(names(:)), string(referenceNames(:))) && ...
    isequal(string(types(:)), string(referenceTypes(:))) && ...
    isequal(dimensions(:), referenceDimensions(:));
end

function endTime = dataset_end_time(dataset, variableName)
lastTimes = zeros(0,1);
for i = 1:dataset.numElements
    element = dataset.getElement(i);
    value = element;
    if isa(element, 'Simulink.SimulationData.Signal')
        value = element.Values;
    end
    lastTimes = [lastTimes; collect_last_times(value, ...
        sprintf('%s input %d', variableName, i))]; %#ok<AGROW>
end
if isempty(lastTimes)
    error('simtest:MatScenarioTimeMissing', ...
        'MAT Dataset variable %s contains no usable signal time.', variableName);
end
endTime = max(lastTimes);
end

function lastTimes = collect_last_times(value, label)
lastTimes = zeros(0,1);
if isa(value, 'timeseries')
    lastTimes = validate_time(value.Time, label);
elseif istimetable(value)
    lastTimes = validate_time(value.Properties.RowTimes, label);
elseif isstruct(value)
    fields = fieldnames(value);
    structureWithTime = isfield(value, 'time') && isfield(value, 'signals');
    for elementIndex = 1:numel(value)
        if structureWithTime
            lastTimes = [lastTimes; validate_time( ...
                value(elementIndex).time, [label '.time'])]; %#ok<AGROW>
        end
        for fieldIndex = 1:numel(fields)
            if structureWithTime && strcmp(fields{fieldIndex}, 'time')
                continue;
            end
            childLabel = sprintf('%s.%s', label, fields{fieldIndex});
            lastTimes = [lastTimes; collect_last_times( ...
                value(elementIndex).(fields{fieldIndex}), childLabel)]; %#ok<AGROW>
        end
    end
elseif iscell(value)
    for i = 1:numel(value)
        lastTimes = [lastTimes; collect_last_times(value{i}, label)]; %#ok<AGROW>
    end
end
end

function lastTime = validate_time(raw, label)
if isempty(raw)
    lastTime = zeros(0,1);
    return;
end
if isduration(raw)
    values = seconds(raw(:));
elseif isnumeric(raw)
    values = double(raw(:));
else
    error('simtest:MatScenarioTimeType', ...
        'Unsupported MAT Dataset time type at %s: %s', label, class(raw));
end
if ~isreal(values) || any(~isfinite(values)) || any(values < 0) || ...
        any(diff(values) < 0)
    error('simtest:MatScenarioTimeInvalid', ...
        'MAT Dataset contains invalid or nonmonotonic time at %s.', label);
end
lastTime = values(end);
end
