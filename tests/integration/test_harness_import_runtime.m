function tests = test_harness_import_runtime
% Opt-in R2025b integration fixture. Uses only newly-created temporary models.
% st_setup; runtests('tests/integration/test_harness_import_runtime.m')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
assumeTrue(testCase,~isempty(which('sltest.harness.create')), ...
    'Simulink Test is required.');
root = tempname; mkdir(root);
[~,id] = fileparts(root); model = ['import_fixture_' id];
testCase.TestData.Root = root; testCase.TestData.Model = model;
cfg = st_config(); cfg.TopModel = model;
cfg.ModelFile = fullfile(root,[model '.slx']); cfg.ResultDir = root;
testCase.TestData.Cfg = cfg;
new_system(model);
for parent = {'A','B','C'}
    branch = [model '/' parent{1}];
    add_block('built-in/SubSystem',branch);
    cut = [branch '/CUT']; add_block('built-in/SubSystem',cut);
    add_block('simulink/Sources/In1',[cut '/u']);
    add_block('simulink/Math Operations/Gain',[cut '/Gain'],'Gain','1');
    add_block('simulink/Sinks/Out1',[cut '/y']);
    add_line(cut,'u/1','Gain/1'); add_line(cut,'Gain/1','y/1');
end
save_system(model,cfg.ModelFile);
case_a = Simulink.SimulationData.Dataset;
case_a = case_a.addElement(timeseries([7;7],[0;1]),'u');
case_b = Simulink.SimulationData.Dataset;
case_b = case_b.addElement(timeseries([8;8],[0;1]),'u');
input = fullfile(root,'source.mat'); save(input,'case_a','case_b');
for parent = {'A','B','C'}
    owner = [model '/' parent{1} '/CUT']; harness = ['test_' parent{1} '_' id];
    sltest.harness.create(owner,'Name',harness,'Source','Signal Editor', ...
        'Sink','Outport','SchedulerBlock','Test Sequence','SeparateAssessment',true, ...
        'SaveExternally',false,'SynchronizationMode','SyncOnOpenAndClose');
    sltest.harness.load(owner,harness);
    signal = st_find_signal_editor_block(harness);
    set_param(signal,'Filename',input);
    save_system(harness); sltest.harness.close(owner,harness);
    sltest.harness.load(owner,harness);
    signal = st_find_signal_editor_block(harness);
    set_param(signal,'ActiveScenario','case_a');
    assessment = st_find_assessment_block(harness);
    action = 'verify(7 == 0);';
    if strcmp(parent{1},'A'), action = 'verify(7 == 7);'; end
    st_prepare_assessment_scenario(assessment,{'case_a','case_b'},action,'true');
    set_param(harness,'StopTime','1');
    save_system(harness); sltest.harness.close(owner,harness);
    testCase.TestData.(['Harness' parent{1}]) = harness;
end
save_system(model);
end

function teardownOnce(testCase)
if isfield(testCase.TestData,'Model') && bdIsLoaded(testCase.TestData.Model)
    close_system(testCase.TestData.Model,0);
end
if isfield(testCase.TestData,'Root') && isfolder(testCase.TestData.Root)
    rmdir(testCase.TestData.Root,'s');
end
end

function testCopiesTwoScenariosAndExpectedActionsToTwoExistingHarnesses(testCase)
cfg = testCase.TestData.Cfg;
model = testCase.TestData.Model;
owners = string(model) + ["/A/CUT";"/B/CUT";"/C/CUT"];
interfaces = st_import_cut_interfaces(owners,cfg);
verifyEqual(testCase,interfaces(char(owners(1))),interfaces(char(owners(2))));
staticInterfaces = st_import_cut_interfaces(owners,cfg,true);
verifyEqual(testCase,staticInterfaces(char(owners(1))), ...
    staticInterfaces(char(owners(2))));
store = [model '_snapshot']; new_system(store);
cleanup = onCleanup(@() close_system(store,0)); %#ok<NASGU>
add_block('built-in/SubSystem',[store '/source']);
source = st_harness_content_snapshot(owners(1),testCase.TestData.HarnessA,cfg,[store '/source']);
for parent = {'B','C'}
    owner = [model '/' parent{1} '/CUT'];
    harness = testCase.TestData.(['Harness' parent{1}]);
    target = st_harness_content_snapshot(owner,harness,cfg);
    input = fullfile(testCase.TestData.Root,['input_' parent{1} '.mat']);
    copyfile(source.InputFile,input);
    st_apply_harness_content(source,target,input,cfg);
    actual = st_harness_content_snapshot(owner,harness,cfg);
    verifyEqual(testCase,actual.Fingerprint,source.Fingerprint);
    verifyNotEqual(testCase,actual.InputFile,source.InputFile);
    verifyEqual(testCase,actual.Profile.ScenarioNames(:),{'case_a';'case_b'});
    verifyEqual(testCase,get_param([owner '/Gain'],'Gain'),'1');
end
unchanged = st_harness_content_snapshot(owners(1),testCase.TestData.HarnessA,cfg);
verifyEqual(testCase,unchanged.Fingerprint,source.Fingerprint);
end
