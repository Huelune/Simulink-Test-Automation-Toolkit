function cfg = st_config()
%ST_CONFIG Common settings for Simulink Test automation.
% Edit repository-wide defaults here. Select the local target model with
% st_select_target_model; do not place a model name in this tracked file.

rootDir = st_project_root();


%% ============================================================
% Runtime target model
%% ============================================================

cfg.RuntimeTargetFile = ...
    fullfile(rootDir, 'runtime_target.mat');

% Model identity is intentionally local and untracked. It is populated only
% from runtime_target.mat, which st_select_target_model creates.
cfg.TopModel = '';
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
%   Before FILE+SLDV validation or GENERATE execution, convert a non-atomic
%   unlinked target Subsystem to TreatAsAtomicUnit=on and keep that model
%   change. Library-linked CUTs are never modified automatically. Ordinary
%   FILE+MAT inputs do not require atomic conversion.
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

% true (temporary compatibility mode):
%   Continue FILE+SLDV preparation when the source MAT was generated for a
%   different subsystem path. The mismatch is logged as WARN; Harness input
%   interface validation still applies before scenarios are configured.
%
% false:
%   Reject an SLDV MAT whose ModelInformation.SubsystemPath differs from the
%   configured CUT path.
cfg.AllowSldvSubsystemPathMismatch = true;

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

% Replace existing clone destinations only after a recovery clone is saved.
cfg.OverwriteHarness = false;


%% ============================================================
% Test execution
%% ============================================================

% true  : Run all generated Enabled Test Cases after Test Manager creation.
% false : Stop after Test Manager creation.
cfg.RunGeneratedTests = true;

% How the tests run. The caller decides; nothing in the workbook does.
%
% PER_CUT : run(tc) per Test Case, in Excel order. The default. Every Test
%           Case runs alone, so one cannot disturb another, an
%           expected-value update reruns only that Test Case, and each CUT
%           gets its own result folder. The run saves one ResultSet per CUT
%           and leaves the artifacts to cfg.PerCutResultCollection.
% BATCH   : one run(tf) for every enabled Test Case. Faster, and it ends
%           with a single integrated report.
%
% Coverage filters no longer affect this choice: they are applied when the
% artifacts are built, not while the tests run.
cfg.ExecutionMode = 'PER_CUT';

% Per-CUT execution continues after a Test Case/report failure only when
% the transient coverage filter was restored and verified successfully.
cfg.PerCutContinueOnFailure = true;
cfg.PerCutReportMode = 'SUMMARY';
% Test verdicts remain in FinalOutcome. Runner/report exceptions are logged,
% recorded in the manifest, and skipped by default so later CUTs can run.
cfg.PerCutFailOnNonPass = false;

% PER_CUT exists so a Test Case that only works alone can run alone. The
% coverage filter is not part of running: it shapes the coverage data of the
% artifacts built from a run. DEFERRED runs each Test Case unfiltered, saves
% its ResultSet, and leaves the CVF and the reports to
% st_collect_per_cut_results. INLINE restores the old behaviour of doing all
% of it inside the run.
cfg.PerCutResultCollection = 'DEFERRED';

% Collect the run the workflow just produced, as its last step.
%
% false (default):
%   The run saves each ResultSet and stops. Build the CVFs and the per-CUT
%   reports afterwards with st_collect_per_cut_results, in this session or
%   in another one. Long runs stay interruptible this way.
%
% true:
%   One command ends with the reports in place. Collecting reopens the
%   models the saved coverage data points at, so the workflow returns later
%   and a collect failure fails the workflow.
%
% Only a DEFERRED run has anything to collect.
cfg.PerCutAutoCollect = false;


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

% Integrated report: build each CUT's coverage rows only from the coverage
% objects whose metadata identifies that CUT.
%
% false (default):
%   Every CUT row is built from every coverage object in the ResultSet.
%   decisioninfo/executioninfo then walk a cross-product, and that walk is
%   the slowest part of st_generate_test_report on a large workbook.
%
% true:
%   st_match_coverage_descriptors selects the objects that belong to the
%   CUT - the rule st_export_result_set_report and the PER_CUT metrics
%   already use. Much faster, and a CUT row stops carrying other CUTs'
%   objects, so the reported numbers can move.
%
% Changing this changes what the report counts, not just how long it takes.
% Compare one report against an existing TestSummary.xlsx before adopting
% it. Only st_generate_test_report reads this; the other coverage readers
% match unconditionally.
cfg.ReportMatchCoverageObjects = false;


% PER_CUT existing-filter policy:
%   REPLACE: temporarily clear Test File, Suite, and Test Case CVFs and
%            register only the newly generated CVF for the isolated run.
%            Restore original settings afterward.
%   MERGE:   combine existing CVFs with the generated Test Case CVF.
cfg.CoverageFilterExistingPolicy = 'REPLACE';

% Generated CVF files are toolkit-owned artifacts. Files outside this
% directory are treated as manual filters and are never removed.
cfg.CoverageFilterDir = ...
    fullfile(rootDir, 'result', 'coverage_filters');

% Running the tests and collecting the results are separate steps. The run
% saves a record of itself either way, so the integrated report can be built
% afterwards with st_generate_test_report('RunRecord','LATEST'). Set this to
% true to have the workflow build it immediately instead.
cfg.GenerateTestReport = false;

% One saved run per directory: the INITIAL/FINAL ResultSets plus the tables
% the report needs. A ResultSet only exists inside a Test Manager session,
% so without this the report could never be produced later.
cfg.RunRecordRootDir = ...
    fullfile(rootDir, 'result', 'run_records');
