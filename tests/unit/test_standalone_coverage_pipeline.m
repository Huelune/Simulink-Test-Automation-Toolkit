function tests = test_standalone_coverage_pipeline
%TEST_STANDALONE_COVERAGE_PIPELINE Static Action workflow contracts.
tests = functiontests(localfunctions);
end

function testControllerUsesActionAPIAndConditionalSavePolicy(testCase)
text = source('pipeline', 'st_run_standalone_coverage_pipeline.m');
verifyTrue(testCase, contains(text, ...
    "addParameter(p, 'Action', 'ALL'"));
verifyTrue(testCase, contains(text, ...
    "{'PREPARE','EXECUTE','PACKAGE','SUMMARY','ALL'}"));
verifyTrue(testCase, contains(text, ...
    "value = strcmp(action, 'EXECUTE')"));
verifyTrue(testCase, contains(text, ...
    "'ExecutionModelMode', 'STANDALONE_HARNESS'"));
verifyTrue(testCase, contains(text, ...
    "'ResultFilterMode', 'POST_RUN_REQUIRED'"));
verifyTrue(testCase, contains(text, ...
    "'BuildCacheFolder', cfg.StandaloneBuildCacheDir"));
verifyTrue(testCase, contains(text, ...
    "st_require_runtime_target('LoadModel', false)"));
verifyTrue(testCase, contains(text, "'Version', 3"));
verifyTrue(testCase, contains(text, "'Actions', struct("));
verifyTrue(testCase, contains(text, "'Inputs', {input_inventory(cfg)}"));
verifyTrue(testCase, contains(text, ...
    "'Harnesses', {harness_asset_inventory(cfg)}"));
verifyTrue(testCase, contains(text, ...
    "'RunnerEnvironmentCleanupStatus', 'NOT_RUN'"));
end

function testPackageHelperIsRefreshedAndContractChecked(testCase)
text = source('pipeline', 'st_run_standalone_coverage_pipeline.m');
verifyEqual(testCase, numel(regexp(text, ...
    'st_package_standalone_coverage_artifacts\(', 'match')), 1);
verifyEqual(testCase, numel(regexp(text, ...
    'invoke_package_action\(', 'match')), 3);
verifyTrue(testCase, contains(text, ...
    'clear st_package_standalone_coverage_artifacts'));
verifyTrue(testCase, contains(text, ...
    'StandalonePipelinePackageResolutionMismatch'));
verifyTrue(testCase, contains(text, ...
    'StandalonePipelinePackageImplementationMismatch'));
verifyTrue(testCase, contains(text, ...
    "'package_captured_report_and_metrics'"));
verifyTrue(testCase, contains(text, ...
    "'PACKAGE report model open complete'"));
verifyTrue(testCase, contains(text, ...
    'Contract=CAPTURED_EVIDENCE_V1'));
end

function testCloseSourceModelSavesThenClosesBeforeSnapshot(testCase)
% The source model is saved (never discarded) and closed before the export,
% and before source_snapshot so the saved file is the compared baseline.
text = source('pipeline', 'st_run_standalone_coverage_pipeline.m');
verifyTrue(testCase, contains(text, ...
    "addParameter(p, 'CloseSourceModel', true"));
releaseAt = strfind(text, 'release_source_model(cfg, options);');
assertAt = strfind(text, ...
    "assert_pipeline_source_unloaded(cfg, 'before standalone export');");
snapshotAt = strfind(text, 'source = source_snapshot(cfg);');
verifyEqual(testCase, numel(releaseAt), 2);
verifyEqual(testCase, numel(assertAt), 2);
verifyEqual(testCase, numel(snapshotAt), 2);
for i = 1:2
    verifyLessThan(testCase, releaseAt(i), assertAt(i));
    verifyLessThan(testCase, assertAt(i), snapshotAt(i));
end
verifyTrue(testCase, contains(text, ...
    'if ~logical(options.CloseSourceModel), return; end'));
verifyTrue(testCase, contains(text, 'save_system(model);'));
verifyTrue(testCase, contains(text, 'close_system(model, 0);'));
verifyTrue(testCase, contains(text, 'saveToFile(openFiles(i));'));
verifyTrue(testCase, contains(text, ...
    'simtest:StandalonePipelineSourceSaveFailed'));
