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
inputs.SIGNAL_EDITOR = st_hash_value(cfg.SignalEditorSampleTime);
inputs.ASSESSMENT = st_hash_value(struct('Outports',cfg.VerifyHarnessOutportsOnly, ...
    'FirstBus',cfg.VerifyFirstBusElementOnly,'AtSample',cfg.VerifyAtSampleTimeOnly, ...
    'Sample',cfg.ExpectedValueSampleTime));
% Of the coverage columns preparation reads only CoverageFilterMode, and
% only with defect tests on: it decides which unreachable outcomes become
% defect iterations. Any other filter change must not rebuild the Test File.
defectInput = "";
if ismember('DefectInputScenario', row.Properties.VariableNames)
    defectInput = row.DefectInputScenario;
end
testManager = struct('File',cfg.TestFile, ...
    'Suite',cfg.TestSuiteName,'Case',char(row.TestCaseName), ...
    'Metrics',cfg.CoverageMetricSettings,'StructuralLevel',cfg.CoverageStructuralLevel, ...
    'Referenced',cfg.CoverageIncludeReferencedModels, ...
    'DefectTests',cfg.UnreachableDefectTests,'DefectInput',char(string(defectInput)));
% Only with defect tests on, so rows with the feature off keep their cache.
if cfg.UnreachableDefectTests
    filterMode = "OFF";
    if ismember('CoverageFilterMode', row.Properties.VariableNames)
        filterMode = row.CoverageFilterMode;
    end
    testManager.CoverageFilterMode = char(string(filterMode));
end
inputs.TEST_MANAGER = st_hash_value(testManager);
inputs.ALIGNMENT = st_hash_value('SCENARIO_BINDINGS_V1');
end
