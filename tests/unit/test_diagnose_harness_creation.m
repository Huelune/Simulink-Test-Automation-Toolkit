function tests = test_diagnose_harness_creation
%TEST_DIAGNOSE_HARNESS_CREATION The Harness diagnosis prints no names and anonymizes the reduced model.
% The fixture model, CUT and buses are named with "secret" so that any name
% leaking to the console or into the reduced model is caught.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
model = 'secret_model_diag';
folder = tempname;
mkdir(folder);
testCase.addTeardown(@() cleanup(model, folder));

inner = Simulink.Bus;
inner.Elements = [element('secret_leaf_a', 'double', 1), element('secret_leaf_b', 'int16', 3)];
outer = Simulink.Bus;
outer.Elements = [element('secret_child', 'Bus: secret_inner_bus', 1), ...
    element('secret_flag', 'boolean', 1)];
assignin('base', 'secret_inner_bus', inner);
assignin('base', 'secret_outer_bus', outer);

new_system(model);
set_param(model, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', 'FixedStep', '0.01');
cut = [model '/secret_cut'];
add_block('built-in/SubSystem', cut, 'TreatAsAtomicUnit', 'on');
add_block('built-in/Inport', [cut '/secret_in_bus'], 'OutDataTypeStr', 'Bus: secret_outer_bus', ...
    'SampleTime', '0.01');
try, set_param([cut '/secret_in_bus'], 'BusOutputAsStruct', 'on'); catch, end
try, set_param([cut '/secret_in_bus'], 'OutputAsNonvirtualBus', 'on'); catch, end
add_block('built-in/Terminator', [cut '/T']);
add_line(cut, 'secret_in_bus/1', 'T/1');
add_block('built-in/Inport', [cut '/secret_in_vec'], 'PortDimensions', '4', 'SampleTime', '0.01');
add_block('built-in/Gain', [cut '/G']);
add_block('built-in/Outport', [cut '/secret_out']);
add_line(cut, 'secret_in_vec/1', 'G/1');
add_line(cut, 'G/1', 'secret_out/1');
add_block('built-in/Inport', [model '/B'], 'OutDataTypeStr', 'Bus: secret_outer_bus', ...
    'SampleTime', '0.01');
try, set_param([model '/B'], 'BusOutputAsStruct', 'on'); catch, end
try, set_param([model '/B'], 'OutputAsNonvirtualBus', 'on'); catch, end
add_block('built-in/Inport', [model '/V'], 'PortDimensions', '4', 'SampleTime', '0.01');
add_block('built-in/Outport', [model '/Y']);
add_line(model, 'B/1', 'secret_cut/1');
add_line(model, 'V/1', 'secret_cut/2');
add_line(model, 'secret_cut/1', 'Y/1');
save_system(model, fullfile(folder, [model '.slx']));

[testCase.TestData.Console, testCase.TestData.Report] = evalc( ...
    'st_diagnose_harness_creation(cut, ''OutputFolder'', folder)');
testCase.TestData.Model = model;
testCase.TestData.Cut = cut;
end

function testConsoleCarriesNoNames(testCase)
console = lower(testCase.TestData.Console);
verifyEmpty(testCase, strfind(console, 'secret'));
verifyNotEmpty(testCase, strfind(console, '하네스 생성 진단'));
end

function testEveryAttemptSucceedsOnAPlainModel(testCase)
report = testCase.TestData.Report;
verifyEqual(testCase, [report.Original.Ok], true(1, 3));
verifyEqual(testCase, [report.Reduced.Ok], true(1, 3));
end

function testInterfaceIsCountedNotNamed(testCase)
ports = testCase.TestData.Report.Ports;
verifyEqual(testCase, [ports.Direction], ["In" "In" "Out"]);
verifyEqual(testCase, ports(1).BusType, "NON_VIRTUAL_BUS");
verifyEqual(testCase, ports(1).Bus.Leaves, 3);
verifyEqual(testCase, ports(1).Bus.Depth, 2);
verifyEqual(testCase, ports(1).Bus.NonScalar, 1);
end

function testReducedModelHoldsOnlyRenamedBuses(testCase)
files = testCase.TestData.Report.ReducedFiles;
verifyNumElements(testCase, files, 2);
buses = load(files(endsWith(files, '.mat')));
verifyEqual(testCase, sort(string(fieldnames(buses))), ["ReproBus_1"; "ReproBus_2"]);
names = string({buses.ReproBus_1.Elements.Name, buses.ReproBus_2.Elements.Name});
verifyTrue(testCase, all(startsWith(names, "e")));
types = string({buses.ReproBus_1.Elements.DataType, buses.ReproBus_2.Elements.DataType});
verifyEmpty(testCase, types(contains(types, 'secret')));
end

function testDiagnosisLeavesNoHarness(testCase)
verifyEmpty(testCase, sltest.harness.find(testCase.TestData.Cut));
end

function e = element(name, type, dims)
e = Simulink.BusElement;
e.Name = name;
e.DataType = type;
e.Dimensions = dims;
end

function cleanup(model, folder)
for name = {model, 'ST_HarnessRepro'}
    if bdIsLoaded(name{1}), close_system(name{1}, 0); end
end
evalin('base', 'clear secret_inner_bus secret_outer_bus ReproBus_1 ReproBus_2');
repro = fullfile(folder, 'st_harness_repro');
if contains(path, repro), rmpath(repro); end
if isfolder(folder), rmdir(folder, 's'); end
end
