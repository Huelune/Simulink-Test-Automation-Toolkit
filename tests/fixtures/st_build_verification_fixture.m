function fixture = st_build_verification_fixture(destination)
%ST_BUILD_VERIFICATION_FIXTURE Build disposable verification inputs.
% Binary SLX, XLSX, MAT, and MLDATX artifacts are generated only in the
% supplied verification workspace and are never stored in Git.

arguments
    destination (1,:) char
end

if ~isfolder(destination), mkdir(destination); end
modelName = 'ST_VerificationModel';
modelFile = fullfile(destination, [modelName '.slx']);
managementFile = fullfile(destination, 'TestManagement.xlsx');
runtimeTargetFile = fullfile(destination, 'runtime_target.mat');

if bdIsLoaded(modelName), close_system(modelName, 0); end
new_system(modelName);
cleanup = onCleanup(@() close_if_loaded(modelName)); %#ok<NASGU>
set_param(modelName, 'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', 'FixedStep', '0.01', ...
    'StopTime', '0.02', 'SaveOutput', 'on');

build_scalar_cut(modelName, 'ScalarApply', [70 40 310 160]);
build_array_cut(modelName, 'NumericArray', [70 200 310 320]);
build_nested_bus_cut(modelName, 'NestedBus', [380 40 620 160]);
build_bus_array_cut(modelName, 'BusArray', [380 200 620 320]);
build_no_inport_cut(modelName, 'NoInportOff', [690 40 930 160]);
build_sldv_cut(modelName, 'SldvBranch', [690 200 930 320]);

save_system(modelName, modelFile);
close_system(modelName, 0);

No = (1:6)';
Enabled = true(6,1);
CUTName = ["ScalarApply"; "NumericArray"; "NestedBus"; ...
    "BusArray"; "NoInportOff"; "SldvBranch"];
CUTPath = modelName + "/" + CUTName;
HarnessName = "h_" + CUTName;
TestCaseName = "tc_" + CUTName;
SldvMode = ["OFF"; "OFF"; "OFF"; "OFF"; "OFF"; "GENERATE"];
SldvDataFile = strings(6,1);
ExpectedUpdateMode = ["APPLY"; "APPLY"; "APPLY"; ...
    "APPLY"; "OFF"; "APPLY"];
CoverageFilterMode = ["SUBSYSTEM"; repmat("OFF", 5, 1)];
CoverageFilterAction = ["JUSTIFY"; strings(5, 1)];
CoverageFilterRationale = ["Verification-only child subsystem"; ...
    strings(5, 1)];
PreparationMode = repmat("DEFAULT", 6, 1);
PreparationFromStage = repmat("DEFAULT", 6, 1);
targets = table(No, Enabled, CUTName, CUTPath, HarnessName, ...
    TestCaseName, SldvMode, SldvDataFile, ExpectedUpdateMode, ...
    CoverageFilterMode, CoverageFilterAction, ...
    CoverageFilterRationale, PreparationMode, PreparationFromStage);
writetable(targets, managementFile, 'Sheet', 'Targets');

TopModel = modelName; %#ok<NASGU>
ModelFile = modelFile; %#ok<NASGU>
save(runtimeTargetFile, 'TopModel', 'ModelFile');

fixture = struct( ...
    'Root', destination, 'TopModel', modelName, ...
    'ModelFile', modelFile, 'ManagementExcel', managementFile, ...
    'RuntimeTargetFile', runtimeTargetFile, ...
    'TestFile', fullfile(destination, [modelName '.mldatx']), ...
    'Targets', targets);
end

function build_scalar_cut(model, name, position)
path = add_subsystem(model, name, position);
add_block('simulink/Sources/In1', [path '/u'], ...
    'Position', [30 53 60 67]);
add_block('simulink/Math Operations/Bias', [path '/MismatchBias'], ...
    'Bias', '1', 'Position', [100 45 155 75]);
add_block('simulink/Sinks/Out1', [path '/y'], ...
    'Position', [210 53 240 67]);
add_block('simulink/Ports & Subsystems/Subsystem', ...
    [path '/FilterOnlyChild'], 'Position', [100 105 155 145]);
add_line(path, 'u/1', 'MismatchBias/1');
add_line(path, 'MismatchBias/1', 'y/1');
end

function build_array_cut(model, name, position)
path = add_subsystem(model, name, position);
add_block('simulink/Sources/In1', [path '/u'], ...
    'PortDimensions', '2', 'Position', [30 53 60 67]);
add_block('simulink/Math Operations/Gain', [path '/ArrayGain'], ...
    'Gain', '2', 'Multiplication', 'Element-wise(K.*u)', ...
    'Position', [100 45 155 75]);
add_block('simulink/Sinks/Out1', [path '/y'], ...
    'Position', [210 53 240 67]);
add_line(path, 'u/1', 'ArrayGain/1');
add_line(path, 'ArrayGain/1', 'y/1');
end

function build_nested_bus_cut(model, name, position)
path = add_subsystem(model, name, position);
add_block('simulink/Sources/In1', [path '/u'], ...
    'Position', [25 28 55 42]);
add_block('simulink/Sources/Constant', [path '/leaf_b'], ...
    'Value', '2', 'Position', [25 83 55 97]);
add_block('simulink/Signal Routing/Bus Creator', [path '/ChildBus'], ...
    'Inputs', '2', 'Position', [105 33 110 92]);
