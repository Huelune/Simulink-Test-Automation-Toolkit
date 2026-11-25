function inputs = st_stage_inputs(row, cfg)
%ST_STAGE_INPUTS Independent policy fingerprints (not downstream file hashes).
inputs = struct();
inputs.HARNESS = st_hash_value(struct('ModelFile',cfg.ModelFile, ...
    'CUTPath',char(row.CUTPath),'HarnessName',char(row.HarnessName)));
source = struct();
if row.SldvMode == "FILE"
    file = char(row.SldvDataFile);
    if ~isfile(file), file = fullfile(fileparts(cfg.ManagementExcel),file); end
    source = st_file_signature(file);
end
testCases = '';
if ismember('SldvTestCases', row.Properties.VariableNames)
    testCases = char(row.SldvTestCases);
end
inputs.SLDV = st_hash_value(struct('Mode',char(row.SldvMode), ...
    'Format',char(row.DataFileFormat),'Variable',char(row.MatVariableName), ...
    'TestCases',testCases, ...
    'Source',source,'Resolution',cfg.SldvTmaxResolution, ...
    'AutoConvertAtomic',cfg.AutoConvertSldvTargetsToAtomic, ...
    'DisableLibraryLink',cfg.DisableLibraryLinkForSldvTargets, ...
    'IgnoreUnexpectedInputs',cfg.IgnoreUnexpectedSldvInputs, ...
    'AllowSubsystemPathMismatch',cfg.AllowSldvSubsystemPathMismatch));
inputs.HARNESS_CONFIG = st_hash_value(cfg.HarnessStopTime);
% Of the coverage columns preparation reads only CoverageFilterMode, and
% only with defect tests on: it decides which unreachable outcomes become
% defect iterations. Any other filter change must not rebuild the Test File.
defectInput = "";
if ismember('DefectInputScenario', row.Properties.VariableNames)
    defectInput = row.DefectInputScenario;
end
% Each defect iteration has a Signal Editor and a Test Sequence scenario of
% its own (st_get_sldv_profile), so what decides the defects is an input of
% those two stages as well.
defects = struct('DefectTests',cfg.UnreachableDefectTests, ...
    'DefectInput',char(string(defectInput)));
if cfg.UnreachableDefectTests
    defects.CoverageFilterMode = char(string(filter_mode(row)));
end
inputs.SIGNAL_EDITOR = st_hash_value(struct( ...
    'SampleTime',cfg.SignalEditorSampleTime,'Defects',defects));
inputs.ASSESSMENT = st_hash_value(struct('Outports',cfg.VerifyHarnessOutportsOnly, ...
    'FirstBus',cfg.VerifyFirstBusElementOnly,'AtSample',cfg.VerifyAtSampleTimeOnly, ...
    'Sample',cfg.ExpectedValueSampleTime,'Defects',defects));
testManager = struct('File',cfg.TestFile, ...
    'Suite',cfg.TestSuiteName,'Case',char(row.TestCaseName), ...
    'Metrics',cfg.CoverageMetricSettings,'StructuralLevel',cfg.CoverageStructuralLevel, ...
    'Referenced',cfg.CoverageIncludeReferencedModels, ...
    'DefectTests',cfg.UnreachableDefectTests,'DefectInput',char(string(defectInput)));
% Only with defect tests on, so rows with the feature off keep their cache.
if cfg.UnreachableDefectTests
    testManager.CoverageFilterMode = char(string(filter_mode(row)));
end
inputs.TEST_MANAGER = st_hash_value(testManager);
inputs.ALIGNMENT = st_hash_value('SCENARIO_BINDINGS_V1');
end


function mode = filter_mode(row)
mode = "OFF";
if ismember('CoverageFilterMode', row.Properties.VariableNames)
    mode = row.CoverageFilterMode;
end
end
