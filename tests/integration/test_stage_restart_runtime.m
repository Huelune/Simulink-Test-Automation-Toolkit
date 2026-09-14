function tests = test_stage_restart_runtime
%TEST_STAGE_RESTART_RUNTIME Readiness and restart on generated disposable data.
tests = functiontests(localfunctions);
end

function setup(testCase)
assumeTrue(testCase,strcmp(version('-release'),'2025b'),'R2025b acceptance only.');
assumeTrue(testCase,~isempty(which('sltest.testmanager.TestFile')),'Simulink Test required.');
testCase.TestData.OldPath = path;
addpath(fullfile(st_project_root(),'tests','fixtures'));
[root,cleanup] = st_isolated_toolkit();
testCase.TestData.Cleanup = cleanup;
demo = st_create_example(fullfile(root,'demo'));
st_save_model_profile('DEMO','ModelFile',demo.ModelFile, ...
    'ManagementExcel',demo.ManagementExcel,'OutputRoot',demo.OutputRoot);
testCase.TestData.Cfg = st_select_model_profile('DEMO');
st_run_from_harness('PreparationMode','FORCE','ExecuteTests',false);
end

function teardown(testCase)
if isfield(testCase.TestData,'Cfg')
    cfg = testCase.TestData.Cfg;
    files = sltest.testmanager.getTestFiles;
    for i = 1:numel(files)
        if st_same_path(files(i).FilePath,cfg.TestFile), close(files(i)); end
    end
    if bdIsLoaded(cfg.TopModel), close_system(cfg.TopModel,0); end
end
if isfield(testCase.TestData,'Cleanup'), testCase.TestData.Cleanup = []; end
if isfield(testCase.TestData,'OldPath'), path(testCase.TestData.OldPath); end
end

function testReadinessDoesNotSaveAndStrictRestartKeepsPredecessors(testCase)
cfg = testCase.TestData.Cfg;
files = {cfg.ModelFile,cfg.ManagementExcel,cfg.TestFile,cfg.WorkflowStateFile};
before = cellfun(@(f) st_file_signature(f).SHA256,files,'UniformOutput',false);
oldPath = path; oldFolder = pwd;
[ready,checks] = st_check_readiness('Workflow','FROM_HARNESS','FromStage','ASSESSMENT');
verifyTrue(testCase,ready.Ready,evalc('disp(checks)'));
verifyEqual(testCase,path,oldPath); verifyEqual(testCase,pwd,oldFolder);
verifyEqual(testCase,cellfun(@(f) st_file_signature(f).SHA256,files,'UniformOutput',false),before);
[stateBefore,~] = st_load_workflow_state(cfg);
st_run_workflow('FULL','FromStage','ASSESSMENT','PreparationMode','FORCE', ...
    'StrictRestart',true,'ExecuteTests',false);
[stateAfter,~] = st_load_workflow_state(cfg);
prior = {'HARNESS','SLDV','HARNESS_CONFIG','SIGNAL_EDITOR'};
left = stateBefore.RestartEvidence(ismember({stateBefore.RestartEvidence.Stage},prior));
right = stateAfter.RestartEvidence(ismember({stateAfter.RestartEvidence.Stage},prior));
verifyEqual(testCase,right,left);
end

function testChangedInputRequiresSLDVAndDoesNotRepair(testCase)
cfg = testCase.TestData.Cfg;
T = st_load_targets(true);
inputFile = char(T.SldvDataFile(1));
data = load(inputFile); data.ChangeMarker = 1; st_atomic_save(inputFile,data);
before = st_file_signature(cfg.WorkflowStateFile);
[ready,checks] = st_check_readiness('Workflow','FROM_HARNESS','FromStage','ASSESSMENT');
verifyFalse(testCase,ready.Ready);
verifyEqual(testCase,ready.RecommendedFromStage,'SLDV',evalc('disp(checks)'));
verifyError(testCase,@() st_run_from_stage('Workflow','FROM_HARNESS','FromStage','ASSESSMENT'), ...
    'simtest:RestartBlocked');
verifyEqual(testCase,st_file_signature(cfg.WorkflowStateFile).SHA256,before.SHA256);
end
