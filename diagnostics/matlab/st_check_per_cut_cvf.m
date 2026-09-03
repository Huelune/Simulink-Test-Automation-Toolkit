function [overallCode, details] = st_check_per_cut_cvf(varargin)
%ST_CHECK_PER_CUT_CVF Inspect generated per-CUT CVFs without changing them.
%
% [code, details] = st_check_per_cut_cvf()
% [code, details] = st_check_per_cut_cvf('RunDirectory', runDirectory)
%
% The command reads the latest PER_CUT run by default and prints one fixed
% six-bit code for every CVF-enabled target plus an aggregate code. Send the
% complete lines beginning with "CVF-CHECK-v1" when requesting diagnosis.
%
% Bit order:
%   B1  target manifest, CVF file, and SHA-256 are consistent
%   B2  generation, application, and restoration statuses are all OK
%   B3  saved rule count matches the manifest and is greater than zero
%   B4  the CUT root itself is not selected
%   B5  selectors exactly match the CUT's direct-child Subsystems
%   B6  selector type and filter action match the Excel mode/action
%
% Only result files are read. A model that was not already loaded is closed
% without saving when the inspection completes.

p = inputParser;
p.FunctionName = 'st_check_per_cut_cvf';
addParameter(p, 'RunDirectory', 'LATEST', ...
    @(x) (ischar(x) || (isstring(x) && isscalar(x))));
parse(p, varargin{:});

cfg = st_config();
totalTimer = tic;
requestedRun = char(string(p.Results.RunDirectory));
st_log(cfg, 'INFO', ...
    'Per-CUT CVF self-check start | RunDirectory=%s', requestedRun);

if ~cfg.HasRuntimeTarget || ~isfile(cfg.ModelFile)
    [overallCode, details] = fatal_result( ...
        'A valid runtime target model is not selected');
    st_log(cfg, 'ERROR', ...
        'Per-CUT CVF self-check failed | runtime target is unavailable');
    return;
end

try
    runDirectory = resolve_run_directory(requestedRun, cfg);
catch ME
    [overallCode, details] = fatal_result(ME.message);
    st_log(cfg, 'ERROR', ...
        'Per-CUT CVF self-check failed | %s: %s', ...
        ME.identifier, ME.message);
    return;
end

rootManifestPath = fullfile(runDirectory, 'manifest.json');
try
    rootManifest = read_json(rootManifestPath);
    if ~isfield(rootManifest, 'Targets') || isempty(rootManifest.Targets)
        error('simtest:CVFSelfCheckTargetsMissing', ...
            'Run manifest contains no target rows: %s', rootManifestPath);
    end
    targets = rootManifest.Targets;
catch ME
    [overallCode, details] = fatal_result(ME.message);
    st_log(cfg, 'ERROR', ...
        'Per-CUT CVF self-check manifest read failed | %s: %s', ...
        ME.identifier, ME.message);
    return;
end

modelName = char(string(cfg.TopModel));
modelWasLoaded = false;
modelAvailable = false;
modelMessage = "";
try
    modelWasLoaded = bdIsLoaded(modelName);
    if ~modelWasLoaded
        load_system(cfg.ModelFile);
    end
    modelAvailable = true;
catch ME
    modelMessage = string(ME.message);
end
modelCleanup = onCleanup(@() close_checker_model( ...
    modelName, modelWasLoaded, modelAvailable)); %#ok<NASGU>

No = zeros(0,1);
TestCaseName = strings(0,1);
CUTPath = strings(0,1);
CoverageFilterMode = strings(0,1);
Code = strings(0,1);
Status = strings(0,1);
Message = strings(0,1);
RuleCount = zeros(0,1);
RulePaths = strings(0,1);
TargetManifest = strings(0,1);
bitRows = false(0,6);

