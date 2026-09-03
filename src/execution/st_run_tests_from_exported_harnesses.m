function [results, updates, summary] = ...
        st_run_tests_from_exported_harnesses(varargin)
%ST_RUN_TESTS_FROM_EXPORTED_HARNESSES Run standalone Harness model SUTs.

p = inputParser;
p.FunctionName = mfilename;
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
if ~strcmp(st_coverage_filter_application_mode( ...
        cfg.CoverageFilterApplicationMode), 'RUNTIME')
    error('simtest:StandaloneModelRequiresTransientFilters', ...
        'EXPORTED_MODEL requires CoverageFilterApplicationMode=RUNTIME.');
end
T = st_load_targets(cfg.OnlyEnabled);
n = height(T);
if n == 0
    error('simtest:StandaloneNoTargets', ...
        'EXPORTED_MODEL execution requires at least one enabled target.');
end
sourceSession = capture_source_session(cfg);
sourceSessionCleanup = onCleanup(@() ...
    restore_source_session_quiet(sourceSession, cfg)); %#ok<NASGU>
[runId, runDirectory] = create_run_directory(cfg.StandaloneRunRootDir);
mkdir(fullfile(runDirectory, 'targets'));
mkdir(fullfile(runDirectory, 'logs'));
mkdir(fullfile(runDirectory, 'test_manager'));
testFilePath = fullfile(runDirectory, 'test_manager', ...
    'StandaloneHarnessTests.mldatx');
logPath = fullfile(runDirectory, 'logs', 'execution.log');
startedAt = timestamp_text();

st_log(cfg, 'INFO', ...
    ['Standalone model execution start | targets=%d | report=%s | ' ...
     'run=%s'], n, reportMode, runId);
sourceBefore = source_state(cfg);
applyRows = T(T.ExpectedUpdateMode == "APPLY", :);
if ~isempty(applyRows)
    st_prepare_expected_value_harness_logging(cfg, applyRows);
end
sourcePrepared = source_state(cfg);

results = repmat(struct('No', NaN, 'TestCaseName', '', ...
    'InitialResult', [], 'FinalResult', [], ...
    'RerunPerformed', false), n, 1);
for resultIndex = 1:n
    results(resultIndex).No = double(T.No(resultIndex));
    results(resultIndex).TestCaseName = char(T.TestCaseName(resultIndex));
end
updates = table();
coverage = table();
artifacts = empty_artifact_table();
modelInfos = repmat(empty_model_info(), n, 1);
finalModelInfos = repmat(empty_model_info(), n, 1);
prepareStatus = repmat("NOT_RUN", n, 1);
prepareMessage = strings(n,1);
testCases = cell(n,1);

No = double(T.No);
CUTName = string(T.CUTName);
CUTPath = string(T.CUTPath);
TestCaseName = string(T.TestCaseName);
FilterMode = string(T.CoverageFilterMode);
InitialModel = strings(n,1);
FinalModel = strings(n,1);
InitialHarnessCVF = strings(n,1);
InitialTargetCVF = strings(n,1);
FinalHarnessCVF = strings(n,1);
FinalTargetCVF = strings(n,1);
InitialHarnessRuleCount = zeros(n,1);
InitialTargetRuleCount = zeros(n,1);
FinalHarnessRuleCount = zeros(n,1);
FinalTargetRuleCount = zeros(n,1);
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

% Export all initial SUTs before the Test File is built. Failures remain
% target-local and are omitted from the run-local Test Manager hierarchy.
for i = 1:n
    targetDirectory = st_per_cut_target_directory(runDirectory, T(i,:));
    if ~isfolder(targetDirectory), mkdir(targetDirectory); end
    try
        modelInfos(i) = st_prepare_standalone_harness_model( ...
            T(i,:), 'INITIAL', targetDirectory, cfg);
        InitialModel(i) = string(modelInfos(i).ModelPath);
        prepareStatus(i) = "OK";
        artifacts = record_file(artifacts, No(i), "INITIAL", ...
            "MODEL", modelInfos(i).ModelPath, "OK", ...
            "Standalone Harness model");
    catch ME
        prepareStatus(i) = "FAIL";
        prepareMessage(i) = string(ME.message);
        Status(i) = "FAIL";
        Message(i) = "Initial standalone model preparation failed: " + ...
            string(ME.message);
        st_log(cfg, 'ERROR', ...
            '[STANDALONE %d/%d] initial preparation failed | %s: %s', ...
            i, n, ME.identifier, ME.message);
    end
