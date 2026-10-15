function tests = test_discard_execution_model_changes
%TEST_DISCARD_EXECUTION_MODEL_CHANGES Only changes a test run left are discarded.
tests = functiontests(localfunctions);
end

function testModelLoadedBeforeIsReloadedFromItsFile(testCase)
[model, file] = dirty_saved_model(testCase);
action = st_discard_execution_model_changes(quiet(), model, file, true, true);
verifyEqual(testCase, action, "RELOADED");
verifyTrue(testCase, bdIsLoaded(model));
verifyEqual(testCase, get_param(model, 'Dirty'), 'off');
verifyEqual(testCase, getSimulinkBlockHandle([model '/unsaved']), -1);
end

function testModelLoadedByTheRunIsClosed(testCase)
[model, file] = dirty_saved_model(testCase);
action = st_discard_execution_model_changes(quiet(), model, file, false, true);
verifyEqual(testCase, action, "CLOSED");
verifyFalse(testCase, bdIsLoaded(model));
end

function testModelThatWasAlreadyDirtyIsLeftAlone(testCase)
[model, file] = dirty_saved_model(testCase);
action = st_discard_execution_model_changes(quiet(), model, file, true, false);
verifyEqual(testCase, action, "NONE");
verifyEqual(testCase, get_param(model, 'Dirty'), 'on');
end

function testCleanOrUnloadedModelIsLeftAlone(testCase)
[model, file] = dirty_saved_model(testCase);
verifyEqual(testCase, st_discard_execution_model_changes( ...
    quiet(), 'st_discard_not_loaded', '', false, true), "NONE");
set_param(model, 'Dirty', 'off');
verifyEqual(testCase, st_discard_execution_model_changes( ...
    quiet(), model, file, true, true), "NONE");
verifyTrue(testCase, bdIsLoaded(model));
end

function testRunWorkflowDiscardsAfterExecution(testCase)
% The call comes after execution and after the BATCH report and PER_CUT
% AutoCollect, which still use the results held in memory.
source = fileread(fullfile(st_project_root(), 'src', 'workflow', 'st_run_workflow.m'));
call = strfind(source, 'st_discard_execution_model_changes(cfg, cfg.TopModel, cfg.ModelFile,');
verifyNumElements(testCase, call, 1);
verifyGreaterThan(testCase, call, strfind(source, "'Generate Integrated Test Report',"));
verifyGreaterThan(testCase, call, strfind(source, "'Collect PER_CUT Results',"));
verifyLessThan(testCase, call, strfind(source, 'reportInfo.CloneFailures ='));
end

function [model, file] = dirty_saved_model(testCase)
model = matlab.lang.makeValidName(sprintf( ...
    'st_discard_%s', char(java.util.UUID.randomUUID)));
folder = tempname;
mkdir(folder);
file = fullfile(folder, [model '.slx']);
new_system(model);
testCase.addTeardown(@() cleanup(model, folder));
save_system(model, file);
add_block('built-in/Gain', [model '/unsaved']);
assumeEqual(testCase, get_param(model, 'Dirty'), 'on');
end

function cleanup(model, folder)
if bdIsLoaded(model), close_system(model, 0); end
if isfolder(folder), rmdir(folder, 's'); end
end

function cfg = quiet()
cfg = struct('ConsoleLogLevel', 'ERROR');
end
