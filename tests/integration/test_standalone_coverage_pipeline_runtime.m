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
st_run_from_harness( ...
    'PreparationMode', 'FORCE', 'ExecutionMode', 'PER_CUT', ...
    'ExecuteTests', false);
cfg = st_config();
beforeModel = st_file_signature(cfg.ModelFile);
beforeTest = st_file_signature(cfg.TestFile);
beforeExcel = st_file_signature(cfg.ManagementExcel);

% Establish the reported production precondition explicitly: the user did
% not open the source model. EXECUTE must keep this state even if dependency
% analysis or Harness APIs load the model internally.
if bdIsLoaded(cfg.TopModel)
    close_system(cfg.TopModel, 0);
end
verifyFalse(testCase, bdIsLoaded(cfg.TopModel));
validatedCfg = st_require_runtime_target('LoadModel', false);
verifyEqual(testCase, validatedCfg.TopModel, cfg.TopModel);
verifyFalse(testCase, bdIsLoaded(cfg.TopModel));

runInfo = st_run_standalone_coverage_pipeline( ...
    'Action', 'EXECUTE', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
verifyTrue(testCase, isfile(runInfo.Manifest));
bundleManifest = jsondecode(fileread(runInfo.BundleManifest));
verifyEqual(testCase,string(bundleManifest.Policy.DependencyScope), ...
    "STANDALONE_HARNESS_MODELS");
verifyEqual(testCase, string(runInfo.Targets(1).ResultFilterStatus), "OK");
verifyEqual(testCase, runInfo.Targets(1).RunCount, 1);
verifyEqual(testCase, runInfo.Targets(1).ResultFilterAttachCount, 1);
verifyEqual(testCase, string(runInfo.Targets(1).PackageEvidenceStatus), "OK");
verifyTrue(testCase, isfile(runInfo.Targets(1).PackageEvidence));
verifyTrue(testCase, runInfo.SaveTestResult);
verifyTrue(testCase, isfile(runInfo.ResultFile));

packageInfo = st_run_standalone_coverage_pipeline( ...
    'Action', 'PACKAGE', 'PipelineId', runInfo.PipelineId);
[packageManifest, ~] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, runInfo.PipelineId);
verifyEqual(testCase, packageManifest.ResultImportCount, 1);
verifyEqual(testCase, packageManifest.PackageResultSource, 'IMPORTED');
finalInfo = st_run_standalone_coverage_pipeline( ...
    'Action', 'SUMMARY', 'PipelineId', runInfo.PipelineId);
verifyTrue(testCase, isfile(packageInfo.TestManagerFile));
verifyTrue(testCase, isfile(finalInfo.CoverageSummary));
target = finalInfo.Targets(1);
verifyEqual(testCase, target.HarnessName, target.StandaloneModel);
[~, modelStem] = fileparts(target.PackagedStandaloneModel);
verifyEqual(testCase, target.HarnessName, modelStem);
verifyTrue(testCase, isfile(target.PackagedCVF));
verifyTrue(testCase, isfile(target.CoverageResult));
verifyTrue(testCase, isfile(target.ReportHTML));
verifyFalse(testCase, isfile(fullfile(target.OutputDirectory, ...
    'TestSummary.xlsx')));
verifyTrue(testCase, isfolder(fullfile( ...
    fileparts(finalInfo.Manifest), '.work')));
resultCountBeforeCheck = numel(sltest.testmanager.getResultSets);
fileStateBeforeCheck = file_state(fileparts(finalInfo.Manifest));
[code, checkSummary] = st_check_standalone_coverage( ...
    'PipelineId', finalInfo.PipelineId);
fileStateAfterCheck = file_state(fileparts(finalInfo.Manifest));
verifyEqual(testCase, code, '1111111111');
verifyEqual(testCase, checkSummary.Status, 'PASS');
verifyEqual(testCase, numel(sltest.testmanager.getResultSets), ...
    resultCountBeforeCheck);
verifyEqual(testCase, fileStateAfterCheck, fileStateBeforeCheck);
for i = 1:numel(finalInfo.Targets)
    verifyFalse(testCase, ...
        bdIsLoaded(finalInfo.Targets(i).StandaloneModel));
end

