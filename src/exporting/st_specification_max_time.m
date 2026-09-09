function [maxTime, source, note] = st_specification_max_time(sldvMode, harnessStopTime, inputMaxTime)
%ST_SPECIFICATION_MAX_TIME Select the exported MaxTime by test-data origin.
% FILE/GENERATE cases use the linked input scenario's maximum time.
% OFF cases use the Harness solver StopTime even when an input is linked.
mode = upper(strtrim(string(sldvMode)));
if ~isscalar(mode)
    error('simtest:SpecificationMaxTimeMode', 'SldvMode must be scalar.');
end

if any(mode == ["FILE" "GENERATE"])
    source = "INPUT_TMAX";
    [maxTime, valid] = numeric_seconds(inputMaxTime);
    if valid
        note = "";
    else
        maxTime = NaN;
        note = "FILE/GENERATE input MaxTime is unavailable for this scenario.";
    end
    return;
end

source = "HARNESS_STOP_TIME";
[maxTime, valid] = numeric_seconds(harnessStopTime);
if valid
    note = "";
else
    maxTime = NaN;
    note = "Harness solver StopTime is not a finite nonnegative numeric value.";
end
end

function [value, valid] = numeric_seconds(raw)
valid = false;
value = NaN;
if (ischar(raw) && isrow(raw)) || (isstring(raw) && isscalar(raw))
    value = str2double(strtrim(string(raw)));
elseif isnumeric(raw) && isscalar(raw)
    value = double(raw);
else
    return;
end
valid = isfinite(value) && value >= 0;
end
