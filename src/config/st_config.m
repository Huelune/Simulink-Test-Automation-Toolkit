function cfg = st_config()
%ST_CONFIG Common settings for Simulink Test automation.
% Edit this file first.

rootDir = st_project_root();


%% ============================================================
% Runtime target model
%% ============================================================

cfg.RuntimeTargetFile = ...
    fullfile(rootDir, 'runtime_target.mat');

cfg.TopModel = ...
    'TEST_TARGET_MODEL_NAME';

cfg.ModelFile = '';
cfg.HasRuntimeTarget = false;

if isfile(cfg.RuntimeTargetFile)

    S = load(cfg.RuntimeTargetFile);

    if isfield(S, 'TopModel') && ...
            isfield(S, 'ModelFile')

        topModel = ...
            strtrim(char(string(S.TopModel)));

        modelFile = ...
            strtrim(char(string(S.ModelFile)));

        if ~isempty(topModel) && ...
                ~isempty(modelFile)

            cfg.TopModel = topModel;
            cfg.ModelFile = modelFile;
            cfg.HasRuntimeTarget = true;
        end
    end
end


%% ============================================================
% Target model / CUT path finder
%% ============================================================

% Default assumes this automation folder is placed one level below
% the folder that contains the target Simulink model(s).
% Change this when the model files live elsewhere.
cfg.ModelSearchRoot = ...
    fileparts(rootDir);

% true  : search subfolders recursively
% false : search only ModelSearchRoot
cfg.ModelSearchRecursive = true;

% Folder names ignored while searching for .slx / .mdl files.
cfg.ModelSearchExcludeFolders = { ...
    '.git', ...
    'slprj', ...
    'result'};

% Number of nearby resolved CUT paths used when ranking duplicated CUTs.
% Multiple nearby paths are also used to derive a stable context root.
cfg.PathFinderAnchorCount = 5;

% Number of physical Excel rows shown above/below the current CUT in the
% duplicate-selection dialog.
cfg.PathFinderExcelContextRows = 3;

% true:
%   After choosing a duplicated CUT candidate, open/highlight it in Simulink
%   and ask for confirmation before the path is accepted.
% false:
%   Do not move/highlight the Simulink model. Accept the selected candidate
%   directly from the ranked list.
cfg.PathFinderHighlightSelection = false;


%% ============================================================
% Model subsystem inventory export
%% ============================================================

% Sheet used by st_export_subsystem_paths.
% The sheet is recreated whenever the inventory is exported.
cfg.SubsystemInventorySheet = 'ModelSubsystems';

% CUTName cell text remains the exact Subsystem name.
% Visual hierarchy is shown with the Excel cell IndentLevel property.
%
% Excel supports a limited indentation level. Actual hierarchy depth is
% always preserved separately in the Depth column even when the visual
% indentation reaches this maximum.
cfg.SubsystemInventoryMaxIndent = 15;


%% ============================================================
% Temporary CUTPath generation from Excel native indentation
%% ============================================================

% false:
%   Preserve non-empty/manual CUTPath cells and fill blank CUTPath only.
%
% true:
%   Replace existing CUTPath cells whenever st_fill_temp_paths_from_indent
%   is executed. You can also override this per call with true/false.
%
% The hierarchy source is CUTName cell IndentLevel, not a numeric Depth
% column and not leading space characters in the cell value.
cfg.IndentPathOverwriteExisting = false;

% Result sheet written by st_fill_temp_paths_from_indent.
cfg.IndentPathResultSheet = 'IndentPathResult';


%% ============================================================
% Management Excel
%% ============================================================

cfg.ManagementExcel = ...
    fullfile(rootDir, 'TestManagement.xlsx');

cfg.ManagementSheet = 'Targets';


%% ============================================================
% Simulink Design Verifier
%% ============================================================

% Per-row SLDV preparation writes a manifest here. Later workflow stages
% use the manifest so GENERATE analysis runs only once per automation run.
cfg.SldvDir = ...
    fullfile(rootDir, 'result', 'sldv');

cfg.SldvManifestFile = ...
    fullfile(cfg.SldvDir, 'sldv_manifest.mat');

% Round each CUT-level SLDV Tmax upward to this time grid. This absorbs
% floating-point tails such as 1.060000001 without ever ending a Harness
% before the source TestCase does. Set to [] to preserve raw end times.
cfg.SldvTmaxResolution = 0.01;

% true (default):
%   Before FILE validation or GENERATE execution, convert a non-atomic SLDV
%   target Subsystem to TreatAsAtomicUnit=on and keep that model change.
%   The normal workflow saves the model during Harness configuration.
%
% false:
%   Require every FILE/GENERATE target to already be atomic.
cfg.AutoConvertSldvTargetsToAtomic = true;

% false (default):
%   Fail when an SLDV Dataset contains input signals that are not present
%   in the target Harness Signal Editor ActiveScenario.
%
% true:
%   Ignore those unexpected SLDV input signals. Only signals that also
%   exist in the Harness input interface are copied into generated
%   Signal Editor scenarios. Ignored names are recorded in the SLDV
%   preparation result and manifest.
cfg.IgnoreUnexpectedSldvInputs = false;

% true:
%   Open every registered Harness before SLDV configuration and fail when
%   multiple Harnesses use the same Signal Editor MAT file.
%
% false (default):
%   Skip the repository-wide ownership scan. This avoids loading and
%   closing every Harness, which can be slow with SyncOnOpenAndClose.
%   Enable the check when Signal Editor MAT files may be shared between
%   Harnesses; otherwise later SLDV scenario writes can conflict.
cfg.CheckSharedSignalEditorDataFile = false;


%% ============================================================
% Harness
%% ============================================================

cfg.HarnessStopTime = '0.01';


