function tests = test_coverage_filters
%TEST_COVERAGE_FILTERS Unit/static checks for managed coverage filters.
tests = functiontests(localfunctions);
end


function testBlankModeDefaultsToOff(testCase)
[mode, action, rationale] = ...
    st_resolve_coverage_filter_settings([""; missing], ["EXCLUDE"; ""], ...
        ["ignored"; ""]);

verifyEqual(testCase, mode, ["OFF"; "OFF"]);
verifyEqual(testCase, action, [""; ""]);
verifyEqual(testCase, rationale, [""; ""]);
end


function testActiveSettingsAreNormalized(testCase)
[mode, action, rationale] = st_resolve_coverage_filter_settings( ...
    [" subsystem "; "all_content"], [" exclude "; "justify"], ...
    [" direct children "; "approved content"]);

verifyEqual(testCase, mode, ["SUBSYSTEM"; "ALL_CONTENT"]);
verifyEqual(testCase, action, ["EXCLUDE"; "JUSTIFY"]);
verifyEqual(testCase, rationale, ...
    ["direct children"; "approved content"]);
end


function testInvalidSettingsAreRejected(testCase)
verifyError(testCase, @() st_resolve_coverage_filter_settings( ...
    "BLOCK", "EXCLUDE", "reason"), ...
    'simtest:InvalidCoverageFilterMode');
verifyError(testCase, @() st_resolve_coverage_filter_settings( ...
    "SUBSYSTEM", "IGNORE", "reason"), ...
    'simtest:InvalidCoverageFilterAction');
verifyError(testCase, @() st_resolve_coverage_filter_settings( ...
    "ALL_CONTENT", "JUSTIFY", ""), ...
    'simtest:MissingCoverageFilterRationale');
end


function testApplicationModeValidation(testCase)
verifyEqual(testCase, ...
    st_coverage_filter_application_mode(' runtime '), 'RUNTIME');
verifyEqual(testCase, ...
    st_coverage_filter_application_mode('persist'), 'PERSIST');
verifyError(testCase, ...
    @() st_coverage_filter_application_mode('GUI'), ...
    'simtest:InvalidCoverageFilterApplicationMode');
end


function testManagedFileIsStableAndRowSpecific(testCase)
cfg = struct('TopModel', 'Top', ...
    'CoverageFilterDir', fullfile(tempdir, 'managed_filters'));
No = [1; 2];
CUTPath = ["Top/CUT"; "Top/CUT"];
TestCaseName = ["TC"; "TC"];
rows = table(No, CUTPath, TestCaseName);

first = st_coverage_filter_file(rows(1,:), cfg);
verifyEqual(testCase, first, ...
    st_coverage_filter_file(rows(1,:), cfg));
verifyNotEqual(testCase, first, ...
    st_coverage_filter_file(rows(2,:), cfg));
verifyTrue(testCase, endsWith(string(first), ".cvf"));
end


function testApplicationUsesTestCaseApiOnly(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'coverage', ...
    'st_apply_test_case_coverage_filters.m'));

verifyNotEmpty(testCase, regexp(source, ...
    'getCoverageSettings\(caseCells\{i\}\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'coverageObjects\{i\}\.CoverageFilterFilename', 'once'));
verifyEmpty(testCase, regexp(source, ...
    'fileCoverage\.CoverageFilterFilename\s*=', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'getCoverageSettings\(caseCells\{i\}\.Parent\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'originalFilters\{i\}\s*=\s*current', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'session\s*=\s*struct', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'Restore.*@restore_explicit', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'CoverageFilterRestoreMismatch', 'once'));
end


function testExecutionKeepsSingleTestFileRun(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'execution', ...
    'st_run_generated_tests.m'));

verifyGreaterThanOrEqual(testCase, ...
    numel(regexp(source, 'run\(tf\)', 'match')), 1);
verifyNotEmpty(testCase, regexp(source, ...
    'st_apply_test_case_coverage_filters', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'coverageFilterSession\.Restore\(\)', 'once'));
end
