function tests = test_harness_import
% Configuration/profile contracts do not require Simulink execution.
tests = functiontests(localfunctions);
end

function testLegacyTableKeepsExistingPreparation(testCase)
T = targets(); T = removevars(T,{'TestPreparationSource','SourceCUTPath','SourceHarnessName'});
actual = st_resolve_harness_import_settings(T,struct());
verifyEqual(testCase,actual.TestPreparationSource,["EXISTING";"EXISTING"]);
verifyEqual(testCase,actual.SldvMode,T.SldvMode);
verifyEqual(testCase,actual.ExpectedUpdateMode,T.ExpectedUpdateMode);
end

function testImportDisablesGenerationAndExpectedUpdateOnlyForImport(testCase)
T = targets(); T.TestPreparationSource(2) = "EXISTING";
actual = st_resolve_harness_import_settings(T,struct());
verifyEqual(testCase,actual.SldvMode,["OFF";"GENERATE"]);
verifyEqual(testCase,actual.SldvDataFile,["";"old.mat"]);
verifyEqual(testCase,actual.ExpectedUpdateMode,["OFF";"APPLY"]);
end

function testSourceMustBeExplicit(testCase)
T = targets(); T.SourceHarnessName(1) = "";
verifyError(testCase,@() st_resolve_harness_import_settings(T,struct()), ...
    'simtest:ImportSourceMissing');
T = targets(); T.TestPreparationSource(1) = "COPY_EVERYTHING";
verifyError(testCase,@() st_resolve_harness_import_settings(T,struct()), ...
    'simtest:InvalidTestPreparationSource');
end

function testDirectStagesProtectImportedRows(testCase)
T = targets(); T.TestPreparationSource(2) = "EXISTING";
s = st_normalize_stage_selection(T,[]);
s = st_skip_import_preparation(T,s,struct());
verifyEqual(testCase,s.Run,[false;true]);
verifyEqual(testCase,s.Action,["SKIP";"RUN"]);
end

function testSelfDuplicateAndChainRejected(testCase)
cfg = struct('TopModel','mdl');
T = targets(); T.SourceCUTPath(1) = T.CUTPath(1);
verifyError(testCase,@() st_validate_import_mapping(T,cfg),'simtest:ImportSelfReference');
T = targets(); T.CUTPath(2) = T.CUTPath(1);
verifyError(testCase,@() st_validate_import_mapping(T,cfg),'simtest:ImportDuplicateTarget');
T = targets(); T.SourceCUTPath(1) = T.CUTPath(2);
verifyError(testCase,@() st_validate_import_mapping(T,cfg),'simtest:ImportChain');
end

function testRelativePathsResolveToSameModel(testCase)
T = targets();
actual = st_validate_import_mapping(T,struct('TopModel','mdl'));
verifyEqual(testCase,actual,["mdl/A/CUT","mdl/B/CUT";"mdl/A/CUT","mdl/C/CUT"]);
end

function testSelectedSourceCannotBeRegenerated(testCase)
T = targets(); T.TestPreparationSource(2) = "EXISTING"; T.CUTPath(2) = "A/CUT";
verifyError(testCase,@() st_validate_import_mapping(T,struct('TopModel','mdl')), ...
    'simtest:ImportSourceSelected');
end

function testImportNeverFallsBackToSldv(testCase)
T = targets();
verifyError(testCase,@() st_get_sldv_profile(T(1,:),struct()), ...
    'simtest:ImportHasNoSldvProfile');
end

function testPreparedProfileUsesIndependentInputAndRejectsChanges(testCase)
root = tempname; mkdir(root);
cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
cfg = struct('TopModel','mdl','ResultDir',root);
T = targets(); row = T(1,:);
input = fullfile(root,'input.mat'); payload = 7; save(input,'payload');
signature = st_file_signature(input);
profile = st_empty_sldv_profile();
profile.Mode = 'HARNESS_IMPORT'; profile.HasSignalEditor = true;
profile.UsesScenarios = true; profile.ScenarioNames = {'a','b'};
profile.SignalScenarioNames = {'a','b'}; profile.SignalEditorDataFile = input;
manifest = struct('Version',1,'Owner','mdl/B/CUT','Harness','dest_b', ...
    'SourceOwner','mdl/A/CUT','SourceHarness','source', ...
    'Profile',profile,'InputSHA256',signature.SHA256);
path = st_harness_import_file(row,cfg); mkdir(fileparts(path)); save(path,'manifest');
actual = st_get_test_profile(row,cfg);
verifyEqual(testCase,actual.ScenarioNames,{'a','b'});
verifyEqual(testCase,actual.TestCaseName,'tc_b');
verifyEqual(testCase,actual.EffectiveDataFile,'');
changed = row; changed.SourceHarnessName = "other";
verifyError(testCase,@() st_get_test_profile(changed,cfg),'simtest:ImportManifestMismatch');
payload = 8; save(input,'payload');
verifyError(testCase,@() st_get_test_profile(row,cfg),'simtest:ImportInputChanged');
delete(input);
verifyError(testCase,@() st_get_test_profile(row,cfg),'simtest:ImportInputChanged');
end

