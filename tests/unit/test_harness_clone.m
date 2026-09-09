function tests = test_harness_clone
tests = functiontests(localfunctions);
end

function testDefaultsPreserveOrdinaryGeneration(testCase)
T = st_resolve_harness_clone_settings(table((1:2).','VariableNames',{'No'}));
verifyEqual(testCase,T.TestPreparationSource,["EXISTING";"EXISTING"]);
verifyFalse(testCase,any(st_is_harness_clone(T)));
cfg = st_config();
verifyFalse(testCase,cfg.OverwriteHarness);
end

function testCloneKeepsIndependentSLDVAndExpectedSettings(testCase)
T = table("harness_clone","TEST_TARGET_MODEL_NAME/A "," Template ", ...
    "FILE","APPLY",'VariableNames',{'TestPreparationSource','SourceCUTPath', ...
    'SourceHarnessName','SldvMode','ExpectedUpdateMode'});
T = st_resolve_harness_clone_settings(T);
verifyTrue(testCase,st_is_harness_clone(T));
verifyEqual(testCase,T.SourceCUTPath,"TEST_TARGET_MODEL_NAME/A ");
verifyEqual(testCase,T.SourceHarnessName,"Template");
verifyEqual(testCase,T.SldvMode,"FILE");
verifyEqual(testCase,T.ExpectedUpdateMode,"APPLY");
end

function testImportRequiresExplicitMigration(testCase)
T = table("HARNESS_IMPORT",'VariableNames',{'TestPreparationSource'});
verifyError(testCase,@() st_resolve_harness_clone_settings(T), ...
    'simtest:HarnessImportRetired');
end

function testScopeRestoresNestedSelectionsAndEmptyMeansNoTargets(testCase)
T = rows();
outer = st_target_scope('enter',T(1,:));
verifyEqual(testCase,st_target_scope('filter',T),T(1,:));
inner = st_target_scope('enter',T(2,:));
verifyEqual(testCase,st_target_scope('filter',T),T(2,:));
clear inner;
verifyEqual(testCase,st_target_scope('filter',T),T(1,:));
empty = st_target_scope('enter',T([],:));
verifyEmpty(testCase,st_target_scope('filter',T));
clear empty outer;
verifyEqual(testCase,st_target_scope('filter',T),T);
end

function testTemplateCannotBeAnotherActiveDestination(testCase)
T = rows();
T = st_resolve_harness_clone_settings(T);
T.TestPreparationSource(2) = "HARNESS_CLONE";
T.SourceCUTPath(2) = T.CUTPath(1);
T.SourceHarnessName(2) = T.HarnessName(1);
cfg = struct('TopModel','TEST_TARGET_MODEL_NAME');
verifyError(testCase,@() st_validate_clone_mapping(T,cfg), ...
    'simtest:CloneTemplateIsTarget');
end

function testScopedManifestKeepsOtherTargetProfiles(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder,'s')); %#ok<NASGU>
cfg = struct('TopModel','TEST_TARGET_MODEL_NAME', ...
    'SldvManifestFile',fullfile(folder,'manifest.mat'));
a = st_empty_sldv_profile();
a.CUTPath = 'TEST_TARGET_MODEL_NAME/A'; a.HarnessName = 'HarnessA';
b = a; b.CUTPath = 'TEST_TARGET_MODEL_NAME/B'; b.HarnessName = 'HarnessB';
manifest = struct('TopModel',cfg.TopModel,'Profiles',[a;b]);
save(cfg.SldvManifestFile,'manifest');
scope = st_target_scope('enter',rows()); %#ok<NASGU>
a.Message = 'updated';
merged = st_merge_scoped_sldv_profiles(a,cfg);
verifyEqual(testCase,numel(merged),2);
verifyEqual(testCase,merged(1),b);
verifyEqual(testCase,merged(2),a);
end

function T = rows()
T = table([1;2],["TEST_TARGET_MODEL_NAME/A";"TEST_TARGET_MODEL_NAME/B"], ...
    ["HarnessA";"HarnessB"],["CaseA";"CaseB"], ...
    'VariableNames',{'No','CUTPath','HarnessName','TestCaseName'});
end
