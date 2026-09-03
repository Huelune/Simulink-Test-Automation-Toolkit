function summary = st_check_actual_system(varargin)
%ST_CHECK_ACTUAL_SYSTEM Print compact read-only acceptance codes.
%
% summary = st_check_actual_system()
% summary = st_check_actual_system('RunDirectory', runDirectory)
%
% The command inspects the local MATLAB environment, one PER_CUT run, and
% the saved CVFs. It never saves a model, Test File, or result artifact.
% Send the complete lines beginning with SYSTEM-CHECK-v1 and CVF-CHECK-v1
% when requesting diagnosis.
%
% ENV bit order:
%   E1  MATLAB release is R2025b
%   E2  required products are installed
%   E3  required product licenses exist
%   E4  runtime target and required project inputs exist
%   E5  required MATLAB/Simulink APIs exist
%   E6  critical toolkit functions resolve once inside this repository
%
% RUN bit order:
%   R1  latest pointer, root manifest, summary, and run ID are coherent
%   R2  target rows and target manifests preserve order and identity
%   R3  every target reached an initial test result without runner failure
%   R4  expected-value updates and final reruns are coherently linked
%   R5  required artifacts exist and contain no recorded failure
%   R6  no run-local CVF remains linked to the Test File hierarchy

p = inputParser;
p.FunctionName = 'st_check_actual_system';
addParameter(p, 'RunDirectory', 'LATEST', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
parse(p, varargin{:});

cfg = st_config();
requestedRun = char(string(p.Results.RunDirectory));
totalTimer = tic;
st_log(cfg, 'INFO', ...
    'Actual-system self-check start | RunDirectory=%s', requestedRun);

[environmentBits, environmentDetails] = check_environment(cfg);
[runBits, runDetails, runDirectory] = check_run( ...
    requestedRun, cfg);

try
    if strlength(string(runDirectory)) > 0
        [cvfCode, cvfDetails] = st_check_per_cut_cvf( ...
            'RunDirectory', runDirectory);
    else
        [cvfCode, cvfDetails] = st_check_per_cut_cvf( ...
            'RunDirectory', requestedRun);
    end
catch ME
    cvfCode = '000000';
    cvfDetails = table(string(ME.message), ...
        'VariableNames', {'Message'});
end

environmentCode = bits_to_code(environmentBits);
runCode = bits_to_code(runBits);
overallCode = [environmentCode runCode cvfCode];

print_legend();
fprintf(['SYSTEM-CHECK-v1 ENV=%s RUN=%s CVF=%s ' ...
    'OVERALL=%s RUN_DIRECTORY="%s"\n'], ...
    environmentCode, runCode, cvfCode, overallCode, ...
    char(replace(string(runDirectory), '"', ' ')));

summary = struct( ...
    'Code', overallCode, ...
    'EnvironmentCode', environmentCode, ...
    'RunCode', runCode, ...
    'CVFCode', cvfCode, ...
    'RunDirectory', char(string(runDirectory)), ...
    'Environment', environmentDetails, ...
    'Run', runDetails, ...
    'CVF', cvfDetails);

if strcmp(overallCode, '111111111111111111')
    st_log(cfg, 'INFO', ...
        'Actual-system self-check complete | code=%s | elapsed=%.3f sec', ...
        overallCode, toc(totalTimer));
else
    st_log(cfg, 'WARN', ...
        ['Actual-system self-check found non-passing checks | ' ...
         'code=%s | elapsed=%.3f sec'], ...
        overallCode, toc(totalTimer));
end
end


function [bits, details] = check_environment(cfg)
bits = false(1,6);
messages = repmat("Check was not completed", 6, 1);

try
    actualRelease = string(version('-release'));
    bits(1) = actualRelease == "2025b";
    messages(1) = "MATLAB release=" + actualRelease + ...
        ", required=2025b";
catch ME
    messages(1) = "MATLAB release query failed: " + string(ME.message);
end

products = {'MATLAB','Simulink','Simulink Test', ...
    'Simulink Coverage','Simulink Design Verifier'};
installed = false(size(products));
for i = 1:numel(products)
    try
        installed(i) = ~isempty(ver(products{i}));
    catch
        installed(i) = false;
    end
end
bits(2) = all(installed);
messages(2) = list_failures("Missing products", products, installed);

licenseFeatures = {'MATLAB','SIMULINK','Simulink_Test', ...
    'Simulink_Coverage','Simulink_Design_Verifier'};
licensed = false(size(licenseFeatures));
for i = 1:numel(licenseFeatures)
    try
        licensed(i) = logical(license('test', licenseFeatures{i}));
    catch
        licensed(i) = false;
    end
end
bits(3) = all(licensed);
messages(3) = list_failures( ...
    "Missing licenses", licenseFeatures, licensed);

requiredPaths = [string(cfg.RuntimeTargetFile); ...
    string(cfg.ModelFile); string(cfg.ManagementExcel); ...
    string(cfg.TestFile)];
pathExists = [isfile(cfg.RuntimeTargetFile); ...
    cfg.HasRuntimeTarget && isfile(cfg.ModelFile); ...
    isfile(cfg.ManagementExcel); isfile(cfg.TestFile)];
bits(4) = all(pathExists);
messages(4) = path_failure_message(requiredPaths, pathExists);

apis = ["sltest.harness.create"; ...
    "sltest.harness.export"; ...
    "sltest.testmanager.TestFile"; "decisioninfo"; ...
    "executioninfo"; "dependencies.fileDependencyAnalysis"];
apiExists = false(size(apis));
for i = 1:numel(apis)
    apiExists(i) = exist(char(apis(i)), 'file') ~= 0 || ...
        exist(char(apis(i)), 'class') ~= 0;
end
bits(5) = all(apiExists);
messages(5) = list_failures("Missing APIs", cellstr(apis), apiExists);

functions = ["st_setup"; "st_run_from_harness"; ...
    "st_run_tests_per_cut"; "st_generate_coverage_filter_file"; ...
    "st_run_tests_from_exported_harnesses"; ...
    "st_generate_standalone_coverage_filters"; ...
    "st_check_per_cut_cvf"; "st_check_standalone_run"; ...
    "st_check_actual_system"];
functionOk = false(size(functions));
functionMessages = strings(size(functions));
projectRoot = canonical_path(st_project_root());
for i = 1:numel(functions)
    locations = which_all(functions(i));
    withinRoot = false(size(locations));
    for j = 1:numel(locations)
        withinRoot(j) = is_descendant_path( ...
            canonical_path(locations(j)), projectRoot);
    end
    functionOk(i) = numel(locations) == 1 && all(withinRoot);
    if functionOk(i)
        functionMessages(i) = functions(i) + "=OK";
    else
        functionMessages(i) = functions(i) + "=" + ...
            string(numel(locations)) + " resolution(s)";
    end
end
bits(6) = all(functionOk);
if bits(6)
    messages(6) = "Critical toolkit functions resolve once in this repository";
else
    messages(6) = strjoin(functionMessages(~functionOk), ' | ');
end

details = build_details("E", [ ...
    "MATLAB_RELEASE"; "PRODUCTS"; "LICENSES"; ...
    "PROJECT_INPUTS"; "REQUIRED_APIS"; "TOOLKIT_PATHS"], ...
    bits, messages);
end


function [bits, details, runDirectory] = check_run(requestedRun, cfg)
bits = false(1,6);
messages = repmat("Check was not completed", 6, 1);
runDirectory = "";
rootManifest = struct();
targets = struct([]);
targetManifests = cell(0,1);

try
    [runDirectory, pointer] = resolve_run_directory(requestedRun, cfg);
    rootManifestPath = fullfile(runDirectory, 'manifest.json');
    summaryPath = fullfile(runDirectory, 'TestSummary.xlsx');
    rootManifest = read_json(rootManifestPath);
    recordedRunId = field_text(rootManifest, {'RunId'}, '');
    bits(1) = isfile(rootManifestPath) && isfile(summaryPath) && ...
        strcmp(recordedRunId, char(run_id_from_directory(runDirectory))) && ...
        strcmpi(field_text(rootManifest, {'ExecutionMode'}, ''), 'PER_CUT') && ...
        same_path(field_text(rootManifest, {'RunDirectory'}, ''), ...
            runDirectory) && ...
        same_path(field_text(rootManifest, {'Summary'}, ''), summaryPath);
    if ~isempty(pointer)
        bits(1) = bits(1) && ...
            strcmp(field_text(pointer, {'RunId'}, ''), recordedRunId) && ...
            same_path(field_text(pointer, {'RunDirectory'}, ''), ...
                runDirectory) && ...
            same_path(field_text(pointer, {'Manifest'}, ''), ...
                rootManifestPath) && ...
            same_path(field_text(pointer, {'Summary'}, ''), summaryPath);
    end
    if bits(1)
        messages(1) = "Pointer, manifest, workbook, and run ID are coherent";
    else
        messages(1) = "Pointer, manifest, workbook, or run ID is inconsistent";
    end
catch ME
    messages(:) = "Run lookup failed: " + string(ME.message);
    details = build_details("R", run_check_names(), bits, messages);
    return;
end

try
    if ~isfield(rootManifest, 'Targets') || isempty(rootManifest.Targets)
        error('simtest:SystemCheckTargetsMissing', ...
            'Root manifest contains no target rows.');
    end
    targets = rootManifest.Targets;
    targetManifests = cell(numel(targets), 1);
    identityOk = true(numel(targets),1);
    for i = 1:numel(targets)
        path = resolve_target_manifest(targets(i), runDirectory);
        targetManifests{i} = read_json(path);
        identityOk(i) = ...
            field_number(targetManifests{i}, {'Order'}, NaN) == i && ...
            strcmp(field_text(targetManifests{i}, {'RunId'}, ''), ...
                field_text(rootManifest, {'RunId'}, '')) && ...
            field_number(targetManifests{i}, {'No'}, NaN) == ...
                field_number(targets(i), {'No'}, NaN) && ...
            strcmp(field_text(targetManifests{i}, {'TestCaseName'}, ''), ...
                field_text(targets(i), {'TestCaseName'}, ''));
    end
    recordedCount = field_number(rootManifest, {'TargetCount'}, NaN);
    configured = st_load_targets(cfg.OnlyEnabled);
    configuredOk = height(configured) == numel(targets);
    if configuredOk
        configuredOk = isequal(double(configured.No(:)), ...
            field_number_vector(targets, {'No'}, NaN)) && ...
            isequal(string(configured.CUTPath(:)), ...
                field_text_vector(targets, {'CUTPath'}, '')) && ...
            isequal(string(configured.TestCaseName(:)), ...
                field_text_vector(targets, {'TestCaseName'}, ''));
    end
    bits(2) = all(identityOk) && recordedCount == numel(targets) && ...
        configuredOk;
    if bits(2)
        messages(2) = "Target order and identities match every manifest";
    else
        messages(2) = "Target order, identity, or count is inconsistent";
    end
catch ME
    messages(2) = "Target manifest check failed: " + string(ME.message);
    targetManifests = cell(0,1);
    messages(4) = "Expected update check requires valid target manifests";
end

if ~isempty(targets)
    targetStatuses = upper(field_text_vector(targets, {'Status'}, ''));
    initialOutcomes = upper(field_text_vector( ...
        targets, {'InitialOutcome'}, ''));
    invalidOutcome = ismember(initialOutcomes, ...
        ["","NOT_RUN","UNKNOWN"]);
    bits(3) = ~any(ismember(targetStatuses, ["FAIL","SKIP"])) && ...
        ~any(invalidOutcome);
    if bits(3)
        messages(3) = "Every target reached an initial result";
    else
        messages(3) = "A target failed, was skipped, or has no initial result";
    end
end

if ~isempty(targetManifests)
    expectedOk = true(numel(targetManifests),1);
    for i = 1:numel(targetManifests)
        manifest = targetManifests{i};
        mode = upper(field_text(manifest, ...
            {'ExpectedUpdateMode'}, ''));
        updated = field_number(manifest, ...
            {'ExpectedUpdatedCount'}, NaN);
        rerun = field_logical(manifest, ...
            {'RerunPerformed'}, false);
        finalSummary = field_text(manifest, ...
            {'FinalSummary'}, '');
        finalOutcome = upper(field_text(manifest, ...
            {'FinalOutcome'}, ''));
        expectedOk(i) = ~isnan(updated) && updated >= 0;
        if strcmp(mode, 'OFF')
            expectedOk(i) = expectedOk(i) && updated == 0 && ~rerun;
        elseif updated > 0
            expectedOk(i) = expectedOk(i) && strcmp(mode, 'APPLY') && ...
                rerun && isfile(finalSummary) && ...
                ~ismember(string(finalOutcome), ...
                    ["","NOT_RUN","UNKNOWN"]);
        end
    end
    bits(4) = all(expectedOk);
    if bits(4)
        messages(4) = "Expected updates and final reruns are coherent";
    else
        messages(4) = "Expected update or final rerun linkage is inconsistent";
    end
end

try
    [bits(5), messages(5)] = check_artifacts( ...
        rootManifest, targets, runDirectory);
catch ME
    messages(5) = "Artifact check failed: " + string(ME.message);
end

try
    [bits(6), messages(6)] = check_filter_leaks( ...
        cfg, targets, runDirectory);
catch ME
    messages(6) = "Filter leak check failed: " + string(ME.message);
end

details = build_details("R", run_check_names(), bits, messages);
end


function [passed, message] = check_artifacts( ...
        rootManifest, targets, runDirectory)
passed = false;
if ~isfield(rootManifest, 'Artifacts') || isempty(rootManifest.Artifacts)
    message = "Root manifest contains no artifact rows";
    return;
end
artifacts = rootManifest.Artifacts;
types = upper(field_text_vector(artifacts, {'Type'}, ''));
statuses = upper(field_text_vector(artifacts, {'Status'}, ''));
paths = field_text_vector(artifacts, {'Path'}, '');
stages = upper(field_text_vector(artifacts, {'Stage'}, ''));
artifactNos = field_number_vector(artifacts, {'No'}, NaN);

if any(statuses == "FAIL")
    message = "One or more artifacts are recorded as FAIL";
    return;
end
for i = 1:numel(paths)
    if statuses(i) == "OK" && strlength(paths(i)) > 0 && ...
            ~artifact_exists(paths(i), runDirectory)
        message = "Recorded artifact is missing: " + paths(i);
        return;
    end
end

rootRequired = ["LOG","MANIFEST"];
for i = 1:numel(rootRequired)
    if ~any(types == rootRequired(i) & statuses == "OK")
        message = "Required root artifact is missing: " + rootRequired(i);
        return;
    end
end

targetRequired = ["SUMMARY_DATA","MLDATX","COVERAGE_DATA", ...
    "RESULT_INTEGRITY","EXCEL","HTML","CVT"];
reportMode = upper(field_text(rootManifest, {'ReportMode'}, ''));
for i = 1:numel(targets)
    targetNo = field_number(targets(i), {'No'}, NaN);
    stagesRequired = "INITIAL";
    if field_logical(targets(i), {'RerunPerformed'}, false)
        stagesRequired(end+1) = "FINAL"; %#ok<AGROW>
    end
    required = targetRequired;
    if ~strcmpi(field_text(targets(i), {'FilterMode'}, 'OFF'), 'OFF')
        required(end+1) = "CVF_COPY"; %#ok<AGROW>
    end
    if strcmp(reportMode, 'FULL')
        required(end+1) = "PDF"; %#ok<AGROW>
    end
    for j = 1:numel(stagesRequired)
        for k = 1:numel(required)
            present = artifactNos == targetNo & ...
                stages == stagesRequired(j) & types == required(k) & ...
                statuses == "OK";
            if ~any(present)
                message = "Required artifact is missing: No=" + ...
                    string(targetNo) + ", stage=" + stagesRequired(j) + ...
                    ", type=" + required(k);
                return;
            end
        end
    end
end

if isempty(targets)
    message = "No target artifacts can be checked";
    return;
end

passed = true;
message = "Required artifacts exist and no artifact failure is recorded";
end


function [passed, message] = check_filter_leaks(cfg, targets, runDirectory)
passed = false;
if ~isfile(cfg.TestFile)
    message = "Test File is missing: " + string(cfg.TestFile);
    return;
end

[tf, openedByChecker] = open_test_file_read_only(cfg.TestFile);
testFileCleanup = onCleanup(@() close_checker_test_file( ...
    tf, openedByChecker)); %#ok<NASGU>

suite = getTestSuiteByName(tf, cfg.TestSuiteName);
if numel(suite) ~= 1
    message = "Expected exactly one Test Suite named " + ...
        string(cfg.TestSuiteName);
    return;
end

fileCoverage = getCoverageSettings(tf);
suiteCoverage = getCoverageSettings(suite);
filters = normalize_filter_values(fileCoverage.CoverageFilterFilename);
filters = [filters; normalize_filter_values( ...
    suiteCoverage.CoverageFilterFilename)]; %#ok<AGROW>
cases = getTestCases(suite);
targetNames = field_text_vector(targets, {'TestCaseName'}, '');
for i = 1:numel(cases)
    if any(targetNames == string(cases(i).Name))
        caseCoverage = getCoverageSettings(cases(i));
        filters = [filters; normalize_filter_values( ...
            caseCoverage.CoverageFilterFilename)]; %#ok<AGROW>
    end
end

runRoot = canonical_path(runDirectory);
generatedNames = strings(0,1);
generatedPaths = field_text_vector(targets, {'CVFPath'}, '');
for i = 1:numel(generatedPaths)
    if strlength(generatedPaths(i)) > 0
        [~, name, extension] = fileparts(generatedPaths(i));
        generatedNames(end+1,1) = string(name) + string(extension); %#ok<AGROW>
    end
end
generatedNames = unique(generatedNames, 'stable');
leaked = strings(0,1);
for i = 1:numel(filters)
    candidate = filters(i);
    if isfile(candidate)
        candidate = canonical_path(candidate);
    end
    [~, name, extension] = fileparts(filters(i));
    generatedName = string(name) + string(extension);
    if is_descendant_path(candidate, runRoot) || ...
            any(generatedNames == generatedName)
        leaked(end+1,1) = filters(i); %#ok<AGROW>
    end
end
passed = isempty(leaked);
if passed
    message = "No run-local CVF remains linked to the Test File hierarchy";
else
    message = "Run-local CVF remains linked: " + strjoin(leaked, ' | ');
end
end


function [tf, openedByChecker] = open_test_file_read_only(path)
openedByChecker = true;
try
    files = sltest.testmanager.getTestFiles;
catch
    files = [];
end
for i = 1:numel(files)
    try
        if same_path(string(files(i).FilePath), string(path))
            tf = files(i);
            openedByChecker = false;
            return;
        end
    catch
        % Continue looking for an already open Test File.
    end
end
tf = sltest.testmanager.TestFile(path);
end


function close_checker_test_file(tf, openedByChecker)
if openedByChecker
    try
        close(tf);
    catch
    end
end
end


function values = normalize_filter_values(value)
if isempty(value)
    values = strings(0,1);
elseif iscell(value)
    values = string(value(:));
else
    values = string(value(:));
end
values = strtrim(values);
values = unique(values(~ismissing(values) & strlength(values) > 0), ...
    'stable');
end


function [runDirectory, pointer] = resolve_run_directory(requestedRun, cfg)
pointer = [];
if strcmpi(strtrim(requestedRun), 'LATEST')
    pointer = read_json(cfg.PerCutLatestPointer);
    runDirectory = field_text(pointer, {'RunDirectory'}, '');
    runId = field_text(pointer, {'RunId'}, '');
    if ~isfolder(runDirectory) && ~isempty(runId)
        runDirectory = fullfile(cfg.PerCutRunRootDir, runId);
    end
else
    runDirectory = requestedRun;
    if ~isfolder(runDirectory)
        candidate = fullfile(cfg.PerCutRunRootDir, requestedRun);
        if isfolder(candidate)
            runDirectory = candidate;
        end
    end
end
if ~isfolder(runDirectory)
    error('simtest:SystemCheckRunNotFound', ...
        'PER_CUT run directory not found: %s', runDirectory);
end
runDirectory = char(canonical_path(runDirectory));
end


function path = resolve_target_manifest(target, runDirectory)
path = field_text(target, {'TargetManifest'}, '');
if isfile(path)
    return;
end
targetDirectory = st_per_cut_target_directory(runDirectory, target);
path = fullfile(targetDirectory, 'target-manifest.json');
if ~isfile(path)
    error('simtest:SystemCheckTargetManifestMissing', ...
        'Target manifest not found: %s', path);
end
end


function tf = artifact_exists(path, runDirectory)
tf = isfile(path) || isfolder(path);
if tf
    return;
end
path = string(path);
runDirectory = string(runDirectory);
marker = string(filesep) + "targets" + string(filesep);
location = strfind(path, marker);
if ~isempty(location)
    relative = extractAfter(path, location(end) + strlength(marker) - 1);
    local = fullfile(runDirectory, 'targets', char(relative));
    tf = isfile(local) || isfolder(local);
end
end


function id = run_id_from_directory(runDirectory)
[~, id] = fileparts(runDirectory);
id = string(id);
end


function values = field_text_vector(data, names, defaultValue)
values = strings(numel(data),1);
for i = 1:numel(data)
    values(i) = string(field_text(data(i), names, defaultValue));
end
end


function values = field_number_vector(data, names, defaultValue)
values = zeros(numel(data),1);
for i = 1:numel(data)
    values(i) = field_number(data(i), names, defaultValue);
end
end


function value = field_text(data, names, defaultValue)
value = defaultValue;
for i = 1:numel(names)
    if isfield(data, names{i}) && ~isempty(data.(names{i}))
        value = char(string(data.(names{i})));
        return;
    end
end
end


function value = field_number(data, names, defaultValue)
value = defaultValue;
for i = 1:numel(names)
    if isfield(data, names{i})
        candidate = data.(names{i});
        if isnumeric(candidate) && isscalar(candidate)
            value = double(candidate);
            return;
        end
        candidate = str2double(string(candidate));
        if isscalar(candidate) && ~isnan(candidate)
            value = double(candidate);
            return;
        end
    end
end
end


function value = field_logical(data, names, defaultValue)
value = defaultValue;
for i = 1:numel(names)
    if isfield(data, names{i})
        candidate = data.(names{i});
        if islogical(candidate) && isscalar(candidate)
            value = candidate;
            return;
        end
        text = upper(strtrim(string(candidate)));
        if isscalar(text) && ismember(text, ["TRUE","FALSE","1","0"])
            value = ismember(text, ["TRUE","1"]);
            return;
        end
    end
end
end


function value = read_json(path)
if ~isfile(path)
    error('simtest:SystemCheckJsonMissing', ...
        'JSON file not found: %s', path);
end
value = jsondecode(fileread(path));
end


function details = build_details(prefix, names, bits, messages)
Bit = string(prefix) + string((1:6)');
Check = string(names(:));
Passed = logical(bits(:));
Status = repmat("FAIL", 6, 1);
Status(Passed) = "PASS";
Message = string(messages(:));
details = table(Bit, Check, Passed, Status, Message);
end


function names = run_check_names()
names = ["RUN_ROOT"; "TARGET_MAPPING"; "TARGET_EXECUTION"; ...
    "EXPECTED_UPDATE"; "ARTIFACTS"; "FILTER_RESTORE"];
end


function message = list_failures(label, names, passed)
if all(passed)
    message = "All checks passed";
else
    message = string(label) + ": " + ...
        strjoin(string(names(~passed)), ', ');
end
end


function message = path_failure_message(paths, passed)
if all(passed)
    message = "Runtime target, model, Excel, and Test File exist";
else
    message = "Missing project inputs: " + ...
        strjoin(paths(~passed), ' | ');
end
end


function locations = which_all(name)
raw = which(char(name), '-all');
if isempty(raw)
    locations = strings(0,1);
elseif ischar(raw)
    locations = string(cellstr(raw));
elseif iscell(raw)
    locations = string(raw(:));
else
    locations = string(raw(:));
end
locations = locations(strlength(locations) > 0);
end


function path = canonical_path(path)
path = string(path);
if strlength(path) == 0
    return;
end
try
    path = string(char(java.io.File(char(path)).getCanonicalPath()));
catch
    path = string(path);
end
end


function tf = is_descendant_path(path, root)
path = canonical_path(path);
root = canonical_path(root);
if ispc
    path = lower(path);
    root = lower(root);
end
rootPrefix = root + string(filesep);
tf = path == root || startsWith(path, rootPrefix);
end


function tf = same_path(left, right)
left = canonical_path(left);
right = canonical_path(right);
if ispc
    left = lower(left);
    right = lower(right);
end
tf = left == right;
end


function code = bits_to_code(bits)
code = sprintf('%d', double(logical(bits)));
end


function print_legend()
fprintf(['SYSTEM-CHECK-v1 ENV_BITS=' ...
    'E1:R2025B,E2:PRODUCTS,E3:LICENSES,E4:INPUTS,' ...
    'E5:APIS,E6:PATHS\n']);
fprintf(['SYSTEM-CHECK-v1 RUN_BITS=' ...
    'R1:RUN_ROOT,R2:TARGET_MAPPING,R3:EXECUTION,' ...
    'R4:EXPECTED_UPDATE,R5:ARTIFACTS,R6:FILTER_RESTORE\n']);
end