end

valid = prepareStatus == "OK";
if any(valid)
    validRows = find(valid);
    [tf, validCases, testManagerResult] = ...
        st_create_standalone_test_manager( ...
        T(valid,:), modelInfos(valid), testFilePath, cfg);
    for j = 1:numel(validRows)
        index = validRows(j);
        if testManagerResult.Status(j) == "OK"
            testCases{index} = validCases{j};
        else
            Status(index) = "FAIL";
            Message(index) = "Standalone Test Manager failed: " + ...
                testManagerResult.Message(j);
        end
    end
    artifacts = record_file(artifacts, 0, "ROOT", "TEST_FILE", ...
        testFilePath, "OK", "Run-local standalone Test File");
    st_prepare_expected_value_test_file_logging(cfg, tf, T(valid,:));
else
    tf = [];
end

abortError = [];
for i = 1:n
    rowTimer = tic;
    StartedAt(i) = timestamp_text();
    row = T(i,:);
    targetDirectory = st_per_cut_target_directory(runDirectory, row);
    manifestPath = fullfile(targetDirectory, 'target-manifest.json');
    TargetManifest(i) = string(manifestPath);
    initialFilter = struct();
    finalFilter = struct();
    initialInfo = struct();
    finalInfo = struct();
    targetError = [];
    session = [];
    sessionCreated = false;
    restoreSucceeded = false;

    append_event(logPath, i, 'TARGET_START', char(TestCaseName(i)));
    st_log(cfg, 'INFO', ...
        '[STANDALONE %d/%d] start | CUT=%s | TestCase=%s', ...
        i, n, char(CUTName(i)), char(TestCaseName(i)));
    try
        if prepareStatus(i) ~= "OK"
            error('simtest:StandaloneInitialPreparationFailed', '%s', ...
                char(prepareMessage(i)));
        end
        if isempty(testCases{i})
            error('simtest:StandaloneTestCaseUnavailable', '%s', ...
                char(Message(i)));
        end
        tc = testCases{i};
        initialFilter = st_generate_standalone_coverage_filters( ...
            modelInfos(i).ModelPath, row, ...
            fullfile(targetDirectory, 'initial', 'filters'), cfg);
        [InitialHarnessCVF(i), InitialTargetCVF(i), ...
            InitialHarnessRuleCount(i), InitialTargetRuleCount(i)] = ...
            filter_columns(initialFilter);
        artifacts = record_filter_artifacts(artifacts, No(i), ...
            "INITIAL", initialFilter);

        [cleanupObj, applyResult, session] = ...
            st_apply_test_case_coverage_filters( ...
            tf, tc, row, cfg, ...
            'FilterFileSets', {initialFilter.Files}, ...
            'ExistingFilterPolicy', 'MERGE', ...
            'ApplyManagedFiltersDuringRun', true); %#ok<NASGU>
        sessionCreated = true;
        FilterApplyStatus(i) = string(applyResult.Status(1));
        if applyResult.Status(1) ~= "OK" || ...
                applyResult.AppliedFilterCount(1) < ...
                numel(initialFilter.Files)
            error('simtest:StandaloneCoverageFilterApplyFailed', ...
                'Not every standalone CVF was applied to %s.', ...
                char(TestCaseName(i)));
        end

        append_event(logPath, i, 'RUN_INITIAL_START', ...
            modelInfos(i).ModelPath);
        initialResult = run_model_test_case(tc, modelInfos(i), cfg);
        append_event(logPath, i, 'RUN_INITIAL_DONE', ...
            char(TestCaseName(i)));
        results(i).No = No(i);
        results(i).TestCaseName = char(TestCaseName(i));
        results(i).InitialResult = initialResult;
        results(i).FinalResult = initialResult;
        InitialOutcome(i) = result_outcome(initialResult, row, 'INITIAL');
        FinalOutcome(i) = InitialOutcome(i);
        validate_verify_timing(initialResult, 'initial');

        [restoreSucceeded, restoreText] = restore_filter_session(session);
        FilterRestoreStatus(i) = restoreText;
        clear cleanupObj;
        if ~restoreSucceeded
            error('simtest:CoverageFilterRestoreFailed', ...
                'Initial standalone CVF restoration failed.');
        end
        sessionCreated = false;

        initialInfo = export_phase_result(initialResult, row, modelInfos(i), ...
            fullfile(targetDirectory, 'initial'), ...
            TestCaseName(i) + " initial", 'INITIAL', reportMode, cfg);
        InitialReport(i) = string(initialInfo.Summary);
        artifacts = append_artifacts(artifacts, No(i), ...
            "INITIAL", initialInfo.Artifacts);
        coverage = append_table(coverage, initialInfo.Coverage);
        if ~strcmp(initialInfo.Status, 'OK')
            error('simtest:StandaloneInitialReportFailed', ...
                'Initial report is incomplete: %s', initialInfo.Summary);
        end
        snapshot_test_file(tf, testFilePath, ...
            fullfile(targetDirectory, 'initial', 'test_manager'));

        if row.ExpectedUpdateMode == "APPLY"
            updateResult = st_update_expected_from_results( ...
                initialResult, row);
            if ~isempty(updateResult)
                updateResult = renamevars(updateResult, 'No', 'TargetNo');
                updates = append_table(updates, updateResult);
                ExpectedUpdatedCount(i) = sum(updateResult.UpdatedCount);
                if any(string(updateResult.Status) == "FAIL")
                    error('simtest:StandaloneExpectedUpdateFailed', ...
                        'Expected-value update failed for %s.', ...
                        char(TestCaseName(i)));
                end
            end
        end

        if ExpectedUpdatedCount(i) > 0 && cfg.RerunAfterExpectedUpdate
            finalModel = st_prepare_standalone_harness_model( ...
                row, 'FINAL', targetDirectory, cfg);
            finalModelInfos(i) = finalModel;
            FinalModel(i) = string(finalModel.ModelPath);
            artifacts = record_file(artifacts, No(i), "FINAL", ...
                "MODEL", finalModel.ModelPath, "OK", ...
                "Re-exported model after expected update");
            st_bind_standalone_test_case(tc, finalModel, cfg);
            saveToFile(tf);
            finalFilter = st_generate_standalone_coverage_filters( ...
                finalModel.ModelPath, row, ...
                fullfile(targetDirectory, 'final', 'filters'), cfg);
            [FinalHarnessCVF(i), FinalTargetCVF(i), ...
                FinalHarnessRuleCount(i), FinalTargetRuleCount(i)] = ...
                filter_columns(finalFilter);
            artifacts = record_filter_artifacts(artifacts, No(i), ...
                "FINAL", finalFilter);

            [finalCleanup, finalApply, session] = ...
                st_apply_test_case_coverage_filters( ...
                tf, tc, row, cfg, ...
                'FilterFileSets', {finalFilter.Files}, ...
                'ExistingFilterPolicy', 'MERGE', ...
                'ApplyManagedFiltersDuringRun', true); %#ok<NASGU>
            sessionCreated = true;
            FilterApplyStatus(i) = string(finalApply.Status(1));
            if finalApply.Status(1) ~= "OK" || ...
                    finalApply.AppliedFilterCount(1) < ...
                    numel(finalFilter.Files)
                error('simtest:StandaloneCoverageFilterApplyFailed', ...
                    'Not every final standalone CVF was applied.');
            end
            append_event(logPath, i, 'RUN_FINAL_START', ...
                finalModel.ModelPath);
            finalResult = run_model_test_case(tc, finalModel, cfg);
            append_event(logPath, i, 'RUN_FINAL_DONE', ...
                char(TestCaseName(i)));
            results(i).FinalResult = finalResult;
            results(i).RerunPerformed = true;
            RerunPerformed(i) = true;
            FinalOutcome(i) = result_outcome(finalResult, row, 'FINAL');
            validate_verify_timing(finalResult, 'final');

            [restoreSucceeded, restoreText] = ...
                restore_filter_session(session);
            FilterRestoreStatus(i) = restoreText;
            clear finalCleanup;
            if ~restoreSucceeded
                error('simtest:CoverageFilterRestoreFailed', ...
                    'Final standalone CVF restoration failed.');
            end
            sessionCreated = false;
            finalInfo = export_phase_result(finalResult, row, finalModel, ...
                fullfile(targetDirectory, 'final'), ...
                TestCaseName(i) + " final", 'FINAL', reportMode, cfg);
            FinalReport(i) = string(finalInfo.Summary);
            artifacts = append_artifacts(artifacts, No(i), ...
                "FINAL", finalInfo.Artifacts);
            coverage = append_table(coverage, finalInfo.Coverage);
            if ~strcmp(finalInfo.Status, 'OK')
                error('simtest:StandaloneFinalReportFailed', ...
                    'Final report is incomplete: %s', finalInfo.Summary);
            end
            snapshot_test_file(tf, testFilePath, ...
                fullfile(targetDirectory, 'final', 'test_manager'));
        end

        if upper(FinalOutcome(i)) == "PASSED"
            Status(i) = "PASS";
            Message(i) = "Standalone model Test Case completed";
        else
            Status(i) = "WARN";
            Message(i) = "Execution completed; final outcome is " + ...
                FinalOutcome(i);
        end
    catch ME
        targetError = ME;
        if sessionCreated
            try
                [restoreSucceeded, restoreText] = ...
                    restore_filter_session(session);
                FilterRestoreStatus(i) = restoreText;
                sessionCreated = false;
            catch restoreME
                targetError = addCause(restoreME, ME);
                abortError = targetError;
                FilterRestoreStatus(i) = "FAIL";
            end
        elseif FilterRestoreStatus(i) == "NOT_RUN"
            FilterRestoreStatus(i) = "NOT_REQUIRED";
        end
        if strcmp(ME.identifier, 'simtest:CoverageFilterRestoreFailed') || ...
                strcmp(ME.identifier, ...
                'simtest:StandaloneExecutionCleanupFailed') || ...
                strcmp(ME.identifier, 'simtest:StandaloneModelShadowing')
            abortError = targetError;
        end
        Status(i) = "FAIL";
        Message(i) = string(targetError.message);
        append_event(logPath, i, 'TARGET_FAIL', targetError.message);
        st_log(cfg, 'ERROR', ...
            '[STANDALONE %d/%d] failed | %s: %s', ...
            i, n, targetError.identifier, targetError.message);
        if isempty(abortError) && ~continueOnFailure
            abortError = targetError;
        end
    end

    DurationSec(i) = toc(rowTimer);
    CompletedAt(i) = timestamp_text();
    targetManifest = build_target_manifest(runId, i, row, ...
        modelInfos(i), finalModelInfos(i), initialFilter, finalFilter, ...
        InitialOutcome(i), ...
        FinalOutcome(i), RerunPerformed(i), ExpectedUpdatedCount(i), ...
        FilterApplyStatus(i), FilterRestoreStatus(i), Status(i), ...
        Message(i), StartedAt(i), CompletedAt(i), DurationSec(i));
    try
        st_write_json_atomic(manifestPath, targetManifest);
        artifacts = record_file(artifacts, No(i), "TARGET", ...
            "MANIFEST", manifestPath, "OK", "Target manifest");
    catch manifestME
        Status(i) = "FAIL";
        Message(i) = "Target manifest write failed: " + ...
            string(manifestME.message);
        if isempty(abortError) && ~continueOnFailure
            abortError = manifestME;
        end
    end
    append_event(logPath, i, 'TARGET_COMPLETE', char(Status(i)));
    if ~isempty(abortError), break; end
