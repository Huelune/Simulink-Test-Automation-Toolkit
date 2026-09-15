function tests = test_standalone_coverage_screen_status
%TEST_STANDALONE_COVERAGE_SCREEN_STATUS One-screen checker contracts.
tests = functiontests(localfunctions);
end

function testCheckerIsReadOnlyAndBounded(testCase)
text = checker_source();
verifyTrue(testCase, contains(text, 'STANDALONE-CHECK-v1 BEGIN'));
verifyTrue(testCase, contains(text, 'STANDALONE-CHECK-v1 END'));
verifyTrue(testCase, contains(text, '1111111111'));
verifyTrue(testCase, contains(text, 'shown = min(10, numel(order))'));
verifyTrue(testCase, contains(text, ...
    'additional targets; inspect details'));
for forbidden = ["importResults","load_system","save_system", ...
        "set_param","clearResults","writetable","writecell"]
    verifyFalse(testCase, contains(text, forbidden));
end
end

function testCompleteFixtureReturnsAllOnes(testCase)
[root, manifest] = complete_fixture(testCase, 2);
st_write_standalone_pipeline_manifest(root, manifest);
output = evalc('[code, summary, details] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code, '1111111111');
verifyTrue(testCase, isscalar(summary));
verifyEqual(testCase, summary.Status, 'PASS');
verifyEqual(testCase, numel(summary.Bits), 10);
verifyEqual(testCase, height(details), 2);
verifyLessThanOrEqual(testCase, numel(splitlines(string(output))), 20);
end

function testPackageFailureAppearsInDetails(testCase)
[root, manifest] = complete_fixture(testCase, 1);
manifest.Targets(1).PackageStatus = 'FAIL';
manifest.Targets(1).PackageFailure = struct( ...
    'Identifier', 'simtest:PackageStage', ...
    'Message', 'Package diagnostics preserve this cause.', ...
    'Stack', struct('Name', 'package_target', ...
        'File', 'st_package_standalone_coverage_artifacts.m', 'Line', 171));
manifest.Actions.PACKAGE.Status = 'WARN';
manifest.Status = 'PARTIAL';
st_write_standalone_pipeline_manifest(root, manifest);
evalc('[~, ~, details] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyTrue(testCase, contains(details.Message(1), 'simtest:PackageStage'));
verifyTrue(testCase, contains(details.Message(1), ...
    'st_package_standalone_coverage_artifacts.m:171'));
end

function testRunCountFailureClearsB4(testCase)
[root, manifest] = complete_fixture(testCase, 1);
manifest.Targets(1).RunCount = 2;
st_write_standalone_pipeline_manifest(root, manifest);
evalc('[code, summary] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(4), '0');
verifyEqual(testCase, summary.Status, 'FAIL');
end

function testIncompleteManifestFailsClosed(testCase)
[root, manifest] = complete_fixture(testCase, 1);
manifest = rmfield(manifest, 'Targets');
st_write_standalone_pipeline_manifest(root, manifest);
output = evalc('[code, summary, details] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code, '0000000000');
verifyEqual(testCase, summary.Status, 'FAIL');
verifyEmpty(testCase, details);
verifyTrue(testCase, contains(output, 'CODE 0000000000 FAIL'));
end

function testAttachCountFailureClearsB5(testCase)
for count = [0 2]
    [root, manifest] = complete_fixture(testCase, 1);
    manifest.Targets(1).ResultFilterAttachCount = count;
    st_write_standalone_pipeline_manifest(root, manifest);
    evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
    verifyEqual(testCase, code(5), '0');
end
end

function testLifecycleOrderFailureClearsB5(testCase)
[root, manifest] = complete_fixture(testCase, 1);
write_text(manifest.ExecutionLog, '');
append_event(manifest.ExecutionLog, 1, 'RUN_START');
append_event(manifest.ExecutionLog, 1, 'CVF_GENERATE');
append_event(manifest.ExecutionLog, 1, 'RUN_DONE');
append_event(manifest.ExecutionLog, 1, 'RESULT_FILTER_ATTACH');
append_event(manifest.ExecutionLog, 1, 'FILTER_RESTORE');
append_event(manifest.ExecutionLog, 1, 'MODEL_CLEANUP');
append_event(manifest.ExecutionLog, 1, 'PATH_CLEANUP');
st_write_standalone_pipeline_manifest(root, manifest);
evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(5), '0');
end

function testNameMismatchClearsB2(testCase)
[root, manifest] = complete_fixture(testCase, 1);
manifest.Targets(1).StandaloneModel = 'st_h_wrong';
st_write_standalone_pipeline_manifest(root, manifest);
evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(2), '0');
end

function testMissingPackageArtifactClearsB6(testCase)
fields = {'CoverageResult','PackagedCVF','ReportHTML'};
for i = 1:numel(fields)
    [root, manifest] = complete_fixture(testCase, 1);
    delete(manifest.Targets(1).(fields{i}));
    st_write_standalone_pipeline_manifest(root, manifest);
    evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
    verifyEqual(testCase, code(6), '0');
end
end

function testSummarySchemaFailureClearsB8(testCase)
[root, manifest] = complete_fixture(testCase, 1);
Wrong = "bad"; %#ok<NASGU>
writetable(table(Wrong), manifest.CoverageSummary, ...
    'Sheet', 'CoverageSummary');
manifest.CoverageSummarySHA256 = ...
    st_file_signature(manifest.CoverageSummary).SHA256;
st_write_standalone_pipeline_manifest(root, manifest);
evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(8), '0');
end

function testZeroDenominatorMetricKeepsB7Valid(testCase)
[root, manifest] = complete_fixture(testCase, 1);
manifest.Targets(1).DecisionCovered = 0;
manifest.Targets(1).DecisionTotal = 0;
manifest.Targets(1).DecisionPercentage = NaN;
manifest.Targets(1).DecisionPercentageText = 'N/A';
st_write_standalone_pipeline_manifest(root, manifest);
evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(7), '1');
end

