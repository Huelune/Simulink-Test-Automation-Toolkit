function checks = st_run_verification_fixture( ...
        options, runDirectory, workspaceDirectory)
%ST_RUN_VERIFICATION_FIXTURE Build and certify disposable automation inputs.

checks = st_empty_verification_checks();
projectRoot = st_project_root();
fixtureRoot = fullfile(workspaceDirectory, 'fixture');
prepare_project_copy(projectRoot, fixtureRoot);

oldPath = path;
oldDirectory = pwd;
cleanup = onCleanup(@() restore_environment( ...
    oldDirectory, oldPath, 'ST_VerificationModel', fixtureRoot)); %#ok<NASGU>
cd(fixtureRoot);
addpath(fullfile(fixtureRoot, 'tests', 'fixtures'), '-begin');

started = timestamp_text(); timerValue = tic;
fixture = st_build_verification_fixture(fixtureRoot);
checks = append(checks, row('FIXTURE.BUILD', 'CORE', options, ...
    'PASS', 'Disposable SLX, XLSX, and runtime target were generated', ...
    fixture.ModelFile, toc(timerValue), started));

addpath(fixtureRoot, '-begin');
clear st_setup st_config st_project_root st_require_runtime_target
st_setup();

started = timestamp_text(); timerValue = tic;
try
    [finalResult, updateResult, workflowResult, reportInfo] = ...
        st_run_from_harness('PreparationMode', 'FORCE', ...
        'FromStage', 'START');
    checks = append(checks, row('CERTIFY.FIXTURE.FORCE', 'EXECUTION', ...
        options, 'PASS', 'FORCE workflow completed', ...
        reportInfo.RunDirectory, toc(timerValue), started));
catch ME
    checks = append(checks, exception_row( ...
        'CERTIFY.FIXTURE.FORCE', 'EXECUTION', options, ME, ...
        fixtureRoot, toc(timerValue), started));
    return;
end

cfg = st_require_runtime_target();
targets = st_load_targets(cfg.OnlyEnabled);
checks = [checks; inspect_fixture_configuration( ...
    cfg, targets, options, reportInfo)];
checks = [checks; inspect_fixture_results( ...
    finalResult, updateResult, targets, options, reportInfo)];
checks = [checks; inspect_fixture_coverage(options, reportInfo)];
checks = [checks; inspect_report_artifacts(options, reportInfo)];

started = timestamp_text(); timerValue = tic;
try
    [~, ~, cachedWorkflow, cachedReport] = ...
        st_run_from_harness('PreparationMode', 'AUTO');
    reused = any(cachedWorkflow.CachedCount > 0);
    testsReran = ~strcmp(cachedReport.RunId, reportInfo.RunId);
    status = pass_if(reused && testsReran);
    message = sprintf( ...
        'Cached preparation=%d, new test report=%d', reused, testsReran);
    checks = append(checks, row('CERTIFY.FIXTURE.CACHE_REUSE', ...
        'CACHE', options, status, message, cachedReport.RunDirectory, ...
        toc(timerValue), started));
catch ME
    checks = append(checks, exception_row( ...
        'CERTIFY.FIXTURE.CACHE_REUSE', 'CACHE', options, ME, ...
        fixtureRoot, toc(timerValue), started));
end

if strcmp(options.Profile, 'CERTIFY')
    checks = [checks; certify_sldv_file_mode(cfg, options)];
    checks = [checks; certify_corrupt_state(cfg, options)];
    checks = [checks; certify_partial_failure(cfg, options)];
    checks = [checks; certify_fixture_export(cfg, options, ...
        fullfile(workspaceDirectory, 'fixture_exports'))];
else
    checks = append(checks, row('CERTIFY.FIXTURE.EXHAUSTIVE', ...
        'CORE', options, 'SKIP', ...
        'Exhaustive recovery, FILE mode, and export checks require CERTIFY'));
end
end

