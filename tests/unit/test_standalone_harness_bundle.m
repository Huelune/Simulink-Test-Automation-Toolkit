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
verifyTrue(testCase, contains(prepare, ...
    'configure_standalone_coverage(tf, suite, tc, cfg)'));
verifyTrue(testCase, contains(prepare, ...
    'caseCoverage.RecordCoverage = true'));
verifyTrue(testCase, contains(prepare, ...
    'verify_coverage_enabled(testCases(i))'));
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


function testCleanupSessionUsesReferenceStateNotNestedFunction(testCase)
% onCleanup(@nestedFunction) sharing this function's own workspace has
% been observed to fail during exception unwinding with "... already
% removed from the workspace of the existing function" instead of
% propagating the real error. cleanup_export_session must be a plain
% (non-nested) function driven by a containers.Map, whose mutations are
% visible regardless of how the caller's stack frame is torn down.
root = st_project_root();
source = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_standalone_harnesses.m'));
verifyTrue(testCase, contains(source, 'containers.Map()'));
verifyTrue(testCase, contains(source, ...
    "onCleanup(@() cleanup_export_session(state))"));
verifyFalse(testCase, contains(source, ...
    'onCleanup(@cleanup_export_session)'));
verifyTrue(testCase, contains(source, ...
    'function cleanup_export_session(state)'));
verifyFalse(testCase, contains(source, ...
    'function cleanup_export_session()'));
end


function testCollectTargetInputsRestoresTopModelLoadState(testCase)
% collect_target_inputs calls sltest.harness.load per target, which loads
% cfg.TopModel as a side effect when it is not already loaded; only the
% Harness was being closed afterward. A model left loaded here makes a
% later bundle runner invocation fail with
% simtest:BundleModelAlreadyLoaded even though nothing the user did left
% it open.
root = st_project_root();
source = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_test_bundle.m'));
verifyTrue(testCase, contains(source, ...
    'topModelWasLoadedAtEntry = bdIsLoaded(cfg.TopModel)'));
verifyTrue(testCase, contains(source, ...
    "st_require_runtime_target('LoadModel', false)"));
verifyTrue(testCase, contains(source, ...
    'cfg.TopModel, topModelWasLoadedAtEntry'));
verifyTrue(testCase, contains(source, ...
    'function restore_top_model_load_state(topModel, wasLoadedBefore)'));
verifyTrue(testCase, contains(source, ...
    'normalize_top_model_load_state(cfg, topModelWasLoadedAtEntry'));
verifyTrue(testCase, contains(source, ...
    'templateRoot, topModelWasLoadedAtEntry)'));
verifyFalse(testCase, contains(source, ...
    'topModelWasLoaded = bdIsLoaded(cfg.TopModel)'));
verifyTrue(testCase, contains(source, ...
    "if ~bdIsLoaded(cfg.TopModel)"));
verifyTrue(testCase, contains(source, ...
    'Target input source model load start'));
% Never auto-save a model that became dirty as a side effect; warn and
% leave it for the user instead.
verifyTrue(testCase, contains(source, ...
    "strcmp(get_param(topModel, 'Dirty'), 'on')"));
verifyFalse(testCase, contains(source, ...
    'save_system(topModel)'));
end


function testStandaloneRunSeparatesExportRestoreFromRunnerIsolation(testCase)
% Export preserves the caller's entry state. The pipeline, which actually
% launches the copied model, owns the stricter unloaded-source guard.
root = st_project_root();
source = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_test_bundle.m'));
verifyFalse(testCase, contains(source, 'assert_top_model_not_loaded'));
pipeline = fileread(fullfile(root, 'src', 'pipeline', ...
    'st_run_standalone_coverage_pipeline.m'));
verifyTrue(testCase, contains(pipeline, ...
    "assert_pipeline_source_unloaded(cfg, 'before standalone export')"));
verifyTrue(testCase, contains(pipeline, ...
    "assert_pipeline_source_unloaded(cfg, 'before bundle runner')"));
runner = fileread(fullfile(root, 'resources', 'export_bundle', ...
    'run_exported_tests.m'));
verifyTrue(testCase, contains(runner, 'BundleModelAlreadyLoaded'));
end


function testRuntimeTargetCanBeValidatedWithoutLoadingModel(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'shared', ...
    'st_require_runtime_target.m'));
verifyTrue(testCase, contains(source, ...
    "addParameter(p, 'LoadModel', true"));
verifyTrue(testCase, contains(source, ...
    'p.Results.LoadModel && ~bdIsLoaded(cfg.TopModel)'));
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
