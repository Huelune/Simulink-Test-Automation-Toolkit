function [results, updates, summary] = st_run_tests_per_cut(varargin)
%ST_RUN_TESTS_PER_CUT Execute enabled Test Cases sequentially with CVF isolation.
%
% [results, updates, summary] = st_run_tests_per_cut( ...
%     'ContinueOnFailure', true, ...
%     'ReportMode', 'SUMMARY', ...
%     'FailOnNonPass', false, ...
%     'ResultFilterMode', 'DURING_RUN', ...
%     'LoadRuntimeModel', true)

p = inputParser;
p.FunctionName = 'st_run_tests_per_cut';
addParameter(p, 'ContinueOnFailure', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'ReportMode', 'SUMMARY', ...
    @(x) ismember(upper(string(x)), ["SUMMARY","FULL"]));
addParameter(p, 'FailOnNonPass', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'ResultFilterMode', 'DURING_RUN', ...
    @(x) ismember(upper(string(x)), ...
    ["DURING_RUN","POST_RUN_REQUIRED"]));
addParameter(p, 'TargetConfig', [], @(x) isempty(x) || istable(x));
addParameter(p, 'TestFile', [], @(x) true);
addParameter(p, 'TestCases', [], @(x) true);
addParameter(p, 'RunRootDirectory', '', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'GenerateResultArtifacts', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'WriteRunSummaryExcel', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'SaveTestResult', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'ResultFile', '', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'CapturePackageEvidence', false, ...
    @(x) islogical(x) && isscalar(x));
