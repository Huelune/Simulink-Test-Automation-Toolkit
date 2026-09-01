function tests = test_export_bundle
%TEST_EXPORT_BUNDLE Pure and static export boundary tests.
tests = functiontests(localfunctions);
end

function testConfigUsesRepositoryExportFolder(testCase)
cfg = st_config();
verifyEqual(testCase, cfg.ExportRootDir, ...
    fullfile(st_project_root(), 'result', 'exports'));
end

function testCommonRootAndRelativePath(testCase)
root = fullfile(tempdir, 'simtest_export_root');
first = fullfile(root, 'models', 'top.slx');
second = fullfile(root, 'data', 'input.mat');
verifyEqual(testCase, st_export_common_root({first, second}), root);
verifyEqual(testCase, st_export_relative_path(first, root), ...
    fullfile('models', 'top.slx'));
if ~ispc
    verifyEqual(testCase, ...
        st_export_relative_path('/tmp/model.slx', filesep), ...
        fullfile('tmp', 'model.slx'));
end
end

function testRelativePathRejectsOutsideRoot(testCase)
root = fullfile(tempdir, 'simtest_export_root');
outside = fullfile(tempdir, 'other_export_root', 'top.slx');
verifyError(testCase, @() st_export_relative_path(outside, root), ...
    'simtest:PathOutsideExportRoot');
end

function testSafeNameIsPortable(testCase)
verifyEqual(testCase, st_export_safe_name('CUT A/B:C'), 'CUT_A_B_C');
verifyEqual(testCase, st_export_safe_name('***'), 'item');
verifyLessThanOrEqual(testCase, ...
    strlength(string(st_export_safe_name(repmat('a', 1, 100)))), 80);
end

function testExportResourcesExist(testCase)
root = st_project_root();
verifyTrue(testCase, isfile(fullfile(root, 'resources', ...
    'export_bundle', 'run_exported_tests.m')));
verifyTrue(testCase, isfile(fullfile(root, 'resources', ...
    'export_bundle', 'README.bundle.ko.md')));
verifyTrue(testCase, isfile(fullfile(root, 'resources', ...
    'export_bundle', 'README.assets.ko.md')));
end

function testNormalWorkflowsDoNotInvokeExport(testCase)
root = st_project_root();
workflowFiles = { ...
    fullfile(root, 'src', 'workflow', 'st_run_workflow.m'), ...
    fullfile(root, 'src', 'workflow', 'st_run_from_harness.m'), ...
    fullfile(root, 'src', 'workflow', 'st_run_after_harness.m')};
for i = 1:numel(workflowFiles)
    text = fileread(workflowFiles{i});
    verifyFalse(testCase, contains(text, 'st_export_test_bundle'));
end
end

function testExportDoesNotDetachInternalHarness(testCase)
root = st_project_root();
text = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_test_bundle.m'));
verifyFalse(testCase, contains(text, 'sltest.harness.export('));

assetText = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_standalone_harnesses.m'));
verifyTrue(testCase, contains(assetText, 'sltest.harness.export('));
verifyTrue(testCase, contains(assetText, 'temporaryModelFile'));
verifyTrue(testCase, contains(assetText, ...
    'copy_checked(sourceModelFile, temporaryModelFile)'));
verifyTrue(testCase, contains(assetText, ...
    'temporaryModelFile = fullfile(workRoot, [sourceName extension])'));
verifyTrue(testCase, contains(assetText, ...
    'restore_source_session('));
verifyTrue(testCase, contains(assetText, ...
    "sltest.harness.find(topModel, 'OpenOnly', 'on')"));
verifyTrue(testCase, contains(assetText, ...
    "sourceWasOpen = strcmp(get_param(topModel, 'Open'), 'on')"));
verifyTrue(testCase, contains(assetText, 'sltest.harness.open('));
verifyTrue(testCase, contains(assetText, ...
    "error('simtest:AssetUnsavedHarness'"));
verifyTrue(testCase, contains(assetText, ...
    "error('simtest:AssetTempModelLoadMismatch'"));
verifyFalse(testCase, contains(assetText, 'copied_owner_path'));
end

function testExportShowsWorkflowStyleProgress(testCase)
root = st_project_root();
text = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_test_bundle.m'));
verifyTrue(testCase, contains(text, ...
    'Reproducible Test Bundle Export'));
verifyTrue(testCase, contains(text, ...
    "currentStage = 'Discover Model Dependencies'"));
verifyTrue(testCase, contains(text, ...
    "currentStage = 'Collect Target Inputs'"));
verifyTrue(testCase, contains(text, ...
    "currentStage = 'Create ZIP Archive'"));
verifyTrue(testCase, contains(text, 'START : %s'));
verifyTrue(testCase, contains(text, 'DONE    : %s'));
verifyTrue(testCase, contains(text, 'FAILED  : %s'));
verifyTrue(testCase, contains(text, 'st_log(cfg, ''ERROR'''));
end

function testAssetExportAcceptsSelectedResultSet(testCase)
root = st_project_root();
assetText = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_test_asset_bundle.m'));
harnessText = fileread(fullfile(root, 'src', 'harness', ...
    'st_create_harnesses.m'));

verifyTrue(testCase, contains(assetText, ...
    "addParameter(p, 'ResultSet', [])"));
verifyTrue(testCase, contains(assetText, ...
    "addParameter(p, 'SelectResult', false"));
verifyTrue(testCase, contains(assetText, ...
    "addParameter(p, 'CreateArchive', false"));
verifyTrue(testCase, contains(assetText, ...
    "fullfile(cfg.ExportRootDir, 'assets')"));