function checks = inspect_fixture_configuration(cfg, targets, options, reportInfo)
checks = st_empty_verification_checks();
harnessCount = 0;
signalEditorCount = 0;
assessmentCount = 0;
for i = 1:height(targets)
    owner = st_normalize_cut_path(targets.CUTPath(i), cfg.TopModel);
    harnesses = sltest.harness.find(owner, ...
        'Name', char(targets.HarnessName(i)));
    harnessCount = harnessCount + numel(harnesses);
    if isempty(harnesses), continue; end
    sltest.harness.load(owner, char(targets.HarnessName(i)));
    try
        st_find_signal_editor_block(char(targets.HarnessName(i)));
        signalEditorCount = signalEditorCount + 1;
    catch
    end
    try
        st_find_assessment_block(char(targets.HarnessName(i)));
        assessmentCount = assessmentCount + 1;
    catch
    end
    try, sltest.harness.close(owner, char(targets.HarnessName(i))); catch, end
end
checks = append(checks, row('FIXTURE.HARNESS', 'HARNESS', options, ...
    pass_if(harnessCount == height(targets)), ...
    sprintf('%d/%d Harnesses exist', harnessCount, height(targets)), ...
    cfg.ModelFile));
checks = append(checks, row('FIXTURE.SIGNAL_EDITOR', 'SIGNAL_EDITOR', ...
    options, pass_if(signalEditorCount == height(targets)), ...
    sprintf('%d/%d Harness Signal Editors exist', ...
    signalEditorCount, height(targets)), cfg.ModelFile));
checks = append(checks, row('FIXTURE.ASSESSMENT', 'ASSESSMENT', options, ...
    pass_if(assessmentCount == height(targets)), ...
    sprintf('%d/%d Assessment blocks exist', ...
    assessmentCount, height(targets)), cfg.ModelFile));
checks = append(checks, row('FIXTURE.TEST_MANAGER', 'TEST_MANAGER', ...
    options, pass_if(isfile(cfg.TestFile)), ...
    'Test File, cases, iterations, and enabled scope were created', ...
    cfg.TestFile));

offIndex = find(targets.CUTName == "NoInportOff", 1);
offOwner = st_normalize_cut_path(targets.CUTPath(offIndex), cfg.TopModel);
offInputs = find_system(offOwner, 'SearchDepth', 1, ...
    'Type', 'Block', 'BlockType', 'Inport');
checks = append(checks, row('FIXTURE.NO_INPORT_SKIP', 'SIGNAL_EDITOR', ...
    options, pass_if(isempty(offInputs)), ...
    'OFF target has no direct Inport and uses the skip path', cfg.ModelFile));

manifestOk = isfile(cfg.SldvManifestFile);
if manifestOk
    loaded = load(cfg.SldvManifestFile, 'manifest');
    manifestOk = isfield(loaded, 'manifest') && ...
        any(strcmp({loaded.manifest.Profiles.Mode}, 'GENERATE'));
end
checks = append(checks, row('FIXTURE.SLDV.GENERATE', 'SLDV', options, ...
    pass_if(manifestOk), ...
    'GENERATE profile and reusable SLDV manifest were inspected', ...
    cfg.SldvManifestFile));
checks = append(checks, row('FIXTURE.REPORT_LINK', 'REPORTING', options, ...
    pass_if(isfield(reportInfo, 'RunDirectory') && ...
    isfolder(reportInfo.RunDirectory)), ...
    'Workflow is linked to an integrated report run', ...
    reportInfo.RunDirectory));
end

function checks = inspect_fixture_results( ...
        finalResult, updateResult, targets, options, reportInfo)
checks = st_empty_verification_checks();
updated = 0;
if ~isempty(updateResult) && ismember('UpdatedCount', ...
        updateResult.Properties.VariableNames)
    updated = sum(updateResult.UpdatedCount);
end
checks = append(checks, row('FIXTURE.EXPECTED_UPDATE.APPLY', ...
    'EXPECTED_UPDATE', options, pass_if(updated > 0), ...
    sprintf('%d expected-value line(s) updated before rerun', updated), ...
    reportInfo.RunDirectory));

[summary, ~] = st_collect_test_result_summary( ...
    finalResult, targets, 'FINAL');
allPassed = ~isempty(summary) && all(upper(summary.Outcome) == "PASSED");
checks = append(checks, row('FIXTURE.FINAL_PASS', 'EXECUTION', options, ...
    pass_if(allPassed), ...
    sprintf('%d/%d final Test Cases passed', ...
    sum(upper(summary.Outcome) == "PASSED"), height(summary)), ...
    reportInfo.RunDirectory));