for i = 1:numel(targets)
    target = targets(i);
    mode = upper(field_text(target, ...
        {'FilterMode','CoverageFilterMode'}, ''));
    if strcmp(mode, 'OFF')
        continue;
    end

    manifestPath = resolve_target_manifest(target, runDirectory);
    [bits, diagnostic] = inspect_target( ...
        manifestPath, target, cfg, modelAvailable, modelMessage);

    No(end+1,1) = field_number(target, {'No'}, NaN); %#ok<AGROW>
    TestCaseName(end+1,1) = string(field_text( ...
        target, {'TestCaseName'}, '<unknown>')); %#ok<AGROW>
    CUTPath(end+1,1) = string(field_text( ...
        target, {'CUTPath'}, '<unknown>')); %#ok<AGROW>
    CoverageFilterMode(end+1,1) = string(mode); %#ok<AGROW>
    Code(end+1,1) = string(bits_to_code(bits)); %#ok<AGROW>
    if all(bits)
        Status(end+1,1) = "PASS"; %#ok<AGROW>
    else
        Status(end+1,1) = "FAIL"; %#ok<AGROW>
    end
    Message(end+1,1) = diagnostic.Message; %#ok<AGROW>
    RuleCount(end+1,1) = diagnostic.RuleCount; %#ok<AGROW>
    RulePaths(end+1,1) = diagnostic.RulePaths; %#ok<AGROW>
    TargetManifest(end+1,1) = string(manifestPath); %#ok<AGROW>
    bitRows(end+1,:) = bits; %#ok<AGROW>
end

if isempty(bitRows)
    overallCode = '000000';
    No = NaN;
    TestCaseName = "<none>";
    CUTPath = "";
    CoverageFilterMode = "OFF";
    Code = "000000";
    Status = "BLOCKED";
    Message = "No CVF-enabled target was found in the selected run";
    RuleCount = 0;
    RulePaths = "";
    TargetManifest = string(rootManifestPath);
else
    overallCode = bits_to_code(all(bitRows, 1));
end

details = table(No, TestCaseName, CUTPath, CoverageFilterMode, Code, ...
    Status, Message, RuleCount, RulePaths, TargetManifest);

print_legend();
for i = 1:height(details)
    fprintf(['CVF-CHECK-v1 TARGET No=%g TestCase="%s" ' ...
        'CODE=%s STATUS=%s\n'], ...
        details.No(i), char(details.TestCaseName(i)), ...
        char(details.Code(i)), char(details.Status(i)));
end
fprintf('CVF-CHECK-v1 OVERALL=%s RUN="%s"\n', ...
    overallCode, runDirectory);

if strcmp(overallCode, '111111')
    st_log(cfg, 'INFO', ...
        'Per-CUT CVF self-check complete | code=%s | elapsed=%.3f sec', ...
        overallCode, toc(totalTimer));
else
    st_log(cfg, 'WARN', ...
        ['Per-CUT CVF self-check found non-passing checks | ' ...
         'code=%s | elapsed=%.3f sec'], ...
        overallCode, toc(totalTimer));
end
end


function runDirectory = resolve_run_directory(requestedRun, cfg)
if strcmpi(strtrim(requestedRun), 'LATEST')
    pointer = cfg.PerCutLatestPointer;
    latest = read_json(pointer);
    if ~isfield(latest, 'RunDirectory')
        error('simtest:CVFSelfCheckLatestInvalid', ...
            'Latest pointer has no RunDirectory: %s', pointer);
    end
    runDirectory = char(string(latest.RunDirectory));
    if ~isfolder(runDirectory) && isfield(latest, 'RunId')
        localCandidate = fullfile( ...
            cfg.PerCutRunRootDir, char(string(latest.RunId)));
        if isfolder(localCandidate)
            runDirectory = localCandidate;
        end
    end
else
    runDirectory = requestedRun;
    if ~isfolder(runDirectory)
        localCandidate = fullfile(cfg.PerCutRunRootDir, requestedRun);
        if isfolder(localCandidate)
            runDirectory = localCandidate;
        end
    end
end
if ~isfolder(runDirectory)
    error('simtest:CVFSelfCheckRunNotFound', ...
        'PER_CUT run directory not found: %s', runDirectory);
end
end


function manifestPath = resolve_target_manifest(target, runDirectory)
manifestPath = field_text(target, {'TargetManifest'}, '');
if isfile(manifestPath)
    return;
end
try
    targetDirectory = st_per_cut_target_directory(runDirectory, target);
    localCandidate = fullfile(targetDirectory, 'target-manifest.json');
    if isfile(localCandidate)
        manifestPath = localCandidate;
    end
catch
    % Keep the recorded path so B1 reports the missing target manifest.
end
end


function [bits, diagnostic] = inspect_target( ...
        manifestPath, target, cfg, modelAvailable, modelMessage)
bits = false(1,6);
diagnostic = struct('Message', "", 'RuleCount', 0, 'RulePaths', "");
failures = strings(0,1);

