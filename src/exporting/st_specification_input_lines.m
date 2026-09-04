function [text, notes, maxTime] = st_specification_input_lines(scenario)
%ST_SPECIFICATION_INPUT_LINES Last stored sample, one scalar leaf per line.
% No interpolation, model evaluation, or verify-target filtering is performed.
lines = cell(0,1);
notes = cell(0,1);
storedTimes = zeros(0,1);
invalidTime = false;
walk(scenario, '');
text = string(strjoin(lines, newline));
notes = string(strjoin(notes, ' | '));
maxTime = NaN;
if ~invalidTime && ~isempty(storedTimes), maxTime = max(storedTimes); end

    function walk(value, path)
        try
            if isa(value, 'Simulink.SimulationData.Dataset')
                if numElements(value) == 0
                    error('simtest:EmptyInput', 'Scenario Dataset contains no signals.');
                end
                names = getElementNames(value);
                for n = 1:numElements(value)
                    name = char(names{n});
                    if isempty(name)
                        name = sprintf('<unnamed_%d>', n);
                        notes{end+1,1} = ['Unnamed Dataset element: ' join_path(path, name)];
                    end
                    walk(getElement(value, n), join_path(path, name));
                end
            elseif isa(value, 'Simulink.SimulationData.Signal')
                walk(value.Values, path);
            elseif isa(value, 'timeseries')
                collect_time(value.Time, value.TimeInfo.Units, path);
                if isempty(value.Time)
                    error('simtest:EmptyInput', 'No stored time samples.');
                end
                % getdatasamples respects IsTimeFirst for matrix signals.
                walk(getdatasamples(value, numel(value.Time)), path);
            elseif istimetable(value)
                collect_time(value.Properties.RowTimes, '', path);
                if height(value) == 0
                    error('simtest:EmptyInput', 'No stored timetable rows.');
                end
                names = value.Properties.VariableNames;
                for n = 1:numel(names)
                    samples = value.(names{n});
                    indices = repmat({':'}, 1, ndims(samples));
                    indices{1} = height(value);
                    sample = samples(indices{:});
                    if iscell(sample) && isscalar(sample), sample = sample{1}; end
                    child = path;
                    if numel(names) > 1, child = join_path(path, names{n}); end
                    walk(sample, child);
                end
            elseif isstruct(value)
                if isempty(value), error('simtest:EmptyInput', 'Empty bus.'); end
                dims = size(value);
                if isvector(value), dims = numel(value); end
                paths = st_indexed_expressions(path, dims, false);
                fields = fieldnames(value);
                for n = 1:numel(value)
                    for f = 1:numel(fields)
                        walk(value(n).(fields{f}), join_path(paths{n}, fields{f}));
                    end
                end
            elseif isnumeric(value) || islogical(value) || isenum(value) || ...
                    isa(value, 'embedded.fi')
                if isempty(value), error('simtest:EmptyInput', 'Empty signal value.'); end
                % Numeric leaf arrays use linear indices, as st_build_verify_action.
                paths = st_indexed_expressions(path, numel(value), false);
                for n = 1:numel(value)
                    lines{end+1,1} = sprintf('%s: %s', paths{n}, scalar_text(value(n)));
                end
            else
                error('simtest:UnsupportedInput', 'Unsupported input class: %s', class(value));
            end
        catch ME
            lines{end+1,1} = sprintf('%s: <읽기 실패>', path);
            notes{end+1,1} = sprintf('%s: %s', path, ME.message);
        end
    end

    function collect_time(times, units, path)
        try
            if isempty(times)
                error('simtest:SpecificationTime', 'No stored time samples.');
            end
            if isduration(times)
                times = seconds(times);
            elseif isnumeric(times)
                names = {'weeks','days','hours','minutes','seconds', ...
                    'milliseconds','microseconds','nanoseconds'};
                scales = [604800 86400 3600 60 1 1e-3 1e-6 1e-9];
                index = find(strcmpi(char(units), names), 1);
                if isempty(index)
                    error('simtest:SpecificationTime', 'Unsupported time units: %s', string(units));
                end
                times = double(times) * scales(index);
            else
                error('simtest:SpecificationTime', ...
                    'MaxTime requires elapsed time, not %s timestamps.', class(times));
            end
            if any(~isfinite(times(:)))
                error('simtest:SpecificationTime', 'Nonfinite time samples.');
            end
            storedTimes(end+1,1) = max(times(:));
        catch ME
            invalidTime = true;
            notes{end+1,1} = sprintf('%s MaxTime: %s', path, ME.message);
        end
    end
end

function path = join_path(parent, child)
if isempty(parent), path = child; else, path = [parent '.' child]; end
end

function text = scalar_text(value)
if islogical(value)
    if value, text = 'true'; else, text = 'false'; end
elseif isenum(value) || isinteger(value) || isa(value, 'embedded.fi')
    text = char(string(value));
else
    text = mat2str(value, 17);
end
end
