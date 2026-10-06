function tests = test_log_adoption
%TEST_LOG_ADOPTION Stage commands print progress through the shared logger.
tests = functiontests(localfunctions);
end

function testStageLoopsUseProgressLines(testCase)
files = stage_files();
for k = 1:numel(files)
    text = src(files{k});
    verifyTrue(testCase, contains(text, 'st_log_progress(cfg,'), files{k});
    verify_no_banner(testCase, text, files{k});
end
end

function testChattyCallsAreQuiet(testCase)
verifyTrue(testCase, contains(src('harness/st_create_harnesses.m'), ...
    "st_call_quiet(cfg, 'sltest.harness.create'"));
verifyTrue(testCase, contains(src('sldv/st_prepare_sldv_targets.m'), ...
    "st_call_quiet(cfg, 'sldvrun'"));
end

function testPreValidateOpensALogScope(testCase)
verifyTrue(testCase, contains(src('targets/st_pre_validate_targets.m'), ...
    'st_log_run(mfilename'));
end

function testLongTargetsAnnounceTheirStart(testCase)
verifyTrue(testCase, contains(src('harness/st_create_harnesses.m'), "'START'"));
verifyTrue(testCase, contains(src('sldv/st_prepare_sldv_targets.m'), "'START'"));
end

function testExecutionCallsAreQuiet(testCase)
perCut = src('execution/st_run_tests_per_cut.m');
verifyEqual(testCase, numel(strfind(perCut, "st_call_quiet(cfg, 'run(testCase)'")), 2);
verifyTrue(testCase, contains(perCut, "st_call_quiet(cfg, 'cvsave'"));
verifyTrue(testCase, contains(perCut, "st_call_quiet(cfg, 'cvhtml'"));
verifyTrue(testCase, contains(perCut, "'START'"));
batch = src('execution/st_run_generated_tests.m');
verifyEqual(testCase, numel(strfind(batch, "st_call_quiet(cfg, 'run(testFile)'")), 2);
for file = {'reporting/st_generate_test_report.m', 'reporting/st_export_result_set_report.m'}
    text = src(file{1});
    verifyTrue(testCase, contains(text, "st_call_quiet(cfg, 'sltest.testmanager.report'"), file{1});
    verifyTrue(testCase, contains(text, "st_call_quiet(cfg, 'cvhtml'"), file{1});
end
verifyTrue(testCase, contains(src('reporting/st_export_result_set_report.m'), ...
    "st_call_quiet(cfg, 'cvsave'"));
end

function testPerCutExpectedUpdateKeepsIterationsInTheLog(testCase)
% A PER_CUT target shows START and one result line on the console (spec
% 6.2). Its expected update is called with that one target row, so the
% per-iteration lines go to DEBUG; the gate's PARTIAL/FAIL WARN stays on
% the console. BATCH passes no target row and keeps its progress lines.
text = src('execution/st_update_expected_from_results.m');
verifyTrue(testCase, contains(text, ...
    'perTarget = nargin >= 2 && ~isempty(targetConfig);'));
verifyEqual(testCase, numel(strfind(text, ...
    'report_iteration(cfg, perTarget, i, n, Status(i),')), 3);
verifyEqual(testCase, numel(strfind(text, 'st_log_progress(')), 1);
helper = extractAfter(text, 'function report_iteration(');
verifyTrue(testCase, contains(helper, 'if perTarget'));
debugAt = strfind(helper, "st_log(cfg, 'DEBUG'");
progressAt = strfind(helper, 'st_log_progress(');
verifyNotEmpty(testCase, debugAt);
verifyNotEmpty(testCase, progressAt);
verifyLessThan(testCase, debugAt(1), progressAt(1));
perCut = src('execution/st_run_tests_per_cut.m');
verifyTrue(testCase, contains(perCut, ...
    'st_update_expected_from_results(initialResult, row)'));
verifyTrue(testCase, contains(perCut, ...
    "ismember(updateGate.Status, {'PARTIAL', 'FAIL'})"));
verifyNotEmpty(testCase, regexp(perCut, ...
    "st_log\(cfg, 'WARN', \.\.\.\s*\['\[PER_CUT %d/%d\] expected update %s", 'once'));
batch = src('execution/st_run_generated_tests.m');
verifyNotEmpty(testCase, regexp(batch, ...
    'st_update_expected_from_results\(\s*\.\.\.\s*resultObj\)', 'once'));
end

function testCollectOpensALogScope(testCase)
verifyTrue(testCase, contains(src('execution/st_collect_per_cut_results.m'), ...
    'st_log_run(mfilename'));
end

function testExecutionScopeFilesPrintNoBanner(testCase)
files = {'test_manager/st_apply_run_test_case_scope.m', ...
    'test_manager/st_get_run_test_cases.m'};
for k = 1:numel(files)
    verify_no_banner(testCase, src(files{k}), files{k});
end
end

