function tests = test_workflow_log_contract
%TEST_WORKFLOW_LOG_CONTRACT Workflow steps report through the shared logger.
tests = functiontests(localfunctions);
end

function testEveryTimedStepReportsItsResult(testCase)
text = src('workflow', 'st_run_workflow.m');
verifyTrue(testCase, contains(text, "st_log_stage(cfg, 'start', label);"));
verifyTrue(testCase, contains(text, "st_log_stage(cfg, 'fail', label, 'Exception', ME"));
verifyTrue(testCase, contains(text, "st_log_stage(cfg, 'end', label, 'Result', result"));
verifyTrue(testCase, contains(text, 'st_suppress_warnings(cfg, label)'));
verifyFalse(testCase, contains(text, "fprintf('\n============"));
end

function testStageFailureNamesTheRunLog(testCase)
text = src('workflow', 'st_run_workflow.m');
verifyTrue(testCase, contains(text, 'target(s) failed%s. See the run log.'));
verifyTrue(testCase, contains(text, 'result.CUTName(failed)'));
verifyFalse(testCase, contains(text, 'WorkflowStageLog'));
end

function testEntryCommandsOpenALogScope(testCase)
for name = ["st_run_from_harness", "st_run_after_harness", "st_run_from_stage"]
    text = src('workflow', name + ".m");
    verifyTrue(testCase, contains(text, 'st_log_run(mfilename'), name);
end
verifyFalse(testCase, isfile(fullfile(st_project_root(), 'src', 'workflow', ...
    'st_log_stage_result.m')));
end

function text = src(folder, file)
text = fileread(fullfile(st_project_root(), 'src', folder, char(file)));
end