% Discarding the user's changes is never an option.
verifyFalse(testCase, contains(text, "'Dirty', 'off'"));
verifyError(testCase, @() st_run_standalone_coverage_pipeline( ...
    'CloseSourceModel', 'yes'), ...
    'MATLAB:InputParser:ArgumentFailedValidation');
end

function testRemovedOptionsReturnMigrationErrorsBeforeRuntime(testCase)
verifyError(testCase, @() st_run_standalone_coverage_pipeline( ...
    'RunMode', 'STEP234'), ...
    'simtest:StandalonePipelineRunModeRemoved');
verifyError(testCase, @() st_run_standalone_coverage_pipeline( ...
    'Action', 'PACKAGE', 'SaveTestResult', true), ...
    'simtest:StandalonePipelineSaveResultNotAllowed');
verifyError(testCase, @() st_run_standalone_coverage_pipeline( ...
    'Action', 'PREPARE', 'SaveTestResult', true), ...
    'simtest:StandalonePipelineSaveResultNotAllowed');
verifyError(testCase, @() st_run_standalone_coverage_pipeline( ...
    'Action', 'BOGUS'), 'simtest:StandalonePipelineActionInvalid');
end

function testExecuteUsesOneRunPostRunFilterContract(testCase)
runner = source('execution', 'st_run_tests_per_cut.m');
prepare = source('execution', ...
    'st_prepare_standalone_bundle_execution.m');
verifyTrue(testCase, contains(prepare, ...
    'targets.ExpectedUpdateMode(:) = "OFF"'));
runAt = strfind(runner, 'initialResult = run(tc)');
generateAt = strfind(runner, ...
    'generate_filter(row, filterDirectory, cfg, logPath, i,');
verifyGreaterThanOrEqual(testCase, numel(generateAt), 2);
verifyLessThan(testCase, runAt(1), generateAt(2));
verifyTrue(testCase, contains(runner, "'RUN_START'"));
verifyTrue(testCase, contains(runner, "'RUN_DONE'"));
verifyTrue(testCase, contains(runner, "'CVF_GENERATE'"));
verifyTrue(testCase, contains(runner, "'RESULT_FILTER_ATTACH'"));
verifyTrue(testCase, contains(runner, "'FILTER_RESTORE'"));
verifyTrue(testCase, contains(runner, "'MODEL_CLEANUP'"));
verifyFalse(testCase, contains(runner, ...
    'verify_result_filter_roundtrip'));
end

function testAllUsesLiveResultAndPackageOnlyImportsOnce(testCase)
controller = source('pipeline', ...
    'st_run_standalone_coverage_pipeline.m');
package = source('pipeline', ...
    'st_package_standalone_coverage_artifacts.m');
runner = string(fileread(fullfile(st_project_root(), ...
    'resources', 'export_bundle', 'run_exported_tests.m')));
perCut = source('execution', 'st_run_tests_per_cut.m');
verifyTrue(testCase, contains(controller, ...
    'outputRoot, manifest, runtimeContext'));
verifyTrue(testCase, contains(controller, ...
    "'CapturePackageEvidence', true"));
verifyTrue(testCase, contains(runner, ...
    "'CapturePackageEvidence', p.Results.CapturePackageEvidence"));
verifyEqual(testCase, numel(regexp(package, ...
    'sltest\.testmanager\.importResults', 'match')), 1);
verifyFalse(testCase, contains(package, ...
    'sltest.testmanager.exportResults'));
verifyFalse(testCase, contains(package, "'ReadOnly', true"));
verifyFalse(testCase, contains(package, 'FilteredResults.mldatx'));
verifyFalse(testCase, contains(package, 'coverage-metrics.mat'));
verifyFalse(testCase, contains(package, 'cvhtml('));
verifyFalse(testCase, contains(package, 'cvsave(arguments{:})'));
verifyTrue(testCase, contains(perCut, 'cvsave(arguments{:})'));
verifyTrue(testCase, contains(perCut, 'cvhtml(reportHTML, coverageObjects{1}'));
verifyEqual(testCase, numel(regexp(package, ...
    'sltest\.testmanager\.report\(', 'match')), 0);
verifyEqual(testCase, numel(regexp(perCut, ...
    'sltest\.testmanager\.report\(', 'match')), 0);
