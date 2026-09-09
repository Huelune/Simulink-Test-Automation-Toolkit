function tests = test_harness_clone_runtime
%TEST_HARNESS_CLONE_RUNTIME Disposable R2025b models; no project input edits.
% st_setup; runtests('tests/integration/test_harness_clone_runtime.m')
tests = functiontests(localfunctions);
end

function setup(testCase)
assumeTrue(testCase,~isempty(which('sltest.harness.clone')),'Simulink Test required.');
root = tempname; mkdir(root);
testCase.TestData.Root = root;
testCase.TestData.OldFolder = pwd;
configSource = fileread(which('st_config'));
write_text(fullfile(root,'st_config.m'), ...
    strrep(configSource,'cfg.RunGeneratedTests = true;','cfg.RunGeneratedTests = false;'));
write_text(fullfile(root,'st_setup.m'),'function st_setup; end');
write_text(fullfile(root,'VERSION.txt'),'clone-runtime-fixture');
mkdir(fullfile(root,'src'));
cd(root); clear st_config st_setup;
[~,id] = fileparts(root);
source = matlab.lang.makeValidName(['clone_source_' id]);
model = matlab.lang.makeValidName(['clone_target_' id]);
testCase.TestData.Models = {source,model};
for current = {source,model}
    new_system(current{1});
    for leaf = {'A','B','C'}
        cut = [current{1} '/' leaf{1}];
        add_block('built-in/SubSystem',cut);
        add_block('simulink/Sources/In1',[cut '/u']);
        add_block('simulink/Math Operations/Gain',[cut '/Gain'],'Gain','1');
        add_block('simulink/Sinks/Out1',[cut '/y']);
        if strcmp(current{1},model), set_param([cut '/Gain'],'Gain','2'); end
        add_line(cut,'u/1','Gain/1'); add_line(cut,'Gain/1','y/1');
    end
    save_system(current{1},fullfile(root,[current{1} '.slx']));
end
TopModel = model; ModelFile = fullfile(root,[model '.slx']); %#ok<NASGU>
save(fullfile(root,'runtime_target.mat'),'TopModel','ModelFile');
template = matlab.lang.makeValidName(['template_' id]);
owner = [source '/A'];
sltest.harness.create(owner,'Name',template,'Source','Signal Editor', ...
    'Sink','Outport','SchedulerBlock','Test Sequence','SeparateAssessment',true, ...
    'SaveExternally',contains(testCase.Name,'External'),'SynchronizationMode','SyncOnOpenAndClose');
input_scenario = Simulink.SimulationData.Dataset;
input_scenario = input_scenario.addElement(timeseries([7;7],[0;1]),'u'); %#ok<NASGU>
inputFile = fullfile(root,'template_input.mat'); save(inputFile,'input_scenario');
sltest.harness.open(owner,template);
signal = st_find_signal_editor_block(template);
set_param(signal,'Filename',inputFile);
assessment = st_find_assessment_block(template);
st_prepare_assessment_scenario(assessment,{'input_scenario'},'verify(1 == 1);','true');
save_system(template); sltest.harness.close(owner,template); save_system(source);
T = table((1:3).',["A";"B";"C"],string(model)+["/A";"/B";"/C"], ...
    string(id)+["_hA";"_hB";"_hC"],["CaseA";"CaseB";"CaseC"], ...
    repmat("HARNESS_CLONE",3,1),repmat(string(owner),3,1),repmat(string(template),3,1), ...
    repmat("OFF",3,1),repmat("OFF",3,1),repmat("OFF",3,1), ...
    'VariableNames',{'No','CUTName','CUTPath','HarnessName','TestCaseName', ...
    'TestPreparationSource','SourceCUTPath','SourceHarnessName','SldvMode', ...
    'ExpectedUpdateMode','CoverageFilterMode'});
for i = 1:height(T), T.HarnessName(i) = string(matlab.lang.makeValidName(T.HarnessName(i))); end
writetable(T,fullfile(root,'TestManagement.xlsx'),'Sheet','Targets');
testCase.TestData.T = T;
testCase.TestData.InputFile = inputFile;
testCase.TestData.SourceHash = st_file_signature(fullfile(root,[source '.slx']));
testCase.TestData.InputHash = st_file_signature(inputFile);
end

function teardown(testCase)
if isfield(testCase.TestData,'Models')
    for model = testCase.TestData.Models
        if bdIsLoaded(model{1}), close_system(model{1},0); end
    end
end
if isfield(testCase.TestData,'OldFolder')
    cd(testCase.TestData.OldFolder); clear st_config st_setup;
end
if isfield(testCase.TestData,'Root') && isfolder(testCase.TestData.Root)
    % Test File handles can hold the temporary mldatx open on Windows.
    files = sltest.testmanager.getTestFiles;
    for i = 1:numel(files)
        if startsWith(string(files(i).FilePath),string(testCase.TestData.Root))
            remove(files(i));
        end
    end
    rmdir(testCase.TestData.Root,'s');
end
end

