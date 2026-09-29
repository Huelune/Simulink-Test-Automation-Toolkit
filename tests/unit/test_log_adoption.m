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
end

function testExportCallIsQuiet(testCase)
verifyTrue(testCase, contains(src('exporting/st_export_standalone_harnesses.m'), ...
    "st_call_quiet(cfg, 'sltest.harness.export'"));
end

function testPublicCommandsOpenALogScope(testCase)
for file = {'verification/st_check_standalone_coverage.m', ...
        'exporting/st_export_test_specification.m', ...
        'exporting/st_export_final_document.m', ...
        'targets/st_select_target_model.m', ...
        'pipeline/st_open_standalone_test_manager.m'}
    verifyTrue(testCase, contains(src(file{1}), 'st_log_run(mfilename'), file{1});
end
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
