function checks = st_verification_quick_checks(cfg, options)
%ST_VERIFICATION_QUICK_CHECKS Inspect current artifacts without saving them.

checks = st_empty_verification_checks();
profile = options.Profile;
target = options.Target;

checks = [checks; file_check('CONFIG_PATHS', 'CONFIG', ...
    st_project_root(), true, true, profile, target, 'Project root')];
checks = [checks; file_check('RUNTIME_TARGET', 'TARGETS', ...
    cfg.RuntimeTargetFile, true, false, profile, target, 'runtime_target.mat')];
checks = [checks; file_check('MANAGEMENT_EXCEL', 'CONFIG', ...
    cfg.ManagementExcel, true, false, profile, target, 'Management Excel')];

if cfg.HasRuntimeTarget
    checks = [checks; file_check('CURRENT.MODEL', 'TARGETS', ...
        cfg.ModelFile, true, false, profile, target, 'Selected model')];
    checks = [checks; file_check('CURRENT_TEST_FILE', 'TEST_MANAGER', ...
        cfg.TestFile, true, false, profile, target, 'Test File')];
else
    checks = [checks; st_verification_check( ...
        'CURRENT_STRUCTURE', 'TARGETS', profile, target, true, ...
        'BLOCKED', 'No valid runtime target is selected')];
    return;
end
if ~isfile(cfg.ModelFile) || ~isfile(cfg.ManagementExcel) || ...
        ~isfile(cfg.TestFile)
    return;
end

beforeInventory = st_verification_source_inventory(cfg, false);
modelWasLoaded = bdIsLoaded(cfg.TopModel);
modelDirty = '';
if modelWasLoaded, modelDirty = get_param(cfg.TopModel, 'Dirty'); end
try
    if ~modelWasLoaded
        load_system(cfg.ModelFile);
    end
    targets = st_load_targets(cfg.OnlyEnabled);
    checks = [checks; inspect_targets(targets, cfg, profile, target)];
    checks = [checks; inspect_test_file(targets, cfg, profile, target)];
    checks = [checks; inspect_state(cfg, profile, target)];
    checks = [checks; inspect_report(cfg, profile, target)];
    checks = [checks; inspect_sldv(targets, cfg, profile, target)];
    checks = [checks; inspect_static_configuration(cfg, profile, target)];
catch ME
    checks = [checks; st_verification_check( ...
        'CURRENT_STRUCTURE', 'TARGETS', profile, target, true, ...
        'FAIL', ME.message)];
end
if ~modelWasLoaded && bdIsLoaded(cfg.TopModel)
    close_system(cfg.TopModel, 0);
end
sessionRestored = bdIsLoaded(cfg.TopModel) == modelWasLoaded;
if modelWasLoaded && bdIsLoaded(cfg.TopModel)
    sessionRestored = sessionRestored && ...
        strcmp(get_param(cfg.TopModel, 'Dirty'), modelDirty);
end
checks = [checks; st_verification_check( ...
    'CURRENT.SESSION_RESTORED', 'CORE', profile, target, true, ...
    pass_if(sessionRestored), ...
    'Model open and Dirty state restored after QUICK inspection')];

afterInventory = st_verification_source_inventory(cfg, false);
unchanged = isequal(beforeInventory.Path, afterInventory.Path) && ...
    isequal(beforeInventory.SHA256, afterInventory.SHA256);
if unchanged
    status = 'PASS';
    message = sprintf('%d source and input file checksum(s) unchanged', ...
        height(beforeInventory));
else
    status = 'FAIL';
    message = 'QUICK changed a model, Test File, Excel, dependency, or input';
end
checks = [checks; st_verification_check( ...
    'SOURCE_IMMUTABLE', 'CORE', profile, target, true, status, message)];
end

function checks = inspect_targets(T, cfg, profile, target)
checks = st_empty_verification_checks();
if isempty(T)
    checks = st_verification_check('CURRENT_STRUCTURE', 'TARGETS', ...
        profile, target, true, 'BLOCKED', 'No enabled target rows');
    return;
