function tests = test_harness_driven_sldv_inputs
%TEST_HARNESS_DRIVEN_SLDV_INPUTS Only a function-call trigger is Harness-driven.
tests = functiontests(localfunctions);
end

function testFunctionCallCutReportsItsTrigger(testCase)
cut = build_cut(testCase, 'function-call');
verifyEqual(testCase, st_harness_driven_sldv_inputs(cut), ...
    {'FcnTriggerPort'});
end

function testEdgeTriggeredCutReportsNothing(testCase)
% An edge trigger is an ordinary Harness input and must still be matched.
cut = build_cut(testCase, 'rising');
verifyEmpty(testCase, st_harness_driven_sldv_inputs(cut));
end

function testPlainSubsystemReportsNothing(testCase)
cut = build_cut(testCase, '');
verifyEmpty(testCase, st_harness_driven_sldv_inputs(cut));
end

function cut = build_cut(testCase, triggerType)
model = matlab.lang.makeValidName(sprintf( ...
    'st_driven_%s', char(java.util.UUID.randomUUID)));
new_system(model);
testCase.addTeardown(@() close_system(model, 0));
cut = [model '/CUT'];
add_block('built-in/Subsystem', cut);
if ~isempty(triggerType)
    trigger = add_block('built-in/TriggerPort', [cut '/Trigger']);
    set_param(trigger, 'TriggerType', triggerType);
end
end