function testPipelineOwnsItsRunLog(testCase)
text = src('pipeline/st_run_standalone_coverage_pipeline.m');
verifyTrue(testCase, contains(text, "logScope = st_log_scope('enter', mfilename);"));
verifyTrue(testCase, contains(text, "st_log_scope('fail', ME);"));
verifyTrue(testCase, contains(text, "st_suppress_warnings(cfg, 'STANDALONE_PIPELINE')"));
failAt = strfind(text, "st_log_scope('fail', ME);");
rethrowAt = strfind(text, 'rethrow(ME);');
verifyLessThan(testCase, failAt(1), rethrowAt(end));
% A normal end is marked inside the main try, so Ctrl+C (which skips the
% catch) closes the log as INTERRUPTED rather than done. The output root
% is created inside the same try, so failing to create it is a FAILED run.
mainTry = regexp(text, '^try\s*$', 'once', 'lineanchors');
completeAt = strfind(text, "st_log_scope('complete');");
mkdirAt = strfind(text, 'if ~isfolder(outputRoot), mkdir(outputRoot); end');
verifyEqual(testCase, numel(completeAt), 1);
verifyEqual(testCase, numel(mkdirAt), 1);
verifyGreaterThan(testCase, completeAt(1), mainTry);
verifyLessThan(testCase, completeAt(1), failAt(1));
verifyGreaterThan(testCase, mkdirAt(1), mainTry);
end

function testExportCallIsQuiet(testCase)
verifyTrue(testCase, contains(src('exporting/st_export_standalone_harnesses.m'), ...
    "st_call_quiet(cfg, 'sltest.harness.export'"));
% Both callers hand over their cfg, so the export's own st_log lines reach
% the run log instead of being dropped by log_message's empty-cfg guard.
for file = {'exporting/st_export_test_asset_bundle.m', ...
        'exporting/st_export_test_bundle.m'}
    verifyNotEmpty(testCase, regexp(src(file{1}), ...
        "st_export_standalone_harnesses\([^;]*'LogConfig', cfg\);", 'once'), ...
        file{1});
end
end

function testPublicCommandsOpenALogScope(testCase)
for file = {'verification/st_check_standalone_coverage.m', ...
        'exporting/st_export_test_specification.m', ...
        'exporting/st_export_final_document.m', ...
        'targets/st_select_target_model.m', ...
        'pipeline/st_open_standalone_test_manager.m', ...
        'reporting/st_generate_test_report.m', ...
        'pipeline/st_classify_standalone_results.m'}
    verifyTrue(testCase, contains(src(file{1}), 'st_log_run(mfilename'), file{1});
end
% The submission tree step also runs inside pipeline ALL, so its result is
% one STEP line instead of a printed banner block.
classify = src('pipeline/st_classify_standalone_results.m');
verifyTrue(testCase, startsWith(classify, ...
    'function varargout = st_classify_standalone_results(varargin)'));
verifyTrue(testCase, contains(classify, '@() classify_body(varargin{:})'));
verifyTrue(testCase, contains(classify, ...
    "st_log(cfg, 'STEP', ..."));
verifyFalse(testCase, contains(classify, 'fprintf('));
report = src('reporting/st_generate_test_report.m');
verifyTrue(testCase, startsWith(report, ...
    'function varargout = st_generate_test_report(varargin)'));
verifyTrue(testCase, contains(report, ...
    '@() generate_report(varargin{:})'));
verifyTrue(testCase, contains(report, ...
    'function reportInfo = generate_report(varargin)'));
end

function testReportAndLateTargetLoopsShowProgress(testCase)
% A report on a large workbook runs for minutes. Its step announcements and
% the throttled coverage progress are the only sign of life, so they reach
% the console. The PACKAGE and specification loops print one result line
% per target; neither announces a START.
report = src('reporting/st_generate_test_report.m');
verifyTrue(testCase, contains(report, ...
    "step = @(text) st_log(cfg, 'STEP', 'Report step | %s', text);"));
verifyTrue(testCase, contains(report, ...
    "st_log(cfg, 'STEP', 'Report step | Coverage %s | %s | %d/%d'"));
package = src('pipeline/st_package_standalone_coverage_artifacts.m');
verifyTrue(testCase, contains(package, ...
    'st_log_progress(cfg, i, numel(manifest.Targets), item.PackageStatus,'));
verifyNotEmpty(testCase, regexp(package, ...
    "st_log\(cfg, 'DEBUG', \.\.\.\s*'\[PACKAGE %d/%d\] failed", 'once'));
verifyFalse(testCase, contains(package, "'START'"));
specification = src('exporting/st_collect_specification_rows.m');
verifyTrue(testCase, contains(specification, ...
    'st_log_progress(cfg, i, height(targets), targetStatus, harness,'));
verifyTrue(testCase, contains(specification, ...
    "st_log(cfg, 'DEBUG', 'Specification target failed"));
verifyFalse(testCase, contains(specification, "'START'"));
end

function testExportBundlesHaveNoBanners(testCase)
for file = {'exporting/st_export_test_bundle.m', 'exporting/st_export_test_asset_bundle.m'}
    verify_no_banner(testCase, src(file{1}), file{1});
end
end

function files = stage_files()
files = {'harness/st_create_harnesses.m', 'sldv/st_prepare_sldv_targets.m', ...
    'harness/st_configure_harnesses.m', 'signal_editor/st_configure_signal_editors.m', ...
    'assessment/st_configure_assessments.m', 'test_manager/st_create_test_manager.m', ...
    'test_manager/st_validate_scenario_alignment.m'};
end

function verify_no_banner(testCase, text, name)
verifyFalse(testCase, contains(text, "fprintf('============"), name);
verifyFalse(testCase, contains(text, "fprintf('------------"), name);
end

function text = src(relativePath)
text = fileread(fullfile(st_project_root(), 'src', relativePath));
end