end
for i = 1:height(T)
    owner = st_normalize_cut_path(T.CUTPath(i), cfg.TopModel);
    handle = getSimulinkBlockHandle(owner);
    id = sprintf('%04d', round(T.No(i)));
    if handle == -1 || ~strcmp(get_param(handle, 'BlockType'), 'SubSystem')
        status = 'FAIL'; message = "CUT is missing or not a Subsystem: " + owner;
    else
        status = 'PASS'; message = "CUT found: " + owner;
    end
    checks = [checks; st_verification_check( ...
        "CURRENT.CUT." + id, 'TARGETS', profile, target, true, ...
        status, message)]; %#ok<AGROW>

    harness = sltest.harness.find(owner, 'SearchDepth', 0, ...
        'Name', char(T.HarnessName(i)));
    if isempty(harness)
        status = 'FAIL'; message = "Harness missing: " + T.HarnessName(i);
    else
        status = 'PASS'; message = "Harness found: " + T.HarnessName(i);
    end
    checks = [checks; st_verification_check( ...
        "CURRENT.HARNESS." + id, 'HARNESS', profile, target, true, ...
        status, message)]; %#ok<AGROW>

    if isempty(harness)
        continue;
    end
    wasLoaded = bdIsLoaded(char(T.HarnessName(i)));
    if ~wasLoaded
        sltest.harness.load(owner, char(T.HarnessName(i)));
    end
    directInports = find_system(owner, 'SearchDepth', 1, ...
        'Type', 'Block', 'BlockType', 'Inport');
    if isempty(directInports) && strcmpi(char(T.SldvMode(i)), 'OFF')
        signalStatus = 'SKIP';
        signalMessage = 'No direct Inport; Signal Editor is not applicable';
    else
        try
            st_find_signal_editor_block(char(T.HarnessName(i)));
            signalStatus = 'PASS'; signalMessage = 'Signal Editor found';
        catch ME
            signalStatus = 'FAIL'; signalMessage = ME.message;
        end
    end
    try
        st_find_assessment_block(char(T.HarnessName(i)));
        assessmentStatus = 'PASS'; assessmentMessage = 'Assessment found';
    catch ME
        assessmentStatus = 'FAIL'; assessmentMessage = ME.message;
    end
    if ~wasLoaded
        try, sltest.harness.close(owner, char(T.HarnessName(i))); catch, end
    end
    checks = [checks; st_verification_check( ...
        "CURRENT.SIGNAL_EDITOR." + id, 'SIGNAL_EDITOR', profile, ...
        target, true, signalStatus, signalMessage)]; %#ok<AGROW>
    checks = [checks; st_verification_check( ...
        "CURRENT.ASSESSMENT." + id, 'ASSESSMENT', profile, ...
        target, true, assessmentStatus, assessmentMessage)]; %#ok<AGROW>
end
end

function checks = inspect_test_file(T, cfg, profile, target)
checks = st_empty_verification_checks();
alreadyOpen = false;
tf = [];
try
    openFiles = sltest.testmanager.getTestFiles;
    for i = 1:numel(openFiles)
        if same_path(openFiles(i).FilePath, cfg.TestFile)
            tf = openFiles(i); alreadyOpen = true; break;
        end
    end
    if isempty(tf), tf = sltest.testmanager.TestFile(cfg.TestFile); end
    suites = getTestSuiteByName(tf, cfg.TestSuiteName);
    if numel(suites) ~= 1
        error('Expected exactly one configured Test Suite.');
    end
    cases = getTestCases(suites);
    names = strings(numel(cases),1);
    for i = 1:numel(cases), names(i) = string(cases(i).Name); end
    missing = setdiff(string(T.TestCaseName), names);
    if isempty(missing)
        status = 'PASS'; message = 'All selected Test Cases exist';
    else
        status = 'FAIL';
        message = "Missing Test Cases: " + strjoin(missing, ', ');
    end
    checks = [checks; st_verification_check( ...
        'CURRENT.TEST_CASES', 'TEST_MANAGER', profile, target, true, ...
        status, message)];
    checks = [checks; st_verification_check( ...
        'CURRENT.EXECUTION_SCOPE', 'EXECUTION', profile, target, true, ...
        status, 'Selected Test Cases can be mapped without changing Enabled')];
catch ME
    checks = [checks; st_verification_check( ...
        'CURRENT.TEST_CASES', 'TEST_MANAGER', profile, target, true, ...
        'FAIL', ME.message)];
    checks = [checks; st_verification_check( ...
        'CURRENT.EXECUTION_SCOPE', 'EXECUTION', profile, target, true, ...
        'FAIL', ME.message)];
end
if ~alreadyOpen && ~isempty(tf)
    try, close(tf); catch, end
end
end

function checks = inspect_static_configuration(cfg, profile, target)
checks = st_empty_verification_checks();
checks = [checks; st_verification_check( ...
    'CURRENT.PATH_LOGIC', 'PATHS', profile, target, true, 'PASS', ...
    'Path ranking and normalization functions are available')];
expectedValid = ismember(upper(string(cfg.ExpectedUpdateMode)), ...
    ["APPLY","OFF"]);
checks = [checks; st_verification_check( ...
    'CURRENT.EXPECTED_UPDATE', 'EXPECTED_UPDATE', profile, target, ...
    true, pass_if(expectedValid), ...
    "Global expected update mode: " + string(cfg.ExpectedUpdateMode))];
coverageValid = strcmpi(cfg.CoverageStructuralLevel, 'Decision') && ...
    contains(lower(cfg.CoverageMetricSettings), 'd');
checks = [checks; st_verification_check( ...
    'CURRENT.COVERAGE_CONFIG', 'COVERAGE', profile, target, true, ...
    pass_if(coverageValid), ...
    'Decision and Block Execution collection is configured')];
root = st_project_root();
exportFiles = {fullfile(root, 'resources', 'export_bundle', ...
    'run_exported_tests.m'), fullfile(root, 'src', 'exporting', ...
    'st_export_test_bundle.m'), fullfile(root, 'src', 'exporting', ...
    'st_export_test_asset_bundle.m'), fullfile(root, 'src', 'exporting', ...
    'st_export_standalone_harnesses.m'), fullfile(root, 'src', 'exporting', ...
    'st_collect_asset_inputs.m'), fullfile(root, 'src', 'exporting', ...
    'st_select_asset_targets.m'), fullfile(root, 'src', 'reporting', ...
    'st_export_result_set_report.m')};