verifyTrue(testCase, contains(package, "source = 'LIVE'"));
verifyTrue(testCase, contains(package, "source = 'IMPORTED'"));
verifyTrue(testCase, contains(package, ...
    "require_not_started(manifest, 'PACKAGE')"));
summary = source('pipeline', ...
    'st_export_standalone_coverage_summary.m');
verifyTrue(testCase, contains(summary, ...
    "require_not_started(manifest, 'SUMMARY')"));
end

function testReportAndMetricsAreCapturedBeforeModelCleanup(testCase)
package = source('pipeline', ...
    'st_package_standalone_coverage_artifacts.m');
perCut = source('execution', 'st_run_tests_per_cut.m');
controller = source('pipeline', ...
    'st_run_standalone_coverage_pipeline.m');
checker = source('verification', 'st_check_standalone_coverage.m');
launcher = string(fileread(fullfile(st_project_root(), 'resources', ...
    'standalone_coverage', 'open_standalone_coverage_test_manager.m')));
captureAt = strfind(perCut, 'capture_package_evidence(');
reportAt = strfind(perCut, 'cvhtml(reportHTML, coverageObjects{1}');
metricAt = strfind(perCut, ...
    'st_collect_final_cut_coverage_metrics(');
cleanupAt = strfind(perCut, 'close_execution_model(row, cfg)');
verifyNotEmpty(testCase, captureAt);
verifyNotEmpty(testCase, reportAt);
verifyNotEmpty(testCase, metricAt);
verifyNotEmpty(testCase, cleanupAt);
verifyLessThan(testCase, captureAt(1), cleanupAt(1));
verifyLessThan(testCase, reportAt(1), metricAt(1));
coverageSaveAt = strfind(perCut, 'save_package_evidence_cvt(cvtPath');
verifyNotEmpty(testCase, coverageSaveAt);
verifyLessThan(testCase, coverageSaveAt(1), cleanupAt(1));
verifyTrue(testCase, contains(perCut, ...
    'StandalonePackageEvidenceModelNotOpen'));
verifyTrue(testCase, contains(perCut, ...
    'StandalonePackageEvidenceModelMismatch'));
verifyTrue(testCase, contains(perCut, ...
    'same_path(loadedFile, modelFile)'));
verifyTrue(testCase, contains(perCut, ...
    "'PACKAGE_EVIDENCE_START'"));
verifyTrue(testCase, contains(perCut, ...
    "'PACKAGE_EVIDENCE_DONE'"));
verifyTrue(testCase, contains(perCut, ...
    "'PACKAGE_EVIDENCE_FAIL'"));
verifyTrue(testCase, contains(package, ...
    'package_captured_report_and_metrics'));
verifyTrue(testCase, contains(package, ...
    'require_signature(reportZip, evidence.CoverageReportZipSHA256'));
verifyTrue(testCase, contains(package, ...
    'require_signature(sourceCVT, evidence.CoverageResultSHA256'));
verifyTrue(testCase, contains(package, ...
    'PACKAGE captured coverage data promotion complete'));
verifyTrue(testCase, contains(perCut, ...
    "'CoverageReportZipSHA256', st_file_signature(reportZip).SHA256"));
verifyTrue(testCase, contains(perCut, ...
    "scratchDirectory = pwd"));
verifyTrue(testCase, contains(perCut, ...
    "reportDirectory = fullfile(scratchDirectory, 'CoverageReport')"));
verifyTrue(testCase, contains(perCut, ...
    "scratchZip = fullfile(scratchDirectory, 'CoverageReport.zip')"));
verifyTrue(testCase, contains(perCut, ...
    "copyfile(scratchZip, reportZip, 'f')"));
verifyFalse(testCase, contains(perCut, ...
    "fullfile(evidenceDirectory, 'CoverageReport')"));
scratchAt = strfind(perCut, "scratchDirectory = pwd");
reportPathAt = strfind(perCut, ...
    "reportHTML = fullfile(reportDirectory, 'report.html')");
cvhtmlAt = strfind(perCut, ...
    "cvhtml(reportHTML, coverageObjects{1}, '-sRT=0')");