end

processed = strlength(CompletedAt) > 0;
Status(~processed) = "SKIP";
Message(~processed) = "Not executed after unsafe cleanup failure";
sourceAfter = source_state(cfg);
try
    restore_source_session(sourceSession, cfg);
    clear sourceSessionCleanup;
catch restoreME
    lastProcessed = find(processed, 1, 'last');
    if isempty(lastProcessed), lastProcessed = 1; end
    Status(lastProcessed) = "FAIL";
    Message(lastProcessed) = "Source model session restore failed: " + ...
        string(restoreME.message);
    abortError = restoreME;
end
sourceState = compare_source_state(sourceBefore, sourcePrepared, ...
    sourceAfter, sum(ExpectedUpdatedCount), ...
    any(T.ExpectedUpdateMode == "APPLY"));
[externalSafe, externalMessage] = ...
    execution_dependencies_unchanged(modelInfos);
sourceState.ExecutionDependenciesUnchanged = externalSafe;
sourceState.ExecutionDependenciesMessage = externalMessage;
sourceState.Safe = sourceState.Safe && externalSafe;
if ~externalSafe
    sourceState.Message = sourceState.Message + " | " + externalMessage;
end
if ~sourceState.Safe
    Status(find(processed, 1, 'last')) = "FAIL";
    Message(find(processed, 1, 'last')) = sourceState.Message;
    abortError = MException('simtest:StandaloneSourceStateChanged', ...
        '%s', sourceState.Message);
