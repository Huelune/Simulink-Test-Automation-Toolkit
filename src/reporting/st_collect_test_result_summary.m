function [targets, iterations] = ...
    st_collect_test_result_summary(resultObj, targetConfig, runLabel)
%ST_COLLECT_TEST_RESULT_SUMMARY Flatten Test Manager result hierarchy.

Run = strings(0,1);
No = zeros(0,1);
CUTName = strings(0,1);
CUTPath = strings(0,1);
TestCaseName = strings(0,1);
Outcome = strings(0,1);
DurationSec = zeros(0,1);
IterationCount = zeros(0,1);

IterationRun = strings(0,1);
IterationNo = zeros(0,1);
IterationCUTName = strings(0,1);
IterationTestCaseName = strings(0,1);
IterationName = strings(0,1);
IterationOutcome = strings(0,1);
IterationDurationSec = zeros(0,1);

caseResults = st_collect_test_case_results(resultObj);
for c = 1:numel(caseResults)
    tcResult = caseResults{c};
    caseName = string(safe_property(tcResult, 'Name', ''));
    targetIndex = find(string(targetConfig.TestCaseName) == caseName, 1);
    if isempty(targetIndex)
        targetNo = NaN;
        cutName = "";
        cutPath = "";
    else
        targetNo = double(targetConfig.No(targetIndex));
        cutName = string(targetConfig.CUTName(targetIndex));
        cutPath = string(targetConfig.CUTPath(targetIndex));
    end

    iterResults = safe_iterations(tcResult);
    Run(end+1,1) = string(runLabel); %#ok<AGROW>
    No(end+1,1) = targetNo; %#ok<AGROW>
    CUTName(end+1,1) = cutName; %#ok<AGROW>
    CUTPath(end+1,1) = cutPath; %#ok<AGROW>
    TestCaseName(end+1,1) = caseName; %#ok<AGROW>
    Outcome(end+1,1) = string(safe_property( ...
        tcResult, 'Outcome', 'UNKNOWN')); %#ok<AGROW>
    DurationSec(end+1,1) = numeric_property( ...
        tcResult, 'Duration', NaN); %#ok<AGROW>
    IterationCount(end+1,1) = numel(iterResults); %#ok<AGROW>

    for i = 1:numel(iterResults)
        iterResult = iterResults(i);
        IterationRun(end+1,1) = string(runLabel); %#ok<AGROW>
        IterationNo(end+1,1) = targetNo; %#ok<AGROW>
        IterationCUTName(end+1,1) = cutName; %#ok<AGROW>
        IterationTestCaseName(end+1,1) = caseName; %#ok<AGROW>
        IterationName(end+1,1) = iteration_name(iterResult, i); %#ok<AGROW>
        IterationOutcome(end+1,1) = string(safe_property( ...
            iterResult, 'Outcome', 'UNKNOWN')); %#ok<AGROW>
        IterationDurationSec(end+1,1) = numeric_property( ...
            iterResult, 'Duration', NaN); %#ok<AGROW>
    end
end

targets = table(Run, No, CUTName, CUTPath, TestCaseName, Outcome, ...
    DurationSec, IterationCount);
iterations = table(IterationRun, IterationNo, IterationCUTName, ...
    IterationTestCaseName, IterationName, IterationOutcome, ...
    IterationDurationSec, 'VariableNames', ...
    {'Run','No','CUTName','TestCaseName','IterationName','Outcome', ...
     'DurationSec'});
end

function results = safe_iterations(tcResult)
try
    results = getIterationResults(tcResult);
catch
    results = [];
end
end

function name = iteration_name(iterResult, index)
name = string(safe_property(iterResult, 'Name', ''));
if strlength(name) > 0
    return;
end
try
    scenario = iterResult.TestSequenceScenario;
    if isstruct(scenario) && isfield(scenario, 'TestSequenceScenario')
        name = string(scenario.TestSequenceScenario);
    end
catch
end
if strlength(name) == 0
    name = "Iteration " + string(index);
end
end

function value = safe_property(object, property, defaultValue)
try
    value = object.(property);
catch
    value = defaultValue;
end
end

function value = numeric_property(object, property, defaultValue)
value = safe_property(object, property, defaultValue);
try
    if isduration(value)
        value = seconds(value);
    else
        value = double(value);
    end
catch
    value = defaultValue;
end
if ~isscalar(value)
    value = defaultValue;
end
end
