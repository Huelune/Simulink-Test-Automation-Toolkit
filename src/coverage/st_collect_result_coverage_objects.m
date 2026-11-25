function coverageObjects = st_collect_result_coverage_objects(resultObj)
%ST_COLLECT_RESULT_COVERAGE_OBJECTS Find coverage at any result hierarchy.
%
% Some Test Manager releases return model coverage from ResultSet while
% others expose it only from TestCaseResult or TestIterationResult after a
% direct run(testCase). Prefer the aggregate object and descend only when
% the parent has no coverage so the same cvdata is not processed twice.

coverageObjects = st_flatten_coverage_results( ...
    getCoverageResults(resultObj));
if ~isempty(coverageObjects)
    return;
end

caseResults = st_collect_test_case_results(resultObj);
for i = 1:numel(caseResults)
    caseCoverage = safe_coverage(caseResults{i});
    if ~isempty(caseCoverage)
        coverageObjects = [coverageObjects; caseCoverage]; %#ok<AGROW>
        continue;
    end

    iterations = safe_iterations(caseResults{i});
    for j = 1:numel(iterations)
        coverageObjects = [coverageObjects; ...
            safe_coverage(iterations(j))]; %#ok<AGROW>
    end
end
end

function objects = safe_coverage(node)
try
    objects = st_flatten_coverage_results(getCoverageResults(node));
catch
    objects = cell(0, 1);
end
objects = objects(:);
end

function iterations = safe_iterations(caseResult)
try
    iterations = getIterationResults(caseResult);
catch
    iterations = [];
end
end