checks = [checks; st_verification_check( ...
    'CURRENT.EXPORT_STATIC', 'EXPORT', profile, target, true, ...
    pass_if(all(cellfun(@isfile, exportFiles))), ...
    'Review/reproducible collectors and rerun entry point are available')];
diagnostics = dir(fullfile(root, 'diagnostics', 'matlab', '*.m'));
checks = [checks; st_verification_check( ...
    'CURRENT.DIAGNOSTICS', 'DIAGNOSTICS', profile, target, true, ...
    pass_if(~isempty(diagnostics)), ...
    sprintf('%d MATLAB diagnostic script(s) available', ...
    numel(diagnostics)))];
end

function checks = inspect_state(cfg, profile, target)
checks = st_empty_verification_checks();
[state, status] = st_load_workflow_state(cfg); %#ok<ASGLU>
switch status
    case 'OK'
        result = 'PASS'; message = 'Workflow MAT checkpoint is valid';
    case 'MISSING'
        result = 'WARN'; message = 'Workflow checkpoint is missing; AUTO will rebuild';
    otherwise
        result = 'WARN'; message = ['Workflow checkpoint is ' status ...
            '; AUTO will rebuild'];
end
checks = [checks; st_verification_check( ...
    'WORKFLOW_STATE', 'CACHE', profile, target, false, result, message)];

if isfile(cfg.WorkflowStateSummaryFile)
    try
        jsondecode(fileread(cfg.WorkflowStateSummaryFile));
        result = 'PASS'; message = 'Workflow JSON summary is readable';
    catch ME
        result = 'FAIL'; message = ME.message;
    end
else
    result = 'WARN'; message = 'Workflow JSON summary is missing';
end
checks = [checks; st_verification_check( ...
    'WORKFLOW_STATE.JSON', 'CACHE', profile, target, false, result, message)];
end

function checks = inspect_report(cfg, profile, target)
if ~isfile(cfg.LatestReportPointer)
    checks = st_verification_check('LATEST_REPORT', 'REPORTING', ...
        profile, target, false, 'WARN', 'No latest integrated report');
    return;
end
try
    latest = jsondecode(fileread(cfg.LatestReportPointer));
    required = {'RunId','RunDirectory','Manifest','Summary','Status'};
    valid = all(isfield(latest, required)) && ...
        isfolder(char(latest.RunDirectory)) && ...
        isfile(char(latest.Manifest)) && isfile(char(latest.Summary));
    if valid
        status = 'PASS'; message = 'Latest report pointer and artifacts are valid';
    else
        status = 'FAIL'; message = 'Latest report pointer references missing artifacts';
    end
catch ME
    status = 'FAIL'; message = ME.message;
end
checks = st_verification_check('LATEST_REPORT', 'REPORTING', ...
    profile, target, false, status, message);
end

function checks = inspect_sldv(T, cfg, profile, target)
required = any(upper(string(T.SldvMode)) ~= "OFF");
if ~required && ~isfile(cfg.SldvManifestFile)
    checks = st_verification_check('SLDV_MANIFEST', 'SLDV', profile, ...
        target, false, 'SKIP', 'No enabled target uses SLDV');
    return;
end
if ~isfile(cfg.SldvManifestFile)
    checks = st_verification_check('SLDV_MANIFEST', 'SLDV', profile, ...
        target, required, 'BLOCKED', 'SLDV manifest is missing');
    return;
end
try
    loaded = load(cfg.SldvManifestFile, 'manifest');
    valid = isfield(loaded, 'manifest') && ...
        isfield(loaded.manifest, 'TopModel') && ...
        strcmp(char(loaded.manifest.TopModel), cfg.TopModel);
    if valid
        status = 'PASS'; message = 'SLDV manifest belongs to the selected model';
    else
        status = 'FAIL'; message = 'SLDV manifest is invalid or belongs to another model';
    end
catch ME
    status = 'FAIL'; message = ME.message;
end
checks = st_verification_check('SLDV_MANIFEST', 'SLDV', profile, ...
    target, required, status, message);
end

function row = file_check(id, feature, path, required, folder, ...
        profile, target, label)
if (folder && isfolder(path)) || (~folder && isfile(path))
    status = 'PASS'; message = [label ' exists: ' path];
elseif required
    status = 'BLOCKED'; message = [label ' is missing: ' path];
else
    status = 'WARN'; message = [label ' is missing: ' path];
end
row = st_verification_check(id, feature, profile, target, ...
    required, status, message);
end

function tf = same_path(left, right)
left = char(java.io.File(char(string(left))).getCanonicalPath());
right = char(java.io.File(char(string(right))).getCanonicalPath());
if ispc, tf = strcmpi(left, right); else, tf = strcmp(left, right); end
end

function status = pass_if(condition)
if condition, status = 'PASS'; else, status = 'FAIL'; end
end