function testCrossModelBatchFailureAndTestManager(testCase)
T = testCase.TestData.T;
T.SourceHarnessName(2) = "missing_template";
writetable(T,fullfile(testCase.TestData.Root,'TestManagement.xlsx'),'Sheet','Targets');
[~,~,~,report] = st_run_workflow('FULL');
verifyEqual(testCase,report.CloneFailures.No,2);
verifyEmpty(testCase,sltest.harness.find(char(T.CUTPath(2)), ...
    'SearchDepth',0,'Name',char(T.HarnessName(2))));
cfg = st_config();
inputs = strings(2,1);
for i = [1 3]
    info = sltest.harness.find(char(T.CUTPath(i)),'SearchDepth',0,'Name',char(T.HarnessName(i)));
    verifyEqual(testCase,string(info.ownerFullPath),T.CUTPath(i));
    name = char(T.HarnessName(i));
    sltest.harness.open(char(T.CUTPath(i)),name);
    gains = find_system(name,'LookUnderMasks','all','BlockType','Gain');
    verifyTrue(testCase,any(cellfun(@(b) strcmp(get_param(b,'Gain'),'2'),gains)));
    signal = st_find_signal_editor_block(name);
    inputs(1+(i==3)) = string(get_param(signal,'Filename'));
    verifyNotEqual(testCase,inputs(1+(i==3)),string(testCase.TestData.InputFile));
    assessment = st_find_assessment_block(name);
    scenario = st_scenario_name(T.CUTName(i),1);
    first = sltest.testsequence.readStep(assessment,[scenario '.step1']);
    second = sltest.testsequence.readStep(assessment,[scenario '.step2']);
    verifyEqual(testCase,strtrim(string(first.Action)),"");
    verifyTrue(testCase,contains(string(second.Action),'verify('));
    verifyFalse(testCase,contains(string(second.Action),'verify(1 == 1)'));
    transition = sltest.testsequence.readTransition(assessment,[scenario '.step1'],1);
    verifyEqual(testCase,string(transition.Condition),"after(0.01, sec)");
    set_param(name,'SimulationCommand','update');
    sltest.harness.close(char(T.CUTPath(i)),name);
end
verifyNotEqual(testCase,inputs(1),inputs(2));
verifyTrue(testCase,isfile(cfg.TestFile));
selected = st_load_targets(true);
scope = st_target_scope('enter',selected([1 3],:)); %#ok<NASGU>
[cases,~] = st_get_run_test_cases();
verifyEqual(testCase,numel(cases),2);
inputHash = st_file_signature(testCase.TestData.InputFile);
verifyEqual(testCase,inputHash.SHA256,testCase.TestData.InputHash.SHA256);
sourceHash = st_file_signature(testCase.TestData.SourceHash.Path);
verifyEqual(testCase,sourceHash.SHA256,testCase.TestData.SourceHash.SHA256);
end

function testExternalTemplateClone(testCase)
testCrossModelBatchFailureAndTestManager(testCase);
end

function testOverwriteSkipAndRecoveryOnPostprocessingFailure(testCase)
cfg = st_config();
T = st_load_targets(true);
[status,~] = st_clone_template_harness(T(1,:),cfg);
verifyEqual(testCase,status,"OK");
[status,~] = st_clone_template_harness(T(1,:),cfg);
verifyEqual(testCase,status,"SKIP");
cfg.OverwriteHarness = true;
% A FILE error occurs after clone, exercising recovery of the old Harness.
bad = testCase.TestData.T;
bad.SldvMode(1) = "FILE";
bad.SldvDataFile = ["missing_sldv.mat";"";""];
writetable(bad,fullfile(testCase.TestData.Root,'TestManagement.xlsx'),'Sheet','Targets');
verifyError(testCase,@() st_clone_template_harness(st_load_one(),cfg), ...
    'simtest:ClonePreparationFailed');
info = sltest.harness.find(char(T.CUTPath(1)),'SearchDepth',0,'Name',char(T.HarnessName(1)));
verifyEqual(testCase,numel(info),1);
sltest.harness.open(char(T.CUTPath(1)),char(T.HarnessName(1)));
signal = st_find_signal_editor_block(char(T.HarnessName(1)));
verifyTrue(testCase,isfile(get_param(signal,'Filename')));
sltest.harness.close(char(T.CUTPath(1)),char(T.HarnessName(1)));
writetable(testCase.TestData.T,fullfile(testCase.TestData.Root,'TestManagement.xlsx'),'Sheet','Targets');
[status,~] = st_clone_template_harness(T(1,:),cfg);
verifyEqual(testCase,status,"OK");
allHarnesses = sltest.harness.find(char(T.CUTPath(1)),'SearchDepth',0);
verifyFalse(testCase,any(startsWith(string({allHarnesses.name}),"clone_recovery_")));
end

function row = st_load_one()
T = st_load_targets(true); row = T(1,:);
end

function write_text(path,text)
fid = fopen(path,'w','n','UTF-8');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',text);
end
