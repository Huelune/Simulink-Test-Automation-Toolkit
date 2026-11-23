function tests = test_explain_block_logic
%TEST_EXPLAIN_BLOCK_LOGIC Name-free equations for the logic behind a block.
tests = functiontests(localfunctions);
end

function testCounterBehindSwitchBecomesEquationsWithoutNames(testCase)
% A counter (Unit Delay + Sum) drives a Switch control input. The output
% must name the delay D1, show its update and initial value, and never
% print a block name (the user sends this screen outside the company).
model = 'stt_explain_secret_model';
if bdIsLoaded(model), close_system(model, 0); end
new_system(model);
cleanup = onCleanup(@() close_system(model, 0)); %#ok<NASGU>
add_block('simulink/Sources/Constant', [model '/Secret_One'], 'Value', '1');
add_block('simulink/Math Operations/Sum', [model '/Secret_Add'], 'Inputs', '++');
add_block('simulink/Discrete/Unit Delay', [model '/Secret_Delay'], 'InitialCondition', '0');
add_block('simulink/Signal Routing/Switch', [model '/Secret_Switch'], ...
    'Criteria', 'u2 >= Threshold', 'Threshold', '1');
add_line(model, 'Secret_One/1', 'Secret_Add/1');
add_line(model, 'Secret_Delay/1', 'Secret_Add/2');
add_line(model, 'Secret_Add/1', 'Secret_Delay/1');
add_line(model, 'Secret_Delay/1', 'Secret_Switch/2');
add_line(model, 'Secret_One/1', 'Secret_Switch/1');
add_line(model, 'Secret_One/1', 'Secret_Switch/3');

printed = evalc('lines = st_explain_block_logic([model ''/Secret_Switch''], ''Boundary'', model);');
text = strjoin(lines, newline);
verifyTrue(testCase, contains(text, '(D1 >= 1) ? 1 : 1'));
verifyTrue(testCase, contains(text, 'D1 (초기값 0) 다음 값 = (1 + D1)'));
verifyFalse(testCase, contains(printed, 'Secret'));
verifyFalse(testCase, contains(printed, model));
end