afterModel = st_file_signature(cfg.ModelFile);
afterTest = st_file_signature(cfg.TestFile);
afterExcel = st_file_signature(cfg.ManagementExcel);
verifyEqual(testCase, afterModel.SHA256, beforeModel.SHA256);
verifyEqual(testCase, afterTest.SHA256, beforeTest.SHA256);
verifyEqual(testCase, afterExcel.SHA256, beforeExcel.SHA256);
for i = 1:numel(packageManifest.SourceAfter.Inputs)
    input = packageManifest.SourceAfter.Inputs(i);
    verifyEqual(testCase, st_file_signature(input.Path).SHA256, ...
        input.SHA256);
end

% STANDALONE_HARNESS export reloads the source model as a side effect of
% collecting each target's Signal Editor/SLDV input (sltest.harness.load
% loads its owner if not already loaded). If that model is left loaded
% afterward, a later EXECUTE run's bundle runner refuses to start because
% a model with the same name is already loaded outside the bundle
% (simtest:BundleModelAlreadyLoaded).
verifyFalse(testCase, bdIsLoaded(testCase.TestData.TopModel));

% Regeneration creates new histories without touching any source bytes.
sourceState = file_state(fileparts(finalInfo.Manifest));
derived = st_run_from_stage('Workflow','STANDALONE','FromStage','PACKAGE', ...
    'SourcePipelineId',finalInfo.PipelineId);
verifyNotEqual(testCase,derived.PipelineId,finalInfo.PipelineId);
verifyEqual(testCase,derived.LocalExecutionCount,0);
verifyEqual(testCase,file_state(fileparts(finalInfo.Manifest)),sourceState);
verifyEqual(testCase,st_check_standalone_coverage('PipelineId',derived.PipelineId),'1111111111');
summaryOnly = st_run_from_stage('Workflow','STANDALONE','FromStage','SUMMARY', ...
    'SourcePipelineId',derived.PipelineId);
verifyEqual(testCase,summaryOnly.LocalExecutionCount,0);
verifyEqual(testCase,st_check_standalone_coverage('PipelineId',summaryOnly.PipelineId),'1111111111');
end

function testAllUsesLiveResultsWithoutResultRoundTrip(testCase)
st_run_from_harness( ...
    'PreparationMode', 'FORCE', 'ExecutionMode', 'PER_CUT', ...
    'ExecuteTests', false);
cfg = st_config();
if bdIsLoaded(cfg.TopModel)
    close_system(cfg.TopModel, 0);
end

info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', 'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
[manifest, ~] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, info.PipelineId);
verifyFalse(testCase, manifest.SaveTestResult);
verifyEqual(testCase, manifest.ResultExportCount, 0);
verifyEqual(testCase, manifest.ResultImportCount, 0);
verifyEqual(testCase, manifest.PackageResultSource, 'LIVE');
verifyEmpty(testCase, manifest.ResultFile);
verifyFalse(testCase, manifest.CanResumePackage);
verifyTrue(testCase, isfile(manifest.CoverageSummary));
for i = 1:numel(manifest.Targets)
    verifyEqual(testCase, ...
        string(manifest.Targets(i).PackageEvidenceStatus), "OK");
    verifyTrue(testCase, isfile(manifest.Targets(i).PackageEvidence));
    verifyTrue(testCase, isfile(manifest.Targets(i).ReportHTML));
end

resultCountBeforeCheck = numel(sltest.testmanager.getResultSets);
fileStateBeforeCheck = file_state(fileparts(info.Manifest));
[code, checkSummary] = st_check_standalone_coverage( ...
    'PipelineId', info.PipelineId);
verifyEqual(testCase, code, '1111111111');
verifyEqual(testCase, checkSummary.Status, 'PASS');
verifyEqual(testCase, numel(sltest.testmanager.getResultSets), ...
    resultCountBeforeCheck);
verifyEqual(testCase, file_state(fileparts(info.Manifest)), ...
    fileStateBeforeCheck);
verifyFalse(testCase, bdIsLoaded(cfg.TopModel));
for i = 1:numel(info.Targets)
    verifyFalse(testCase, bdIsLoaded(info.Targets(i).StandaloneModel));
end
end

function state = file_state(root)
items = dir(fullfile(root, '**', '*'));
items = items(~[items.isdir]);
Path = strings(numel(items),1);
Bytes = zeros(numel(items),1);
Modified = zeros(numel(items),1);
for i = 1:numel(items)
    Path(i) = string(fullfile(items(i).folder, items(i).name));
    Bytes(i) = items(i).bytes;
    Modified(i) = items(i).datenum;
end
state = sortrows(table(Path, Bytes, Modified), 'Path');
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
