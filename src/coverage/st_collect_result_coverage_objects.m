function coverageObjects = st_collect_result_coverage_objects(resultObj, boundObjects)
%ST_COLLECT_RESULT_COVERAGE_OBJECTS Find coverage at any result hierarchy.
%
% Some Test Manager releases return model coverage from ResultSet while
% others expose it only from TestCaseResult or TestIterationResult after a
% direct run(testCase). Prefer the aggregate object and descend only when
% the parent has no coverage so the same cvdata is not processed twice.
%
% st_collect_result_coverage_objects(resultObj, boundObjects) remembers the
% instances a CVF was set on. Test Manager can hand out a new cvdata
% instance on every query, and a CVF set on one is not on the next: a PER_CUT
% collect reported CUT decisions 27/30 where the same CUT's CVF-filtered
% coverage was 20/22. Later queries for that result return the bound ones,
% so every report reads the filtered coverage.

persistent bindings
if isempty(bindings), bindings = cell(0, 2); end
known = cellfun(@(r) same_result(r, resultObj), bindings(:, 1));
if nargin >= 2
    % shortcut: keeps the last 4 bindings (one target's initial and final need 2), pass the objects explicitly if a caller binds more before it reports
    bindings = [bindings(~known, :); {resultObj, boundObjects(:)}];
    bindings = bindings(max(1, end - 3):end, :);
    coverageObjects = boundObjects(:);
    return;
end
if any(known)
    coverageObjects = bindings{find(known, 1, 'last'), 2};
    return;
end

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

function tf = same_result(a, b)
% A deleted or different object simply does not match.
try
    tf = isequal(a, b);
catch
    tf = false;
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