verifyFalse(testCase, contains(assetText, 'IncludeReferenceReport'));
verifyTrue(testCase, contains(assetText, ...
    'st_export_result_set_report'));
verifyTrue(testCase, contains(assetText, ...
    'st_export_standalone_harnesses'));
verifyTrue(testCase, contains(assetText, ...
    "'ResultSource', selection.Type"));
verifyTrue(testCase, contains(assetText, ...
    "targetInventory(i).ResultPath = resultBundlePath"));
verifyTrue(testCase, contains(assetText, ...
    'all_harness_inventory(cfg.TopModel)'));
verifyTrue(testCase, contains(assetText, ...
    "st_log(cfg, 'INFO', '[AssetExport] stage start"));
verifyFalse(testCase, contains(assetText, ...
    'matlab.codetools.requiredFilesAndProducts'));
verifyTrue(testCase, contains(harnessText, ...
    "'SaveExternally', false"));
end

function testAssetExportProvidesInteractiveResultPicker(testCase)
root = st_project_root();
text = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_test_asset_bundle.m'));
verifyTrue(testCase, contains(text, ...
    'sltest.testmanager.getResultSets'));
verifyTrue(testCase, contains(text, 'list_toolkit_run_choices(cfg)'));
verifyTrue(testCase, contains(text, 'listdlg('));
verifyTrue(testCase, contains(text, ...
    "'SelectionMode', 'single'"));
verifyTrue(testCase, contains(text, '[Test Manager]'));
verifyTrue(testCase, contains(text, '[Toolkit Run]'));
end

function testAssetTargetSelectionIgnoresEnabledAndUsesResultOrder(testCase)
No = (1:3)';
Enabled = [false; true; false];
CUTPath = ["Top/A";"Top/B";"Top/C"];
HarnessName = ["hA";"hB";"hC"];
TestCaseName = ["tcA";"tcB";"tcC"];
targets = table(No, Enabled, CUTPath, HarnessName, TestCaseName);

selected = st_select_asset_targets(targets, ["tcC";"tcA"]);
verifyEqual(testCase, selected.TestCaseName, ["tcC";"tcA"]);
verifyEqual(testCase, selected.Enabled, [false;false]);
end

function testAssetTargetSelectionRejectsMissingCase(testCase)
targets = asset_target_fixture(["tcA";"tcB"]);
verifyError(testCase, ...
    @() st_select_asset_targets(targets, "tcMissing"), ...
    'simtest:AssetResultTargetMissing');
end

function testAssetTargetSelectionRejectsDuplicateMapping(testCase)
targets = asset_target_fixture(["tcA";"tcA"]);
verifyError(testCase, ...
    @() st_select_asset_targets(targets, "tcA"), ...
    'simtest:AssetResultTargetDuplicate');
end

function testAssetResultSelectionRejectsConflictBeforeRuntime(testCase)
verifyError(testCase, @() st_export_test_asset_bundle( ...
    'ResultSet', 1, 'RunId', 'run-id'), ...
    'simtest:AssetResultSelectionConflict');
end

function testAssetInteractiveSelectionRejectsExplicitRunBeforeRuntime(testCase)
verifyError(testCase, @() st_export_test_asset_bundle( ...
    'SelectResult', true, 'RunId', 'run-id'), ...
    'simtest:AssetResultSelectionConflict');
end

function testAssetResultSelectionRejectsInvalidObjectBeforeRuntime(testCase)
verifyError(testCase, @() st_export_test_asset_bundle( ...
    'ResultSet', 1), 'simtest:InvalidAssetResultSet');
end

function testAssetResultSelectionRejectsNonScalarBeforeRuntime(testCase)
verifyError(testCase, @() st_export_test_asset_bundle( ...
    'ResultSet', [1 2]), 'simtest:InvalidAssetResultSet');
end

function testSelectedResultReportDoesNotUpdateLatestOrClearResults(testCase)
root = st_project_root();
text = fileread(fullfile(root, 'src', 'reporting', ...
    'st_export_result_set_report.m'));
verifyFalse(testCase, contains(text, 'LatestReportPointer'));
verifyFalse(testCase, contains(text, 'clearResults'));
verifyTrue(testCase, contains(text, 'SelectedResults.mldatx'));
verifyTrue(testCase, contains(text, 'SelectedTestResults.pdf'));
end

function testReviewBundleRemainsCompatibilityAlias(testCase)
root = st_project_root();
text = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_review_bundle.m'));
verifyTrue(testCase, contains(text, ...
    'st_export_test_asset_bundle(varargin{:})'));
end

function testRunnerCreatesExecutionWorkspace(testCase)
root = st_project_root();
text = fileread(fullfile(root, 'resources', 'export_bundle', ...
    'run_exported_tests.m'));
verifyTrue(testCase, contains(text, "'executions'"));
verifyTrue(testCase, contains(text, 'copyfile(templateRoot, workRoot)'));
verifyTrue(testCase, contains(text, 'validate_files'));
verifyTrue(testCase, contains(text, 'prepare_existing_session'));
end

function testVerificationSnapshotCanOmitReferenceReport(testCase)
root = st_project_root();
exportText = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_test_bundle.m'));
snapshotText = fileread(fullfile(root, 'src', 'verification', ...
    'st_create_verification_snapshot.m'));
verifyTrue(testCase, contains(exportText, 'IncludeReferenceReport'));
verifyTrue(testCase, contains(snapshotText, ...
    "'IncludeReferenceReport', false"));
end

function targets = asset_target_fixture(names)
n = numel(names);
No = (1:n)';
CUTPath = repmat("Top/CUT", n, 1);
HarnessName = repmat("Harness", n, 1);
TestCaseName = names(:);
targets = table(No, CUTPath, HarnessName, TestCaseName);
end
