function tests = test_model_profiles_and_restart
tests = functiontests(localfunctions);
end

function setup(testCase)
testCase.TestData.OriginalPath = path;
fixtureDir = fullfile(st_project_root(),'tests','fixtures');
addpath(fixtureDir);
[root,cleanup] = st_isolated_toolkit();
testCase.TestData.Root = root;
testCase.TestData.Cleanup = cleanup;
for name = {'A.slx','B.slx','A.xlsx','B.xlsx'}
    st_atomic_save(fullfile(root,name{1}),struct('Fixture',1));
end
end

function teardown(testCase)
testCase.TestData.Cleanup = [];
path(testCase.TestData.OriginalPath);
end

function testProfilesSwitchWithoutLoadingAndKeepLegacy(testCase)
root = testCase.TestData.Root;
st_save_runtime_target_fields(fullfile(root,'runtime_target.mat'), ...
    struct('TopModel','Legacy','ModelFile',fullfile(root,'legacy.slx'),'CustomValue',42));
save_profile('A',root); save_profile('B',root);
a = st_select_model_profile('A');
verifyEqual(testCase,a.ManagementExcel,fullfile(root,'A.xlsx'));
verifyEqual(testCase,a.TestFile,fullfile(root,'outA','A.mldatx'));
b = st_select_model_profile('B');
verifyNotEqual(testCase,a.WorkflowStateFile,b.WorkflowStateFile);
verifyNotEqual(testCase,a.PerCutLatestPointer,b.PerCutLatestPointer);
again = st_select_model_profile('A');
verifyEqual(testCase,again.WorkflowStateFile,a.WorkflowStateFile);
legacy = st_select_model_profile('');
verifyEqual(testCase,legacy.TopModel,'Legacy');
saved = load(fullfile(root,'runtime_target.mat'));
verifyEqual(testCase,saved.CustomValue,42);
end

function testRejectedSelectionsDoNotChangeActiveSettings(testCase)
root = testCase.TestData.Root;
save_profile('A',root); st_select_model_profile('A');
before = st_file_signature(fullfile(root,'runtime_target.mat'));
verifyError(testCase,@() st_select_model_profile('missing'),'simtest:ModelProfileMissing');
after = st_file_signature(fullfile(root,'runtime_target.mat'));
verifyEqual(testCase,after.SHA256,before.SHA256);
verifyError(testCase,@() save_profile('A',root),'simtest:ModelProfileExists');
verifyError(testCase,@() st_save_model_profile('B','ModelFile',fullfile(root,'B.slx'), ...
    'ManagementExcel',fullfile(root,'B.xlsx'),'OutputRoot',fullfile(root,'outA','nested')), ...
    'simtest:ModelProfileOutputConflict');
end

function testRootOverrideIsProfileLocal(testCase)
root = testCase.TestData.Root;
save_profile('A',root); save_profile('B',root);
st_select_model_profile('A');
a = st_set_standalone_coverage_root(fullfile(root,'shortA'));
verifyEqual(testCase,a.StandaloneCoverageRootDir,fullfile(root,'shortA'));
b = st_select_model_profile('B');
verifyEqual(testCase,b.StandaloneCoverageRootDir,fullfile(root,'outB','standalone_coverage'));
st_select_model_profile('A'); a = st_set_standalone_coverage_root('');
verifyEqual(testCase,a.StandaloneCoverageRootDir,fullfile(root,'outA','standalone_coverage'));
end

function testDifferentModelDeactivatesProfile(testCase)
root = testCase.TestData.Root; save_profile('A',root); st_select_model_profile('A');
st_save_runtime_target_fields(fullfile(root,'runtime_target.mat'), ...
    struct('ModelFile',fullfile(root,'B.slx'),'TopModel','B'));
cfg = st_config();
verifyEmpty(testCase,cfg.ActiveModelProfile);
verifyEqual(testCase,cfg.ManagementExcel,fullfile(root,'TestManagement.xlsx'));
verifyEqual(testCase,cfg.TopModel,'B');
end

function testCorruptStoreDoesNotSilentlyReset(testCase)
root = testCase.TestData.Root;
st_atomic_save(fullfile(root,'model_profiles.mat'),struct('store',struct('Version',99)));
verifyError(testCase,@() st_list_model_profiles(),'simtest:ModelProfilesInvalid');
end

function testAllRestartBoundariesOverrideDirtyEarlierStages(testCase)
stages = st_workflow_stages('FROM_HARNESS');
for start = 1:numel(stages)
    plan = table([1;2],'VariableNames',{'No'});
    for k = 1:8
        stage = char(stages(k));
        plan.(['Run' stage]) = true(2,1);
        plan.(['Action' stage]) = repmat("RUN",2,1);
        plan.(['Reason' stage]) = repmat("dirty",2,1);
    end
    actual = st_restart_plan(plan,stages(start));
    for k = 1:8
        verifyEqual(testCase,actual.(['Run' char(stages(k))]),repmat(k>=start,2,1));
    end
end
verifyError(testCase,@() st_workflow_stages('AFTER_HARNESS','HARNESS'),'simtest:RestartStageInvalid');
verifyError(testCase,@() st_workflow_stages('STANDALONE','ASSESSMENT'),'simtest:RestartStageInvalid');
end

function testBindingsRequireAssociatedExactValues(testCase)
params = {'TestSequenceScenario','Scenario_1';'SignalBuilderGroup','Scenario_2'};
verifyTrue(testCase,st_iteration_binding_matches(params,{'TestSequenceScenario'},'Scenario_1'));
verifyFalse(testCase,st_iteration_binding_matches(params,{'TestSequenceScenario'},'Scenario_2'));
verifyFalse(testCase,st_iteration_binding_matches(params,{'TestSequenceScenario'},'Scenario'));
verifyTrue(testCase,st_iteration_binding_matches(struct('Name','SignalBuilderGroup','Value','Scenario_2'), ...
    {'SignalEditorScenario','SignalBuilderGroup'},'Scenario_2'));
verifyFalse(testCase,st_iteration_binding_matches(struct('Name','Unknown','Value','Scenario_2'), ...
    {'SignalBuilderGroup'},'Scenario_2'));
end

function testFailedCandidateDoesNotPublishLatest(testCase)
root = fullfile(testCase.TestData.Root,'pipelines');
first = struct('Version',3,'PipelineId','first','Actions',struct(),'PublishLatest',true);
st_write_standalone_pipeline_manifest(root,first);
before = st_file_signature(fullfile(root,'latest.json'));
candidate = first; candidate.PipelineId = 'candidate'; candidate.PublishLatest = false;
st_write_standalone_pipeline_manifest(root,candidate);
verifyTrue(testCase,isfile(fullfile(root,'candidate','pipeline-manifest.json')));
verifyEqual(testCase,st_file_signature(fullfile(root,'latest.json')).SHA256,before.SHA256);
candidate.PublishLatest = true;
st_write_standalone_pipeline_manifest(root,candidate);
loaded = st_load_standalone_pipeline_manifest(root,'LATEST');
verifyEqual(testCase,loaded.PipelineId,'candidate');
end

function save_profile(name,root)
st_save_model_profile(name,'ModelFile',fullfile(root,[name '.slx']), ...
    'ManagementExcel',fullfile(root,[name '.xlsx']),'OutputRoot',fullfile(root,['out' name]));
end