promoteAt = strfind(perCut, "copyfile(scratchZip, reportZip, 'f')");
verifyLessThan(testCase, scratchAt(1), reportPathAt(1));
verifyLessThan(testCase, reportPathAt(1), cvhtmlAt(1));
verifyLessThan(testCase, cvhtmlAt(1), promoteAt(1));
verifyTrue(testCase, contains(perCut, ...
    "'Version', 2"));
verifyTrue(testCase, contains(perCut, ...
    'Standalone original Coverage report capture complete'));
verifyTrue(testCase, contains(perCut, ...
    'apply_package_report_filter(coverageObjects, row, coverageFilterPath, cfg)'));
verifyTrue(testCase, contains(perCut, ...
    'StandalonePackageEvidenceCoverageFilterApplyFailed'));
verifyTrue(testCase, contains(perCut, ...
    'Standalone original Coverage report CVF binding readback complete'));
verifyTrue(testCase, contains(perCut, ...
    "'CoverageObjects', coverageObjects"));
metrics = source('reporting', 'st_collect_final_cut_coverage_metrics.m');
summary = source('reporting', 'st_collect_coverage_summary.m');
verifyTrue(testCase, contains(metrics, "'CoverageObjects', p.Results.CoverageObjects"));
verifyTrue(testCase, contains(summary, 'resultCoverage = p.Results.CoverageObjects'));
verifyTrue(testCase, contains(package, ...
    'assign_metric(item, evidence.Decision'));
verifyTrue(testCase, contains(package, ...
    'item.PackageFailure = package_failure_detail(ME)'));
verifyTrue(testCase, contains(package, ...
    "'Stack', frames"));
verifyTrue(testCase, contains(controller, ...
    "'PackageFailure', empty_package_failure()"));
verifyTrue(testCase, contains(controller, "'TestManagerLauncher', ''"));
verifyTrue(testCase, contains(package, ...
    "'open_standalone_coverage_test_manager.m'"));
verifyTrue(testCase, contains(package, ...
    'PACKAGE Test Manager launcher complete'));
verifyTrue(testCase, contains(launcher, ...
    'sltest.testmanager.load(testFilePath)'));
verifyTrue(testCase, contains(launcher, ...
    'load_system(modelFile)'));
verifyTrue(testCase, contains(launcher, ...
    'coverage.CoverageFilterFilename = filterFile'));
verifyTrue(testCase, contains(launcher, ...
    'filter_readback_matches(filterFile, actual)'));
verifyTrue(testCase, contains(launcher, ...
    'Coverage filter applied | TestCase=%s | Filter=%s'));
verifyTrue(testCase, contains(launcher, 'sltest.testmanager.view'));
verifyTrue(testCase, contains(checker, 'TestManagerLauncherSHA256'));
rewireAt = strfind(package, 'function item = rewire_packaged_input');
rewireIsolationAt = strfind(package, ...
    "if bdIsLoaded(modelName)");
rewireCleanupAt = strfind(package, ...
    'cleanup = onCleanup(@() restore_model_context');
rewireIsolationAt = rewireIsolationAt( ...
    rewireIsolationAt > rewireAt(1));
verifyLessThan(testCase, rewireIsolationAt(1), rewireCleanupAt(1));
end

function testPackageUsesTestCaseNamesAndPlacesHtmlAtTargetRoot(testCase)
package = source('pipeline', ...
    'st_package_standalone_coverage_artifacts.m');
perCut = source('execution', 'st_run_tests_per_cut.m');
verifyTrue(testCase, contains(package, ...
    "st_artifact_stem(item.TestCaseName)"));
verifyFalse(testCase, contains(package, ...
    "st_export_safe_name(item.CUTName)"));
verifyTrue(testCase, contains(package, ...
    'reportDirectory = targetDirectory'));
verifyTrue(testCase, contains(package, ...
    "[st_artifact_stem(item.TestCaseName) '.html']"));
verifyTrue(testCase, contains(package, ...
    "[st_artifact_stem(item.TestCaseName) '.cvf']"));
verifyTrue(testCase, contains(package, ...
    "[st_artifact_stem(item.TestCaseName) '.cvt']"));
verifyTrue(testCase, contains(package, 'movefile(rootReport, reportHTML'));
verifyFalse(testCase, contains(package, "'_CoverageReport'"));
verifyTrue(testCase, contains(perCut, ...
    'bind_report_filter_display_name(coverageObjects, row, coverageFilterPath'));