% Standalone exported bundles rewire Test Cases to disposable Harness
% models.  They must not load cfg.TopModel solely to read runtime config,
% because that would reintroduce unrelated whole-model dependencies.
addParameter(p, 'LoadRuntimeModel', true, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

continueOnFailure = logical(p.Results.ContinueOnFailure);
reportMode = upper(char(string(p.Results.ReportMode)));
failOnNonPass = logical(p.Results.FailOnNonPass);
resultFilterMode = upper(char(string(p.Results.ResultFilterMode)));
applyManagedFiltersDuringRun = strcmp(resultFilterMode, 'DURING_RUN');
generateResultArtifacts = logical(p.Results.GenerateResultArtifacts);
writeRunSummaryExcel = logical(p.Results.WriteRunSummaryExcel);
saveTestResult = logical(p.Results.SaveTestResult);
resultFile = strtrim(char(string(p.Results.ResultFile)));
capturePackageEvidence = logical(p.Results.CapturePackageEvidence);
loadRuntimeModel = logical(p.Results.LoadRuntimeModel);
if saveTestResult && isempty(resultFile)
    error('simtest:PerCutResultFileRequired', ...
        'ResultFile is required when SaveTestResult=true.');
end

cfg = st_require_runtime_target('LoadModel', loadRuntimeModel);
existingFilterPolicy = st_coverage_filter_existing_policy( ...
    cfg.CoverageFilterExistingPolicy);
if ~strcmp(st_coverage_filter_application_mode( ...
        cfg.CoverageFilterApplicationMode), 'RUNTIME')
    error('simtest:PerCutRequiresTransientFilters', ...
        ['PER_CUT execution always uses transient filters. Set ' ...
         'cfg.CoverageFilterApplicationMode to RUNTIME.']);
end
if ~isfile(cfg.TestFile)
    error('simtest:TestFileNotFound', ...
        'Test File not found: %s', cfg.TestFile);
end

if isempty(p.Results.TargetConfig)
    targetConfig = st_load_targets(cfg.OnlyEnabled);
else
    targetConfig = p.Results.TargetConfig;
end
if isempty(p.Results.TestFile)
    tf = sltest.testmanager.TestFile(cfg.TestFile);
else
    tf = p.Results.TestFile;
end
if isempty(p.Results.TestCases)
    [testCases, runScope] = st_get_run_test_cases(tf);
else
    testCases = p.Results.TestCases;
    runScope = table(double(targetConfig.No), ...
        string(targetConfig.TestCaseName), true(height(targetConfig),1), ...
        'VariableNames', {'No','TestCaseName','WillRun'});
end
n = height(targetConfig);
if numel(testCases) ~= n
    error('simtest:PerCutTargetMappingFailed', ...
        'Enabled target count and resolved Test Case count differ.');
end

runRootDirectory = strtrim(char(string(p.Results.RunRootDirectory)));
if isempty(runRootDirectory)
    runRootDirectory = cfg.PerCutRunRootDir;
end
[runId, runDirectory] = create_run_directory(runRootDirectory);
mkdir(fullfile(runDirectory, 'targets'));
mkdir(fullfile(runDirectory, 'logs'));
logPath = fullfile(runDirectory, 'logs', 'execution.log');
startedAt = timestamp_text();

results = repmat(struct( ...
    'No', NaN, 'TestCaseName', '', 'InitialResult', [], ...
    'FinalResult', [], 'RerunPerformed', false), n, 1);
updates = table();
coverage = table();
artifacts = empty_artifact_table();

No = double(targetConfig.No);
CUTName = string(targetConfig.CUTName);
CUTPath = string(targetConfig.CUTPath);
ExecutionModel = strings(n,1);
if ismember('ExecutionModel', targetConfig.Properties.VariableNames)
    ExecutionModel = string(targetConfig.ExecutionModel);
end
StandaloneCUTPath = strings(n,1);
if ismember('StandaloneCUTPath', targetConfig.Properties.VariableNames)
    StandaloneCUTPath = string(targetConfig.StandaloneCUTPath);
end
TestCaseName = string(targetConfig.TestCaseName);
FilterMode = string(targetConfig.CoverageFilterMode);
BoundaryMode = repmat("OFF", n, 1);
if ismember('CoverageBoundaryMode', targetConfig.Properties.VariableNames)
    BoundaryMode = string(targetConfig.CoverageBoundaryMode);
end
FilterAction = string(targetConfig.CoverageFilterAction);
FilterRationale = string(targetConfig.CoverageFilterRationale);
ExistingFilterPolicy = repmat(string(existingFilterPolicy), n, 1);
ResultFilterMode = repmat(string(resultFilterMode), n, 1);
if applyManagedFiltersDuringRun
    managedApplication = "DURING_RUN";
else
    managedApplication = "RESULT_POST_RUN";
end
ManagedFilterApplication = repmat(managedApplication, n, 1);
CVFPath = strings(n,1);
CVFSHA256 = strings(n,1);
CVFRuleCount = zeros(n,1);
FilterGenerationStatus = repmat("OFF", n, 1);
RunCount = zeros(n,1);
ResultFilterAttachCount = zeros(n,1);
InitialOutcome = repmat("NOT_RUN", n, 1);
FinalOutcome = repmat("NOT_RUN", n, 1);
InitialReport = strings(n,1);
FinalReport = strings(n,1);
RerunPerformed = false(n,1);
ExpectedUpdatedCount = zeros(n,1);
FilterApplyStatus = repmat("NOT_RUN", n, 1);
ResultFilterStatus = repmat("NOT_REQUIRED", n, 1);
FilterRestoreStatus = repmat("NOT_RUN", n, 1);
ModelCleanupStatus = repmat("NOT_RUN", n, 1);
PathCleanupStatus = repmat("NOT_RUN", n, 1);
Status = repmat("FAIL", n, 1);
Message = strings(n,1);
DurationSec = zeros(n,1);
StartedAt = strings(n,1);
CompletedAt = strings(n,1);
TargetManifest = strings(n,1);
PackageEvidence = strings(n,1);
PackageEvidenceSHA256 = strings(n,1);
if capturePackageEvidence
    PackageEvidenceStatus = repmat("NOT_RUN", n, 1);
else
    PackageEvidenceStatus = repmat("NOT_REQUIRED", n, 1);
end

abortError = [];
for i = 1:n
    rowTimer = tic;
    StartedAt(i) = timestamp_text();
    row = targetConfig(i,:);
    tc = testCases(i);
    targetDirectory = st_per_cut_target_directory(runDirectory, row);
    initialDirectory = fullfile(targetDirectory, 'initial');
    finalDirectory = fullfile(targetDirectory, 'final');
    filterDirectory = fullfile(targetDirectory, 'filter');
    manifestPath = fullfile(targetDirectory, 'target-manifest.json');
    TargetManifest(i) = string(manifestPath);
    mkdir(targetDirectory);

    session = [];
    sessionCreated = false;
    applyStarted = false;
    restoreSucceeded = false;
    initialInfo = struct();
    finalInfo = struct();
    targetError = [];
    modelPathCleanup = register_execution_model_folder(row, cfg); %#ok<NASGU>

    st_log(cfg, 'INFO', ...
        '[PER_CUT %d/%d] start | No=%g | CUT=%s | TestCase=%s | CVF=%s', ...
        i, n, No(i), char(CUTName(i)), char(TestCaseName(i)), ...
        char(FilterMode(i)));
    append_event(logPath, i, 'TARGET_START', char(TestCaseName(i)));

    try
        if row.ExpectedUpdateMode == "APPLY"
            st_prepare_expected_value_logging_for_targets(cfg, tf, row);
        end

        filterFile = "";
        if applyManagedFiltersDuringRun && st_coverage_filter_active(row)
            FilterGenerationStatus(i) = "STARTED";
            [filterFile, generationStatus, ruleCount, filterHash] = ...
                generate_filter(row, filterDirectory, cfg, logPath, i, true);
            FilterGenerationStatus(i) = generationStatus;
            CVFRuleCount(i) = ruleCount;
            CVFPath(i) = filterFile;
            CVFSHA256(i) = filterHash;
        end

        applyStarted = true;
        FilterApplyStatus(i) = "STARTED";
        append_event(logPath, i, 'APPLY_START', char(CVFPath(i)));
        [filterCleanup, applyResult, session] = ...
            st_apply_test_case_coverage_filters( ...
                tf, tc, row, cfg, 'FilterFiles', filterFile, ...
                'ExistingFilterPolicy', ...
                existingFilterPolicy, ...
                'ApplyManagedFiltersDuringRun', ...
                applyManagedFiltersDuringRun); %#ok<NASGU>
        sessionCreated = true;
        FilterApplyStatus(i) = string(applyResult.Status(1));
        append_event(logPath, i, 'APPLY_DONE', ...
            char(FilterApplyStatus(i)));
        if any(applyResult.Status == "FAIL") || ...
                (applyManagedFiltersDuringRun && ...
                st_coverage_filter_active(row) && ...
                strlength(string(applyResult.FilterFile(1))) == 0)
            error('simtest:PerCutCoverageFilterApplyFailed', ...
                'The generated CVF was not applied to %s.', ...
                char(TestCaseName(i)));
        end
        st_log(cfg, 'DEBUG', ...
            '[PER_CUT %d/%d] run(testCase) initial start', i, n);
        append_event(logPath, i, 'RUN_START', char(TestCaseName(i)));
        append_event(logPath, i, 'RUN_INITIAL_START', char(TestCaseName(i)));
        initialResult = run(tc);
        RunCount(i) = RunCount(i) + 1;
        append_event(logPath, i, 'RUN_INITIAL_DONE', char(TestCaseName(i)));
        append_event(logPath, i, 'RUN_DONE', char(TestCaseName(i)));
        st_log(cfg, 'DEBUG', ...
            ['[PER_CUT %d/%d] run(testCase) initial complete | ' ...
             'CVF managed by Test Manager=%s'], ...
            i, n, char(CVFPath(i)));
        append_event(logPath, i, 'RESULT_FILTER_MANAGED', ...
            char(CVFPath(i)));
        results(i).No = No(i);
        results(i).TestCaseName = char(TestCaseName(i));
        results(i).InitialResult = initialResult;
        results(i).FinalResult = initialResult;
        InitialOutcome(i) = result_outcome(initialResult, row, 'INITIAL');
        FinalOutcome(i) = InitialOutcome(i);
        validate_verify_timing(initialResult, 'initial', row);
        if ~applyManagedFiltersDuringRun && ...
                st_coverage_filter_active(row)
            FilterGenerationStatus(i) = "STARTED";
            [filterFile, generationStatus, ruleCount, filterHash] = ...
                generate_filter(row, filterDirectory, cfg, logPath, i, false);
            FilterGenerationStatus(i) = generationStatus;
            CVFRuleCount(i) = ruleCount;
            CVFPath(i) = filterFile;
            CVFSHA256(i) = filterHash;
            ResultFilterStatus(i) = "STARTED";
            append_event(logPath, i, 'RESULT_FILTER_ATTACH', ...
                char(CVFPath(i)));
            append_event(logPath, i, 'RESULT_FILTER_ATTACH_START', ...
                char(CVFPath(i)));
            attachInfo = st_apply_result_coverage_filters( ...
                initialResult, CVFPath(i), cfg, ...
                'RequireCoverage', true, ...
                'CoveragePath', coverage_path(row), ...
                'RequireExactSet', true);
            ResultFilterStatus(i) = string(attachInfo.Status);
            ResultFilterAttachCount(i) = ResultFilterAttachCount(i) + 1;
            if ResultFilterStatus(i) ~= "OK"
                error('simtest:ResultCoverageFilterRequired', ...
                    'Required initial result CVF registration failed.');
            end
            append_event(logPath, i, 'RESULT_FILTER_ATTACH_DONE', ...
                char(ResultFilterStatus(i)));
        end

        if row.ExpectedUpdateMode == "APPLY"
            updateResult = st_update_expected_from_results(initialResult, row);
            if ~isempty(updateResult)
                updateResult = renamevars(updateResult, 'No', 'TargetNo');
                updates = append_table(updates, updateResult);
                ExpectedUpdatedCount(i) = sum(updateResult.UpdatedCount);
                if any(string(updateResult.Status) == "FAIL")
                    error('simtest:PerCutExpectedUpdateFailed', ...
                        'Expected-value update failed for %s.', ...
                        char(TestCaseName(i)));
                end
            end
        end

        if ExpectedUpdatedCount(i) > 0 && cfg.RerunAfterExpectedUpdate
            st_log(cfg, 'DEBUG', ...
                '[PER_CUT %d/%d] run(testCase) final start', i, n);
            append_event(logPath, i, 'RUN_FINAL_START', char(TestCaseName(i)));
            finalResult = run(tc);
            RunCount(i) = RunCount(i) + 1;
            append_event(logPath, i, 'RUN_FINAL_DONE', char(TestCaseName(i)));
            st_log(cfg, 'DEBUG', ...
                ['[PER_CUT %d/%d] run(testCase) final complete | ' ...
                 'CVF managed by Test Manager=%s'], ...
                i, n, char(CVFPath(i)));
            append_event(logPath, i, 'RESULT_FILTER_MANAGED', ...
                char(CVFPath(i)));
            results(i).FinalResult = finalResult;
            results(i).RerunPerformed = true;
            RerunPerformed(i) = true;
            FinalOutcome(i) = result_outcome(finalResult, row, 'FINAL');
            validate_verify_timing(finalResult, 'final', row);
            if ~applyManagedFiltersDuringRun && ...
                    st_coverage_filter_active(row)
                ResultFilterStatus(i) = "STARTED";
                attachInfo = st_apply_result_coverage_filters( ...
                    finalResult, CVFPath(i), cfg, ...
                    'RequireCoverage', true, ...
                    'CoveragePath', coverage_path(row), ...
                    'RequireExactSet', true);
                ResultFilterStatus(i) = string(attachInfo.Status);
                ResultFilterAttachCount(i) = ...
                    ResultFilterAttachCount(i) + 1;
                if ResultFilterStatus(i) ~= "OK"
                    error('simtest:ResultCoverageFilterRequired', ...
                        'Required final result CVF registration failed.');
                end
            end
        end

        append_event(logPath, i, 'RESTORE_START', char(TestCaseName(i)));
        restoreResult = session.Restore();
        restoreSucceeded = all(restoreResult.Status == "OK");
        FilterRestoreStatus(i) = string(restoreResult.Status(1));
        append_event(logPath, i, 'FILTER_RESTORE', ...
            char(FilterRestoreStatus(i)));
        append_event(logPath, i, 'RESTORE_DONE', ...
            char(FilterRestoreStatus(i)));
        clear filterCleanup;
        if ~restoreSucceeded
            error('simtest:CoverageFilterRestoreFailed', ...
                'Coverage filter restoration did not pass.');
        end

        % The general PER_CUT workflow keeps its legacy result assets.  The
        % standalone pipeline disables this block and packages the live
        % Result exactly once in its PACKAGE action.
        if generateResultArtifacts
        append_event(logPath, i, 'EXPORT_INITIAL_START', initialDirectory);
        st_log(cfg, 'DEBUG', ...
            ['[PER_CUT %d/%d] portable result copy start | ' ...
             'stage=INITIAL | filters=RESTORED | directory=%s'], ...
            i, n, initialDirectory);
        initialInfo = st_export_result_set_report( ...
            initialResult, row, initialDirectory, ...
            [char(TestCaseName(i)) ' initial'], ...
            'CoverageReportMode', reportMode, ...
            'IncludeOfficialReport', strcmp(reportMode, 'FULL'), ...
            'IncludePortableCoverageDetail', true, ...
            'LogConfig', cfg, ...
            'ResultLabel', 'INITIAL');
        st_log(cfg, 'DEBUG', ...
            ['[PER_CUT %d/%d] portable result copy complete | ' ...
             'stage=INITIAL | directory=%s'], ...
            i, n, initialDirectory);
        InitialReport(i) = string(initialInfo.Summary);
        append_event(logPath, i, 'EXPORT_INITIAL_DONE', initialInfo.Status);
        artifacts = append_artifacts(artifacts, No(i), ...
            "INITIAL", initialInfo.Artifacts);
        coverage = append_table(coverage, initialInfo.Coverage);
        if ~strcmp(initialInfo.Status, 'OK')
            error('simtest:PerCutInitialReportFailed', ...
                'Initial report is incomplete: %s', initialInfo.Summary);
        end

        if RerunPerformed(i)
            append_event(logPath, i, 'EXPORT_FINAL_START', finalDirectory);
            st_log(cfg, 'DEBUG', ...
                ['[PER_CUT %d/%d] portable result copy start | ' ...
                 'stage=FINAL | filters=RESTORED | directory=%s'], ...
                i, n, finalDirectory);
            finalInfo = st_export_result_set_report( ...
                finalResult, row, finalDirectory, ...
                [char(TestCaseName(i)) ' final'], ...
                'CoverageReportMode', reportMode, ...
                'IncludeOfficialReport', strcmp(reportMode, 'FULL'), ...
                'IncludePortableCoverageDetail', true, ...
                'LogConfig', cfg, ...
                'ResultLabel', 'FINAL');
            st_log(cfg, 'DEBUG', ...
                ['[PER_CUT %d/%d] portable result copy complete | ' ...
                 'stage=FINAL | directory=%s'], ...
                i, n, finalDirectory);
            FinalReport(i) = string(finalInfo.Summary);
            append_event(logPath, i, 'EXPORT_FINAL_DONE', finalInfo.Status);
            artifacts = append_artifacts(artifacts, No(i), ...
                "FINAL", finalInfo.Artifacts);
            coverage = append_table(coverage, finalInfo.Coverage);
            if ~strcmp(finalInfo.Status, 'OK')
                error('simtest:PerCutFinalReportFailed', ...
                    'Final report is incomplete: %s', finalInfo.Summary);
            end
        end
        end

        if upper(FinalOutcome(i)) == "PASSED"
            Status(i) = "PASS";
            Message(i) = "Test Case completed and filter state restored";
        else
            actualOutcome = upper(strtrim(FinalOutcome(i)));
            if strlength(actualOutcome) == 0
                actualOutcome = "UNKNOWN";
            end
            % A Test Manager verdict is result data, not a runner error.
            % Keep the verdict in FinalOutcome and continue to the next CUT.
            Status(i) = "WARN";
            Message(i) = "Execution completed; final Test Case outcome is " + ...
                actualOutcome;
            st_log(cfg, 'WARN', ...
                ['[PER_CUT %d/%d] non-passing outcome | ' ...
                 'TestCase=%s | outcome=%s | continuing'], ...
                i, n, char(TestCaseName(i)), char(actualOutcome));
            append_event(logPath, i, 'TARGET_OUTCOME_NONPASS', ...
                char(Message(i)));
        end
        if capturePackageEvidence
            PackageEvidenceStatus(i) = "STARTED";
            append_event(logPath, i, 'PACKAGE_EVIDENCE_START', ...
                char(TestCaseName(i)));
            [PackageEvidence(i), PackageEvidenceSHA256(i)] = ...
                capture_package_evidence( ...
                    results(i).FinalResult, row, CVFPath(i), ...
                    targetDirectory, cfg);
            PackageEvidenceStatus(i) = "OK";
            append_event(logPath, i, 'PACKAGE_EVIDENCE_DONE', ...
                char(PackageEvidence(i)));
        end
    catch ME
        targetError = ME;
        if FilterGenerationStatus(i) == "STARTED"
            FilterGenerationStatus(i) = "FAIL";
        end
        if ResultFilterStatus(i) == "STARTED"
            ResultFilterStatus(i) = "FAIL";
        end
        if PackageEvidenceStatus(i) == "STARTED"
            PackageEvidenceStatus(i) = "FAIL";
            append_event(logPath, i, 'PACKAGE_EVIDENCE_FAIL', ...
                ME.message);
        end
        if strcmp(ME.identifier, 'simtest:CoverageFilterRestoreFailed')
            abortError = ME;
        end
        if sessionCreated && ~restoreSucceeded
            try
                append_event(logPath, i, 'RESTORE_START', ...
                    char(TestCaseName(i)));
                restoreResult = session.Restore();
                restoreSucceeded = all(restoreResult.Status == "OK");
                FilterRestoreStatus(i) = string(restoreResult.Status(1));
                append_event(logPath, i, 'RESTORE_DONE', ...
                    char(FilterRestoreStatus(i)));
            catch restoreME
                FilterRestoreStatus(i) = "FAIL";
                targetError = addCause(restoreME, ME);
                abortError = targetError;
            end
        elseif applyStarted && ~restoreSucceeded
            FilterApplyStatus(i) = "FAIL";
            if isempty(abortError)
                % The apply helper rethrows only after its exact rollback
                % succeeds; rollback failure uses the restore identifier.
                FilterRestoreStatus(i) = "OK";
            else
                FilterRestoreStatus(i) = "FAIL";
            end
        elseif ~sessionCreated
            FilterRestoreStatus(i) = "NOT_REQUIRED";
        end

        Status(i) = "EXCEPT";
        Message(i) = string(targetError.message);
        st_log(cfg, 'ERROR', ...
            '[PER_CUT %d/%d] exception | %s: %s', ...
            i, n, targetError.identifier, targetError.message);
        append_event(logPath, i, 'TARGET_EXCEPT', targetError.message);

        if isempty(abortError) && ~continueOnFailure
            abortError = targetError;
        end
    end

    [ModelCleanupStatus(i), cleanupMessage] = close_execution_model(row, cfg);
    append_event(logPath, i, 'MODEL_CLEANUP', cleanupMessage);
    if ModelCleanupStatus(i) == "FAIL"
        Status(i) = "EXCEPT";
        Message(i) = "Execution model cleanup failed: " + cleanupMessage;
        if isempty(abortError)
            abortError = MException('simtest:ExecutionModelCleanupFailed', ...
                '%s', char(Message(i)));
        end
    end
    clear modelPathCleanup;
    PathCleanupStatus(i) = verify_execution_model_path_cleanup(row);
    append_event(logPath, i, 'PATH_CLEANUP', ...
        char(PathCleanupStatus(i)));
    if PathCleanupStatus(i) == "FAIL"
        Status(i) = "EXCEPT";
        Message(i) = "Execution model path cleanup failed";
        if isempty(abortError)
            abortError = MException('simtest:ExecutionModelPathCleanupFailed', ...
                '%s', char(Message(i)));
        end
    end
    DurationSec(i) = toc(rowTimer);
    CompletedAt(i) = timestamp_text();
    targetManifest = build_target_manifest( ...
        runId, i, row, targetDirectory, CVFPath(i), CVFSHA256(i), ...
        CVFRuleCount(i), FilterGenerationStatus(i), ...
        FilterApplyStatus(i), FilterRestoreStatus(i), ...
        ResultFilterStatus(i), RunCount(i), ...
        ResultFilterAttachCount(i), ModelCleanupStatus(i), ...
        PathCleanupStatus(i), ...
        PackageEvidence(i), PackageEvidenceSHA256(i), ...
        PackageEvidenceStatus(i), ...
        InitialOutcome(i), FinalOutcome(i), InitialReport(i), ...
        FinalReport(i), RerunPerformed(i), ExpectedUpdatedCount(i), ...
        Status(i), Message(i), StartedAt(i), CompletedAt(i), ...
        DurationSec(i), reportMode, existingFilterPolicy, ...
        char(ManagedFilterApplication(i)), char(ResultFilterMode(i)));
    try
        write_json_atomic(manifestPath, targetManifest);
        artifacts(end+1,:) = {No(i), "TARGET", "MANIFEST", ...
            string(manifestPath), "OK", "Target manifest written"};
    catch manifestME
        Status(i) = "EXCEPT";
        Message(i) = "Target manifest write failed: " + ...
            string(manifestME.message);
        artifacts(end+1,:) = {No(i), "TARGET", "MANIFEST", ...
            string(manifestPath), "FAIL", string(manifestME.message)};
        if isempty(abortError) && ~continueOnFailure
            abortError = manifestME;
        end
    end

    if ~isempty(abortError)
        st_log(cfg, 'ERROR', ...
            '[PER_CUT %d/%d] aborting remaining targets | %s', ...
            i, n, abortError.message);
        break;
    end
    append_event(logPath, i, 'TARGET_COMPLETE', char(Status(i)));
end

processed = strlength(CompletedAt) > 0;
Status(~processed) = "SKIP";
Message(~processed) = "Not executed because a previous CUT could not be restored";
FilterRestoreStatus(~processed) = "NOT_RUN";

targets = table(No, CUTName, CUTPath, ExecutionModel, StandaloneCUTPath, TestCaseName, ...
    FilterMode, BoundaryMode, FilterAction, FilterRationale, ExistingFilterPolicy, ...
    ManagedFilterApplication, ResultFilterMode, CVFPath, CVFSHA256, ...
    CVFRuleCount, FilterGenerationStatus, RunCount, ...
    ResultFilterAttachCount, InitialOutcome, FinalOutcome, ...
    InitialReport, FinalReport, ...
    RerunPerformed, ExpectedUpdatedCount, FilterApplyStatus, ...
    ResultFilterStatus, FilterRestoreStatus, ModelCleanupStatus, ...
    PathCleanupStatus, PackageEvidence, PackageEvidenceSHA256, ...
    PackageEvidenceStatus, ...
    Status, Message, DurationSec, StartedAt, ...
    CompletedAt, TargetManifest);
if isfile(logPath)
    artifacts(end+1,:) = {0, "ROOT", "LOG", string(logPath), ...
        "OK", "Sequential execution event log"};
end
completedAt = timestamp_text();
if saveTestResult && isempty(abortError)
    export_aggregate_result(results, resultFile, cfg, logPath);
    artifacts(end+1,:) = {0, "ROOT", "MLDATX", string(resultFile), ...
        "OK", "Aggregate Test Manager Result"};
end
summary = st_write_per_cut_run_report( ...
    runId, runDirectory, targets, coverage, artifacts, cfg, ...
    startedAt, completedAt, reportMode, ...
    'WriteExcel', writeRunSummaryExcel);
summary.Targets = targets;
summary.RunScope = runScope;
summary.EventLog = logPath;
summary.ResultFile = resultFile;
summary.ResultSaved = saveTestResult;

if ~isempty(abortError)
    abortError = addCause(abortError, MException( ...
        'simtest:PerCutRunReportWritten', ...
        'Partial PER_CUT report was written to %s.', summary.Manifest));
    throw(abortError);
end
nonPassMask = ismember(Status, ["FAIL","EXCEPT","WARN"]);
if failOnNonPass && (any(nonPassMask) || strcmp(summary.Status, 'FAIL'))
    nonPassCount = sum(nonPassMask);
    if nonPassCount > 0
        failureDetails = format_nonpass_targets( ...
            TestCaseName, FinalOutcome, Message, nonPassMask);
        failureMessage = sprintf( ...
            '%d CUT(s) did not pass: %s. Results were written to %s.', ...
            nonPassCount, failureDetails, summary.Manifest);
    else
        failureMessage = sprintf( ...
            'The root report was incomplete. Results were written to %s.', ...
            summary.Manifest);
    end
    st_log(cfg, 'ERROR', 'PER_CUT execution failed | %s', failureMessage);
    error('simtest:PerCutRunFailed', '%s', failureMessage);
end
end

function [status, message] = close_execution_model(row, cfg)
status = "OK";
message = "No standalone execution model was loaded";
if ~ismember('ExecutionModel', row.Properties.VariableNames)
    return;
end

model = char(string(row.ExecutionModel));
if isempty(model) || strcmp(model, cfg.TopModel) || ~bdIsLoaded(model)
    return;
end
st_log(cfg, 'DEBUG', ...
    'Standalone execution model close start | Model=%s', model);
try
    close_system(model, 0);
    message = "Standalone execution model closed";
    st_log(cfg, 'DEBUG', ...
        'Standalone execution model close complete | Model=%s', model);
catch ME
    status = "FAIL";
    message = string(ME.message);
    st_log(cfg, 'WARN', ...
        'Standalone execution model close failed | Model=%s | %s', ...
        model, ME.message);
end
end

function status = verify_execution_model_path_cleanup(row)
status = "OK";
if ~ismember('ExecutionModelFile', row.Properties.VariableNames)
    return;
end
modelFile = char(string(row.ExecutionModelFile));
if isempty(modelFile), return; end
if path_contains(fileparts(modelFile)), status = "FAIL"; end
end


function validate_verify_timing(resultObj, phase, targetRow)
verifyResult = st_validate_sldv_verify_results(resultObj, targetRow);
if ~isempty(verifyResult) && any(string(verifyResult.Status) == "FAIL")
    failed = verifyResult(string(verifyResult.Status) == "FAIL", :);
    error('simtest:PerCutVerifyTimingFailed', ...
        'SLDV verify timing failed during %s run: %s', ...
        phase, char(strjoin(string(failed.Message), ' | ')));
end
end


function outcome = result_outcome(resultObj, row, label)
[targetResult, ~] = st_collect_test_result_summary(resultObj, row, label);
if isempty(targetResult)
    outcome = "UNKNOWN";
else
    outcome = upper(string(targetResult.Outcome(end)));
end
end


function text = format_nonpass_targets( ...
        testCaseNames, finalOutcomes, messages, nonPassMask)
indices = find(nonPassMask);
details = strings(numel(indices), 1);
for i = 1:numel(indices)
    index = indices(i);
    outcome = upper(strtrim(finalOutcomes(index)));
    if strlength(outcome) == 0
        outcome = "UNKNOWN";
    end
    details(i) = testCaseNames(index) + "=" + outcome + ...
        " [" + messages(index) + "]";
end
text = char(strjoin(details, ' | '));
end


function combined = append_table(combined, added)
if isempty(added)
    return;
end
if isempty(combined)
    combined = added;
else
    combined = [combined; added];
end
end


function combined = append_artifacts(combined, targetNo, stage, added)
for i = 1:height(added)
    combined(end+1,:) = {targetNo, string(stage), ...
        string(added.Type(i)), string(added.Path(i)), ...
        string(added.Status(i)), string(added.Message(i))};
end
end


function T = empty_artifact_table()
T = table(zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','Stage','Type','Path','Status','Message'});
end


function [runId, runDirectory] = create_run_directory(rootDirectory)
if ~isfolder(rootDirectory)
    mkdir(rootDirectory);
end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
uuid = char(java.util.UUID.randomUUID());
runId = [stamp '_' uuid(1:8)];
runDirectory = fullfile(rootDirectory, runId);
mkdir(runDirectory);
end


function [evidencePath, evidenceHash] = capture_package_evidence( ...
        resultObj, row, coverageFilterPath, targetDirectory, cfg)
timerValue = tic;
modelName = optional_text(row, 'ExecutionModel');
modelFile = optional_text(row, 'ExecutionModelFile');
evidenceDirectory = fullfile(targetDirectory, 'package-evidence');
if ~isfolder(evidenceDirectory)
    mkdir(evidenceDirectory);
end
reportZip = fullfile(evidenceDirectory, 'CoverageReport.zip');
cvtPath = fullfile(evidenceDirectory, 'CoverageResult.cvt');
evidencePath = fullfile(evidenceDirectory, 'evidence.json');
delete_if_present(reportZip);
delete_if_present(cvtPath);
delete_if_present(evidencePath);
st_log(cfg, 'INFO', ...
    'Standalone package evidence capture start | CUT=%s', ...
    char(string(row.CUTName)));
try
    if isempty(modelName) || ~bdIsLoaded(modelName)
        error('simtest:StandalonePackageEvidenceModelNotOpen', ...
            ['Execution model must remain open while capturing package ' ...
             'evidence: %s'], modelName);
    end
    loadedFile = char(string(get_param(modelName, 'FileName')));
    if isempty(modelFile) || ~same_path(loadedFile, modelFile)
        error('simtest:StandalonePackageEvidenceModelMismatch', ...
            ['A different execution model is open while capturing package ' ...
             'evidence. Expected=%s | Actual=%s'], modelFile, loadedFile);
    end
    st_log(cfg, 'INFO', ...
        'Standalone package coverage data capture start | CUT=%s | Model=%s', ...
        char(string(row.CUTName)), modelName);
    coverageObjects = st_collect_result_coverage_objects(resultObj);
    if isempty(coverageObjects)
        error('simtest:StandalonePackageEvidenceCoverageMissing', ...
            'Result contains no coverage objects for %s.', ...
            char(string(row.CUTName)));
    end
    % Test Manager can materialize a new cvdata instance every time its
    % result hierarchy is queried.  Bind the CVF to this exact instance:
    % it is the object passed to cvsave, cvhtml, and metric extraction.
    apply_package_report_filter(coverageObjects, row, coverageFilterPath, cfg);
    save_package_evidence_cvt(cvtPath, coverageObjects, cfg);
    st_log(cfg, 'INFO', ...
        ['Standalone package coverage data capture complete | CUT=%s | ' ...
         'File=%s'], char(string(row.CUTName)), cvtPath);
    if ~bdIsLoaded(modelName) || ...
            ~same_path(get_param(modelName, 'FileName'), modelFile)
        error('simtest:StandalonePackageEvidenceModelLost', ...
            ['Execution model changed or closed after coverage data capture. ' ...
             'Expected=%s'], modelFile);
    end
    capture_package_coverage_report(reportZip, coverageObjects, row, ...
        coverageFilterPath, cfg);
    if ~bdIsLoaded(modelName) || ...
            ~same_path(get_param(modelName, 'FileName'), modelFile)
        error('simtest:StandalonePackageEvidenceModelLost', ...
            ['Execution model changed or closed after report capture. ' ...
             'Expected=%s'], modelFile);
    end
    metrics = st_collect_final_cut_coverage_metrics( ...
        resultObj, row, 'LogConfig', cfg, ...
        'CoverageObjects', coverageObjects);
    evidence = struct( ...
        'Version', 2, ...
        'No', double(row.No), ...
        'CUTName', char(string(row.CUTName)), ...
        'TestCaseName', char(string(row.TestCaseName)), ...
        'StandaloneModel', optional_text(row, 'ExecutionModel'), ...
        'CoverageResult', cvtPath, ...
        'CoverageResultSHA256', st_file_signature(cvtPath).SHA256, ...
        'CoverageReportZip', reportZip, ...
        'CoverageReportZipSHA256', st_file_signature(reportZip).SHA256, ...
        'Decision', metrics.Decision, ...
        'Execution', metrics.Execution, ...
        'MetricSource', metrics.Source, ...
        'MetricSourceStatus', metrics.SourceStatus);
    write_json_atomic(evidencePath, evidence);
    evidenceHash = string(st_file_signature(evidencePath).SHA256);
    st_log(cfg, 'INFO', ...
        ['Standalone package evidence capture complete | CUT=%s | ' ...
         'elapsed=%.3f sec'], ...
        char(string(row.CUTName)), toc(timerValue));
catch ME
    st_log(cfg, 'ERROR', ...
        'Standalone package evidence capture failed | CUT=%s | %s: %s', ...
        char(string(row.CUTName)), ME.identifier, ME.message);
    rethrow(ME);
end
end

function apply_package_report_filter(coverageObjects, row, coverageFilterPath, cfg)
if ~st_coverage_filter_active(row)
    st_log(cfg, 'DEBUG', ...
        'Standalone original Coverage report CVF binding skipped | CUT=%s | inactive', ...
        char(string(row.CUTName)));
    return;
end
expected = char(string(coverageFilterPath));
if isempty(expected) || ~isfile(expected)
    error('simtest:StandalonePackageEvidenceCoverageFilterMissing', ...
        'Coverage report CVF is missing for %s: %s', ...
        char(string(row.CUTName)), expected);
end
st_log(cfg, 'INFO', ...
    ['Standalone original Coverage report CVF binding start | CUT=%s | ' ...
     'Filter=%s | Objects=%d'], ...
    char(string(row.CUTName)), expected, numel(coverageObjects));
for i = 1:numel(coverageObjects)
    coverageObjects{i}.filter = expected;
    actual = string(coverageObjects{i}.filter);
    actual = actual(:);
    actual(ismissing(actual)) = "";
    actual = actual(strlength(actual) > 0);
    if ~filter_name_matches(expected, actual)
        error('simtest:StandalonePackageEvidenceCoverageFilterApplyFailed', ...
            ['Could not bind the CVF to the coverage object used for the ' ...
             'original report. ' ...
             'CUT=%s | Expected=%s | Actual=%s'], ...
            char(string(row.CUTName)), expected, ...
            char(strjoin(actual, ' | ')));
    end
    st_log(cfg, 'INFO', ...
        ['Standalone original Coverage report CVF binding readback complete | ' ...
         'CUT=%s | Object=%d | Filter=%s'], ...
        char(string(row.CUTName)), i, expected);
end
st_log(cfg, 'INFO', ...
    'Standalone original Coverage report CVF binding complete | CUT=%s', ...
    char(string(row.CUTName)));
end

function tf = filter_name_matches(expected, actual)
tf = any(strcmpi(string(expected), actual));
if tf, return; end
[~, expectedName, expectedExtension] = fileparts(expected);
expectedKey = string([expectedName lower(expectedExtension)]);
for i = 1:numel(actual)
    [~, actualName, actualExtension] = fileparts(char(actual(i)));
    actualKey = string([actualName lower(actualExtension)]);
    if strcmpi(expectedKey, actualKey)
        tf = true;
        return;
    end
end
end

function save_package_evidence_cvt(path, objects, cfg)
[folder, name] = fileparts(path);
base = fullfile(folder, name);
arguments = [{base}; objects(:)];
writableCleanup = st_enter_writable_coverage_directory(cfg, 'CVSAVE');
cvsave(arguments{:});
clear writableCleanup;
if ~isfile(path)
    error('simtest:StandalonePackageEvidenceCVTSaveMissing', ...
        'cvsave did not create the package evidence file: %s', path);
end
end

function capture_package_coverage_report( ...
        reportZip, coverageObjects, row, coverageFilterPath, cfg)
if numel(coverageObjects) ~= 1
    error('simtest:StandalonePackageEvidenceCoverageReportAmbiguous', ...
        ['Expected exactly one final Coverage object for the original ' ...
         'Coverage report of %s, found %d.'], ...
        char(string(row.CUTName)), numel(coverageObjects));
end
writableCleanup = st_enter_writable_coverage_directory(cfg, 'CVHTML');
scratchDirectory = pwd;
bind_report_filter_display_name(coverageObjects, row, coverageFilterPath, ...
    scratchDirectory, cfg);
reportDirectory = fullfile(scratchDirectory, 'CoverageReport');
mkdir(reportDirectory);
reportHTML = fullfile(reportDirectory, 'report.html');
st_log(cfg, 'INFO', ...
    ['Standalone original Coverage report capture start | CUT=%s | ' ...
     'Scratch=%s | Destination=%s'], ...
    char(string(row.CUTName)), reportHTML, reportZip);
report = cvhtml(reportHTML, coverageObjects{1}, '-sRT=0');
if isstruct(report) && isfield(report, 'fileName') && isfield(report, 'path')
    reportHTML = fullfile(char(report(1).path), char(report(1).fileName));
end
ensure_evidence_report_html(reportDirectory, reportHTML);
scratchZip = fullfile(scratchDirectory, 'CoverageReport.zip');
zip(scratchZip, {'*'}, reportDirectory);
if ~isfile(scratchZip)
    error('simtest:StandalonePackageEvidenceCoverageReportMissing', ...
        'cvhtml did not create the scratch Coverage ZIP: %s', scratchZip);
end
[copied, copyMessage] = copyfile(scratchZip, reportZip, 'f');
if ~copied
    error('simtest:StandalonePackageEvidenceCoverageReportCopyFailed', ...
        'Cannot promote the scratch Coverage ZIP to %s: %s', ...
        reportZip, copyMessage);
end
clear writableCleanup;
if ~isfile(reportZip)
    error('simtest:StandalonePackageEvidenceCoverageReportMissing', ...
        'The promoted package evidence ZIP is missing: %s', reportZip);
end
% Restore the validated absolute CVF binding. The display filter lives in
% the scratch directory that was just removed, and the same coverage
% objects still feed final metric extraction.
apply_package_report_filter(coverageObjects, row, coverageFilterPath, cfg);
st_log(cfg, 'INFO', ...
    ['Standalone original Coverage report capture complete | CUT=%s | ' ...
     'ZIP=%s'], char(string(row.CUTName)), reportZip);
end

function bind_report_filter_display_name( ...
        coverageObjects, row, coverageFilterPath, scratchDirectory, cfg)
% Bind a short local name only for the HTML UI; CVT was already saved with
% the validated execution filter binding.
if ~st_coverage_filter_active(row)
    return;
end
sourceFilter = char(string(coverageFilterPath));
if isempty(sourceFilter) || ~isfile(sourceFilter)
    error('simtest:StandalonePackageEvidenceCoverageFilterMissing', ...
        'Coverage report CVF is missing for %s: %s', ...
        char(string(row.CUTName)), sourceFilter);
end
% Must equal the CVF that PACKAGE places beside this report, or the
% filter name printed in the HTML points at a file that is not there.
displayFilter = [st_artifact_stem(char(string(row.TestCaseName))) '.cvf'];
destinationFilter = fullfile(scratchDirectory, displayFilter);
st_log(cfg, 'INFO', ...
    ['Standalone original Coverage report display filter start | CUT=%s | ' ...
     'Filter=%s'], char(string(row.CUTName)), displayFilter);
try
    [copied, copyMessage] = copyfile(sourceFilter, destinationFilter, 'f');
    if ~copied
        error('simtest:StandalonePackageEvidenceCoverageFilterCopyFailed', ...
            'Cannot stage report display CVF %s: %s', ...
            destinationFilter, copyMessage);
    end
    coverageObjects{1}.filter = displayFilter;
    actual = string(coverageObjects{1}.filter);
    if ~filter_name_matches(displayFilter, actual)
        error('simtest:StandalonePackageEvidenceCoverageFilterApplyFailed', ...
            ['Could not bind the report display CVF to the coverage object. ' ...
             'CUT=%s | Expected=%s | Actual=%s'], ...
            char(string(row.CUTName)), displayFilter, char(actual));
    end
    st_log(cfg, 'INFO', ...
        ['Standalone original Coverage report display filter complete | ' ...
         'CUT=%s | Filter=%s'], char(string(row.CUTName)), displayFilter);
catch ME
    st_log(cfg, 'ERROR', ...
        ['Standalone original Coverage report display filter failed | ' ...
         'CUT=%s | %s: %s'], char(string(row.CUTName)), ...
        ME.identifier, ME.message);
    rethrow(ME);
end
end

function ensure_evidence_report_html(reportDirectory, generatedHTML)
rootReport = fullfile(reportDirectory, 'report.html');
if isfile(rootReport), return; end
if isfile(generatedHTML)
    [ok, message] = copyfile(generatedHTML, rootReport, 'f');
    if ~ok
        error('simtest:StandalonePackageEvidenceCoverageReportCopyFailed', ...
            'Cannot place generated Coverage report at %s: %s', ...
            rootReport, message);
    end
    return;
end
error('simtest:StandalonePackageEvidenceCoverageReportMissing', ...
    'cvhtml created no root report.html in %s.', reportDirectory);
end


function manifest = build_target_manifest( ...
        runId, order, row, targetDirectory, cvfPath, cvfHash, ...
        cvfRuleCount, generationStatus, applyStatus, restoreStatus, ...
        resultFilterStatus, runCount, resultFilterAttachCount, ...
        modelCleanupStatus, pathCleanupStatus, packageEvidence, ...
        packageEvidenceSHA256, packageEvidenceStatus, ...
        initialOutcome, finalOutcome, ...
        initialReport, finalReport, rerunPerformed, updatedCount, ...
        status, message, startedAt, completedAt, durationSec, reportMode, ...
        existingFilterPolicy, managedFilterApplication, resultFilterMode)
manifest = struct( ...
    'Version', 2, ...
    'RunId', runId, ...
    'Order', order, ...
    'No', double(row.No), ...
    'CUTName', char(string(row.CUTName)), ...
    'CUTPath', char(string(row.CUTPath)), ...
    'ExecutionModel', optional_text(row, 'ExecutionModel'), ...
    'ExecutionModelFile', optional_text(row, 'ExecutionModelFile'), ...
    'StandaloneCUTPath', optional_text(row, 'StandaloneCUTPath'), ...
    'TestCaseName', char(string(row.TestCaseName)), ...
    'ExpectedUpdateMode', char(string(row.ExpectedUpdateMode)), ...
    'CoverageFilterMode', char(string(row.CoverageFilterMode)), ...
    'CoverageBoundaryMode', boundary_mode(row), ...
    'CoverageFilterAction', char(string(row.CoverageFilterAction)), ...
    'CoverageFilterRationale', char(string(row.CoverageFilterRationale)), ...
    'CoverageFilterFile', char(string(cvfPath)), ...
    'CoverageFilterSHA256', char(string(cvfHash)), ...
    'CoverageFilterRuleCount', double(cvfRuleCount), ...
    'CoverageFilterApplicationMode', 'RUNTIME', ...
    'CoverageFilterExistingPolicy', existingFilterPolicy, ...
    'ManagedFilterApplication', managedFilterApplication, ...
    'ResultFilterMode', resultFilterMode, ...
    'FilterGenerationStatus', char(string(generationStatus)), ...
    'FilterApplyStatus', char(string(applyStatus)), ...
    'ResultFilterStatus', char(string(resultFilterStatus)), ...
    'RunCount', double(runCount), ...
    'ResultFilterAttachCount', double(resultFilterAttachCount), ...
    'FilterRestoreStatus', char(string(restoreStatus)), ...
    'ModelCleanupStatus', char(string(modelCleanupStatus)), ...
    'PathCleanupStatus', char(string(pathCleanupStatus)), ...
    'PackageEvidence', char(string(packageEvidence)), ...
    'PackageEvidenceSHA256', char(string(packageEvidenceSHA256)), ...
    'PackageEvidenceStatus', char(string(packageEvidenceStatus)), ...
    'InitialOutcome', char(string(initialOutcome)), ...
    'FinalOutcome', char(string(finalOutcome)), ...
    'InitialSummary', char(string(initialReport)), ...
    'FinalSummary', char(string(finalReport)), ...
    'RerunPerformed', logical(rerunPerformed), ...
    'ExpectedUpdatedCount', double(updatedCount), ...
    'ReportMode', char(string(reportMode)), ...
    'Status', char(string(status)), ...
    'Message', char(string(message)), ...
    'StartedAt', char(string(startedAt)), ...
    'CompletedAt', char(string(completedAt)), ...
    'DurationSec', double(durationSec), ...
    'TargetDirectory', targetDirectory);
end

function cleanup = register_execution_model_folder(row, cfg)
cleanup = [];
if ~ismember('ExecutionModelFile', row.Properties.VariableNames)
    return;
end
modelFile = char(string(row.ExecutionModelFile));
if isempty(modelFile) || ~isfile(modelFile)
    return;
end
folder = fileparts(modelFile);
if path_contains(folder)
    return;
end
addpath(folder, '-begin');
st_log(cfg, 'DEBUG', ...
    'Execution model folder registered for current CUT | %s', folder);
cleanup = onCleanup(@() remove_path_quietly(folder));
end

function remove_path_quietly(folder)
try, rmpath(folder); catch, end
end

function tf = path_contains(folder)
entries = string(strsplit(path, pathsep));
folder = canonical_path(folder);
tf = false;
for i = 1:numel(entries)
    if strlength(entries(i)) == 0, continue; end
    candidate = canonical_path(char(entries(i)));
    if (ispc && strcmpi(candidate, folder)) || ...
            (~ispc && strcmp(candidate, folder))
        tf = true;
        return;
    end
end
end

function value = canonical_path(value)
value = char(java.io.File(char(value)).getCanonicalPath());
end

function tf = same_path(left, right)
left = canonical_path(left);
right = canonical_path(right);
if ispc
    tf = strcmpi(left, right);
else
    tf = strcmp(left, right);
end
end

function path = coverage_path(row)
path = optional_text(row, 'StandaloneCUTPath');
if isempty(path)
    path = char(string(row.CUTPath));
end
end

function [filterFile, status, ruleCount, filterHash] = ...
        generate_filter(row, filterDirectory, cfg, logPath, order, ...
        validateSavedFilter)
if ~isfolder(filterDirectory)
    mkdir(filterDirectory);
end
filterFile = string(st_per_cut_coverage_filter_file(filterDirectory, row));
append_event(logPath, order, 'CVF_GENERATE', char(filterFile));
st_log(cfg, 'DEBUG', ...
    'Coverage filter generation start | TestCase=%s | File=%s', ...
    char(string(row.TestCaseName)), char(filterFile));
generated = st_generate_coverage_filter_file( ...
    row, char(filterFile), cfg, ...
    'ValidateSavedFilter', validateSavedFilter);
status = string(generated.Status);
ruleCount = double(generated.RuleCount);
if status ~= "OK" || ~isfile(filterFile)
    error('simtest:PerCutCoverageFilterPreparationFailed', ...
        'CVF was not generated for %s: %s', ...
        char(string(row.TestCaseName)), char(string(generated.Message)));
end
signature = st_file_signature(filterFile);
filterHash = string(signature.SHA256);
st_log(cfg, 'DEBUG', ...
    'Coverage filter generation complete | TestCase=%s | Rules=%d', ...
    char(string(row.TestCaseName)), ruleCount);
end

function export_aggregate_result(results, resultFile, cfg, logPath)
finalResults = cell(numel(results), 1);
for i = 1:numel(results)
    finalResults{i} = results(i).FinalResult;
    if isempty(finalResults{i})
        error('simtest:PerCutAggregateResultIncomplete', ...
            'Cannot save aggregate Result because target %d has no Result.', i);
    end
end
parent = fileparts(resultFile);
if ~isempty(parent) && ~isfolder(parent)
    mkdir(parent);
end
append_event(logPath, 0, 'RESULT_EXPORT', resultFile);
st_log(cfg, 'INFO', ...
    'Aggregate Test Manager Result export start | Targets=%d | File=%s', ...
    numel(finalResults), resultFile);
sltest.testmanager.exportResults([finalResults{:}], resultFile);
if ~isfile(resultFile)
    error('simtest:PerCutAggregateResultMissing', ...
        'Aggregate Result export did not create %s.', resultFile);
end
st_log(cfg, 'INFO', ...
    'Aggregate Test Manager Result export complete | File=%s', resultFile);
end

function mode = boundary_mode(row)
mode = 'OFF';
if ismember('CoverageBoundaryMode', row.Properties.VariableNames)
    mode = char(string(row.CoverageBoundaryMode));
end
end

function value = optional_text(row, name)
value = '';
if ismember(name, row.Properties.VariableNames)
    value = char(string(row.(name)));
end
end


function write_json_atomic(path, value)
folder = fileparts(path);
if ~isfolder(folder)
    mkdir(folder);
end
temporary = [tempname(folder) '.json'];
cleanup = onCleanup(@() delete_if_present(temporary)); %#ok<NASGU>
fileId = fopen(temporary, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:PerCutJsonWriteFailed', ...
        'Cannot open target manifest: %s', path);
end
fileCleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(value, 'PrettyPrint', true));
clear fileCleanup;
[moved, moveMessage] = movefile(temporary, path, 'f');
if ~moved
    error('simtest:PerCutJsonWriteFailed', ...
        'Cannot replace target manifest %s: %s', path, moveMessage);
end
end


function delete_if_present(path)
if isfile(path)
    delete(path);
end
end


function append_event(path, order, event, message)
fileId = fopen(path, 'a', 'n', 'UTF-8');
if fileId < 0
    warning('simtest:PerCutLogWriteFailed', ...
        'Cannot append per-CUT execution log: %s', path);
    return;
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
message = strrep(char(string(message)), newline, ' ');
entry = struct('Timestamp', timestamp_text(), 'Order', order, ...
    'Event', char(string(event)), 'Message', message);
fprintf(fileId, '%s\n', jsonencode(entry));
end


function value = timestamp_text()
value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
end
