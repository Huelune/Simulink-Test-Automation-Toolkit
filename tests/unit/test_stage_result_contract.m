function tests = test_stage_result_contract
%TEST_STAGE_RESULT_CONTRACT A stage result must carry a Status column.
%
% st_run_workflow hands every stage result to st_checkpoint_workflow_state,
% which reads Status per row to decide which signatures to store. A stage
% that returns the right number of rows under the wrong column names breaks
% the run after the stage has already reported DONE.
tests = functiontests(localfunctions);
end

function testCheckpointRejectsAResultWithoutStatus(testCase)
plan = table(true, "RUN", "dirty", "sig", 'VariableNames', ...
    {'RunTEST_MANAGER', 'ActionTEST_MANAGER', 'ReasonTEST_MANAGER', ...
     'SignatureTEST_MANAGER'});
withoutStatus = table("CACHED", 'VariableNames', {'Var1'});

verifyError(testCase, @() st_checkpoint_workflow_state( ...
    struct(), plan, 'TEST_MANAGER', withoutStatus, struct()), ...
    'simtest:InvalidStageResult');
end

function testCachedTestManagerResultDeclaresItsColumns(testCase)
% The all-cached branch returns before any Test File is opened, so it builds
% its own table. Without an explicit name list MATLAB calls the columns
% Var1..Var9 and the checkpoint rejects the stage it just skipped.
source = fileread(fullfile(st_project_root(), 'src', 'test_manager', ...
    'st_create_test_manager.m'));
cachedBranch = extractBetween(source, 'if ~any(selection.Run)', 'return;');

verifyNumElements(testCase, cachedBranch, 1);
verifyTrue(testCase, contains(cachedBranch{1}, "'VariableNames'"));
verifyTrue(testCase, contains(cachedBranch{1}, "'Status'"));
end
