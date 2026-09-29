function tests = test_stage_result_log
%TEST_STAGE_RESULT_LOG Every workflow step reports its outcome and failures.
tests = functiontests(localfunctions);
end

function testEveryTimedStepReportsItsResult(testCase)
source = workflow_source();
% Both the returned and the thrown path go through the stage logger.
verifyTrue(testCase, contains(source, 'st_log_stage_result(label, [], ME);'));
verifyTrue(testCase, contains(source, 'st_log_stage_result(label, result);'));
end

function testStageFailureNamesTheFailedTargets(testCase)
source = workflow_source();
verifyTrue(testCase, contains(source, 'target(s) failed%s. See WorkflowStageLog.log.'));
verifyTrue(testCase, contains(source, 'result.CUTName(failed)'));
end

function testFailedRowsAreLoggedToAFile(testCase)
source = fileread(fullfile(st_project_root(), 'src', 'workflow', ...
    'st_log_stage_result.m'));
verifyTrue(testCase, contains(source, "ismember(status, [""FAIL"",""EXCEPT""])"));
verifyTrue(testCase, contains(source, "st_log(cfg, 'ERROR', '[StageResult] %s', detail);"));
verifyTrue(testCase, contains(source, "'WorkflowStageLog.log'"));
% Appending, so earlier runs survive the next one.
verifyTrue(testCase, contains(source, "fopen(logPath, 'a', 'n', 'UTF-8')"));
% A log that cannot be written never fails the step.
verifyTrue(testCase, contains(source, 'Stage result log write failed'));
end

function source = workflow_source()
source = fileread(fullfile(st_project_root(), 'src', 'workflow', ...
    'st_run_workflow.m'));
end
