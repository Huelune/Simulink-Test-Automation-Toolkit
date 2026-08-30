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
