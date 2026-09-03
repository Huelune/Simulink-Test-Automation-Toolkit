function [results, updates, summary] = st_run_tests_per_cut(varargin)
%ST_RUN_TESTS_PER_CUT Execute enabled Test Cases sequentially with CVF isolation.
%
% [results, updates, summary] = st_run_tests_per_cut( ...
%     'ContinueOnFailure', true, ...
%     'ReportMode', 'SUMMARY', ...
%     'FailOnNonPass', false)

p = inputParser;
p.FunctionName = 'st_run_tests_per_cut';
addParameter(p, 'ContinueOnFailure', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'ReportMode', 'SUMMARY', ...
    @(x) ismember(upper(string(x)), ["SUMMARY","FULL"]));
addParameter(p, 'FailOnNonPass', false, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

continueOnFailure = logical(p.Results.ContinueOnFailure);
reportMode = upper(char(string(p.Results.ReportMode)));
failOnNonPass = logical(p.Results.FailOnNonPass);

cfg = st_require_runtime_target();
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

targetConfig = st_load_targets(cfg.OnlyEnabled);
tf = sltest.testmanager.TestFile(cfg.TestFile);
[testCases, runScope] = st_get_run_test_cases(tf);
n = height(targetConfig);
if numel(testCases) ~= n
    error('simtest:PerCutTargetMappingFailed', ...
        'Enabled target count and resolved Test Case count differ.');
end

[runId, runDirectory] = create_run_directory(cfg.PerCutRunRootDir);
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
TestCaseName = string(targetConfig.TestCaseName);
FilterMode = string(targetConfig.CoverageFilterMode);
FilterAction = string(targetConfig.CoverageFilterAction);
FilterRationale = string(targetConfig.CoverageFilterRationale);
ExistingFilterPolicy = repmat(string(existingFilterPolicy), n, 1);
ManagedFilterApplication = repmat("DURING_RUN", n, 1);
CVFPath = strings(n,1);
CVFSHA256 = strings(n,1);
CVFRuleCount = zeros(n,1);
FilterGenerationStatus = repmat("OFF", n, 1);
InitialOutcome = repmat("NOT_RUN", n, 1);
FinalOutcome = repmat("NOT_RUN", n, 1);
InitialReport = strings(n,1);
FinalReport = strings(n,1);
RerunPerformed = false(n,1);
ExpectedUpdatedCount = zeros(n,1);
FilterApplyStatus = repmat("NOT_RUN", n, 1);
FilterRestoreStatus = repmat("NOT_RUN", n, 1);
Status = repmat("FAIL", n, 1);
Message = strings(n,1);
DurationSec = zeros(n,1);
StartedAt = strings(n,1);
CompletedAt = strings(n,1);
TargetManifest = strings(n,1);

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
        if row.CoverageFilterMode ~= "OFF"
            mkdir(filterDirectory);
            filterFile = string(st_per_cut_coverage_filter_file( ...
                filterDirectory, row));
            FilterGenerationStatus(i) = "STARTED";
            generated = st_generate_coverage_filter_file( ...
                row, char(filterFile), cfg);
            FilterGenerationStatus(i) = generated.Status;
            CVFRuleCount(i) = generated.RuleCount;
            if generated.Status ~= "OK" || ~isfile(filterFile)
                error('simtest:PerCutCoverageFilterPreparationFailed', ...
                    'CVF was not generated for %s: %s', ...
                    char(TestCaseName(i)), char(generated.Message));
            end
            CVFPath(i) = filterFile;
            signature = st_file_signature(filterFile);
            CVFSHA256(i) = string(signature.SHA256);
            addpath(filterDirectory, '-begin');
            st_log(cfg, 'DEBUG', ...
                '[PER_CUT %d/%d] CVF directory registered | %s', ...
                i, n, filterDirectory);
        end

        applyStarted = true;
        FilterApplyStatus(i) = "STARTED";
        append_event(logPath, i, 'APPLY_START', char(CVFPath(i)));
        [filterCleanup, applyResult, session] = ...
            st_apply_test_case_coverage_filters( ...
                tf, tc, row, cfg, 'FilterFiles', filterFile, ...
                'ExistingFilterPolicy', ...
                existingFilterPolicy, ...
                'ApplyManagedFiltersDuringRun', true); %#ok<NASGU>
        sessionCreated = true;
        FilterApplyStatus(i) = string(applyResult.Status(1));
        append_event(logPath, i, 'APPLY_DONE', ...
            char(FilterApplyStatus(i)));
        if any(applyResult.Status == "FAIL") || ...
                (row.CoverageFilterMode ~= "OFF" && ...
                strlength(string(applyResult.FilterFile(1))) == 0)
            error('simtest:PerCutCoverageFilterApplyFailed', ...
                'The generated CVF was not applied to %s.', ...
                char(TestCaseName(i)));
        end
        st_log(cfg, 'DEBUG', ...
            '[PER_CUT %d/%d] run(testCase) initial start', i, n);
        append_event(logPath, i, 'RUN_INITIAL_START', char(TestCaseName(i)));
        initialResult = run(tc);
        append_event(logPath, i, 'RUN_INITIAL_DONE', char(TestCaseName(i)));
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
        validate_verify_timing(initialResult, 'initial');

        append_event(logPath, i, 'EXPORT_INITIAL_START', initialDirectory);
        st_log(cfg, 'DEBUG', ...
            ['[PER_CUT %d/%d] portable result copy start | ' ...
             'stage=INITIAL | directory=%s'], ...
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
            validate_verify_timing(finalResult, 'final');
            append_event(logPath, i, 'EXPORT_FINAL_START', finalDirectory);
            st_log(cfg, 'DEBUG', ...
                ['[PER_CUT %d/%d] portable result copy start | ' ...
                 'stage=FINAL | directory=%s'], ...
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

        append_event(logPath, i, 'RESTORE_START', char(TestCaseName(i)));
        restoreResult = session.Restore();
        restoreSucceeded = all(restoreResult.Status == "OK");
        FilterRestoreStatus(i) = string(restoreResult.Status(1));
        append_event(logPath, i, 'RESTORE_DONE', ...
            char(FilterRestoreStatus(i)));
        clear filterCleanup;
        if ~restoreSucceeded
            error('simtest:CoverageFilterRestoreFailed', ...
                'Coverage filter restoration did not pass.');
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
    catch ME
        targetError = ME;
        if FilterGenerationStatus(i) == "STARTED"
            FilterGenerationStatus(i) = "FAIL";
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
        elseif applyStarted
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

        Status(i) = "FAIL";
        Message(i) = string(targetError.message);
        st_log(cfg, 'ERROR', ...
            '[PER_CUT %d/%d] failed | %s: %s', ...
            i, n, targetError.identifier, targetError.message);
        append_event(logPath, i, 'TARGET_FAIL', targetError.message);

        if isempty(abortError) && ~continueOnFailure
            abortError = targetError;
        end
    end

    % Test Manager can fail while opening Aggregated Coverage Details when
    % the test harness remains loaded. Close it after result export and
    % filter restoration so the saved ResultSet stays viewable.
    harnessClose = close_harness_for_coverage_view(row, cfg);
    append_event(logPath, i, 'HARNESS_CLOSE_FOR_COVERAGE', ...
        char(harnessClose.Status));
    if harnessClose.Status == "WARN"
        if Status(i) == "PASS"
            Status(i) = "WARN";
        end
        Message(i) = append_status_message( ...
            Message(i), string(harnessClose.Message));
    end

    DurationSec(i) = toc(rowTimer);
    CompletedAt(i) = timestamp_text();
    targetManifest = build_target_manifest( ...
        runId, i, row, targetDirectory, CVFPath(i), CVFSHA256(i), ...
        CVFRuleCount(i), FilterGenerationStatus(i), ...
        FilterApplyStatus(i), FilterRestoreStatus(i), ...
        InitialOutcome(i), FinalOutcome(i), InitialReport(i), ...
        FinalReport(i), RerunPerformed(i), ExpectedUpdatedCount(i), ...
        Status(i), Message(i), StartedAt(i), CompletedAt(i), ...
        DurationSec(i), reportMode, existingFilterPolicy, ...
        char(ManagedFilterApplication(i)));
    try
        write_json_atomic(manifestPath, targetManifest);
        artifacts(end+1,:) = {No(i), "TARGET", "MANIFEST", ...
            string(manifestPath), "OK", "Target manifest written"};
    catch manifestME
        Status(i) = "FAIL";
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

targets = table(No, CUTName, CUTPath, TestCaseName, ...
    FilterMode, FilterAction, FilterRationale, ExistingFilterPolicy, ...
    ManagedFilterApplication, CVFPath, CVFSHA256, ...
    CVFRuleCount, FilterGenerationStatus, InitialOutcome, FinalOutcome, ...
    InitialReport, FinalReport, ...
    RerunPerformed, ExpectedUpdatedCount, FilterApplyStatus, ...
    FilterRestoreStatus, Status, Message, DurationSec, StartedAt, ...
    CompletedAt, TargetManifest);
if isfile(logPath)
    artifacts(end+1,:) = {0, "ROOT", "LOG", string(logPath), ...
        "OK", "Sequential execution event log"};
end
completedAt = timestamp_text();
summary = st_write_per_cut_run_report( ...
    runId, runDirectory, targets, coverage, artifacts, cfg, ...
    startedAt, completedAt, reportMode);
summary.Targets = targets;
summary.RunScope = runScope;

if ~isempty(abortError)
    abortError = addCause(abortError, MException( ...
        'simtest:PerCutRunReportWritten', ...
        'Partial PER_CUT report was written to %s.', summary.Manifest));
    throw(abortError);
end
nonPassMask = ismember(Status, ["FAIL","WARN"]);
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


function validate_verify_timing(resultObj, phase)
verifyResult = st_validate_sldv_verify_results(resultObj);
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


function result = close_harness_for_coverage_view(row, cfg)
result = struct('Status', "SKIP", ...
    'Message', "Harness was not loaded");
harnessName = char(string(row.HarnessName));
timer = tic;
try
    if isempty(harnessName) || ~bdIsLoaded(harnessName)
        st_log(cfg, 'TRACE', ...
            ['Coverage-view Harness close skipped | Harness=%s | ' ...
             'elapsed=%.3f sec'], harnessName, toc(timer));
        return;
    end

    ownerPath = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
    st_log(cfg, 'DEBUG', ...
        'Coverage-view Harness close start | Owner=%s | Harness=%s', ...
        ownerPath, harnessName);
    sltest.harness.close(ownerPath, harnessName);
    if bdIsLoaded(harnessName)
        error('simtest:HarnessStillLoadedForCoverageView', ...
            'Harness remained loaded after close: %s', harnessName);
    end
    result.Status = "OK";
    result.Message = "Harness closed for Test Manager Coverage view";
    st_log(cfg, 'DEBUG', ...
        ['Coverage-view Harness close complete | Harness=%s | ' ...
         'elapsed=%.3f sec'], harnessName, toc(timer));
catch ME
    result.Status = "WARN";
    result.Message = "Could not close Harness for Coverage view: " + ...
        string(ME.message);
    st_log(cfg, 'WARN', ...
        ['Coverage-view Harness close failed | Harness=%s | %s: %s | ' ...
         'elapsed=%.3f sec'], ...
        harnessName, ME.identifier, ME.message, toc(timer));
end
end


function value = append_status_message(current, added)
if strlength(current) == 0
    value = added;
else
    value = current + " | " + added;
end
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


function manifest = build_target_manifest( ...
        runId, order, row, targetDirectory, cvfPath, cvfHash, ...
        cvfRuleCount, generationStatus, applyStatus, restoreStatus, ...
        initialOutcome, finalOutcome, ...
        initialReport, finalReport, rerunPerformed, updatedCount, ...
        status, message, startedAt, completedAt, durationSec, reportMode, ...
        existingFilterPolicy, managedFilterApplication)
manifest = struct( ...
    'Version', 2, ...
    'RunId', runId, ...
    'Order', order, ...
    'No', double(row.No), ...
    'CUTName', char(string(row.CUTName)), ...
    'CUTPath', char(string(row.CUTPath)), ...
    'TestCaseName', char(string(row.TestCaseName)), ...
    'ExpectedUpdateMode', char(string(row.ExpectedUpdateMode)), ...
    'CoverageFilterMode', char(string(row.CoverageFilterMode)), ...
    'CoverageFilterAction', char(string(row.CoverageFilterAction)), ...
    'CoverageFilterRationale', char(string(row.CoverageFilterRationale)), ...
    'CoverageFilterFile', char(string(cvfPath)), ...
    'CoverageFilterSHA256', char(string(cvfHash)), ...
    'CoverageFilterRuleCount', double(cvfRuleCount), ...
    'CoverageFilterApplicationMode', 'RUNTIME', ...
    'CoverageFilterExistingPolicy', existingFilterPolicy, ...
    'ManagedFilterApplication', managedFilterApplication, ...
    'FilterGenerationStatus', char(string(generationStatus)), ...
    'FilterApplyStatus', char(string(applyStatus)), ...
    'FilterRestoreStatus', char(string(restoreStatus)), ...
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
fprintf(fileId, '%s\t%d\t%s\t%s\n', ...
    timestamp_text(), order, char(string(event)), message);
end


function value = timestamp_text()
value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
end
