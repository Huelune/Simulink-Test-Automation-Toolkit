function R = st_validate_sldv_verify_results(resultObj)
%ST_VALIDATE_SLDV_VERIFY_RESULTS Fail SLDV scenarios with untested verify.

cfg = st_require_runtime_target();
T = st_load_targets(cfg.OnlyEnabled);
testCaseResults = st_collect_test_case_results(resultObj);

TargetRow = zeros(0,1);
No = zeros(0,1);
CUTName = strings(0,1);
TestCaseName = strings(0,1);
ScenarioName = strings(0,1);
VerifyCount = zeros(0,1);
UntestedCount = zeros(0,1);
Status = strings(0,1);
Message = strings(0,1);

for targetIndex = 1:height(T)
    profile = st_get_sldv_profile(T(targetIndex,:), cfg);
    if strcmp(profile.Mode, 'OFF')
        continue;
    end

    tcResult = find_test_case_result(testCaseResults, char(T.TestCaseName(targetIndex)));
    for scenarioIndex = 1:numel(profile.ScenarioNames)
        row = numel(TargetRow) + 1;
        scenario = profile.ScenarioNames{scenarioIndex};
        TargetRow(row,1) = targetIndex;
        No(row,1) = double(T.No(targetIndex));
        CUTName(row,1) = string(T.CUTName(targetIndex));
        TestCaseName(row,1) = string(T.TestCaseName(targetIndex));
        ScenarioName(row,1) = string(scenario);

        % Keep result-table row counts aligned even when validation fails
        % before verify counts can be collected.
        VerifyCount(row,1) = NaN;
        UntestedCount(row,1) = NaN;

        try
            if isempty(tcResult)
                error('Test Case Result not found.');
            end
            iterResult = find_iteration_result(tcResult, scenario);
            if isempty(iterResult)
                error('Test Iteration Result not found.');
            end

            [verifyCount, untestedCount] = scenario_verify_summary( ...
                iterResult, scenario);
            VerifyCount(row,1) = verifyCount;
            UntestedCount(row,1) = untestedCount;

            if verifyCount == 0
                error(['No verify result was recorded for the active scenario at ' ...
                    'Tmax=%.17g.'], profile.Tmax);
            end
            if untestedCount > 0
                error(['%d verify result(s) remained Untested at Tmax=%.17g. ' ...
                    'Check StopTime and after(Tmax,sec) scheduling.'], ...
                    untestedCount, profile.Tmax);
            end

            Status(row,1) = 'OK';
            Message(row,1) = sprintf('verify=%d, Tmax=%.17g', ...
                verifyCount, profile.Tmax);
        catch ME
            Status(row,1) = 'FAIL';
            Message(row,1) = string(ME.message);
        end
    end
end

R = table(TargetRow, No, CUTName, TestCaseName, ScenarioName, ...
    VerifyCount, UntestedCount, Status, Message);
st_write_result('SldvVerifyTimingResult', R);
end


function [count, untested] = scenario_verify_summary(iterResult, scenarioName)
count = 0;
untested = 0;
verifyRuns = getVerifyRuns(iterResult);

for runIndex = 1:numel(verifyRuns)
    % Export the whole Verify Run. Exporting a single SDI signal can return
    % a timeseries, which does not provide Dataset numElements semantics.
    dataset = export(verifyRuns(runIndex));

    if isempty(dataset)
        continue;
    end

    for elementIndex = 1:numElements(dataset)
        assessment = dataset{elementIndex};
        if ~assessment_belongs_to_scenario(assessment, scenarioName)
            continue;
        end

        count = count + 1;
        resultText = char(string(assessment.Result));
        if isequal(assessment.Result, slTestResult.Untested) || ...
                strcmpi(resultText, 'Untested') || ...
                endsWith(resultText, '.Untested', 'IgnoreCase', true)
            untested = untested + 1;
        end
    end
end
end


function tf = assessment_belongs_to_scenario(assessment, scenarioName)
tf = false;
try
    parts = convertToCell(assessment.BlockPath);
    pathText = strjoin(parts, ' > ');
    try
        pathText = [pathText ' > ' char(assessment.BlockPath.SubPath)];
    catch
    end
    tf = contains(pathText, [scenarioName '.step2']);
catch
    % If the release omits BlockPath metadata, the result cannot be safely
    % attributed when multiple scenarios exist.
end
end


function tcResult = find_test_case_result(resultCells, testCaseName)
tcResult = [];
for i = 1:numel(resultCells)
    if strcmp(char(resultCells{i}.Name), testCaseName)
        tcResult = resultCells{i};
        return;
    end
end
end


function iterResult = find_iteration_result(tcResult, scenarioName)
iterResult = [];
iterations = getIterationResults(tcResult);
for i = 1:numel(iterations)
    try
        scenario = iterations(i).TestSequenceScenario;
        if isstruct(scenario) && isfield(scenario, 'TestSequenceScenario') && ...
                strcmp(char(scenario.TestSequenceScenario), scenarioName)
            iterResult = iterations(i);
            return;
        end
    catch
    end
end
end