add_block('simulink/Sources/Constant', [path '/outer_c'], ...
    'Value', '3', 'Position', [25 128 55 142]);
add_block('simulink/Signal Routing/Bus Creator', [path '/OuterBus'], ...
    'Inputs', '2', 'Position', [160 55 165 130]);
add_block('simulink/Sinks/Out1', [path '/y'], ...
    'Position', [215 83 245 97]);
add_line(path, 'u/1', 'ChildBus/1');
add_line(path, 'leaf_b/1', 'ChildBus/2');
add_line(path, 'ChildBus/1', 'OuterBus/1');
add_line(path, 'outer_c/1', 'OuterBus/2');
add_line(path, 'OuterBus/1', 'y/1');
set_param([path '/u'], 'Name', 'leaf_a');
end

function build_bus_array_cut(model, name, position)
path = add_subsystem(model, name, position);
valueElement = Simulink.BusElement;
valueElement.Name = 'value';
offsetElement = Simulink.BusElement;
offsetElement.Name = 'offset';
elementBus = Simulink.Bus;
elementBus.Elements = [valueElement; offsetElement];
modelWorkspace = get_param(model, 'ModelWorkspace');
assignin(modelWorkspace, 'STVerificationElementBus', elementBus);
add_block('simulink/Sources/In1', [path '/u'], ...
    'PortDimensions', '2', 'Position', [20 28 50 42]);
add_block('simulink/Signal Routing/Demux', [path '/Split'], ...
    'Outputs', '2', 'Position', [75 23 80 72]);
add_block('simulink/Sources/Constant', [path '/b1'], ...
    'Value', '1', 'Position', [20 83 50 97]);
add_block('simulink/Sources/Constant', [path '/b2'], ...
    'Value', '2', 'Position', [20 128 50 142]);
add_block('simulink/Signal Routing/Bus Creator', [path '/Bus1'], ...
    'Inputs', '2', 'OutDataTypeStr', ...
    'Bus: STVerificationElementBus', ...
    'Position', [105 28 110 82]);
add_block('simulink/Signal Routing/Bus Creator', [path '/Bus2'], ...
    'Inputs', '2', 'OutDataTypeStr', ...
    'Bus: STVerificationElementBus', ...
    'Position', [105 103 110 157]);
add_block('simulink/Signal Routing/Vector Concatenate', ...
    [path '/BusArray'], ...
    'Inputs', '2', 'Position', [160 58 165 127]);
add_block('simulink/Sinks/Out1', [path '/y'], ...
    'Position', [215 83 245 97]);
add_line(path, 'u/1', 'Split/1');
set_param(add_line(path, 'Split/1', 'Bus1/1'), 'Name', 'value');
set_param(add_line(path, 'b1/1', 'Bus1/2'), 'Name', 'offset');
set_param(add_line(path, 'Split/2', 'Bus2/1'), 'Name', 'value');
set_param(add_line(path, 'b2/1', 'Bus2/2'), 'Name', 'offset');
add_line(path, 'Bus1/1', 'BusArray/1');
add_line(path, 'Bus2/1', 'BusArray/2');
add_line(path, 'BusArray/1', 'y/1');
end

function build_no_inport_cut(model, name, position)
path = add_subsystem(model, name, position);
add_block('simulink/Sources/Constant', [path '/constant'], ...
    'Value', '0', 'Position', [35 53 65 67]);
add_block('simulink/Sinks/Out1', [path '/y'], ...
    'Position', [160 53 190 67]);
add_line(path, 'constant/1', 'y/1');
end

function build_sldv_cut(model, name, position)
path = add_subsystem(model, name, position);
branchGain = Simulink.Parameter(1);
branchGain.Description = 'Verification fixture tunable parameter';
assignin(get_param(model, 'ModelWorkspace'), ...
    'STVerificationBranchGain', branchGain);
add_block('simulink/Sources/In1', [path '/u'], ...
    'Position', [25 83 55 97]);
add_block('simulink/Sources/Constant', [path '/positive'], ...
    'Value', '1', 'Position', [25 28 55 42]);
add_block('simulink/Sources/Constant', [path '/negative'], ...
    'Value', '-1', 'Position', [25 138 55 152]);
add_block('simulink/Signal Routing/Switch', [path '/Branch'], ...
    'Threshold', '0', 'Criteria', 'u2 >= Threshold', ...
    'Position', [115 48 165 132]);
add_block('simulink/Math Operations/Gain', [path '/ParameterGain'], ...
    'Gain', 'STVerificationBranchGain', ...
    'Position', [180 73 210 107]);
add_block('simulink/Sinks/Out1', [path '/y'], ...
    'Position', [235 83 265 97]);
add_line(path, 'positive/1', 'Branch/1');
add_line(path, 'u/1', 'Branch/2');
add_line(path, 'negative/1', 'Branch/3');
add_line(path, 'Branch/1', 'ParameterGain/1');
add_line(path, 'ParameterGain/1', 'y/1');
end

function path = add_subsystem(model, name, position)
path = [model '/' name];
add_block('simulink/Ports & Subsystems/Subsystem', path, ...
    'Position', position);
delete_line(path, 'In1/1', 'Out1/1');
delete_block([path '/In1']);
delete_block([path '/Out1']);
end

function close_if_loaded(modelName)
if bdIsLoaded(modelName), close_system(modelName, 0); end
end