function testImportFromStageAccepted(testCase)
opts = st_parse_workflow_options('PreparationMode','FORCE','FromStage','HARNESS_IMPORT');
verifyEqual(testCase,opts.FromStage,'HARNESS_IMPORT');
end

function testRestoreRevertsExistingFilesAndRemovesNewManifest(testCase)
root = tempname; mkdir(root);
cleanup = onCleanup(@() rmdir(root,'s')); %#ok<NASGU>
original = fullfile(root,'original.mat'); target = fullfile(root,'target.mat');
created = fullfile(root,'new_manifest.mat'); unrelated = fullfile(root,'unrelated.mat');
payload = 7; save(original,'payload');
payload = 9; save(target,'payload'); save(created,'payload'); save(unrelated,'payload');
st_restore_import_backup({target,created},{original,''},[true,false],struct());
data = load(target); verifyEqual(testCase,data.payload,7);
verifyFalse(testCase,isfile(created));
verifyTrue(testCase,isfile(unrelated));
end

function testIterationBindingsCompareExactNames(testCase)
profile = struct('ScenarioNames',{{'a'}},'SignalScenarioNames',{{'a'}}, ...
    'HasSignalEditor',true,'UsesScenarios',true);
iteration = struct('Name','a','Enabled',true,'Variables',{{}},'ModelParams',{{}}, ...
    'TestParams',{{'SignalEditorScenario','ab';'TestSequenceScenario','a'}});
verifyError(testCase,@() st_validate_import_iterations(iteration,profile), ...
    'simtest:ImportIterationBinding');
iteration.TestParams{1,2} = 'a';
[inputCount,seqCount] = st_validate_import_iterations(iteration,profile);
verifyEqual(testCase,[inputCount,seqCount],[1,1]);
iteration.Enabled = false;
verifyError(testCase,@() st_validate_import_iterations(iteration,profile), ...
    'simtest:ImportIterationOverride');
end

function testSingleRunDoesNotRequireScenarioParameters(testCase)
profile = struct('ScenarioNames',{{'Iteration 1'}},'HasSignalEditor',false,'UsesScenarios',false);
iteration = struct('Name','Iteration 1','Enabled',true,'Variables',{{}}, ...
    'ModelParams',{{}},'TestParams',{{}});
[a,b] = st_validate_import_iterations(iteration,profile);
verifyEqual(testCase,[a,b],[0,0]);
end

function testPlannerNeverSchedulesGeneratedStagesForImportedRows(testCase)
T = targets(); T = T(1,:);
T = st_resolve_harness_import_settings(T,struct());
T.PreparationMode = "DEFAULT"; T.PreparationFromStage = "DEFAULT";
T.CoverageFilterMode = "OFF"; T.CoverageFilterAction = ""; T.CoverageFilterRationale = "";
cfg = st_config(); cfg.TopModel = 'mdl'; cfg.ModelFile = '';
cfg.WorkflowStateFile = [tempname '.mat']; cfg.SldvManifestFile = [tempname '.mat'];
options = st_parse_workflow_options('PreparationMode','FORCE','FromStage','SLDV');
plan = st_build_execution_plan(T,cfg,'AFTER_HARNESS',options);
verifyFalse(testCase,any([plan.RunSLDV,plan.RunHARNESS_CONFIG, ...
    plan.RunSIGNAL_EDITOR,plan.RunASSESSMENT]));
verifyTrue(testCase,plan.RunHARNESS_IMPORT);
verifyTrue(testCase,plan.RunTEST_MANAGER);
verifyEqual(testCase,plan.TestPreparationSource,"HARNESS_IMPORT");
verifyEqual(testCase,plan.SourceCUTPath,"A/CUT");
verifyEqual(testCase,plan.SourceHarnessName,"source");
end

function T = targets()
T = table([1;2],["CUT";"CUT"],["B/CUT";"C/CUT"], ...
    ["dest_b";"dest_c"],["tc_b";"tc_c"], ...
    ["HARNESS_IMPORT";"HARNESS_IMPORT"],["A/CUT";"A/CUT"], ...
    ["source";"source"],["GENERATE";"GENERATE"],["old.mat";"old.mat"], ...
    ["APPLY";"APPLY"], 'VariableNames', ...
    {'No','CUTName','CUTPath','HarnessName','TestCaseName','TestPreparationSource', ...
    'SourceCUTPath','SourceHarnessName','SldvMode','SldvDataFile','ExpectedUpdateMode'});
end
