function tests = test_no_output_verify_skip
%TEST_NO_OUTPUT_VERIFY_SKIP Pure/static checks for output-less targets.
tests = functiontests(localfunctions);
end


function testOutportOnlyModeSkipsWhenNoUsableOutputExists(testCase)
verifyFalse(testCase, st_verify_results_required(true, 0));
verifyTrue(testCase, st_verify_results_required(true, 1));
end


function testAllAssessmentInputsModeStillRequiresVerify(testCase)
verifyTrue(testCase, st_verify_results_required(false, 0));
end


function testInvalidOutputCountsAreRejected(testCase)
verifyError(testCase, @() st_verify_results_required(true, -1), ...
    'simtest:InvalidVerifyOutputCount');
verifyError(testCase, @() st_verify_results_required(true, 0.5), ...
    'simtest:InvalidVerifyOutputCount');
verifyError(testCase, @() st_verify_results_required(true, NaN), ...
    'simtest:InvalidVerifyOutputCount');
end


function testVerifyValidatorDistinguishesSkipFromMissingResult(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'sldv', ...
    'st_validate_sldv_verify_results.m'));

verifyNotEmpty(testCase, regexp(source, ...
    'st_inspect_verify_output_requirement', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'Status\(row,1\) = ''SKIP''', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'SKIP_NO_VERIFY_OUTPUT', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'No verify result was recorded', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'verify result\(s\) remained Untested', 'once'));
end


function testExpectedUpdateSkipsBeforeReadingOutputRuns(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'execution', ...
    'st_update_expected_from_results.m'));

skipPosition = regexp(source, 'SKIP_NO_VERIFY_OUTPUT', 'once');
outputRunPosition = regexp(source, 'getOutputRuns\s*start', 'once');
verifyNotEmpty(testCase, skipPosition);
verifyNotEmpty(testCase, outputRunPosition);
verifyLessThan(testCase, skipPosition, outputRunPosition);
verifyNotEmpty(testCase, regexp(source, ...
    'Simulation Output Run.*없습니다', 'once'));
end


function testPerCutValidationUsesOnlyCurrentTarget(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'execution', ...
    'st_run_tests_per_cut.m'));

verifyNotEmpty(testCase, regexp(source, ...
    'validate_verify_timing\(initialResult, ''initial'', row\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'validate_verify_timing\(finalResult, ''final'', row\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'st_validate_sldv_verify_results\(resultObj, targetRow\)', 'once'));
end