end

targets = table(No, CUTName, CUTPath, TestCaseName, FilterMode, ...
    InitialModel, FinalModel, InitialHarnessCVF, InitialTargetCVF, ...
    FinalHarnessCVF, FinalTargetCVF, InitialHarnessRuleCount, ...
    InitialTargetRuleCount, FinalHarnessRuleCount, FinalTargetRuleCount, ...
    InitialOutcome, FinalOutcome, InitialReport, FinalReport, ...
    RerunPerformed, ExpectedUpdatedCount, FilterApplyStatus, ...
    FilterRestoreStatus, Status, Message, DurationSec, StartedAt, ...
    CompletedAt, TargetManifest);
if isfile(logPath)
    artifacts = record_file(artifacts, 0, "ROOT", "LOG", ...
        logPath, "OK", "Standalone execution log");
end
summary = st_write_standalone_run_report(runId, runDirectory, ...
    targets, coverage, artifacts, cfg, startedAt, timestamp_text(), ...
    reportMode, sourceState);
summary.Targets = targets;
st_log(cfg, 'INFO', ...
    'Standalone model execution complete | status=%s | run=%s', ...
    summary.Status, runId);

if ~isempty(abortError)
    abortError = addCause(abortError, MException( ...
        'simtest:StandaloneRunReportWritten', ...
        'Partial standalone report was written to %s.', summary.Manifest));
    throw(abortError);