if ~isfile(manifestPath)
    diagnostic.Message = "B1 target manifest is missing: " + ...
        string(manifestPath);
    return;
end

try
    manifest = read_json(manifestPath);
catch ME
    diagnostic.Message = "B1 target manifest cannot be read: " + ...
        string(ME.message);
    return;
end

cvfPath = field_text(manifest, {'CoverageFilterFile'}, '');
if ~isfile(cvfPath)
    listing = dir(fullfile(fileparts(manifestPath), 'filter', '*.cvf'));
    if numel(listing) == 1
        cvfPath = fullfile(listing(1).folder, listing(1).name);
    end
end

recordedHash = field_text(manifest, {'CoverageFilterSHA256'}, '');
try
    signature = st_file_signature(cvfPath);
    bits(1) = signature.Exists && ~isempty(recordedHash) && ...
        strcmpi(signature.SHA256, recordedHash);
catch ME
    failures(end+1,1) = "B1 " + string(ME.message); %#ok<AGROW>
end
if ~bits(1)
    failures(end+1,1) = ...
        "B1 manifest/CVF/SHA-256 integrity mismatch"; %#ok<AGROW>
end

generationStatus = upper(field_text( ...
    manifest, {'FilterGenerationStatus'}, ''));
applyStatus = upper(field_text(manifest, {'FilterApplyStatus'}, ''));
restoreStatus = upper(field_text(manifest, {'FilterRestoreStatus'}, ''));
bits(2) = strcmp(generationStatus, 'OK') && ...
    strcmp(applyStatus, 'OK') && strcmp(restoreStatus, 'OK');
if ~bits(2)
    failures(end+1,1) = "B2 lifecycle status is not OK/OK/OK"; %#ok<AGROW>
end

savedRules = [];
try
    savedFilter = slcoverage.Filter(cvfPath);
    savedRules = rules(savedFilter);
catch ME
    failures(end+1,1) = "B3 CVF read failed: " + ...
        string(ME.message); %#ok<AGROW>
end
actualRuleCount = numel(savedRules);
recordedRuleCount = field_number( ...
    manifest, {'CoverageFilterRuleCount'}, NaN);
diagnostic.RuleCount = actualRuleCount;
bits(3) = actualRuleCount > 0 && ...
    actualRuleCount == recordedRuleCount;
if ~bits(3)
    failures(end+1,1) = ...
        "B3 rule count is zero or differs from the manifest"; %#ok<AGROW>
end

if ~modelAvailable
    failures(end+1,1) = "B4-B6 model could not be loaded: " + ...
        modelMessage; %#ok<AGROW>
    diagnostic.Message = strjoin(unique(failures, 'stable'), ' | ');
    return;
end

mode = upper(field_text(manifest, ...
    {'CoverageFilterMode'}, field_text(target, {'FilterMode'}, '')));
action = upper(field_text(manifest, ...
    {'CoverageFilterAction'}, field_text(target, {'FilterAction'}, '')));
ownerPath = st_normalize_cut_path( ...
    field_text(manifest, {'CUTPath'}, field_text(target, {'CUTPath'}, '')), ...
    cfg.TopModel);

try
    ownerSid = string(Simulink.ID.getSID(ownerPath));
    expectedPaths = direct_child_subsystems(ownerPath);
    expectedSids = strings(numel(expectedPaths),1);
    for i = 1:numel(expectedPaths)
        expectedSids(i) = string(Simulink.ID.getSID(expectedPaths{i}));
    end

    selectedSids = strings(actualRuleCount,1);
    selectedPaths = strings(actualRuleCount,1);
    selectorTypes = strings(actualRuleCount,1);
    ruleModes = strings(actualRuleCount,1);
    selectorsAreBlocks = true;
    for i = 1:actualRuleCount
        selector = savedRules(i).Selector;
        selectorsAreBlocks = selectorsAreBlocks && ...
            isa(selector, 'slcoverage.BlockSelector');
        selectedSids(i) = string(selector.Id);
        selectedPaths(i) = selector_path(selector.Id);
        selectorTypes(i) = enum_tail(selector.Type);
        ruleModes(i) = enum_tail(savedRules(i).Mode);
    end
    diagnostic.RulePaths = strjoin(selectedPaths, ' | ');

    bits(4) = selectorsAreBlocks && ...
        ~any(selectedSids == ownerSid) && ...
        ~any(selectedPaths == string(ownerPath));
    if ~bits(4)
        failures(end+1,1) = "B4 CUT root is selected or unresolved"; %#ok<AGROW>
    end

    bits(5) = selectorsAreBlocks && exact_string_set( ...
        selectedPaths, string(expectedPaths(:)));
    if ~bits(5)
        failures(end+1,1) = ...
            "B5 selectors do not exactly match direct-child Subsystems"; %#ok<AGROW>
    end

    if strcmp(mode, 'SUBSYSTEM')
        expectedSelectorType = "BLOCKINSTANCE";
    else
        expectedSelectorType = "SUBSYSTEMALLCONTENT";
    end
    bits(6) = selectorsAreBlocks && ...
        all(selectorTypes == expectedSelectorType) && ...
        all(ruleModes == string(action));
    if ~bits(6)
        failures(end+1,1) = ...
            "B6 selector type or filter action differs from Excel"; %#ok<AGROW>
    end
