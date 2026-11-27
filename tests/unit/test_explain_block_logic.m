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

lines = {};  % declared first: evalc alone leaves 'lines' as MATLAB's colormap function
printed = evalc('lines = st_explain_block_logic([model ''/Secret_Switch''], ''Boundary'', model);');
text = strjoin(lines, newline);
verifyTrue(testCase, contains(text, '(D1 >= 1) ? 1 : 1'));
verifyTrue(testCase, contains(text, 'D1 (초기값 0) 다음 값 = (1 + D1)'));
verifyFalse(testCase, contains(printed, 'Secret'));
verifyFalse(testCase, contains(printed, model));
end

function testShowTypesAddsCompiledTypesWithoutNames(testCase)
% A boolean that feeds a comparison with 2 can never equal 2; the compiled
% type answers that, so ShowTypes appends it per symbol, still name-free.
model = 'stt_explain_secret_types';
if bdIsLoaded(model), close_system(model, 0); end
new_system(model);
cleanup = onCleanup(@() close_system(model, 0)); %#ok<NASGU>
add_block('simulink/Sources/Constant', [model '/Secret_One'], 'Value', '1');
add_block('simulink/Math Operations/Sum', [model '/Secret_Add'], 'Inputs', '++');
add_block('simulink/Discrete/Unit Delay', [model '/Secret_Delay'], 'InitialCondition', '0', 'SampleTime', '1');
add_block('simulink/Signal Routing/Switch', [model '/Secret_Switch'], ...
    'Criteria', 'u2 >= Threshold', 'Threshold', '1');
add_block('simulink/Sinks/Terminator', [model '/Secret_End']);
add_line(model, 'Secret_One/1', 'Secret_Add/1');
add_line(model, 'Secret_Delay/1', 'Secret_Add/2');
add_line(model, 'Secret_Add/1', 'Secret_Delay/1');
add_line(model, 'Secret_Delay/1', 'Secret_Switch/2');
add_line(model, 'Secret_One/1', 'Secret_Switch/1');
add_line(model, 'Secret_One/1', 'Secret_Switch/3');
add_line(model, 'Secret_Switch/1', 'Secret_End/1');

lines = {};  % declared first: evalc alone leaves 'lines' as MATLAB's colormap function
printed = evalc('lines = st_explain_block_logic([model ''/Secret_Switch''], ''Boundary'', model, ''ShowTypes'', true);');
text = strjoin(lines, newline);
verifyTrue(testCase, contains(text, '형식: D1=double'));
verifyFalse(testCase, contains(printed, 'Secret'));
verifyEqual(testCase, get_param(model, 'SimulationStatus'), 'stopped');
end

function testShowRangesAddsCutInputRangesWithoutNames(testCase)
% A CUT input whose Min is 1 keeps "u2 >= 1" true, which is why SLDV finds
% the false outcome unreachable. ShowRanges prints that range per input.
model = 'stt_explain_secret_ranges';
if bdIsLoaded(model), close_system(model, 0); end
new_system(model);
cleanup = onCleanup(@() close_system(model, 0)); %#ok<NASGU>
cut = [model '/Secret_CUT'];
add_block('simulink/Ports & Subsystems/Subsystem', cut);
delete_line(cut, 'In1/1', 'Out1/1');
set_param([cut '/In1'], 'Name', 'Secret_In', 'OutDataTypeStr', 'uint8', 'OutMin', '1', 'OutMax', '10');
add_block('simulink/Sources/In1', [cut '/Secret_Free']);
add_block('simulink/Sources/Constant', [cut '/Secret_One'], 'Value', '1');
add_block('simulink/Signal Routing/Switch', [cut '/Secret_Switch'], ...
    'Criteria', 'u2 >= Threshold', 'Threshold', '1');
add_line(cut, 'Secret_One/1', 'Secret_Switch/1');
add_line(cut, 'Secret_In/1', 'Secret_Switch/2');
add_line(cut, 'Secret_Free/1', 'Secret_Switch/3');
add_line(cut, 'Secret_Switch/1', 'Out1/1');

lines = {};  % declared first: evalc alone leaves 'lines' as MATLAB's colormap function
printed = evalc('lines = st_explain_block_logic([cut ''/Secret_Switch''], ''Boundary'', cut, ''ShowRanges'', true);');
text = strjoin(lines, newline);
verifyTrue(testCase, contains(text, '(In1 >= 1) ? 1 : In2'));
verifyTrue(testCase, contains(text, '입력: In1=uint8 1~10, In2=상속 범위 없음'));
verifyFalse(testCase, contains(printed, 'Secret'));
end