verifyTrue(testCase, contains(perCut, ...
    "displayFilter = [st_artifact_stem(char(string(row.TestCaseName))) '.cvf']"));
verifyTrue(testCase, contains(perCut, 'coverageObjects{1}.filter = displayFilter'));
end

function testFailedExecutionStillPreservesStandaloneInputs(testCase)
package = source('pipeline', ...
    'st_package_standalone_coverage_artifacts.m');
inputAt = strfind(package, ...
    'item = package_execution_inputs(item, targetDirectory, cfg);');
executionFailureAt = strfind(package, ...
    'if executionStatus == "EXCEPT"');
verifyEqual(testCase, numel(inputAt), 1);
verifyNotEmpty(testCase, executionFailureAt);
verifyLessThan(testCase, inputAt(1), executionFailureAt(1));
verifyTrue(testCase, contains(package, ...
    'standalone inputs preserved | CUT=%s'));
verifyTrue(testCase, contains(package, ...
    'StandalonePipelineExecuteTargetException'));
controller = source('pipeline', 'st_run_standalone_coverage_pipeline.m');
verifyTrue(testCase, contains(controller, ...
    'if reportedExecutionStatus == "EXCEPT"'));
verifyTrue(testCase, contains(controller, ...
    'values == "FAIL" | values == "EXCEPT" | values == "SKIP"'));
end

function testReportFilterHelpersAreFileLevelSubfunctions(testCase)
% Nested helpers stay invisible to the report subfunctions that bind the
% display CVF and restore the validated absolute binding, so
% capture_package_evidence must close before them.
perCut = source('execution', 'st_run_tests_per_cut.m');
verifyNotEmpty(testCase, regexp(perCut, ...
    'rethrow\(ME\);\s*end\s*end\s*function apply_package_report_filter', ...
    'once'));
calls = strfind(perCut, ...
    'apply_package_report_filter(coverageObjects, row, coverageFilterPath, cfg);');
verifyEqual(testCase, numel(calls), 2);
end

function testCoverageWithoutObjectivesUsesValidZeroDenominatorMetric(testCase)
metrics = source('reporting', 'st_collect_final_cut_coverage_metrics.m');
summary = source('reporting', 'st_collect_coverage_summary.m');
prepare = source('execution', 'st_prepare_standalone_bundle_execution.m');
verifyTrue(testCase, contains(summary, 'if isempty(values)'));
verifyTrue(testCase, contains(summary, ...
    'st_coverage_percentage(0, 0)'));
verifyTrue(testCase, contains(summary, ...
    'coverage has no objectives for this CUT'));
verifyFalse(testCase, contains(metrics, 'zero_decision_metric'));
verifyTrue(testCase, contains(prepare, ...
    'StandaloneCoverageMetricSettingsReadbackFailed'));
verifyTrue(testCase, contains(prepare, "contains(metricSettings, 'd')"));
verifyFalse(testCase, contains(prepare, "contains(metricSettings, 'e')"));
end

function testSummaryUsesDecisionAndExecutionCounts(testCase)
text = source('pipeline', ...
    'st_export_standalone_coverage_summary.m');
verifyTrue(testCase, contains(text, ...
    "{'NUM','CUT_NAME','CUT_PATH','Test Case Name','Harness Name', ..."));
verifyTrue(testCase, contains(text, ...
    "'Decision Executed','Decision Total','Decision (%)', ..."));
verifyTrue(testCase, contains(text, ...
    "'Execution Executed','Execution Total','Execution (%)'"));
verifyTrue(testCase, contains(text, 'DecisionExecuted(i) = scalar_metric(item.DecisionCovered)'));
verifyTrue(testCase, contains(text, 'ExecutionExecuted(i) = scalar_metric(item.ExecutionCovered)'));
verifyFalse(testCase, contains(text, 'MetricSnapshot'));
verifyFalse(testCase, contains(text, 'load('));
[percentage, percentageText] = st_coverage_percentage(0, 0);
verifyTrue(testCase, isnan(percentage));
verifyEqual(testCase, percentageText, "N/A");
end

function testPipelineStateIsAtomicAndV2Only(testCase)
writer = source('pipeline', ...
    'st_write_standalone_pipeline_manifest.m');
