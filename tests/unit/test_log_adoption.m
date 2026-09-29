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
