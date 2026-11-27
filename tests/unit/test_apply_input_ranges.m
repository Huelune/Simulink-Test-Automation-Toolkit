function tests = test_apply_input_ranges
%TEST_APPLY_INPUT_RANGES Min/Max from the range table reach Inports and Bus elements.
tests = functiontests(localfunctions);
end

function testSetsRangesAndCountsFailureKinds(testCase)
% Rows: an Inport set, an Inport already equal, a non-number, Min above Max,
% a Bus element in the model workspace, and a Bus only in the base workspace.
% Every name carries "Secret"; the screen leaves the company, so none may print.
model = 'Secret_ApplyRangeModel';
folder = tempname;
mkdir(folder);
new_system(model);
cleanup = onCleanup(@() remove_model(model, folder)); %#ok<NASGU>
cut = [model '/Secret_CUT'];
add_block('simulink/Ports & Subsystems/Subsystem', cut);
set_param([cut '/In1'], 'Name', 'Secret_In1');
for k = 2:4
    add_block('simulink/Sources/In1', sprintf('%s/Secret_In%d', cut, k));
end
set_param([cut '/Secret_In2'], 'OutMin', '-1', 'OutMax', '1');
el = Simulink.BusElement; el.Name = 'Secret_A';
bus = Simulink.Bus; bus.Elements = el;
assignin(get_param(model, 'ModelWorkspace'), 'Secret_Bus', bus);
assignin('base', 'Secret_BaseBus', bus);
save_system(model, fullfile(folder, [model '.slx']));

T = table(repmat(string(cut), 6, 1), ...
    ["Secret_In1"; "Secret_In2"; "Secret_In3"; "Secret_In4"; "Secret_Bus"; "Secret_Bus"], ...
    ["";            "";           "";           "";           "Secret_Bus"; "Secret_BaseBus"], ...
    ["";            "";           "";           "";           "Secret_A";   "Secret_A"], ...
    ["0";           "-1";         "Secret_x";   "5";          "-2.5";       "0"], ...
    ["10";          "1";          "1";          "4";          "[]";         "1"], ...
    'VariableNames', {'CUT', 'Input', 'Bus', 'Element', 'Min', 'Max'});
file = fullfile(folder, 'Secret_ranges.csv');
writetable(T, file);

shown = {};
printed = evalc('shown = st_apply_input_ranges(file);');
joined = strjoin(shown, newline);
verifyTrue(testCase, contains(joined, '표 6줄 | Inport 바꿈 1 | Bus 요소 바꿈 1 | 그대로 1 | 실패 3'));
verifyTrue(testCase, contains(joined, '실패 1 | Min/Max가 숫자가 아님'));
verifyTrue(testCase, contains(joined, '실패 1 | Min이 Max보다 큼'));
verifyTrue(testCase, contains(joined, '실패 1 | Bus 객체가 base workspace에만 있음'));
verifyTrue(testCase, contains(joined, '저장 | 모델 1 | dictionary 0'));
verifyFalse(testCase, contains(printed, 'Secret'));

verifyEqual(testCase, get_param([cut '/Secret_In1'], 'OutMin'), '0');
verifyEqual(testCase, get_param([cut '/Secret_In1'], 'OutMax'), '10');
verifyEqual(testCase, get_param([cut '/Secret_In3'], 'OutMin'), '[]');
saved = getVariable(get_param(model, 'ModelWorkspace'), 'Secret_Bus');
verifyEqual(testCase, saved.Elements(1).Min, -2.5);
verifyEmpty(testCase, saved.Elements(1).Max);
verifyEqual(testCase, get_param(model, 'Dirty'), 'off');
end

function remove_model(model, folder)
if bdIsLoaded(model), close_system(model, 0); end
evalin('base', 'clear Secret_BaseBus');
rmdir(folder, 's');
end