loader = source('pipeline', ...
    'st_load_standalone_pipeline_manifest.m');
verifyTrue(testCase, contains(writer, 'tempname(folder)'));
verifyTrue(testCase, contains(writer, "movefile(temporary, path, 'f')"));
verifyTrue(testCase, contains(writer, 'ManifestSHA256'));
verifyTrue(testCase, contains(loader, ...
    'StandalonePipelineManifestChecksumMismatch'));
verifyTrue(testCase, contains(loader, ...
    'StandalonePipelineManifestMigrationRequired'));
end

function testResultFilterFlattensSupportedShapes(testCase)
helper = source('coverage', 'st_flatten_coverage_results.m');
collector = source('coverage', 'st_collect_result_coverage_objects.m');
filter = source('coverage', 'st_apply_result_coverage_filters.m');
verifyTrue(testCase, contains(helper, "isa(value, 'cvdata')"));
verifyTrue(testCase, contains(helper, "isa(value, 'cv.cvdatagroup')"));
verifyTrue(testCase, contains(filter, ...
    'st_collect_result_coverage_objects(resultObj)'));
verifyTrue(testCase, contains(collector, ...
    'st_collect_test_case_results(resultObj)'));
end

function text = source(folder, file)
text = string(fileread(fullfile(st_project_root(), 'src', folder, file)));
end

function testPrepareActionStopsBeforeExecution(testCase)
% PREPARE produces only the rewired Test File. It must reuse the same
% export and preparation as EXECUTE, branch away before any Test Case
% runs, and never be mistaken for a run by PACKAGE, SUMMARY, or LATEST.
controller = source('pipeline', 'st_run_standalone_coverage_pipeline.m');
runner = string(fileread(fullfile(st_project_root(), ...
    'resources', 'export_bundle', 'run_exported_tests.m')));

verifyTrue(testCase, contains(controller, "case 'PREPARE'"));
verifyTrue(testCase, contains(controller, ...
    "manifest = run_prepare(outputRoot, pipelineId, p.Results, cfg);"));
verifyTrue(testCase, contains(controller, "'PrepareOnly', prepareOnly"));
verifyTrue(testCase, contains(controller, "manifest.PublishLatest = false;"));
verifyTrue(testCase, contains(controller, ...
    "manifest = copy_prepared_test_file(manifest, pipelineRoot, cfg);"));
verifyTrue(testCase, contains(controller, ...
    "'simtest:StandalonePipelinePrepareOnly'"));
verifyEqual(testCase, ...
    count(controller, "assert_executed_pipeline(manifest, action);"), 2, ...
    'PACKAGE and SUMMARY must both refuse a PREPARE pipeline.');
verifyTrue(testCase, contains(controller, ...
    "if ~isfield(manifest.Actions, name), continue; end"));

verifyTrue(testCase, contains(runner, ...
    "addParameter(p, 'PrepareOnly', false"));
verifyTrue(testCase, contains(runner, ...
    "'simtest:BundlePrepareOnlyRequiresStandalone'"));
verifyTrue(testCase, contains(runner, ...
    "'simtest:BundlePrepareOnlySaveResultNotAllowed'"));
prepareAt = strfind(runner, 'st_prepare_standalone_bundle_execution(');
branchAt = regexp(runner, '\n {4}if prepareOnly\r?\n');
runAt = strfind(runner, 'st_run_tests_per_cut(');
verifyNumElements(testCase, prepareAt, 1);
verifyNumElements(testCase, branchAt, 1);
verifyNumElements(testCase, runAt, 1);
verifyTrue(testCase, prepareAt < branchAt && branchAt < runAt, ...
    'PrepareOnly must branch after preparation and before the run.');
end

function testInternalBundleSkipsProductAnalysis(testCase)
% The pipeline bundle is an execution vehicle under workRoot, not a
% delivery, so it should not pay for the toolbox dependency analysis.
controller = source('pipeline', 'st_run_standalone_coverage_pipeline.m');
verifyTrue(testCase, contains(controller, "'CreateArchive', false, ..."));
verifyTrue(testCase, contains(controller, "'AnalyzeProducts', false, ..."));
snapshot = source('verification', 'st_create_verification_snapshot.m');
verifyTrue(testCase, contains(snapshot, "'AnalyzeProducts', false, ..."));
end
