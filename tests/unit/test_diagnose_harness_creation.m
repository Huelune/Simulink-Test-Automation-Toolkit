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
% A virtual bus with no bus object, as a Bus Creator makes it.
add_block('built-in/Inport', [cut '/secret_in_virtual'], 'SampleTime', '0.01');
add_block('built-in/Terminator', [cut '/T2']);
add_line(cut, 'secret_in_virtual/1', 'T2/1');
add_block('built-in/Constant', [model '/C1'], 'Value', '1', 'SampleTime', '0.01');
add_block('built-in/Constant', [model '/C2'], 'Value', '[1 2]', 'SampleTime', '0.01');
add_block('built-in/BusCreator', [model '/BC'], 'Inputs', '2');
wire = add_line(model, 'C1/1', 'BC/1');
set_param(wire, 'Name', 'secret_sig_a');
wire = add_line(model, 'C2/1', 'BC/2');
set_param(wire, 'Name', 'secret_sig_b');
add_line(model, 'BC/1', 'secret_cut/3');
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

function testSignalEditorRefusesTheVirtualBusWithoutObject(testCase)
% The fixture's third input is a Bus Creator bus with no bus object, which a
% Signal Editor Harness does not accept; an Inport Harness does.
original = testCase.TestData.Report.Original;
summary = attempt_summary(original);
verifyEqual(testCase, [original.Ok], [false false true], summary);
verifyTrue(testCase, all(contains([original(1:2).Ids], "VBusWithNoBusObjNotSupported_SE")), summary);
end

function testReducedModelAcceptsEveryAttempt(testCase)
% The reduced model carries the derived bus object, so Signal Editor works.
reduced = testCase.TestData.Report.Reduced;
verifyEqual(testCase, [reduced.Ok], true(1, 3), attempt_summary(reduced));
end

function testInterfaceIsCountedNotNamed(testCase)
ports = testCase.TestData.Report.Ports;
verifyEqual(testCase, [ports.Direction], ["In" "In" "In" "Out"]);
verifyEqual(testCase, ports(1).BusType, "NON_VIRTUAL_BUS");
verifyEqual(testCase, ports(1).Bus.Leaves, 3);
verifyEqual(testCase, ports(1).Bus.Depth, 2);
verifyEqual(testCase, ports(1).Bus.NonScalar, 1);
end

function testVirtualBusWithoutObjectKeepsItsStructure(testCase)
% Simulink derives a bus object from the Bus Creator, so the reduced model
% does not fall back to Inherit: auto.
report = testCase.TestData.Report;
port = report.Ports(3);
summary = sprintf('BusType=%s Resolved=%d Leaves=%d Unresolved=%d', port.BusType, ...
    ~isempty(port.Bus) && port.Bus.Resolved, leaves(port), report.ReducedNotes.UnresolvedBuses);
verifyEqual(testCase, port.BusType, "VIRTUAL_BUS", summary);
verifyTrue(testCase, ~isempty(port.Bus) && port.Bus.Resolved, summary);
verifyEqual(testCase, leaves(port), 2, summary);
verifyEqual(testCase, report.ReducedNotes.UnresolvedBuses, 0, summary);
verifyTrue(testCase, port.Derived, summary);
verifyFalse(testCase, report.Ports(1).Derived);
end

function testReducedModelHoldsOnlyRenamedBuses(testCase)
files = testCase.TestData.Report.ReducedFiles;
verifyNumElements(testCase, files, 2);
buses = load(files(endsWith(files, '.mat')));
busNames = sort(string(fieldnames(buses)));
verifyEqual(testCase, busNames, ["ReproBus_1"; "ReproBus_2"; "ReproBus_3"], ...
    "buses: " + strjoin(busNames, ', '));
elements = arrayfun(@(n) buses.(n).Elements, busNames, 'UniformOutput', false);
elements = vertcat(elements{:});
verifyTrue(testCase, all(startsWith(string({elements.Name}), "e")));
types = string({elements.DataType});
verifyEmpty(testCase, types(contains(types, 'secret')));
end

function testDerivedBusObjectsAreClearedFromBase(testCase)
names = string(evalin('base', 'who'));
verifyEmpty(testCase, names(startsWith(names, "slBus")));
end

function testDiagnosisLeavesNoHarness(testCase)
verifyEmpty(testCase, sltest.harness.find(testCase.TestData.Cut));
end

function text = attempt_summary(results)
parts = strings(1, numel(results));
for k = 1:numel(results)
    parts(k) = "OK";
    if ~results(k).Ok, parts(k) = results(k).Ids; end
end
text = char(strjoin(parts, ' / '));
end

function n = leaves(port)
n = 0;
if ~isempty(port.Bus), n = port.Bus.Leaves; end
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
evalin('base', 'clear secret_inner_bus secret_outer_bus ReproBus_*');
repro = fullfile(folder, 'st_harness_repro');
if contains(path, repro), rmpath(repro); end
if isfolder(folder), rmdir(folder, 's'); end
end
