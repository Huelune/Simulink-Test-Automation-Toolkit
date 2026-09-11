function tests = test_standalone_coverage_screen_status
%TEST_STANDALONE_COVERAGE_SCREEN_STATUS Static compact-output contracts.
tests = functiontests(localfunctions);
end

function testStatusIsCompactAndScreenshotReady(testCase)
text = string(fileread(fullfile(st_project_root(), 'src', ...
    'verification', 'st_print_standalone_coverage_status.m')));
verifyTrue(testCase, contains(text, 'STANDALONE-STATUS-v1 BEGIN'));
verifyTrue(testCase, contains(text, 'STANDALONE-STATUS-v1 END'));
verifyTrue(testCase, contains(text, 'FILES work[slx='));
verifyTrue(testCase, contains(text, 'flags[preserve=%d hierarchy=%d]'));
verifyTrue(testCase, contains(text, 'RCV=%s HCV=%s'));
verifyTrue(testCase, contains(text, ...
    '234-DETAIL artifact-failures='));
verifyTrue(testCase, contains(text, ...
    'AF " + field_text(sample, ''Type'')'));
verifyTrue(testCase, contains(text, "unique(keys, 'stable')"));
verifyFalse(testCase, contains(text, 'lines(end+1)'));
verifyTrue(testCase, contains(text, 'lines(end+1,1)'));
verifyTrue(testCase, contains(text, ...
    'st_collect_result_coverage_objects(imported(i))'));
verifyFalse(testCase, contains(text, 'zip('));
verifyFalse(testCase, contains(text, 'writetable('));
end
