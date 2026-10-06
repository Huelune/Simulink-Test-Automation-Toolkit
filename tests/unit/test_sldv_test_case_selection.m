function tests = test_sldv_test_case_selection
tests = functiontests(localfunctions);
end


function testEmptyCellSelectsEveryTestCase(testCase)
[indices, isExplicit, normalized] = st_select_sldv_test_cases('', 4);
verifyEqual(testCase, indices, (1:4).');
verifyFalse(testCase, isExplicit);
verifyEqual(testCase, normalized, '');

[indices, isExplicit] = st_select_sldv_test_cases(string(missing), 2);
verifyEqual(testCase, indices, (1:2).');
verifyFalse(testCase, isExplicit);

[indices, isExplicit] = st_select_sldv_test_cases(NaN, 3);
verifyEqual(testCase, indices, (1:3).');
verifyFalse(testCase, isExplicit);
end


function testListAndRangeTokens(testCase)
[indices, isExplicit, normalized] = ...
    st_select_sldv_test_cases('5, 1;3 2-4', 6);
verifyEqual(testCase, indices, (1:5).');
verifyTrue(testCase, isExplicit);
verifyEqual(testCase, normalized, '1,2,3,4,5');
end


function testDuplicatesCollapseAndOrderNormalizes(testCase)
[~, ~, first] = st_select_sldv_test_cases('3,1,3', 5);
[~, ~, second] = st_select_sldv_test_cases(' 1 ,3 ', 5);
verifyEqual(testCase, first, '1,3');
verifyEqual(testCase, first, second);
end


function testNumericCellIsAccepted(testCase)
[indices, isExplicit, normalized] = st_select_sldv_test_cases(2, 3);
verifyEqual(testCase, indices, 2);
verifyTrue(testCase, isExplicit);
verifyEqual(testCase, normalized, '2');
end


function testCountOmittedSkipsRangeCheck(testCase)
[indices, isExplicit, normalized] = st_select_sldv_test_cases('7,9');
verifyEqual(testCase, indices, [7; 9]);
verifyTrue(testCase, isExplicit);
verifyEqual(testCase, normalized, '7,9');
end


function testOutOfRangeIsRejected(testCase)
verifyError(testCase, ...
    @() st_select_sldv_test_cases('1,4,6', 3), ...
    'simtest:SldvTestCaseOutOfRange');
end


function testInvalidTokensAreRejected(testCase)
verifyError(testCase, @() st_select_sldv_test_cases('1,a', 3), ...
    'simtest:InvalidSldvTestCases');
verifyError(testCase, @() st_select_sldv_test_cases('0', 3), ...
    'simtest:InvalidSldvTestCases');
verifyError(testCase, @() st_select_sldv_test_cases('3-1', 3), ...
    'simtest:InvalidSldvTestCases');
verifyError(testCase, @() st_select_sldv_test_cases('TestCase_1', 3), ...
    'simtest:InvalidSldvTestCases');
verifyError(testCase, @() st_select_sldv_test_cases(',', 3), ...
    'simtest:InvalidSldvTestCases');
end


function testInputFilterKeepsTheTestCaseSelection(testCase)
% inspect_sldv_data once wrote the kept input positions into the variable
% that held the selected TestCase numbers. Every TestCase after the first
% was then filtered by input position, so a CUT with 3 inputs and 12
% TestCases kept only TestCases 1-3 without a warning. The variable the
% loop tests must be assigned once, by st_select_sldv_test_cases.
source = fileread(fullfile(st_project_root(), ...
    'src', 'sldv', 'st_prepare_sldv_targets.m'));
body = extractBetween(source, ...
    'function meta = inspect_sldv_data(', [newline 'function ']);
assertNumElements(testCase, body, 1);
body = body{1};

loopVariable = regexp(body, ...
    'if ~ismember\(sourceIndex, (\w+)\)', 'tokens', 'once');
assertNumElements(testCase, loopVariable, 1);
name = loopVariable{1};

assignments = regexp(body, ['(\[[^\]\n]*\<' name '\>[^\]\n]*\]|\<' ...
    name '\>)\s*=[^=]'], 'match');
verifyNumElements(testCase, assignments, 1);
verifyTrue(testCase, contains(assignments{1}, 'selectionIsExplicit'));
end
