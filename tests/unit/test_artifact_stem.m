function tests = test_artifact_stem
%TEST_ARTIFACT_STEM Delivery naming contract shared by producers and checker.
tests = functiontests(localfunctions);
end

function testPrefixIsAdded(testCase)
verifyEqual(testCase, st_artifact_stem('tc_A'), 'UT_REQ_tc_A');
end

function testPrefixIsNotDuplicated(testCase)
% A workbook that already carries the prefix must not become
% UT_REQ_UT_REQ_.
verifyEqual(testCase, st_artifact_stem('UT_REQ_tc_A'), 'UT_REQ_tc_A');
verifyEqual(testCase, st_artifact_stem('ut_req_tc_A'), 'ut_req_tc_A');
end

function testUnsafeCharactersAreStillNormalised(testCase)
verifyEqual(testCase, st_artifact_stem('tc A/B:C'), 'UT_REQ_tc_A_B_C');
end

function testStemStaysWithinTheLengthCap(testCase)
% The prefix is applied before the safe-name pass, so the cap bounds the
% whole stem rather than the prefix pushing it past the path limit.
stem = st_artifact_stem(repmat('a', 1, 100));
verifyEqual(testCase, numel(stem), 80);
verifyTrue(testCase, startsWith(stem, 'UT_REQ_'));
end

function testProducersAndCheckerShareTheHelper(testCase)
% Four producers and the checker must derive the same stem. Any of them
% assembling the string locally is how the delivery names drift apart.
root = st_project_root();
package = fileread(fullfile(root, 'src', 'pipeline', ...
    'st_package_standalone_coverage_artifacts.m'));
verifyEqual(testCase, ...
    numel(strfind(package, 'st_artifact_stem(item.TestCaseName)')), 4);
verifyFalse(testCase, contains(package, ...
    'st_export_safe_name(item.TestCaseName)'));

perCut = fileread(fullfile(root, 'src', 'execution', ...
    'st_run_tests_per_cut.m'));
verifyTrue(testCase, contains(perCut, ...
    "[st_artifact_stem(char(string(row.TestCaseName))) '.cvf']"));

checker = fileread(fullfile(root, 'src', 'verification', ...
    'st_check_standalone_coverage.m'));
verifyTrue(testCase, contains(checker, ...
    "artifactStem = st_artifact_stem(field_text(item, 'TestCaseName'))"));
end
