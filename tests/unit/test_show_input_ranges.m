function tests = test_show_input_ranges
%TEST_SHOW_INPUT_RANGES Counts of CUT input ranges and types, with no names on screen.
tests = functiontests(localfunctions);
end

function testCountsRangesTypesAndBusElements(testCase)
% CUT inputs: double with Min/Max, inherited (gets uint8 after compile),
% single with Max only, and a Bus of two leaves (one with Min/Max).
% Every name carries "Secret"; the screen leaves the company, so none may print.
model = 'Secret_InputRangeModel';
bus = Simulink.Bus;
el1 = Simulink.BusElement; el1.Name = 'Secret_A'; el1.DataType = 'int16'; el1.Min = -5; el1.Max = 5;
el2 = Simulink.BusElement; el2.Name = 'Secret_B'; el2.DataType = 'single';
bus.Elements = [el1 el2];
assignin('base', 'Secret_Bus', bus);
new_system(model);
cleanup = onCleanup(@() remove_model(model)); %#ok<NASGU>

cut = [model '/Secret_CUT'];
add_block('simulink/Ports & Subsystems/Subsystem', cut);
delete_line(cut, 'In1/1', 'Out1/1');
delete_block([cut '/In1']);
delete_block([cut '/Out1']);
spec = {'double', '0', '100'; 'Inherit: auto', '[]', '[]'; 'single', '[]', '1'; 'Bus: Secret_Bus', '[]', '[]'};
for k = 1:size(spec, 1)
    in = sprintf('%s/Secret_In%d', cut, k);
    add_block('simulink/Sources/In1', in, 'OutDataTypeStr', spec{k, 1}, ...
        'OutMin', spec{k, 2}, 'OutMax', spec{k, 3});
    add_block('simulink/Sinks/Terminator', sprintf('%s/Secret_Term%d', cut, k));
    add_line(cut, sprintf('Secret_In%d/1', k), sprintf('Secret_Term%d/1', k));
end
add_block('simulink/Sources/Constant', [model '/Secret_C1'], 'Value', '1');
add_block('simulink/Sources/Constant', [model '/Secret_C2'], 'Value', '3', 'OutDataTypeStr', 'uint8');
add_block('simulink/Sources/Constant', [model '/Secret_C3'], 'Value', '0.5', 'OutDataTypeStr', 'single');
add_block('simulink/Sources/In1', [model '/Secret_BusIn'], 'OutDataTypeStr', 'Bus: Secret_Bus');
add_line(model, 'Secret_C1/1', 'Secret_CUT/1');
add_line(model, 'Secret_C2/1', 'Secret_CUT/2');
add_line(model, 'Secret_C3/1', 'Secret_CUT/3');
add_line(model, 'Secret_BusIn/1', 'Secret_CUT/4');

shown = {};
printed = evalc('shown = st_show_input_ranges({cut});');
joined = strjoin(shown, newline);
verifyTrue(testCase, contains(printed, '입력 5 | 그중 Bus 요소 2 | 컴파일 OK'));
verifyTrue(testCase, contains(joined, 'double 1'));
verifyTrue(testCase, contains(joined, 'uint8 1'));   % inherited, resolved by compile
verifyTrue(testCase, contains(joined, 'int16 1'));
verifyTrue(testCase, contains(joined, 'single 2'));
verifyTrue(testCase, contains(joined, '최소·최대 모두 2 | 한쪽만 1 | 없음 2'));
verifyTrue(testCase, contains(joined, '대상 1 | 입력 5 | 범위 없음 2 | 형식 미확정 0'));
verifyFalse(testCase, contains(printed, 'Secret'));

T = readtable(fullfile(tempdir, 'st_input_ranges.csv'), 'TextType', 'string', 'Delimiter', ',');
verifyEqual(testCase, height(T), 5);
verifyTrue(testCase, any(T.Element == "Secret_A"));
end

function remove_model(model)
if bdIsLoaded(model), close_system(model, 0); end
evalin('base', 'clear Secret_Bus');
end