end
nonPass = ismember(Status, ["FAIL","WARN"]);
if failOnNonPass && any(nonPass)
    error('simtest:StandaloneRunFailed', ...
        '%d CUT(s) did not pass. Results: %s', ...
        sum(nonPass), summary.Manifest);
end
end

function info = export_phase_result(resultObj, row, modelInfo, directory, ...
        label, phase, reportMode, cfg)
modelDirectory = fileparts(modelInfo.ModelPath);
addpath(modelDirectory, '-begin');
pathCleanup = onCleanup(@() remove_path_quiet(modelDirectory)); %#ok<NASGU>
load_system(modelInfo.ModelPath);
modelCleanup = onCleanup(@() close_model_quiet(modelInfo.ModelName)); %#ok<NASGU>
actual = get_param(modelInfo.ModelName, 'FileName');
if ~same_path(actual, modelInfo.ModelPath)
    error('simtest:StandaloneReportModelShadowing', ...
        'Report preparation loaded a different standalone model: %s', actual);
end
info = st_export_result_set_report(resultObj, row, directory, ...
    char(label), 'CoverageReportMode', reportMode, ...
    'IncludeOfficialReport', strcmp(reportMode, 'FULL'), ...
    'IncludePortableCoverageDetail', true, ...
    'LogConfig', cfg, 'ResultLabel', phase, ...
    'CoverageTargetPaths', string(modelInfo.ExportedCUTPath));
end

function remove_path_quiet(directory)
try, rmpath(directory); catch, end
end

function close_model_quiet(modelName)
if bdIsLoaded(modelName), close_system(modelName, 0); end
end

function resultObj = run_model_test_case(tc, modelInfo, cfg)
directory = fileparts(modelInfo.ModelPath);
locations = which(modelInfo.ModelName, '-all');
if ischar(locations), locations = {locations}; end
for i = 1:numel(locations)
    if ~same_path(locations{i}, modelInfo.ModelPath)
        error('simtest:StandaloneModelShadowing', ...
            'Standalone model is shadowed: %s', locations{i});
    end
end
addpath(directory, '-begin');
runError = [];
cleanupError = [];
try
    st_log(cfg, 'DEBUG', ...
        'run(testCase) standalone start | Model=%s | TestCase=%s', ...
        modelInfo.ModelName, char(tc.Name));
    resultObj = run(tc);
    st_log(cfg, 'DEBUG', ...
        'run(testCase) standalone complete | Model=%s', ...
        modelInfo.ModelName);
catch ME
    runError = ME;
    resultObj = [];
