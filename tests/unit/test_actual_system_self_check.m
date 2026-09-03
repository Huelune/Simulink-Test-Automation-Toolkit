function tests = test_actual_system_self_check
%TEST_ACTUAL_SYSTEM_SELF_CHECK Static contract for compact field checks.
tests = functiontests(localfunctions);
end


function testDiagnosticUsesFixedEighteenBitContract(testCase)
source = diagnostic_source();
envLabels = {'E1:R2025B','E2:PRODUCTS','E3:LICENSES', ...
    'E4:INPUTS','E5:APIS','E6:PATHS'};
runLabels = {'R1:RUN_ROOT','R2:TARGET_MAPPING','R3:EXECUTION', ...
    'R4:EXPECTED_UPDATE','R5:ARTIFACTS','R6:FILTER_RESTORE'};
for i = 1:numel(envLabels)
    verifyNotEmpty(testCase, regexp(source, envLabels{i}, 'once'));
end
for i = 1:numel(runLabels)
    verifyNotEmpty(testCase, regexp(source, runLabels{i}, 'once'));
end
verifyNotEmpty(testCase, regexp(source, ...
    'SYSTEM-CHECK-v1 ENV=%s RUN=%s CVF=%s', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    "strcmp\(overallCode, '111111111111111111'\)", 'once'));
end


function testEnvironmentChecksRequiredRuntimeAndPaths(testCase)
source = diagnostic_source();
requiredTokens = { ...
    "version('-release')", "license('test'", ...
    'cfg.RuntimeTargetFile', 'cfg.ManagementExcel', 'cfg.TestFile', ...
    "which(char(name), '-all')", ...
    'dependencies.fileDependencyAnalysis'};
for i = 1:numel(requiredTokens)
    verifyNotEmpty(testCase, regexp(source, ...
        regexptranslate('escape', requiredTokens{i}), 'once'));
end
end


function testRunChecksExecutionUpdateArtifactsAndLeakage(testCase)
source = diagnostic_source();
requiredTokens = { ...
    "fullfile(runDirectory, 'manifest.json')", ...
    "{'Order'}", "{'InitialOutcome'}", "{'ExpectedUpdatedCount'}", ...
    "{'RerunPerformed'}", 'RESULT_INTEGRITY', 'CVF_COPY', ...
    'fileCoverage.CoverageFilterFilename', ...
    'suiteCoverage.CoverageFilterFilename', ...
    'st_check_per_cut_cvf'};
for i = 1:numel(requiredTokens)
    verifyNotEmpty(testCase, regexp(source, ...
        regexptranslate('escape', requiredTokens{i}), 'once'));
end
end


function testDiagnosticDoesNotWriteOrSaveProjectAssets(testCase)
source = diagnostic_source();
forbidden = {'writetable\s*\(', 'writecell\s*\(', ...
    'save_system\s*\(', 'saveToFile\s*\(', ...
    'st_write_result\s*\('};
for i = 1:numel(forbidden)
    verifyEmpty(testCase, regexp(source, forbidden{i}, 'once'));
end
verifyNotEmpty(testCase, regexp(source, ...
    'close_checker_test_file', 'once'));
end


function source = diagnostic_source()
root = st_project_root();
path = fullfile(root, 'diagnostics', 'matlab', ...
    'st_check_actual_system.m');
assert(isfile(path), 'Actual-system diagnostic is missing.');
source = fileread(path);
end
