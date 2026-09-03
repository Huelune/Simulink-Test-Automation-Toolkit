function resultCells = st_collect_test_case_results(resultObj)
%ST_COLLECT_TEST_CASE_RESULTS Collect TestCaseResult objects at any depth.
%
% run(testCase) can place TestCaseResult directly below ResultSet, while
% run(testFile) normally uses ResultSet/TestFileResult/TestSuiteResult.

resultCells = {};
pending = object_cells(resultObj);

while ~isempty(pending)
    node = pending{1};
    pending(1) = [];

    caseResults = safe_test_case_results(node);
    for i = 1:numel(caseResults)
        candidate = caseResults(i);
        if ~contains_result(resultCells, candidate)
            resultCells{end+1,1} = candidate; %#ok<AGROW>
        end
    end

    pending = [pending; object_cells(safe_test_file_results(node)); ...
        object_cells(safe_test_suite_results(node))]; %#ok<AGROW>
end
end


function children = safe_test_case_results(node)
try
    children = getTestCaseResults(node);
catch
    children = [];
end
end


function children = safe_test_file_results(node)
try
    children = getTestFileResults(node);
catch
    children = [];
end
end


function children = safe_test_suite_results(node)
try
    children = getTestSuiteResults(node);
catch
    children = [];
end
end


function cells = object_cells(objects)
cells = cell(numel(objects), 1);
for i = 1:numel(objects)
    cells{i} = objects(i);
end
end


function tf = contains_result(results, candidate)
tf = false;
for i = 1:numel(results)
    try
        if isequal(results{i}, candidate)
            tf = true;
            return;
        end
    catch
    end
end
end
