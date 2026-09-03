function coverage = ...
    st_collect_coverage_summary(resultObj, targetConfig, runLabel, varargin)
%ST_COLLECT_COVERAGE_SUMMARY Extract Decision and Execution coverage.

p = inputParser;
addParameter(p, 'IncludeTestDetails', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'MatchCoverageObjects', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'ProgressFcn', [], ...
    @(x) isempty(x) || isa(x, 'function_handle'));
parse(p, varargin{:});
includeTestDetails = p.Results.IncludeTestDetails;
matchCoverageObjects = p.Results.MatchCoverageObjects;
progressFcn = p.Results.ProgressFcn;

coverage = empty_coverage_table();
resultCoverage = getCoverageResults(resultObj);
resultDescriptors = describe_coverage_objects(resultCoverage);

% Overall CUT rows come from the aggregated ResultSet coverage so repeated
% Test Cases are not summed as if they were different coverage objectives.
for t = 1:height(targetConfig)
    notify_progress(progressFcn, 'CUT coverage', t, height(targetConfig));
    target = targetConfig(t,:);
    targetPath = char(target.CUTPath);
    matches = select_coverage_objects(resultDescriptors, targetPath, ...
        matchCoverageObjects);
    if isempty(matches)
        coverage = append_unmatched_coverage(coverage, runLabel, ...
            'CUT', target, '', '', targetPath);
        continue;
    end
    coverage = append_object_coverage(coverage, ...
        resultCoverage(matches), runLabel, 'CUT', target, '', '', ...
        targetPath);
end

cutRows = coverage(coverage.Level == "CUT" & coverage.Status == "OK", :);
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

if ~includeTestDetails
    return;
end

caseResults = st_collect_test_case_results(resultObj);
for c = 1:numel(caseResults)
    notify_progress(progressFcn, 'Test Case coverage', c, ...
        numel(caseResults));
    tcResult = caseResults{c};
    caseName = string(safe_property(tcResult, 'Name', ''));
    targetIndex = find(string(targetConfig.TestCaseName) == caseName, 1);
    if isempty(targetIndex)
        continue;
    end
    target = targetConfig(targetIndex,:);
    caseCoverage = getCoverageResults(tcResult);
    targetPath = char(target.CUTPath);
    caseMatches = select_coverage_objects( ...
        describe_coverage_objects(caseCoverage), targetPath, ...
        matchCoverageObjects);
    if ~isempty(caseMatches)
        coverage = append_object_coverage(coverage, ...
            caseCoverage(caseMatches), runLabel, 'TEST_CASE', target, ...
            caseName, '', targetPath);
    end

    iterResults = safe_iterations(tcResult);
    for i = 1:numel(iterResults)
        iterName = iteration_name(iterResults(i), i);
        iterCoverage = getCoverageResults(iterResults(i));
        iterationMatches = select_coverage_objects( ...
            describe_coverage_objects(iterCoverage), targetPath, ...
            matchCoverageObjects);
        if ~isempty(iterationMatches)
            coverage = append_object_coverage(coverage, ...
                iterCoverage(iterationMatches), runLabel, 'ITERATION', ...
                target, caseName, iterName, targetPath);
        end
    end
end
end

function indices = select_coverage_objects( ...
        descriptors, targetPath, requireMatch)
if requireMatch
    indices = st_match_coverage_descriptors(descriptors, targetPath);
else
    indices = (1:height(descriptors))';
end
end

function coverage = append_unmatched_coverage(coverage, runLabel, level, ...
        target, testCaseName, iterationName, objectPath)
row = empty_coverage_table();
row(1,:) = {string(runLabel), string(level), double(target.No), ...
    string(target.CUTName), string(testCaseName), string(iterationName), ...
    string(objectPath), "", "", "Coverage", NaN, NaN, NaN, NaN, ...
    "N/A", "EXTRACTION_FAILED", ...
    "No coverage object metadata matched this CUT"};
coverage = [coverage; row];
end

function descriptors = describe_coverage_objects(coverageObjects)
n = numel(coverageObjects);
Root = strings(n, 1);
OwnerModel = strings(n, 1);
OwnerBlock = strings(n, 1);
AnalyzedModel = strings(n, 1);
DataType = strings(n, 1);
for i = 1:n
    Root(i) = string(coverage_source_root(coverageObjects(i)));
    try
        DataType(i) = string(coverageObjects(i).type);
    catch
    end
    try
        info = coverageObjects(i).modelinfo;
        OwnerModel(i) = metadata_value(info, 'ownerModel');
        OwnerBlock(i) = metadata_value(info, 'ownerBlock');
        AnalyzedModel(i) = metadata_value(info, 'analyzedModel');
    catch
    end
end
descriptors = table( ...
    Root, OwnerModel, OwnerBlock, AnalyzedModel, DataType);
end

function value = metadata_value(info, field)
value = "";
if ~isstruct(info) || ~isfield(info, field) || isempty(info)
    return;
end
raw = string({info.(field)});
raw = raw(~ismissing(raw) & strlength(raw) > 0);
if ~isempty(raw), value = raw(1); end
end

function notify_progress(progressFcn, phase, current, total)
if isempty(progressFcn), return; end
progressFcn(phase, current, total);
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