function testSummaryRowCountFailureClearsB8(testCase)
[root, manifest] = complete_fixture(testCase, 2);
value = readtable(manifest.CoverageSummary, ...
    'Sheet', 'CoverageSummary', 'VariableNamingRule', 'preserve');
writetable(value(1,:), manifest.CoverageSummary, ...
    'Sheet', 'CoverageSummary');
manifest.CoverageSummarySHA256 = ...
    st_file_signature(manifest.CoverageSummary).SHA256;
st_write_standalone_pipeline_manifest(root, manifest);
evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(8), '0');
end

function testSourceAndCleanupFailuresClearFinalBits(testCase)
[root, manifest] = complete_fixture(testCase, 1);
manifest.SourceAfter.Model.SHA256 = 'changed';
manifest.Targets(1).ModelCleanupStatus = 'FAIL';
st_write_standalone_pipeline_manifest(root, manifest);
evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(9:10), '00');
end

function testChangedSourceInputClearsB9(testCase)
[root, manifest] = complete_fixture(testCase, 1);
write_text(manifest.SourceAfter.Inputs(1).Path, 'changed input');
st_write_standalone_pipeline_manifest(root, manifest);
evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(9), '0');
end

function testMoreThanTenTargetsStaysWithinTwentyLines(testCase)
[root, manifest] = complete_fixture(testCase, 12);
manifest.Targets(12).RunCount = 2;
st_write_standalone_pipeline_manifest(root, manifest);
output = evalc('[~, ~, details] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, height(details), 12);
verifyLessThanOrEqual(testCase, numel(splitlines(strtrim(string(output)))), 20);
verifyTrue(testCase, contains(output, 'additional targets; inspect details'));
end

function testExecuteOnlyUsesPartialBits(testCase)
[root, manifest] = complete_fixture(testCase, 1);
manifest.Action = 'EXECUTE';
manifest.Status = 'PARTIAL';
manifest.Actions.PACKAGE.Status = 'NOT_RUN';
manifest.Actions.SUMMARY.Status = 'NOT_RUN';
manifest.CoverageSummary = '';
manifest.CoverageSummarySHA256 = '';
st_write_standalone_pipeline_manifest(root, manifest);
evalc('[code, summary] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(6:8), '---');
verifyEqual(testCase, summary.Status, 'PARTIAL');
end

function testForbiddenArtifactClearsB6(testCase)
[root, manifest] = complete_fixture(testCase, 1);
write_text(fullfile(manifest.Targets(1).OutputDirectory, ...
    'coverage-metrics.mat'), 'forbidden');
st_write_standalone_pipeline_manifest(root, manifest);
evalc('[code, summary] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(6), '0');
verifyEqual(testCase, summary.Files.Forbidden, 1);
end

function testDuplicateCoverageArtifactClearsB6(testCase)
[root, manifest] = complete_fixture(testCase, 1);
write_text(fullfile(manifest.Targets(1).OutputDirectory, ...
    'duplicate.cvt'), 'duplicate');
st_write_standalone_pipeline_manifest(root, manifest);
evalc('code = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code(6), '0');
end

function [root, manifest] = complete_fixture(testCase, count)
root = tempname;
mkdir(root);
testCase.addTeardown(@() remove_fixture(root));
pipelineId = 'fixture';
pipelineRoot = fullfile(root, pipelineId);
mkdir(pipelineRoot);
logDirectory = fullfile(pipelineRoot, 'logs');
mkdir(logDirectory);
eventLog = fullfile(logDirectory, 'execution.log');

state = struct('Status', 'OK', 'Message', '', 'UpdatedAt', 'now');
sourceDirectory = fullfile(root, 'source');
modelSource = fullfile(sourceDirectory, 'Top.slx');
testSource = fullfile(sourceDirectory, 'Top.mldatx');
excelSource = fullfile(sourceDirectory, 'TestManagement.xlsx');
inputSource = fullfile(sourceDirectory, 'input.mat');
write_text(modelSource, 'source model');
write_text(testSource, 'source test');
write_text(excelSource, 'source excel');
write_text(inputSource, 'source input');
sourceState = struct( ...
    'Model', st_file_signature(modelSource), ...
    'TestFile', st_file_signature(testSource), ...
    'ManagementExcel', st_file_signature(excelSource), ...
    'ModelDirty', false, 'TestFileDirty', false, ...
    'HarnessInventory', {{'Top/CUT|Harness'}}, ...
    'Harnesses', struct('Owner', 'Top/CUT', 'Name', 'Harness', ...
        'Storage', 'INTERNAL_MODEL', 'Path', modelSource, ...
        'SHA256', st_file_signature(modelSource).SHA256), ...
    'Inputs', struct('No', 1, 'Path', inputSource, ...
        'SHA256', st_file_signature(inputSource).SHA256));
targets = repmat(empty_target(), count, 1);
for i = 1:count
    targetDirectory = fullfile(pipelineRoot, ...
        sprintf('%03d_UT_REQ_TC_%d', i, i));
    mkdir(targetDirectory);
    harness = sprintf('Harness%d', i);
    model = fullfile(targetDirectory, [harness '.slx']);
    input = fullfile(targetDirectory, sprintf('input%d.mat', i));
    cvf = fullfile(targetDirectory, sprintf('UT_REQ_TC_%d.cvf', i));
    cvt = fullfile(targetDirectory, sprintf('UT_REQ_TC_%d.cvt', i));
    reportDirectory = targetDirectory;
    html = fullfile(reportDirectory, sprintf('UT_REQ_TC_%d.html', i));
    write_text(model, 'model');
    write_text(input, 'input');
    write_text(cvf, 'cvf');
    write_text(cvt, 'cvt');
    write_text(html, 'html');
    item = empty_target();
    item.Order = i;
    item.No = i;
    item.CUTName = sprintf('CUT_%d', i);
    item.CUTPath = sprintf('Top/CUT_%d', i);
    item.HarnessName = harness;
    item.StandaloneModel = harness;
    item.StandaloneModelFile = model;
    item.TestCaseName = sprintf('TC_%d', i);
    item.ExpectedUpdateMode = 'OFF';
    item.SUTReadbackStatus = 'OK';
    item.IterationIntegrityStatus = 'OK';
    item.InputReadbackStatus = 'OK';
    item.AssessmentReadbackStatus = 'OK';
    item.RunCount = 1;
    item.RerunPerformed = false;
    item.CVFGenerationStatus = 'OK';
    item.CVFRuleCount = 1;
    item.ExecutionCVFPath = cvf;
    item.CVFSHA256 = st_file_signature(cvf).SHA256;
    item.ResultFilterAttachCount = 1;
    item.ResultFilterStatus = 'OK';
    item.FilterRestoreStatus = 'OK';
    item.ModelCleanupStatus = 'OK';
    item.PathCleanupStatus = 'OK';
    item.ExecutionStatus = 'PASS';
    item.PackageStatus = 'OK';
    item.SummaryStatus = 'OK';
    item.SignalEditorInput = input;
    item.PackagedStandaloneModel = model;
    item.PackagedStandaloneModelSHA256 = st_file_signature(model).SHA256;
    item.PackagedInput = input;
    item.PackagedInputSHA256 = st_file_signature(input).SHA256;
    item.PackagedInputReadbackStatus = 'OK';
    item.PackagedCVF = cvf;
    item.PackagedCVFSHA256 = st_file_signature(cvf).SHA256;
    item.CoverageResult = cvt;
    item.CoverageResultSHA256 = st_file_signature(cvt).SHA256;
    item.TestReport = reportDirectory;
    item.ReportHTML = html;
    item.OutputDirectory = targetDirectory;
    item.MetricSource = 'Result coverage API';
    item.MetricSourceStatus = 'PROVISIONAL';
    item.DecisionMetricStatus = 'OK';
    item.ExecutionMetricStatus = 'OK';
    item.DecisionCovered = 1;
    item.DecisionTotal = 2;
    item.DecisionPercentage = 50;
    item.ExecutionCovered = 3;
    item.ExecutionTotal = 4;
    item.ExecutionPercentage = 75;
    item.DecisionPercentageText = '50.00';
    item.ExecutionPercentageText = '75.00';
    targets(i) = item;
    append_event(eventLog, i, 'RUN_START');
    append_event(eventLog, i, 'RUN_DONE');
    append_event(eventLog, i, 'CVF_GENERATE');
    append_event(eventLog, i, 'RESULT_FILTER_ATTACH');
    append_event(eventLog, i, 'FILTER_RESTORE');
    append_event(eventLog, i, 'MODEL_CLEANUP');
    append_event(eventLog, i, 'PATH_CLEANUP');
end

testManager = fullfile(pipelineRoot, 'TestManager', 'Top.mldatx');
write_text(testManager, 'test manager');
testManagerLauncher = fullfile(pipelineRoot, 'TestManager', ...
    'open_standalone_coverage_test_manager.m');
write_text(testManagerLauncher, 'launcher');
summaryPath = fullfile(pipelineRoot, 'CoverageSummary.xlsx');
NUM = (1:count)';
CUT_NAME = "CUT_" + string(NUM);
CUT_PATH = "Top/CUT_" + string(NUM);
TestCaseName = "TC_" + string(NUM);
HarnessName = "Harness" + string(NUM);
DecisionExecuted = ones(count, 1);
DecisionTotal = repmat(2, count, 1);
Decision = repmat("50.00", count, 1);
ExecutionExecuted = repmat(3, count, 1);
ExecutionTotal = repmat(4, count, 1);
Execution = repmat("75.00", count, 1);
T = table(NUM, CUT_NAME, CUT_PATH, TestCaseName, HarnessName, ...
    DecisionExecuted, DecisionTotal, Decision, ...
    ExecutionExecuted, ExecutionTotal, Execution, 'VariableNames', ...
    {'NUM','CUT_NAME','CUT_PATH','Test Case Name','Harness Name', ...
    'Decision Executed','Decision Total','Decision (%)', ...
    'Execution Executed','Execution Total','Execution (%)'});
writetable(T, summaryPath, 'Sheet', 'CoverageSummary');

manifest = struct( ...
    'Version', 2, 'PipelineId', pipelineId, ...
    'PipelineRoot', pipelineRoot, 'Action', 'ALL', 'Status', 'OK', ...
    'CreatedAt', 'now', 'UpdatedAt', 'now', ...
    'SaveTestResult', false, 'ResultFile', '', 'ResultSHA256', '', ...
    'CanResumePackage', false, 'ResultExportCount', 0, ...
    'ResultImportCount', 0, 'PackageResultSource', 'LIVE', ...
    'ExecutionLog', eventLog, ...
    'BundleSessionCleanup', struct( ...
        'TestFileStatus', 'OK', 'TopModelStatus', 'OK'), ...
    'RunnerEnvironmentCleanupStatus', 'OK', ...
    'TestManagerFile', testManager, ...
    'TestManagerSHA256', st_file_signature(testManager).SHA256, ...
    'TestManagerLauncher', testManagerLauncher, ...
    'TestManagerLauncherSHA256', st_file_signature(testManagerLauncher).SHA256, ...
    'CoverageSummary', summaryPath, ...
    'CoverageSummarySHA256', st_file_signature(summaryPath).SHA256, ...
    'SourceBefore', sourceState, 'SourceAfter', sourceState, ...
    'Targets', targets, ...
    'Actions', struct('EXECUTE', state, 'PACKAGE', state, 'SUMMARY', state));
end

function value = empty_target()
value = struct( ...
    'Order', 0, 'No', 0, 'CUTName', '', 'CUTPath', '', ...
    'HarnessName', '', 'StandaloneModel', '', 'StandaloneModelFile', '', ...
    'TestCaseName', '', 'ExpectedUpdateMode', 'OFF', ...
    'SUTReadbackStatus', '', 'IterationIntegrityStatus', '', ...
    'InputReadbackStatus', '', 'AssessmentReadbackStatus', '', ...
    'RunCount', 0, 'RerunPerformed', false, ...
    'CVFGenerationStatus', '', 'CVFRuleCount', 0, ...
    'ExecutionCVFPath', '', 'CVFSHA256', '', ...
    'ResultFilterAttachCount', 0, 'ResultFilterStatus', '', ...
    'FilterRestoreStatus', '', 'ModelCleanupStatus', '', ...
    'PathCleanupStatus', '', ...
    'ExecutionStatus', '', 'PackageStatus', '', 'SummaryStatus', '', ...
    'SignalEditorInput', '', 'PackagedStandaloneModel', '', ...
    'PackagedStandaloneModelSHA256', '', 'PackagedInput', '', ...
    'PackagedInputSHA256', '', 'PackagedInputReadbackStatus', '', ...
    'PackagedCVF', '', 'PackagedCVFSHA256', '', ...
    'CoverageResult', '', 'CoverageResultSHA256', '', ...
    'TestReport', '', 'ReportHTML', '', 'OutputDirectory', '', ...
    'MetricSource', '', 'MetricSourceStatus', '', ...
    'DecisionCovered', NaN, 'DecisionTotal', NaN, ...
    'DecisionPercentage', NaN, ...
    'ExecutionCovered', NaN, 'ExecutionTotal', NaN, ...
    'ExecutionPercentage', NaN, ...
    'DecisionMetricStatus', '', 'ExecutionMetricStatus', '', ...
    'DecisionPercentageText', 'N/A', 'ExecutionPercentageText', 'N/A');
end

function append_event(path, order, event)
fileId = fopen(path, 'a', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
entry = struct('Timestamp', 'now', 'Order', order, ...
    'Event', event, 'Message', 'fixture');
fprintf(fileId, '%s\n', jsonencode(entry));
end

function write_text(path, value)
folder = fileparts(path);
if ~isfolder(folder), mkdir(folder); end
fileId = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '%s', value);
end

function text = checker_source()
text = string(fileread(fullfile(st_project_root(), 'src', ...
    'verification', 'st_check_standalone_coverage.m')));
end

function remove_fixture(path)
if isfolder(path), rmdir(path, 's'); end
end

function testForbiddenScanWalksTheTreeOnce(testCase)
% Five patterns times every target directory meant the unzipped Coverage
% report assets were walked again and again.
text = checker_source();
verifyTrue(testCase, contains(text, 'forbiddenPaths = forbidden_paths(pipelineRoot)'));
verifyTrue(testCase, contains(text, 'forbidden_under(forbiddenPaths, item.OutputDirectory)'));
verifyTrue(testCase, contains(text, "'Forbidden', numel(forbiddenPaths)"));
verifyFalse(testCase, contains(text, 'forbidden_count('));
verifyEqual(testCase, numel(strfind(text, "dir(fullfile(root, '**', '*'))")), 1);
end

function testExceptedTargetDoesNotFailTheOtherTargets(testCase)
% A known-defective CUT keeps its Harness and input but produces no
% coverage. That must not zero the package bit for every other target.
[root, manifest] = complete_fixture(testCase, 2);
delete(manifest.Targets(2).PackagedCVF);
delete(manifest.Targets(2).CoverageResult);
delete(manifest.Targets(2).ReportHTML);
manifest.Targets(2).ExecutionStatus = 'EXCEPT';
manifest.Targets(2).PackageStatus = 'FAIL';
manifest.Targets(2).PackagedCVF = '';
manifest.Targets(2).PackagedCVFSHA256 = '';
manifest.Targets(2).CoverageResult = '';
manifest.Targets(2).CoverageResultSHA256 = '';
manifest.Targets(2).ReportHTML = '';
manifest.Actions.EXECUTE.Status = 'WARN';
manifest.Actions.PACKAGE.Status = 'WARN';
manifest.Actions.SUMMARY.Status = 'WARN';
manifest.Status = 'PARTIAL';
st_write_standalone_pipeline_manifest(root, manifest);
evalc('[code, summary, details] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyEqual(testCase, code, '1111111111');
verifyEqual(testCase, summary.Status, 'PARTIAL');
verifyEqual(testCase, summary.ExceptedTargetCount, 1);
verifyEqual(testCase, char(details.Status(1)), 'PASS');
verifyEqual(testCase, char(details.Status(2)), 'EXCEPT');
% Result filtering and metrics never ran for that target, so those bits are
% reported as not applicable rather than as defects.
verifyEqual(testCase, char(details.B5(2)), '-');
verifyEqual(testCase, char(details.B7(2)), '-');
% Cleanup is still enforced: the model must be closed and the path restored.
verifyEqual(testCase, char(details.B10(2)), '1');
end

function testExceptedTargetStillNeedsCleanup(testCase)
% The EXCEPT allowance must not excuse a leaked execution model.
[root, manifest] = complete_fixture(testCase, 2);
delete(manifest.Targets(2).PackagedCVF);
delete(manifest.Targets(2).CoverageResult);
delete(manifest.Targets(2).ReportHTML);
manifest.Targets(2).ExecutionStatus = 'EXCEPT';
manifest.Targets(2).PackageStatus = 'FAIL';
manifest.Targets(2).PackagedCVF = '';
manifest.Targets(2).CoverageResult = '';
manifest.Targets(2).ReportHTML = '';
manifest.Targets(2).ModelCleanupStatus = 'FAIL';
manifest.Actions.EXECUTE.Status = 'WARN';
manifest.Actions.PACKAGE.Status = 'WARN';
manifest.Actions.SUMMARY.Status = 'WARN';
manifest.Status = 'PARTIAL';
st_write_standalone_pipeline_manifest(root, manifest);
evalc('[code, ~, details] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyNotEqual(testCase, code, '1111111111');
verifyEqual(testCase, char(details.B10(2)), '0');
end

function testUnexplainedFailureStillBreaksTheContract(testCase)
% The EXCEPT allowance must not let a real packaging defect through.
[root, manifest] = complete_fixture(testCase, 2);
delete(manifest.Targets(2).CoverageResult);
manifest.Targets(2).ExecutionStatus = 'FAIL';
manifest.Actions.PACKAGE.Status = 'WARN';
manifest.Status = 'PARTIAL';
st_write_standalone_pipeline_manifest(root, manifest);
evalc('[code, summary] = st_check_standalone_coverage(''OutputRoot'', root);');
verifyNotEqual(testCase, code, '1111111111');
verifyEqual(testCase, summary.Status, 'FAIL');
end
