function tests = test_result_regeneration
tests = functiontests(localfunctions);
end

function setup(testCase)
testCase.TestData.OriginalPath = path;
addpath(fullfile(st_project_root(),'tests','fixtures'));
[root,cleanup] = st_isolated_toolkit();
testCase.TestData.Cleanup = cleanup;
for name = {'A.slx','A.xlsx'}
    st_atomic_save(fullfile(root,name{1}),struct('Fixture',1));
end
st_save_model_profile('A','ModelFile',fullfile(root,'A.slx'), ...
    'ManagementExcel',fullfile(root,'A.xlsx'),'OutputRoot',fullfile(root,'out'));
cfg = st_select_model_profile('A');
m = fixture(cfg);
testCase.TestData.Cfg = cfg;
testCase.TestData.Manifest = m;
end

function teardown(testCase)
testCase.TestData.Cleanup = [];
path(testCase.TestData.OriginalPath);
end

function testSummaryIsDerivedWithoutModelOrResultLoading(testCase)
cfg = testCase.TestData.Cfg; original = testCase.TestData.Manifest;
sourceFile = fullfile(original.PipelineRoot,'pipeline-manifest.json');
before = st_file_signature(sourceFile);
info = st_regenerate_standalone_results(cfg,original.PipelineId,'SUMMARY');
verifyNotEqual(testCase,info.PipelineId,original.PipelineId);
verifyEqual(testCase,info.LocalExecutionCount,0);
verifyEqual(testCase,st_file_signature(sourceFile).SHA256,before.SHA256);
m = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,info.PipelineId);
verifyEqual(testCase,m.ResultImportCount,0);
verifyEqual(testCase,m.PackageResultSource,'REUSED_PACKAGE');
verifyTrue(testCase,st_regeneration_contract(m));
t = readtable(info.CoverageSummary,'Sheet','CoverageSummary','VariableNamingRule','preserve');
verifyEqual(testCase,width(t),11);
verifyEqual(testCase,t.('Decision Executed'),2);
verifyEqual(testCase,t.('Execution Total'),3);
verifyEqual(testCase,st_file_signature(m.Targets.PackagedStandaloneModel).SHA256, ...
    st_file_signature(original.Targets.PackagedStandaloneModel).SHA256);
% The fixture SLX/MLDATX are intentionally MAT blobs: loading them as
% Simulink models or Test Manager Results would fail this test.
end

function testTamperedPackageBlocksBeforeNewOutput(testCase)
cfg = testCase.TestData.Cfg; original = testCase.TestData.Manifest;
before = dir(cfg.StandaloneCoverageRootDir);
st_atomic_save(original.Targets.PackagedStandaloneModel,struct('Changed',true));
verifyError(testCase,@() st_regenerate_standalone_results(cfg,original.PipelineId,'SUMMARY'), ...
    'simtest:RestartPackageChanged');
after = dir(cfg.StandaloneCoverageRootDir);
verifyEqual(testCase,{after.name},{before.name});
end

function testMissingResultCannotRegeneratePackage(testCase)
cfg = testCase.TestData.Cfg;
verifyError(testCase,@() st_validate_regeneration_source(cfg,'source','PACKAGE'), ...
    'simtest:RestartResultNotSaved');
verifyError(testCase,@() st_validate_regeneration_source(cfg,'LATEST','SUMMARY'), ...
    'simtest:RestartSourceRequired');
end

function testNewExecutionClaimsInvalidateProvenance(testCase)
cfg = testCase.TestData.Cfg;
info = st_regenerate_standalone_results(cfg,'source','SUMMARY');
m = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,info.PipelineId);
m.LocalExecutionCount = 1;
verifyFalse(testCase,st_regeneration_contract(m));
m.LocalExecutionCount = 0; m.Targets.RunCount = 2;
verifyFalse(testCase,st_regeneration_contract(m));
end

function testNotApplicableMetricsAndExceptionStayPartial(testCase)
cfg = testCase.TestData.Cfg; m = testCase.TestData.Manifest;
m.Targets.DecisionCovered = 0; m.Targets.DecisionTotal = 0;
m.Targets.DecisionPercentageText = 'N/A';
m.Targets.ExecutionCovered = []; m.Targets.ExecutionTotal = [];
m.Targets.ExecutionPercentageText = 'N/A';
m.Targets.ExecutionStatus = 'EXCEPT'; m.Targets.PackageStatus = 'FAIL';
m.Actions.EXECUTE.Status = 'WARN'; m.Actions.PACKAGE.Status = 'WARN';
st_write_json_atomic(m.Targets.TargetManifest,m.Targets);
m.PackageInventory = st_package_inventory(m);
st_write_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,m);
latest = st_file_signature(fullfile(cfg.StandaloneCoverageRootDir,'latest.json'));
info = st_regenerate_standalone_results(cfg,'source','SUMMARY');
actual = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,info.PipelineId);
verifyEqual(testCase,actual.Targets.ExecutionStatus,'EXCEPT');
verifyEqual(testCase,actual.Status,'PARTIAL');
verifyEqual(testCase,actual.Targets.DecisionCovered,0);
verifyTrue(testCase,st_regeneration_contract(actual));
verifyEqual(testCase,st_file_signature(fullfile(cfg.StandaloneCoverageRootDir,'latest.json')).SHA256,latest.SHA256);
end

