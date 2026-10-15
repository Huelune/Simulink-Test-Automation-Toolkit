function tests = test_release_execution_dirty_flag
%TEST_RELEASE_EXECUTION_DIRTY_FLAG Only a flag raised during execution is cleared.
tests = functiontests(localfunctions);
end

function testFlagRaisedOnACleanModelIsCleared(testCase)
model = dirty_model(testCase);
verifyTrue(testCase, st_release_execution_dirty_flag(quiet(), model, true));
verifyEqual(testCase, get_param(model, 'Dirty'), 'off');
end

function testModelThatWasAlreadyDirtyKeepsItsFlag(testCase)
model = dirty_model(testCase);
verifyFalse(testCase, st_release_execution_dirty_flag(quiet(), model, false));
verifyEqual(testCase, get_param(model, 'Dirty'), 'on');
end

function testUnloadedModelIsIgnored(testCase)
verifyFalse(testCase, st_release_execution_dirty_flag(quiet(), ...
    'st_release_dirty_not_loaded', true));
end

function testRunWorkflowReleasesTheFlagAfterExecution(testCase)
% The call sits after both execution modes and the skip branch.
source = fileread(fullfile(st_project_root(), 'src', 'workflow', 'st_run_workflow.m'));
call = strfind(source, 'st_release_execution_dirty_flag(cfg, cfg.TopModel, topModelWasClean)');
verifyNumElements(testCase, call, 1);
verifyGreaterThan(testCase, call, strfind(source, "'Run Generated Tests', @() st_run_generated_tests())"));
verifyLessThan(testCase, call, strfind(source, 'state.Artifacts.Model = '));
end

function model = dirty_model(testCase)
model = matlab.lang.makeValidName(sprintf( ...
    'st_release_dirty_%s', char(java.util.UUID.randomUUID)));
new_system(model);
testCase.addTeardown(@() close_system(model, 0));
add_block('built-in/Gain', [model '/g']);
assumeEqual(testCase, get_param(model, 'Dirty'), 'on');
end

function cfg = quiet()
cfg = struct('ConsoleLogLevel', 'ERROR');
end