%% ============================================================
% Signal Editor
%% ============================================================

cfg.SignalEditorSampleTime = '0.01';


%% ============================================================
% Assessment - Verify target
%% ============================================================

% true:
%   Verify only Test Assessment Input symbols that correspond to
%   top-level Harness Outport signals.
%
% false:
%   Verify every Input Data Symbol registered in Test Assessment.
cfg.VerifyHarnessOutportsOnly = true;


%% ============================================================
% Assessment - Bus array handling
%% ============================================================

% true:
%   When the same Bus structure is repeated as an array, verify only
%   the first Bus instance.
%
% Example:
%   a(1,1).aa
%   a(1,1).ab
%
% false:
%   Verify every Bus array element.
%
% Numeric arrays inside a Bus leaf are still verified completely.
cfg.VerifyFirstBusElementOnly = true;


%% ============================================================
% Assessment - Verify timing
%% ============================================================

% false:
%   step1 -> step2 transition = true
%
% true:
%   step1 -> step2 transition = after(ExpectedValueSampleTime, sec)
%
% When true, HarnessStopTime should normally be greater than
% ExpectedValueSampleTime.
cfg.VerifyAtSampleTimeOnly = false;


%% ============================================================
% Test Manager
%% ============================================================

cfg.TestFile = ...
    fullfile(rootDir, [cfg.TopModel '.mldatx']);

cfg.TestSuiteName = ...
    'New Test Suite 1';

% false (default):
%   Incremental update.
%   - Preserve the existing .mldatx file and existing Test Cases.
%   - Reuse the Test File when it is already open.
%   - Add only Excel TestCaseName values that do not already exist
%     in cfg.TestSuiteName.
%
% true:
%   Full recreation.
%   - Close the target Test File if it is already open.
%   - Overwrite the .mldatx file.
%   - Recreate Test Cases from Excel.
cfg.OverwriteTestFile = false;


%% ============================================================
% Test execution
%% ============================================================

% true  : Run all generated Enabled Test Cases after Test Manager creation.
% false : Stop after Test Manager creation.
cfg.RunGeneratedTests = true;


%% ============================================================
% Incremental preparation
%% ============================================================

% AUTO:
%   Reuse successful preparation stages while their inputs and artifacts
%   still match the last checkpoint.
% FORCE:
%   Reapply the selected stage and all downstream preparation stages.
cfg.PreparationMode = 'AUTO';

% Earliest stage used by FORCE. START resolves to HARNESS for the full
% workflow and SLDV for the existing-Harness workflow.
cfg.PreparationFromStage = 'START';

cfg.WorkflowStateFile = ...
    fullfile(rootDir, 'result', 'state', 'workflow_state.mat');

cfg.WorkflowStateSummaryFile = ...
    fullfile(rootDir, 'result', 'state', 'workflow_state.json');


%% ============================================================
% Expected value update
%% ============================================================

% Global default when TestManagement.xlsx does not override the mode.
%
% 'OFF':
%   Never modify verify expected values after a failed test.
%
% 'APPLY':
%   Read the actual Harness Outport value after a failed test and update
%   the RHS of verify(... == RHS). Use this only when regenerating an
%   expected value is intentional.
%
% The optional Targets.ExpectedUpdateMode column can override this value
% per row with DEFAULT, OFF, or APPLY. DEFAULT uses this global setting.
cfg.ExpectedUpdateMode = 'APPLY';

% Simulation time used as the expected-value sample point [sec].
cfg.ExpectedValueSampleTime = 0.01;

% Run the Test File again after APPLY updates at least one expected value.
cfg.RerunAfterExpectedUpdate = true;


%% ============================================================
% Coverage and integrated reporting
%% ============================================================

% Decision includes Block Execution coverage. Test Manager stores the
% equivalent legacy metric setting in the Test File for R2025b support.
cfg.CoverageStructuralLevel = 'Decision';
cfg.CoverageMetricSettings = 'dwe';
cfg.CoverageIncludeReferencedModels = false;

cfg.GenerateTestReport = true;
cfg.TestRunRootDir = ...
    fullfile(rootDir, 'result', 'runs');
cfg.LatestReportPointer = ...
    fullfile(rootDir, 'result', 'latest.json');
cfg.LatestSummaryFile = ...
    fullfile(rootDir, 'result', 'TestSummary.xlsx');

% Standalone command st_export_test_bundle writes reproducible bundles here.
% This setting is not used by either normal workflow entry point.
cfg.ExportRootDir = ...
    fullfile(rootDir, 'result', 'exports');

% Standalone verification runs and latest pointers are stored separately
% from normal workflow reports. QUICK inspections never write elsewhere.
cfg.VerificationRootDir = ...
    fullfile(rootDir, 'result', 'verification');


%% ============================================================
% Execution
%% ============================================================

% If Enabled exists in TestManagement.xlsx:
% true  -> process Enabled rows only
% false -> process all rows
cfg.OnlyEnabled = true;


%% ============================================================
% Progress / diagnostic logging
%% ============================================================

% true:
%   Print detailed timestamped checkpoints around long-running operations.
%   Useful for identifying the exact API call MATLAB is currently waiting on.
%
% false:
%   Suppress detailed INFO / DEBUG / TRACE logs.
%   Existing normal START / OK / FAIL / summary messages are still printed.
cfg.VerboseLogging = true;


%% ============================================================
% Result
%% ============================================================

cfg.ResultDir = ...
    fullfile(rootDir, 'result');

% TestManagement.xlsx is an input-only management file during the normal
% workflow. Result tables are written as standalone INI reports instead.
% Set false when no result files should be created.
cfg.SaveResultFiles = true;

cfg.ResultReportDir = ...
    fullfile(cfg.ResultDir, 'reports');

end