cfg.LatestRunRecordPointer = ...
    fullfile(rootDir, 'result', 'run_record_latest.json');

cfg.TestRunRootDir = ...
    fullfile(rootDir, 'result', 'runs');
cfg.LatestReportPointer = ...
    fullfile(rootDir, 'result', 'latest.json');
cfg.LatestSummaryFile = ...
    fullfile(rootDir, 'result', 'TestSummary.xlsx');

cfg.PerCutRunRootDir = ...
    fullfile(rootDir, 'result', 'per_cut_runs');
cfg.PerCutLatestPointer = ...
    fullfile(rootDir, 'result', 'per_cut_latest.json');

% Standalone command st_export_test_bundle writes reproducible bundles here.
% This setting is not used by either normal workflow entry point.
cfg.ExportRootDir = ...
    fullfile(rootDir, 'result', 'exports');

% Resumable standalone Harness coverage pipelines are isolated from normal
% export bundles and PER_CUT reports. A deeply nested repository checkout
% combined with this pipeline's own nested export folders can exceed the
% Windows 260-character MAX_PATH limit, so a local, untracked override is
% read from runtime_target.mat when present (set it with
% st_set_standalone_coverage_root, for example to a short path on another
% drive). The tracked default stays under the repository.
cfg.StandaloneCoverageRootDir = ...
    fullfile(rootDir, 'result', 'standalone_coverage');

if isfile(cfg.RuntimeTargetFile)

    standaloneOverride = load(cfg.RuntimeTargetFile);

    if isfield(standaloneOverride, 'StandaloneCoverageRootDir')

        overrideDir = ...
            strtrim(char(string( ...
                standaloneOverride.StandaloneCoverageRootDir)));

        if ~isempty(overrideDir)
            cfg.StandaloneCoverageRootDir = overrideDir;
        end
    end
end

% Where the standalone pipeline's bundle runner lets Simulink build. The
% execution workspace is already ~150 characters deep, and Stateflow
% simulation targets nest slprj/_sfprj/<Harness>/... below pwd, so building
% there fails on Windows before any coverage is recorded. Empty (default)
% builds under tempdir; set a short path such as 'D:\stt_build' to keep the
% build on a specific drive. Each execution gets its own subfolder and
% removes it when the run ends.
cfg.StandaloneBuildCacheDir = '';

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
% Test specification export
%% ============================================================

% How much of the DecisionBlocks inventory st_export_test_specification
% writes. Override per run with
% st_export_test_specification('DecisionBlockScope','ALL').
%
% 'EXPLICIT':
%   Only blocks that carry a condition in their dialog, that is If, Switch,
%   MinMax, Multiport Switch and Switch Case. The shortest list.
%
% 'ALL':
%   Also the blocks that create Simulink Coverage objectives without
%   carrying a condition: Saturate, Abs, Dead Zone, Rate Limiter, Relay,
%   the lookup table family, the integrators, the iterators and Logical
%   Operator. Use this to explain Decision coverage reported for a model
%   that contains no If or Switch block at all. The column gets much
%   longer, and a lookup table heavy CUT can push the cell into the
%   OverflowDetails sheet.
%
% 'NONE':
%   Leave the DecisionBlocks column empty and skip the scan.
%
% The scanned types for each level are defined in
% src/exporting/st_specification_decision_catalog.m.
cfg.DecisionBlockScope = 'EXPLICIT';


%% ============================================================
% Final document export
%% ============================================================

% st_export_final_document collects the customer submission workbook. It
% reads the specification rows from the saved model again and takes only
% the verdicts and the coverage from earlier result files. Override any of
% these per run, for example
% st_export_final_document('ResultRun','BATCH').

% Which executed run the per-iteration verdicts are read from.
%
% 'AUTO':
%   Compare result/latest.json and result/per_cut_latest.json and read
%   whichever was updated last. The chosen run is written to the Metadata
%   sheet.
%
% 'BATCH':
%   The run that st_generate_test_report last reported.
%
% 'PER_CUT':
%   The run that st_collect_per_cut_results last collected.
%
% A run directory path is also accepted. BATCH and PER_CUT fail when that
% history is missing, because an explicit choice must not silently fall
% back to the other mode.
%
% result/TestSummary.xlsx is never read. That copy is refreshed by BATCH
% only, so after a PER_CUT run it holds the previous BATCH numbers.
cfg.FinalDocumentResultRun = 'AUTO';

% Where the coverage sheet gets its numbers.
%
% 'STANDALONE':
%   CoverageSummary.xlsx of the latest standalone pipeline run. This is a
%   separate execution from the one the verdicts come from: it swaps in
%   standalone models and forces expected-value updates off, so its
%   pass/fail can differ. Only its coverage is used, and both run
%   identities are recorded in the Metadata sheet.
%
% 'TEST_RUN':
%   The Coverage sheet of the resolved run, FINAL rows.
%
% 'NONE':
%   Leave every coverage value as N/A.
cfg.FinalDocumentCoverageSource = 'STANDALONE';

% true:
%   Append the internal command list as a 사용법 sheet. Off by default
%   because a list of st_* commands does not belong in a customer file.
cfg.FinalDocumentIncludeUsageSheet = false;

% What an unavailable value is written as. The standalone pipeline already
% writes N/A, so both files read the same.
cfg.FinalDocumentNAText = 'N/A';


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

% Simulink warning identifiers to suppress while the toolkit drives a
% long API loop. Each entry is reported once through st_log and restored
% afterwards, so the information survives without flooding the console.
% Collect the identifiers for your model with
% diagnostics/matlab/st_collect_warning_ids.m; leave empty to suppress none.
cfg.SuppressedWarnings = {};


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