end
try
    if bdIsLoaded(modelInfo.ModelName)
        close_system(modelInfo.ModelName, 0);
    end
    if bdIsLoaded(modelInfo.ModelName)
        error('simtest:StandaloneModelUnloadFailed', ...
            'Standalone model remained loaded: %s', modelInfo.ModelName);
    end
    rmpath(directory);
catch ME
    cleanupError = ME;
end
if ~isempty(cleanupError)
    combined = MException('simtest:StandaloneExecutionCleanupFailed', ...
        'Standalone model/path cleanup failed: %s', cleanupError.message);
    combined = addCause(combined, cleanupError);
    if ~isempty(runError), combined = addCause(combined, runError); end
    throw(combined);
end
if ~isempty(runError), rethrow(runError); end
end

function [ok, status] = restore_filter_session(session)
restoreResult = session.Restore();
ok = all(string(restoreResult.Status) == "OK");
if ok, status = "OK"; else, status = "FAIL"; end
end

function snapshot_test_file(tf, source, destination)
if ~isfolder(destination), mkdir(destination); end
saveToFile(tf);
[ok, message] = copyfile(source, ...
    fullfile(destination, 'StandaloneHarnessTests.mldatx'), 'f');
if ~ok
    error('simtest:StandaloneTestFileSnapshotFailed', ...
        'Cannot snapshot Test File: %s', message);
end
end

function [harnessPath, targetPath, harnessCount, targetCount] = ...
        filter_columns(info)
harnessPath = string(info.Harness.Path);
targetPath = string(info.Target.Path);
harnessCount = info.Harness.RuleCount;
targetCount = info.Target.RuleCount;
end

function artifacts = record_filter_artifacts(artifacts, no, phase, info)
artifacts = record_file(artifacts, no, phase, "HARNESS_CVF", ...
    info.Harness.Path, info.Harness.Status, ...
    "Harness infrastructure coverage filter");
if strcmp(info.Target.Status, 'OK')
    artifacts = record_file(artifacts, no, phase, "TARGET_CVF", ...
        info.Target.Path, info.Target.Status, ...
        "CUT direct-child coverage policy filter");
end
end

function manifest = build_target_manifest(runId, order, row, modelInfo, ...
        finalModelInfo, initialFilter, finalFilter, initialOutcome, ...
        finalOutcome, rerun, ...
        updateCount, applyStatus, restoreStatus, status, message, ...
        startedAt, completedAt, duration)
manifest = struct( ...
    'Version', 1, 'RunId', runId, 'Order', order, ...
    'No', double(row.No), 'CUTName', char(row.CUTName), ...
    'CUTPath', char(row.CUTPath), ...
    'TestCaseName', char(row.TestCaseName), ...
    'SystemUnderTestMode', 'EXPORTED_MODEL', ...
    'ExpectedUpdateMode', char(row.ExpectedUpdateMode), ...
    'CoverageFilterMode', char(row.CoverageFilterMode), ...
    'CoverageFilterAction', char(row.CoverageFilterAction), ...
    'CoverageFilterRationale', char(row.CoverageFilterRationale), ...
    'InitialModel', modelInfo, ...
    'FinalModel', finalModelInfo, ...
    'InitialFilters', initialFilter, 'FinalFilters', finalFilter, ...
    'InitialOutcome', char(initialOutcome), ...
    'FinalOutcome', char(finalOutcome), ...
    'RerunPerformed', logical(rerun), ...
    'ExpectedUpdatedCount', double(updateCount), ...
    'FilterApplyStatus', char(applyStatus), ...
    'FilterRestoreStatus', char(restoreStatus), ...
    'Status', char(status), 'Message', char(message), ...
    'StartedAt', startedAt, 'CompletedAt', completedAt, ...
    'DurationSec', duration);
end

function state = source_state(cfg)
state = struct( ...
    'ModelSHA256', signature_hash(cfg.ModelFile), ...
    'TestFileSHA256', signature_hash(cfg.TestFile), ...
    'ManagementExcelSHA256', signature_hash(cfg.ManagementExcel));
end

function value = signature_hash(path)
signature = st_file_signature(path);
if signature.Exists, value = signature.SHA256; else, value = ''; end
end

function state = compare_source_state( ...
        before, prepared, after, updateCount, applyConfigured)
testFileSame = strcmp(before.TestFileSHA256, after.TestFileSHA256);
excelSame = strcmp(before.ManagementExcelSHA256, ...
    after.ManagementExcelSHA256);
