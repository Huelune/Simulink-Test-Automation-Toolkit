function tests = test_standalone_harness_bundle
%TEST_STANDALONE_HARNESS_BUNDLE Static v2 replay contracts.
tests = functiontests(localfunctions);
end

function testPublicOptionAndManifestV2(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_test_bundle.m'));
verifyTrue(testCase, contains(source, ...
    "addParameter(p, 'ExecutionModelMode', 'ORIGINAL'"));
verifyTrue(testCase, contains(source, "manifest.Version = 2"));
verifyTrue(testCase, contains(source, ...
    "manifest.ExecutionModelMode = executionModelMode"));
verifyTrue(testCase, contains(source, ...
    "item.CoverageBoundaryMode = char(row.CoverageBoundaryMode)"));
verifyTrue(testCase, contains(source, ...
    'StandaloneHarnessRequiresReproducibleProfile'));
end

function testDisposableExportUsesUniqueTargetModelAndCUTReadback(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_standalone_harnesses.m'));
verifyTrue(testCase, contains(source, "'TARGET_HARNESS'"));
verifyTrue(testCase, contains(source, "sprintf('st_h_%04d_%s'"));
verifyTrue(testCase, contains(source, 'temporaryModelFile'));
verifyTrue(testCase, contains(source, 'identify_standalone_cut'));
verifyTrue(testCase, contains(source, 'interface_signature'));
verifyTrue(testCase, contains(source, 'StandaloneCUTPath'));
end

function testRunnerRewiresAndUsesSequentialPath(testCase)
root = st_project_root();
runner = fileread(fullfile(root, 'resources', 'export_bundle', ...
    'run_exported_tests.m'));
prepare = fileread(fullfile(root, 'src', 'execution', ...
    'st_prepare_standalone_bundle_execution.m'));
verifyTrue(testCase, contains(runner, ...
    "strcmp(executionModelMode, 'STANDALONE_HARNESS')"));
verifyTrue(testCase, contains(runner, 'st_run_tests_per_cut('));
verifyTrue(testCase, contains(prepare, "'HarnessOwner', ''"));
verifyTrue(testCase, contains(prepare, "'HarnessName', ''"));
verifyTrue(testCase, contains(prepare, ...
    "verify_property(tc, 'Model', model)"));
verifyTrue(testCase, contains(prepare, ...
    "verify_property(tc, 'TestSequenceBlock', assessment)"));
verifyTrue(testCase, contains(prepare, ...
    'originalIterationSignature = iteration_signature(tc)'));
verifyTrue(testCase, contains(prepare, ...
    'StandaloneIterationChanged'));
end

function testStandaloneExportPathsStayShort(testCase)
% destination here is already deeply nested (template/workspace/
% standalone/...) under whatever the caller passed. tempname() and an
% unbounded CUT-name folder both risk pushing a deeply nested project
% path past the Windows 260-character MAX_PATH limit
% (MATLAB:cd:DirectoryNameTooLong).
root = st_project_root();
source = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_standalone_harnesses.m'));
verifyTrue(testCase, contains(source, 'short_work_directory'));
verifyFalse(testCase, contains(source, 'tempname(destination)'));
verifyTrue(testCase, contains(source, 'maxNameLength = 32'));
end


function testExpectedUpdateSupportsStandaloneRoot(testCase)
root = st_project_root();
update = fileread(fullfile(root, 'src', 'execution', ...
    'st_update_expected_from_results.m'));
logging = fileread(fullfile(root, 'src', 'execution', ...
    'st_prepare_expected_value_logging_for_targets.m'));
verifyTrue(testCase, contains(update, 'harnessRoot = executionModel'));
verifyTrue(testCase, contains(update, 'save_system(executionModel)'));
verifyTrue(testCase, contains(logging, ...
    'loggingRoot = executionModel'));
end