offRows = updateResult([],:);
if ~isempty(updateResult) && ismember('No', ...
        updateResult.Properties.VariableNames)
    offNo = targets.No(targets.ExpectedUpdateMode == "OFF");
    offRows = updateResult(ismember(updateResult.No, offNo),:);
end
offUnchanged = isempty(offRows) || ...
    ~ismember('UpdatedCount', offRows.Properties.VariableNames) || ...
    all(offRows.UpdatedCount == 0);
checks = append(checks, row('FIXTURE.EXPECTED_UPDATE.OFF', ...
    'EXPECTED_UPDATE', options, pass_if(offUnchanged), ...
    'OFF target expected values were not updated', ...
    reportInfo.RunDirectory));
end

function checks = inspect_fixture_coverage(options, reportInfo)
checks = st_empty_verification_checks();
try
    coverage = readtable(reportInfo.Summary, 'Sheet', 'Coverage', ...
        'TextType', 'string', 'VariableNamingRule', 'preserve');
    selected = coverage.Run == "FINAL" & coverage.Total > 0 & ...
        ismember(coverage.Metric, ["Decision","Execution"]);
    metrics = unique(coverage.Metric(selected));
    complete = all(coverage.Percentage(selected) == 100) && ...
        all(ismember(["Decision"; "Execution"], metrics));
    checks = append(checks, row('FIXTURE.COVERAGE.100', 'COVERAGE', ...
        options, pass_if(complete), ...
        sprintf('%d non-empty final coverage row(s) inspected', ...
        sum(selected)), reportInfo.Summary));
    naRows = coverage.Total == 0 | coverage.PercentageText == "N/A";
    checks = append(checks, row('FIXTURE.COVERAGE.NA', 'COVERAGE', ...
        options, pass_if(all(isnan(coverage.Percentage(naRows)))), ...
        'Zero-denominator coverage is represented as N/A', ...
        reportInfo.Summary));
catch ME
    checks = append(checks, exception_row('FIXTURE.COVERAGE', ...
        'COVERAGE', options, ME, reportInfo.Summary));
end
end

function checks = inspect_report_artifacts(options, reportInfo)
checks = st_empty_verification_checks();
required = {reportInfo.Summary, reportInfo.Manifest, ...
    fullfile(reportInfo.RunDirectory, 'raw', 'InitialResults.mldatx'), ...
    fullfile(reportInfo.RunDirectory, 'raw', 'FinalResults.mldatx'), ...
    fullfile(reportInfo.RunDirectory, 'official', ...
    'InitialTestResults.pdf'), ...
    fullfile(reportInfo.RunDirectory, 'official', ...
    'FinalTestResults.pdf')};
exists = cellfun(@isfile, required);
coverageHtml = dir(fullfile(reportInfo.RunDirectory, ...
    'coverage', '*.html'));
complete = all(exists) && ~isempty(coverageHtml);
checks = append(checks, row('FIXTURE.REPORT.ARTIFACTS', 'REPORTING', ...
    options, pass_if(complete), ...
    sprintf('%d/%d required files and %d HTML report(s) exist', ...
    sum(exists), numel(exists), numel(coverageHtml)), ...
    reportInfo.RunDirectory));
end

function checks = certify_sldv_file_mode(cfg, options)
checks = st_empty_verification_checks();
started = timestamp_text(); timerValue = tic;
try
    loaded = load(cfg.SldvManifestFile, 'manifest');
    profiles = loaded.manifest.Profiles;
    index = find(strcmp({profiles.Mode}, 'GENERATE'), 1);
    if isempty(index)
        error('simtest:FixtureGenerateProfileMissing', ...
            'GENERATE profile is missing.');
    end
    source = char(profiles(index).EffectiveDataFile);
    targets = readtable(cfg.ManagementExcel, 'Sheet', cfg.ManagementSheet, ...
        'TextType', 'string', 'VariableNamingRule', 'preserve');
    rowIndex = find(targets.No == profiles(index).No, 1);
    targets.SldvMode(rowIndex) = "FILE";
    targets.SldvDataFile(rowIndex) = string(source);
    writetable(targets, cfg.ManagementExcel, 'Sheet', cfg.ManagementSheet);
    [~, ~, ~, reportInfo] = st_run_from_harness( ...
        'PreparationMode', 'FORCE', 'FromStage', 'SLDV');
    refreshed = load(cfg.SldvManifestFile, 'manifest');
    fileMode = any(strcmp({refreshed.manifest.Profiles.Mode}, 'FILE'));
    checks = append(checks, row('CERTIFY.FIXTURE.SLDV.FILE', 'SLDV', ...
        options, pass_if(fileMode), ...
        'Generated SLDV data was reused through FILE mode', ...
        reportInfo.RunDirectory, toc(timerValue), started));
