function coverage = ...
    st_collect_coverage_summary(resultObj, targetConfig, runLabel)
%ST_COLLECT_COVERAGE_SUMMARY Extract Decision and Execution coverage.

coverage = empty_coverage_table();
resultCoverage = getCoverageResults(resultObj);

% Overall CUT rows come from the aggregated ResultSet coverage so repeated
% Test Cases are not summed as if they were different coverage objectives.
for t = 1:height(targetConfig)
    coverage = append_object_coverage(coverage, resultCoverage, ...
        runLabel, 'CUT', targetConfig(t,:), '', '', ...
        char(targetConfig.CUTPath(t)));
end

cutRows = coverage(coverage.Level == "CUT", :);
if ~isempty(cutRows)
    aggregateInput = cutRows(:, ...
        {'CoverageRoot','Checksum','Metric','Covered','Total','Justified'});
    aggregate = st_aggregate_coverage_rows(aggregateInput);
    for m = 1:height(aggregate)
        row = empty_coverage_table();
        row(1,:) = {string(runLabel), "OVERALL", NaN, "", "", "", ...
            "ALL_COMPATIBLE_CUTS", "", "", aggregate.Metric(m), ...
            aggregate.Covered(m), aggregate.Total(m), ...
            aggregate.Justified(m), aggregate.Percentage(m), ...
            aggregate.PercentageText(m), aggregate.Status(m), ...
            sprintf('%d compatible CUT(s), %d checksum mismatch CUT(s)', ...
                aggregate.CompatibleCUTCount(m), ...
                aggregate.IncompatibleCUTCount(m))};
        coverage = [coverage; row]; %#ok<AGROW>
    end
end

caseResults = collect_test_cases(resultObj);
for c = 1:numel(caseResults)
    tcResult = caseResults{c};
    caseName = string(safe_property(tcResult, 'Name', ''));
    targetIndex = find(string(targetConfig.TestCaseName) == caseName, 1);
    if isempty(targetIndex)
        continue;
    end
    target = targetConfig(targetIndex,:);
    caseCoverage = getCoverageResults(tcResult);
    coverage = append_object_coverage(coverage, caseCoverage, ...
        runLabel, 'TEST_CASE', target, caseName, '', ...
        char(target.CUTPath));

    iterResults = safe_iterations(tcResult);
    for i = 1:numel(iterResults)
        iterName = iteration_name(iterResults(i), i);
        iterCoverage = getCoverageResults(iterResults(i));
        coverage = append_object_coverage(coverage, iterCoverage, ...
            runLabel, 'ITERATION', target, caseName, iterName, ...
            char(target.CUTPath));
    end
end
end

function coverage = append_object_coverage(coverage, coverageObjects, ...
        runLabel, level, target, testCaseName, iterationName, objectPath)
for c = 1:numel(coverageObjects)
    cvd = coverageObjects(c);
    sourceRoot = coverage_source_root(cvd);
    checksum = coverage_checksum(cvd);
    coverage = append_metric(coverage, cvd, @decisioninfo, ...
        'Decision', runLabel, level, target, testCaseName, ...
        iterationName, objectPath, sourceRoot, checksum);
    coverage = append_metric(coverage, cvd, @executioninfo, ...
        'Execution', runLabel, level, target, testCaseName, ...
        iterationName, objectPath, sourceRoot, checksum);
end
end

function coverage = append_metric(coverage, cvd, metricFunction, metric, ...
        runLabel, level, target, testCaseName, iterationName, objectPath, ...
        sourceRoot, checksum)
try
    [values, description] = metricFunction(cvd, objectPath);
catch ME
    row = empty_coverage_table();
    row(1,:) = {string(runLabel), string(level), double(target.No), ...
        string(target.CUTName), string(testCaseName), ...
        string(iterationName), string(objectPath), string(sourceRoot), ...
        string(checksum), string(metric), NaN, NaN, NaN, NaN, "N/A", ...
        "EXTRACTION_FAILED", string(ME.message)};
    coverage = [coverage; row];
    return;
end
if isempty(values)
    return;
end

covered = double(values(1));
total = double(values(2));
justified = justified_count(description);
[percentage, percentageText] = st_coverage_percentage(covered, total);
row = empty_coverage_table();
row(1,:) = {string(runLabel), string(level), double(target.No), ...
    string(target.CUTName), string(testCaseName), string(iterationName), ...
    string(objectPath), string(sourceRoot), string(checksum), ...
    string(metric), covered, total, justified, percentage, ...
    percentageText, "OK", ""};
coverage = [coverage; row];
end

function value = justified_count(description)
value = 0;
try
    if isstruct(description) && isfield(description, 'justifiedCoverage')
        values = [description.justifiedCoverage];
        value = sum(double(values));
    end
catch
    value = NaN;
end
end

function value = coverage_checksum(cvd)
value = "";
try
    value = string(st_hash_value(cvd.checksum));
catch
end
end

function value = coverage_source_root(cvd)
value = "";
try
    value = string(cvd.test.rootPath);
catch
end
end

function resultCells = collect_test_cases(resultObj)
resultCells = {};
fileResults = getTestFileResults(resultObj);
for f = 1:numel(fileResults)
    suiteResults = getTestSuiteResults(fileResults(f));
    for s = 1:numel(suiteResults)
        caseResults = getTestCaseResults(suiteResults(s));
        for c = 1:numel(caseResults)
            resultCells{end+1,1} = caseResults(c); %#ok<AGROW>
        end
    end
end
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

function T = empty_coverage_table()
T = table(strings(0,1), strings(0,1), zeros(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), 'VariableNames', ...
    {'Run','Level','No','CUTName','TestCaseName','IterationName', ...
     'CoverageRoot','SourceCoverageRoot','Checksum','Metric','Covered', ...
     'Total','Justified','Percentage','PercentageText','Status','Message'});
end