function testLegacyWithoutInventoryCannotRegenerateSummary(testCase)
cfg = testCase.TestData.Cfg; m = testCase.TestData.Manifest;
m.Version = 2; m = rmfield(m,'PackageInventory');
st_write_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,m);
verifyEqual(testCase,st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,'source').Version,2);
verifyError(testCase,@() st_validate_regeneration_source(cfg,'source','SUMMARY'),'simtest:RestartLegacyEvidence');
end

function testDerivedSummaryCanBeRegeneratedAndMetricTamperingRejected(testCase)
cfg = testCase.TestData.Cfg;
first = st_regenerate_standalone_results(cfg,'source','SUMMARY');
second = st_regenerate_standalone_results(cfg,first.PipelineId,'SUMMARY');
m = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,second.PipelineId);
verifyTrue(testCase,st_regeneration_contract(m));
m.Targets.DecisionCovered = 1;
verifyFalse(testCase,st_regeneration_contract(m));
end

function testMissingReplayInputDigestBlocksPackage(testCase)
cfg = testCase.TestData.Cfg; m = testCase.TestData.Manifest;
m.CanResumePackage = true;
m.ResultFile = fullfile(m.PipelineRoot,'saved-result.mldatx');
st_atomic_save(m.ResultFile,struct('Fixture',1));
m.ResultSHA256 = st_file_signature(m.ResultFile).SHA256;
m.TestManagerWorkFile = fullfile(m.PipelineRoot,'execution.mldatx');
m.Targets.StandaloneModelFile = m.Targets.PackagedStandaloneModel;
m.Targets.SignalEditorInput = '';
m.ReplayInputs = struct('Path',m.ResultFile,'SHA256',m.ResultSHA256);
st_write_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,m);
verifyError(testCase,@() st_validate_regeneration_source(cfg,'source','PACKAGE'),'simtest:RestartReplayInputMissing');
end

function m = fixture(cfg)
root = fullfile(cfg.StandaloneCoverageRootDir,'source');
directory = fullfile(root,'001_UT_REQ_tc_A');
mkdir(directory); mkdir(fullfile(root,'TestManager'));
item = struct('No',1,'CUTName','A','CUTPath','A/CUT','TestCaseName','tc_A', ...
    'HarnessName','h_A','StandaloneModel','h_A','StandaloneCUTPath','h_A/CUT', ...
    'ExecutionStatus','PASS','RunCount',1,'ResultFilterAttachCount',1,'FinalOutcome','Passed', ...
    'FilterRestoreStatus','OK','ModelCleanupStatus','OK','PathCleanupStatus','OK', ...
    'IterationSignature','fixture','InputReadbackStatus','OK', ...
    'PackageStatus','OK','SummaryStatus','NOT_RUN','OutputDirectory',directory, ...
    'TargetManifest',fullfile(directory,'target-manifest.json'), ...
    'PackagedStandaloneModel',fullfile(directory,'h_A.slx'),'PackagedInput','', ...
    'PackagedCVF',fullfile(directory,'UT_REQ_tc_A.cvf'), ...
    'CoverageResult',fullfile(directory,'UT_REQ_tc_A.cvt'), ...
    'TestReport',directory,'ReportHTML',fullfile(directory,'UT_REQ_tc_A.html'), ...
    'DecisionCovered',2,'DecisionTotal',2,'DecisionPercentageText','100.00%', ...
    'ExecutionCovered',3,'ExecutionTotal',3,'ExecutionPercentageText','100.00%');
for field = {'PackagedStandaloneModel','PackagedCVF','CoverageResult','ReportHTML'}
    st_atomic_save(item.(field{1}),struct('Fixture',1));
end
st_write_json_atomic(item.TargetManifest,item);
snapshot = struct('Model',st_file_signature(cfg.ModelFile), ...
    'ManagementExcel',st_file_signature(cfg.ManagementExcel));
m = struct('Version',3,'PipelineId','source','PipelineRoot',root,'Action','PACKAGE', ...
    'Status','PARTIAL','CreatedAt','fixture','UpdatedAt','fixture','SourceBefore',snapshot, ...
    'SourceAfter',snapshot,'Targets',item,'TestManagerFile',fullfile(root,'TestManager','A.mldatx'), ...
    'TestManagerLauncher',fullfile(root,'TestManager','open_standalone_coverage_test_manager.m'), ...
    'ExecutionLog',fullfile(root,'execution.log'),'SaveTestResult',false, ...
    'CanResumePackage',false,'ResultFile','','ResultSHA256','','ResultExportCount',0,'ResultImportCount',0, ...
    'PackageResultSource','LIVE','CoverageSummary','','CoverageSummarySHA256','', ...
    'Actions',struct('EXECUTE',action('OK'),'PACKAGE',action('OK'),'SUMMARY',action('NOT_RUN')));
for field = {'TestManagerFile','TestManagerLauncher','ExecutionLog'}
    st_atomic_save(m.(field{1}),struct('Fixture',1));
end
m.PackageInventory = st_package_inventory(m);
st_write_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,m);
end

function value = action(status)
value = struct('Status',status,'Message','','UpdatedAt','fixture');
end
