function [Summary, Detail] = st_diagnose_sldv_timing(dataFile)
%ST_DIAGNOSE_SLDV_TIMING Compare raw SLDV and sldvsimdata end times.
%
% This is read-only. It does not run a Harness or update the SLDV manifest.
% When dataFile is omitted, it uses the one Enabled target's prepared SLDV
% file. Use it to distinguish an SLDV MAT double-value tail from a Dataset
% conversion difference.

cfg = st_require_runtime_target();

if nargin < 1 || isempty(dataFile)
    T = st_load_targets(cfg.OnlyEnabled);
    if height(T) ~= 1
        error(['Specify dataFile when the current management selection does ' ...
            'not contain exactly one target.']);
    end
    profile = st_get_sldv_profile(T(1,:), cfg);
    if strcmp(profile.Mode, 'OFF')
        error('The selected target has SldvMode=OFF and no SLDV data file.');
    end
    dataFile = profile.EffectiveDataFile;
end

dataFile = char(dataFile);
loaded = load(dataFile, 'sldvData');
if ~isfield(loaded, 'sldvData') || ...
        ~isfield(loaded.sldvData, 'TestCases')
    error('No sldvData.TestCases were found: %s', dataFile);
end

testCases = loaded.sldvData.TestCases;
caseCount = numel(testCases);

TestCaseIndex = (1:caseCount).';
RawStartTime = nan(caseCount,1);
RawEndTime = nan(caseCount,1);
RawEndHex = strings(caseCount,1);
DatasetMaxEndTime = nan(caseCount,1);
DatasetMaxEndHex = strings(caseCount,1);
DatasetDelta = nan(caseCount,1);
DatasetSignalCount = zeros(caseCount,1);
Status = strings(caseCount,1);
Message = strings(caseCount,1);

DetailTestCaseIndex = zeros(0,1);
ElementIndex = zeros(0,1);
ElementName = strings(0,1);
TimeSource = strings(0,1);
ElementEndTime = zeros(0,1);
ElementEndHex = strings(0,1);

fprintf('\n============================================\n');
fprintf('Diagnose SLDV Timing (read-only)\n');
fprintf('Data file: %s\n', dataFile);
fprintf('============================================\n');

for testCaseIndex = 1:caseCount
    try
        times = double(testCases(testCaseIndex).timeValues(:));
        if isempty(times) || any(~isfinite(times))
            error('TestCases(%d).timeValues is empty or non-finite.', testCaseIndex);
        end

        RawStartTime(testCaseIndex) = times(1);
        RawEndTime(testCaseIndex) = times(end);
        RawEndHex(testCaseIndex) = string(num2hex(times(end)));

        dataset = sldvsimdata(dataFile, testCaseIndex);
        if ~isa(dataset, 'Simulink.SimulationData.Dataset')
            error('sldvsimdata returned %s, not Dataset.', class(dataset));
        end

        DatasetSignalCount(testCaseIndex) = dataset.numElements;
        elementEnds = nan(dataset.numElements,1);
        for elementIndex = 1:dataset.numElements
            element = dataset.getElement(elementIndex);
            [elementEnd, source] = dataset_element_end_time(element);
            elementEnds(elementIndex) = elementEnd;

            DetailTestCaseIndex(end+1,1) = testCaseIndex; %#ok<AGROW>
            ElementIndex(end+1,1) = elementIndex; %#ok<AGROW>
            ElementName(end+1,1) = string(element.Name); %#ok<AGROW>
            TimeSource(end+1,1) = string(source); %#ok<AGROW>
            ElementEndTime(end+1,1) = elementEnd; %#ok<AGROW>
            if isfinite(elementEnd)
                ElementEndHex(end+1,1) = string(num2hex(elementEnd)); %#ok<AGROW>
            else
                ElementEndHex(end+1,1) = ""; %#ok<AGROW>
            end
        end

        finiteEnds = elementEnds(isfinite(elementEnds));
        if ~isempty(finiteEnds)
            DatasetMaxEndTime(testCaseIndex) = max(finiteEnds);
            DatasetMaxEndHex(testCaseIndex) = ...
                string(num2hex(DatasetMaxEndTime(testCaseIndex)));
            DatasetDelta(testCaseIndex) = ...
                DatasetMaxEndTime(testCaseIndex) - RawEndTime(testCaseIndex);
        end

        Status(testCaseIndex) = 'OK';
        Message(testCaseIndex) = 'Raw TestCases.timeValues and Dataset elements compared';

        fprintf(['[%d/%d] rawEnd=%.17g (%s) | datasetMaxEnd=%.17g (%s) ' ...
            '| delta=%.17g\n'], ...
            testCaseIndex, caseCount, RawEndTime(testCaseIndex), ...
            RawEndHex(testCaseIndex), DatasetMaxEndTime(testCaseIndex), ...
            DatasetMaxEndHex(testCaseIndex), DatasetDelta(testCaseIndex));
    catch ME
        Status(testCaseIndex) = 'FAIL';
        Message(testCaseIndex) = string(ME.message);
        fprintf('[%d/%d] FAIL %s\n', testCaseIndex, caseCount, ME.message);
    end
end

Summary = table(TestCaseIndex, RawStartTime, RawEndTime, RawEndHex, ...
    DatasetMaxEndTime, DatasetMaxEndHex, DatasetDelta, DatasetSignalCount, ...
    Status, Message);
Detail = table(DetailTestCaseIndex, ElementIndex, ElementName, TimeSource, ...
    ElementEndTime, ElementEndHex);

st_write_result('SldvTimingSummary', Summary);
st_write_result('SldvTimingDetail', Detail);
end


function [endTime, source] = dataset_element_end_time(element)

value = element;
if isa(element, 'Simulink.SimulationData.Signal')
    value = element.Values;
end

if isa(value, 'timeseries')
    times = double(value.Time(:));
    source = 'timeseries.Time';
elseif istimetable(value)
    times = seconds(value.Properties.RowTimes - value.Properties.RowTimes(1));
    times = double(times(:));
    source = 'timetable.RowTimes';
else
    endTime = NaN;
    source = class(value);
    return;
end

if isempty(times) || any(~isfinite(times))
    endTime = NaN;
else
    endTime = times(end);
end
end