modelSame = strcmp(before.ModelSHA256, after.ModelSHA256);
preparedSame = strcmp(prepared.ModelSHA256, after.ModelSHA256);
if ~applyConfigured
    modelAllowed = modelSame;
elseif updateCount > 0
    modelAllowed = true;
else
    modelAllowed = preparedSame;
end
safe = testFileSame && excelSame && modelAllowed;
if safe
    message = ['Source assets unchanged except approved APPLY logging/' ...
        'expected updates'];
else
    message = sprintf(['Unexpected source change: modelSame=%d, ' ...
        'testFileSame=%d, excelSame=%d, expectedUpdates=%d'], ...
        modelSame, testFileSame, excelSame, updateCount);
end
state = struct('ModelBefore', before.ModelSHA256, ...
    'ModelAfterLoggingPreparation', prepared.ModelSHA256, ...
    'ModelAfter', after.ModelSHA256, ...
    'TestFileBefore', before.TestFileSHA256, ...
    'TestFileAfter', after.TestFileSHA256, ...
    'ManagementExcelBefore', before.ManagementExcelSHA256, ...
    'ManagementExcelAfter', after.ManagementExcelSHA256, ...
    'ExpectedUpdatedCount', updateCount, 'Safe', safe, ...
    'Message', message);
end

function [safe, message] = execution_dependencies_unchanged(models)
safe = true;
messages = strings(0,1);
for i = 1:numel(models)
    inputRecords = models(i).InputSignatures;
    for j = 1:numel(inputRecords)
        current = st_file_signature(inputRecords(j).Source);
        if ~current.Exists || ...
                ~strcmp(current.SHA256, inputRecords(j).SourceSHA256)
            safe = false;
            messages(end+1,1) = "Input changed: " + ... %#ok<AGROW>
                string(inputRecords(j).Source);
        end
    end
    references = models(i).Dependencies.ReferencedModels;
    for j = 1:numel(references)
        if ~dependency_record_matches(references(j))
            safe = false;
            messages(end+1,1) = "Referenced model changed: " + ... %#ok<AGROW>
                string(references(j).Path);
        end
    end
    dictionary = models(i).Dependencies.DataDictionary;
    if ~dependency_record_matches(dictionary)
        safe = false;
        messages(end+1,1) = "Data dictionary changed: " + ... %#ok<AGROW>
            string(dictionary.Path);
    end
end
if safe
    message = "Input and external dependency checksums are unchanged";
else
    message = strjoin(unique(messages, 'stable'), ' | ');
end
end

function matches = dependency_record_matches(record)
if isempty(record) || ~isstruct(record), matches = true; return; end
path = char(string(record.Path));
current = st_file_signature(path);
matches = logical(current.Exists) == logical(record.Exists);
if matches && logical(record.Exists)
    matches = strcmp(current.SHA256, char(string(record.SHA256)));
end
end

function model = empty_model_info()
model = struct('Phase', '', 'ModelName', '', 'ModelPath', '', ...
    'ModelSHA256', '', 'ExportedCUTPath', '', 'ExportedCUTSID', '', ...
    'InputCount', 0, 'OutputCount', 0, ...
    'Inputs', struct('SignalEditor', '', 'EffectiveSldv', '', ...
        'SourceSldv', '', 'SourceSignalEditor', '', ...
        'SourceEffectiveSldv', '', 'SourceSourceSldv', ''), ...
    'InputSignatures', repmat(struct('Type', '', 'Source', '', ...
        'Copy', '', 'SourceSHA256', '', 'CopySHA256', '', ...
        'Match', false), 0, 1), ...
    'Dependencies', struct('Model', '', ...
        'ReferencedModels', repmat(struct('Name', '', 'Path', '', ...
            'Exists', false, 'SHA256', ''), 0, 1), ...
        'DataDictionary', struct('Name', '', 'Path', '', ...
            'Exists', false, 'SHA256', ''), ...
        'CustomCodeSettings', strings(0,1)), 'Status', '');
end

function [runId, directory] = create_run_directory(root)
if ~isfolder(root), mkdir(root); end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
uuid = char(java.util.UUID.randomUUID());
runId = sprintf('%s_%s', stamp, uuid(1:8));
directory = fullfile(root, runId);
mkdir(directory);
end