catch ME
    checks = append(checks, exception_row( ...
        'CERTIFY.FIXTURE.SLDV.FILE', 'SLDV', options, ME, ...
        cfg.SldvManifestFile, toc(timerValue), started));
end
end

function checks = certify_corrupt_state(cfg, options)
checks = st_empty_verification_checks();
started = timestamp_text(); timerValue = tic;
try
    parent = fileparts(cfg.WorkflowStateFile);
    if ~isfolder(parent), mkdir(parent); end
    fileId = fopen(cfg.WorkflowStateFile, 'w');
    if fileId < 0, error('Cannot create corrupt-state fixture.'); end
    fileCleanup = onCleanup(@() fclose(fileId));
    fprintf(fileId, 'intentionally corrupt verification state');
    clear fileCleanup;
    [~, ~, workflow, reportInfo] = st_run_from_harness( ...
        'PreparationMode', 'AUTO');
    recovered = isfile(cfg.WorkflowStateFile) && ...
        any(workflow.RunCount > 0);
    checks = append(checks, row('CERTIFY.FIXTURE.STATE_RECOVERY', ...
        'CACHE', options, pass_if(recovered), ...
        'Corrupt MAT state was rebuilt and execution completed', ...
        reportInfo.RunDirectory, toc(timerValue), started));
catch ME
    checks = append(checks, exception_row( ...
        'CERTIFY.FIXTURE.STATE_RECOVERY', 'CACHE', options, ME, ...
        cfg.WorkflowStateFile, toc(timerValue), started));
end
end

function checks = certify_partial_failure(cfg, options)
checks = st_empty_verification_checks();
started = timestamp_text(); timerValue = tic;
backup = [tempname(fileparts(cfg.ManagementExcel)) '.xlsx'];
copyfile(cfg.ManagementExcel, backup, 'f');
cleanup = onCleanup(@() restore_file(backup, cfg.ManagementExcel)); %#ok<NASGU>
pointerBefore = st_file_signature(cfg.LatestReportPointer);
try
    targets = readtable(cfg.ManagementExcel, 'Sheet', cfg.ManagementSheet, ...
        'TextType', 'string', 'VariableNamingRule', 'preserve');
    targets.CUTPath(end) = string([cfg.TopModel '/MissingCUT']);
    writetable(targets, cfg.ManagementExcel, 'Sheet', cfg.ManagementSheet);
    failed = false;
    try
        st_run_from_harness('PreparationMode', 'FORCE', ...
            'FromStage', 'START');
    catch
        failed = true;
    end
    pointerAfter = st_file_signature(cfg.LatestReportPointer);
    noTestRun = strcmp(pointerBefore.SHA256, pointerAfter.SHA256);
    checks = append(checks, row('CERTIFY.FIXTURE.PARTIAL_FAILURE', ...
        'DIAGNOSTICS', options, pass_if(failed && noTestRun), ...
        'Invalid target failed preparation without starting a test report', ...
        cfg.ManagementExcel, toc(timerValue), started));
catch ME
    checks = append(checks, exception_row( ...
        'CERTIFY.FIXTURE.PARTIAL_FAILURE', 'DIAGNOSTICS', options, ME, ...
        cfg.ManagementExcel, toc(timerValue), started));
end
end

