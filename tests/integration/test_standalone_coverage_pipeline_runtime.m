function tests = test_standalone_coverage_pipeline_runtime
%TEST_STANDALONE_COVERAGE_PIPELINE_RUNTIME Disposable R2025b end-to-end test.
tests = functiontests(localfunctions);
end

function setup(testCase)
assumeTrue(testCase, ~isempty(which('sltest.testmanager.importResults')), ...
    'Simulink Test and Coverage are required.');
sourceRoot = st_project_root();
root = tempname;
mkdir(root);
copyfile(fullfile(sourceRoot, 'src'), fullfile(root, 'src'));
copyfile(fullfile(sourceRoot, 'resources'), fullfile(root, 'resources'));
copyfile(fullfile(sourceRoot, 'st_setup.m'), fullfile(root, 'st_setup.m'));
copyfile(fullfile(sourceRoot, 'VERSION.txt'), fullfile(root, 'VERSION.txt'));
fixture = st_build_verification_fixture(root);
targets = fixture.Targets;
targets.Enabled(:) = false;
targets.Enabled(1) = true;
targets.CoverageFilterMode(:) = "ALL_CONTENT";
targets.CoverageBoundaryMode(:) = "CUT_ONLY";
targets.CoverageFilterAction(:) = "EXCLUDE";
targets.CoverageFilterRationale(:) = ...
    "Standalone pipeline runtime exclusion";
writetable(targets, fixture.ManagementExcel, 'Sheet', 'Targets');

testCase.TestData.Root = root;
testCase.TestData.OldFolder = pwd;
testCase.TestData.TopModel = fixture.TopModel;
cd(root);
clear st_setup st_config st_project_root;
st_setup;
end

function teardown(testCase)
try
    files = sltest.testmanager.getTestFiles;
    for i = 1:numel(files)
        if startsWith(string(files(i).FilePath), ...
                string(testCase.TestData.Root))
            close(files(i));
        end
    end
catch
end
if bdIsLoaded(testCase.TestData.TopModel)
    close_system(testCase.TestData.TopModel, 0);
end
cd(testCase.TestData.OldFolder);
clear st_setup st_config st_project_root;
if isfolder(testCase.TestData.Root)
    try, rmdir(testCase.TestData.Root, 's'); catch, end
end
end

function testPrepareRunResumeAndSourceIntegrity(testCase)
st_run_standalone_coverage_pipeline( ...
    'RunMode', 'STEP1', 'PreparationMode', 'FORCE');
cfg = st_config();
beforeModel = st_file_signature(cfg.ModelFile);
beforeTest = st_file_signature(cfg.TestFile);
beforeExcel = st_file_signature(cfg.ManagementExcel);

% Establish the reported production precondition explicitly: the user did
% not open the source model. STEP234 must keep this state even if dependency
% analysis or Harness APIs load the model internally.
if bdIsLoaded(cfg.TopModel)
    close_system(cfg.TopModel, 0);
end
verifyFalse(testCase, bdIsLoaded(cfg.TopModel));

runInfo = st_run_standalone_coverage_pipeline( ...
    'RunMode', 'STEP234', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false, ...
    'ReportMode', 'SUMMARY');
verifyTrue(testCase, isfile(runInfo.Manifest));
verifyEqual(testCase, string(runInfo.Targets(1).ResultFilterStatus), "OK");

packageInfo = st_run_standalone_coverage_pipeline( ...
    'RunMode', 'STEP5', 'PipelineId', runInfo.PipelineId, ...
    'ReportMode', 'FULL');
finalInfo = st_run_standalone_coverage_pipeline( ...
    'RunMode', 'STEP6', 'PipelineId', runInfo.PipelineId);
verifyTrue(testCase, isfile(packageInfo.TestManagerFile));
verifyTrue(testCase, isfile(finalInfo.CoverageSummary));
target = finalInfo.Targets(1);
verifyTrue(testCase, isfile(target.CVFPath));
verifyTrue(testCase, isfile(target.CoverageResult));
verifyTrue(testCase, isfile(fullfile(target.TestReport, 'report.html')));
verifyTrue(testCase, isfolder(fullfile(target.TestReport, 'coverage')));
verifyTrue(testCase, isfolder(fullfile( ...
    fileparts(finalInfo.Manifest), '.work')));

afterModel = st_file_signature(cfg.ModelFile);
afterTest = st_file_signature(cfg.TestFile);
afterExcel = st_file_signature(cfg.ManagementExcel);
verifyEqual(testCase, afterModel.SHA256, beforeModel.SHA256);
verifyEqual(testCase, afterTest.SHA256, beforeTest.SHA256);
verifyEqual(testCase, afterExcel.SHA256, beforeExcel.SHA256);

% STANDALONE_HARNESS export reloads the source model as a side effect of
% collecting each target's Signal Editor/SLDV input (sltest.harness.load
% loads its owner if not already loaded). If that model is left loaded
% afterward, a later STEP234 run's bundle runner refuses to start because
% a model with the same name is already loaded outside the bundle
% (simtest:BundleModelAlreadyLoaded).
verifyFalse(testCase, bdIsLoaded(testCase.TestData.TopModel));
end

function testStandaloneExportRestoresSessionWhenATargetFails(testCase)
% Forces st_export_standalone_harnesses to fail partway through its
% per-target loop so its onCleanup-driven session restore runs during
% exception unwinding. A prior implementation used a nested cleanup
% function sharing this function's own workspace, which has been observed
% to fail unwinding with "... already removed from the workspace of the
% existing function" instead of propagating the real error.
cfg = st_require_runtime_target();
if ~bdIsLoaded(cfg.TopModel)
    load_system(cfg.ModelFile);
end
wasLoadedBefore = bdIsLoaded(cfg.TopModel);
wasOpenBefore = wasLoadedBefore && ...
    strcmp(get_param(cfg.TopModel, 'Open'), 'on');

targets = st_load_targets(false);
badTarget = targets(1,:);
badTarget.HarnessName = "NoSuchHarnessForRegressionTest";

destination = fullfile(testCase.TestData.Root, 'standalone_export_fail');
bundleRoot = testCase.TestData.Root;

caughtError = [];
try
    st_export_standalone_harnesses( ...
        cfg.ModelFile, cfg.TopModel, badTarget, destination, bundleRoot);
catch caughtError
end

verifyNotEmpty(testCase, caughtError);
verifyEqual(testCase, caughtError.identifier, 'simtest:AssetHarnessMissing');

% The session must be restored to exactly how it was found, and no
% leftover scratch work folder (~w...) should remain under destination.
verifyEqual(testCase, bdIsLoaded(cfg.TopModel), wasLoadedBefore);
if wasLoadedBefore
    verifyEqual(testCase, ...
        strcmp(get_param(cfg.TopModel, 'Open'), 'on'), wasOpenBefore);
end
if isfolder(destination)
    leftoverWork = dir(fullfile(destination, '~w*'));
    verifyEmpty(testCase, leftoverWork);
end
end