function artifacts = empty_artifact_table()
artifacts = table(zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','Stage','Type','Path','Status','Message'});
end

function artifacts = record_file(artifacts, no, stage, type, path, ...
        status, message)
artifacts(end+1,:) = {no, string(stage), string(type), string(path), ...
    string(status), string(message)};
end

function artifacts = append_artifacts(artifacts, no, stage, source)
for i = 1:height(source)
    artifacts(end+1,:) = {no, string(stage), string(source.Type(i)), ...
        string(source.Path(i)), string(source.Status(i)), ...
        string(source.Message(i))};
end
end

function output = append_table(output, value)
if isempty(value), return; end
if isempty(output), output = value; else, output = [output; value]; end
end

function validate_verify_timing(resultObj, phase)
R = st_validate_sldv_verify_results(resultObj);
if ~isempty(R) && any(string(R.Status) == "FAIL")
    error('simtest:StandaloneVerifyTimingFailed', ...
        'SLDV verify timing failed during %s.', phase);
end
end

function outcome = result_outcome(resultObj, row, label)
[R, ~] = st_collect_test_result_summary(resultObj, row, label);
if isempty(R), outcome = "UNKNOWN"; else, outcome = upper(string(R.Outcome(end))); end
end

function append_event(path, order, event, detail)
fileId = fopen(path, 'a', 'n', 'UTF-8');
if fileId < 0, return; end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '%s\t%d\t%s\t%s\n', timestamp_text(), order, ...
    event, strrep(char(string(detail)), sprintf('\n'), ' '));
end

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end

function state = capture_source_session(cfg)
state = struct('WasLoaded', bdIsLoaded(cfg.TopModel), ...
    'WasOpen', false, ...
    'Harnesses', repmat(struct('Owner', '', 'Name', ''), 0, 1));
if ~state.WasLoaded, return; end
if strcmp(get_param(cfg.TopModel, 'Dirty'), 'on')
    error('simtest:StandaloneUnsavedSourceModel', ...
        'Save the source model before standalone execution: %s', ...
        cfg.TopModel);
end
try
    state.WasOpen = strcmp(get_param(cfg.TopModel, 'Open'), 'on');
catch
end
harnesses = sltest.harness.find(cfg.TopModel, 'OpenOnly', 'on');
for i = 1:numel(harnesses)
    name = char(harnesses(i).name);
    if bdIsLoaded(name) && strcmp(get_param(name, 'Dirty'), 'on')
        error('simtest:StandaloneUnsavedHarness', ...
            'Save the open Harness before standalone execution: %s', name);
    end
    state.Harnesses(end+1,1) = struct( ... %#ok<AGROW>
        'Owner', char(harnesses(i).ownerFullPath), 'Name', name);
end
end

function restore_source_session(state, cfg)
if bdIsLoaded(cfg.TopModel)
    current = sltest.harness.find(cfg.TopModel, 'OpenOnly', 'on');
    for i = 1:numel(current)
        sltest.harness.close(char(current(i).ownerFullPath), ...
            char(current(i).name));
    end
    close_system(cfg.TopModel, 0);
end
if ~state.WasLoaded
    if bdIsLoaded(cfg.TopModel)
        error('simtest:StandaloneSourceModelUnloadFailed', ...
            'Source model remained loaded: %s', cfg.TopModel);
    end
    return;
end
load_system(cfg.ModelFile);
actual = get_param(cfg.TopModel, 'FileName');
if ~same_path(actual, cfg.ModelFile)
    error('simtest:StandaloneSourceModelRestoreMismatch', ...
        'A different source model was restored: %s', actual);
end
if state.WasOpen, open_system(cfg.TopModel); end
for i = 1:numel(state.Harnesses)
    sltest.harness.open(state.Harnesses(i).Owner, ...
        state.Harnesses(i).Name);
end
end

function restore_source_session_quiet(state, cfg)
try
    restore_source_session(state, cfg);
catch ME
    warning('simtest:StandaloneSourceSessionRestoreFailed', ...
        'Fallback source session restoration failed: %s', ME.message);
end
end

function tf = same_path(left, right)
left = char(java.io.File(char(left)).getCanonicalPath());
right = char(java.io.File(char(right)).getCanonicalPath());
if ispc, tf = strcmpi(left, right); else, tf = strcmp(left, right); end
end