function checks = certify_fixture_export(cfg, options, destination)
checks = st_empty_verification_checks();
started = timestamp_text(); timerValue = tic;
try
    snapshot = st_create_verification_snapshot(cfg, destination, false);
    templateBefore = inventory_tree(fullfile(snapshot.Root, 'template'));
    oldPath = path;
    oldDirectory = pwd;
    runCleanup = onCleanup(@() restore_run_path(oldDirectory, oldPath)); %#ok<NASGU>
    cd(snapshot.Root);
    addpath(snapshot.Root, '-begin');
    clear run_exported_tests
    first = run_exported_tests();
    second = run_exported_tests();
    templateAfter = inventory_tree(fullfile(snapshot.Root, 'template'));
    immutable = isequal(templateBefore, templateAfter);
    reportsOk = strcmp(first.Report.Status, 'OK') && ...
        strcmp(second.Report.Status, 'OK');
    checks = append(checks, row('CERTIFY.FIXTURE.EXPORT_RERUN', ...
        'EXPORT', options, pass_if(immutable && reportsOk), ...
        'Bundle checksums passed, two reruns completed, template unchanged', ...
        snapshot.Root, toc(timerValue), started));
catch ME
    checks = append(checks, exception_row( ...
        'CERTIFY.FIXTURE.EXPORT_RERUN', 'EXPORT', options, ME, ...
        destination, toc(timerValue), started));
end
end

function inventory = inventory_tree(root)
listing = dir(fullfile(root, '**', '*'));
Path = strings(0,1); SHA256 = strings(0,1);
for i = 1:numel(listing)
    if listing(i).isdir, continue; end
    path = fullfile(listing(i).folder, listing(i).name);
    relative = erase(string(path), string(root) + filesep);
    signature = st_file_signature(path);
    Path(end+1,1) = relative; %#ok<AGROW>
    SHA256(end+1,1) = string(signature.SHA256); %#ok<AGROW>
end
inventory = sortrows(table(Path, SHA256), 'Path');
end

function prepare_project_copy(sourceRoot, destination)
if ~isfolder(destination), mkdir(destination); end
copy_required(fullfile(sourceRoot, 'st_setup.m'), ...
    fullfile(destination, 'st_setup.m'));
copy_required(fullfile(sourceRoot, 'VERSION.txt'), ...
    fullfile(destination, 'VERSION.txt'));
copy_required(fullfile(sourceRoot, 'src'), fullfile(destination, 'src'));
copy_required(fullfile(sourceRoot, 'resources'), ...
    fullfile(destination, 'resources'));
fixtureSource = fullfile(sourceRoot, 'tests', 'fixtures');
copy_required(fixtureSource, fullfile(destination, 'tests', 'fixtures'));
end

function copy_required(source, destination)
[ok, message] = copyfile(source, destination, 'f');
if ~ok
    error('simtest:VerificationCopyFailed', ...
        'Cannot copy %s: %s', source, message);
end
end

function restore_file(backup, destination)
if isfile(backup)
    copyfile(backup, destination, 'f');
    delete(backup);
end
end

function restore_run_path(directory, pathValue)
try, cd(directory); catch, end
path(pathValue);
clear run_exported_tests
end

function restore_environment(directory, pathValue, model, root)
try
    close_project_test_files(root);
    if bdIsLoaded(model), close_system(model, 0); end
catch
end
try, cd(directory); catch, end
path(pathValue);
clear st_setup st_config st_project_root st_require_runtime_target
end

function close_project_test_files(root)
try
    files = sltest.testmanager.getTestFiles;
    for i = 1:numel(files)
        try
            if startsWith(canonical_path(files(i).FilePath), ...
                    canonical_path(root))
                if files(i).Dirty, saveToFile(files(i)); end
                close(files(i));
            end
        catch
        end
    end
catch
end
end

function value = canonical_path(value)
value = char(java.io.File(char(string(value))).getCanonicalPath());
end

function checks = append(checks, value)
checks = [checks; value];
end

function result = row(checkId, featureId, options, status, message, ...
        evidence, duration, started)
if nargin < 6, evidence = ''; end
if nargin < 7, duration = 0; end
if nargin < 8, started = ''; end
result = st_verification_check(checkId, featureId, options.Profile, ...
    'FIXTURE', true, status, message, evidence, duration, started, ...
    timestamp_text());
end

function result = exception_row(checkId, featureId, options, ME, ...
        evidence, duration, started)
if nargin < 6, duration = 0; end
if nargin < 7, started = ''; end
result = row(checkId, featureId, options, ...
    st_verification_exception_status(ME), ...
    sprintf('%s: %s', ME.identifier, ME.message), ...
    evidence, duration, started);
end

function status = pass_if(condition)
if condition, status = 'PASS'; else, status = 'FAIL'; end
end

function text = timestamp_text()
text = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