catch ME
    failures(end+1,1) = "B4-B6 model selector inspection failed: " + ...
        string(ME.message); %#ok<AGROW>
end

if isempty(failures)
    diagnostic.Message = "All six CVF checks passed";
else
    diagnostic.Message = strjoin(unique(failures, 'stable'), ' | ');
end
end


function paths = direct_child_subsystems(ownerPath)
paths = find_system(ownerPath, ...
    'SearchDepth', 1, ...
    'FollowLinks', 'on', ...
    'LookUnderMasks', 'all', ...
    'LookInsideSubsystemReference', 'on', ...
    'MatchFilter', @Simulink.match.allVariants, ...
    'Type', 'Block', ...
    'BlockType', 'SubSystem');
paths = cellstr(string(paths(:)));
paths = paths(~strcmp(paths, ownerPath));
paths = unique(paths, 'stable');
end


function path = selector_path(identifier)
path = "";
try
    handle = Simulink.ID.getHandle(char(string(identifier)));
    if ~isempty(handle) && handle ~= -1
        path = string(getfullname(handle));
    end
catch
    try
        handle = getSimulinkBlockHandle(char(string(identifier)));
        if handle ~= -1
            path = string(getfullname(handle));
        end
    catch
        path = "";
    end
end
end


function tf = exact_string_set(actual, expected)
actual = actual(:);
expected = expected(:);
tf = numel(actual) == numel(expected) && ...
    numel(unique(actual)) == numel(actual) && ...
    isequal(sort(actual), sort(expected));
end


function text = enum_tail(value)
text = upper(string(value));
pieces = split(text, '.');
text = pieces(end);
end


function value = field_text(data, names, defaultValue)
value = defaultValue;
for i = 1:numel(names)
    if isfield(data, names{i})
        candidate = data.(names{i});
        if ~isempty(candidate)
            value = char(string(candidate));
            return;
        end
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
        parsed = str2double(string(candidate));
        if isscalar(parsed) && ~isnan(parsed)
            value = double(parsed);
            return;
        end
    end
end
end


function value = read_json(path)
if ~isfile(path)
    error('simtest:CVFSelfCheckJsonMissing', ...
        'JSON file not found: %s', path);
end
value = jsondecode(fileread(path));
end


function code = bits_to_code(bits)
code = sprintf('%d', double(logical(bits)));
end


function print_legend()
fprintf(['CVF-CHECK-v1 BITS=' ...
    'B1:INTEGRITY,' ...
    'B2:LIFECYCLE,' ...
    'B3:RULE_COUNT,' ...
    'B4:CUT_EXCLUDED,' ...
    'B5:DIRECT_CHILDREN,' ...
    'B6:MODE_ACTION\n']);
end


function close_checker_model(modelName, modelWasLoaded, modelAvailable)
if modelAvailable && ~modelWasLoaded && bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end


function [code, details] = fatal_result(message)
code = '000000';
No = NaN;
TestCaseName = "<unavailable>";
CUTPath = "";
CoverageFilterMode = "";
Code = "000000";
Status = "BLOCKED";
Message = string(message);
RuleCount = 0;
RulePaths = "";
TargetManifest = "";
details = table(No, TestCaseName, CUTPath, CoverageFilterMode, Code, ...
    Status, Message, RuleCount, RulePaths, TargetManifest);
print_legend();
fprintf('CVF-CHECK-v1 OVERALL=000000 ERROR="%s"\n', ...
    char(replace(string(message), '"', ' ')));
end
