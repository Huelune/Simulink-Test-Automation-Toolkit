function [code, details] = st_check_standalone_run(varargin)
%ST_CHECK_STANDALONE_RUN Print a six-bit exported-model acceptance code.
%
% S1 root pointer, manifest, workbook, and Test File are coherent
% S2 every CUT has the required initial/final standalone model snapshot
% S3 Harness CVF exactly covers top-level infrastructure except the CUT
% S4 target CVF is OFF or exactly covers direct child Subsystems
% S5 expected-value update and final re-export linkage is coherent
% S6 execution, filter restoration, source-state, and artifacts passed

p = inputParser;
addParameter(p, 'RunDirectory', 'LATEST', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
parse(p, varargin{:});
cfg = st_require_runtime_target();
requested = char(string(p.Results.RunDirectory));
st_log(cfg, 'INFO', ...
    'Standalone self-check start | RunDirectory=%s', requested);

[runDirectory, pointer] = resolve_run(requested, cfg);
manifestPath = fullfile(runDirectory, 'manifest.json');
manifest = read_json(manifestPath);
bits = false(1,6);
messages = repmat("Check was not completed", 6, 1);

summaryPath = fullfile(runDirectory, 'TestSummary.xlsx');
testFilePath = fullfile(runDirectory, 'test_manager', ...
    'StandaloneHarnessTests.mldatx');
bits(1) = isfile(manifestPath) && isfile(summaryPath) && ...
    isfile(testFilePath) && ...
    strcmpi(field_text(manifest, 'SystemUnderTestMode'), ...
        'EXPORTED_MODEL') && ...
    same_path(field_text(manifest, 'RunDirectory'), runDirectory) && ...
    isempty(pointer_error(pointer, manifest, manifestPath, summaryPath));
messages(1) = ternary(bits(1), ...
    "Standalone run root is coherent", ...
    "Pointer, manifest, workbook, or Test File is inconsistent");

targets = manifest.Targets;
if isempty(targets), targets = struct([]); end
modelOk = true(numel(targets),1);
harnessOk = true(numel(targets),1);
targetOk = true(numel(targets),1);
linkOk = true(numel(targets),1);
runOk = true(numel(targets),1);
targetMessages = strings(numel(targets),1);
for i = 1:numel(targets)
    try
        targetManifest = read_json(field_text(targets(i), ...
            'TargetManifest'));
        initialModel = targetManifest.InitialModel;
        finalModel = targetManifest.FinalModel;
        initialFilters = targetManifest.InitialFilters;
        finalFilters = targetManifest.FinalFilters;

        modelOk(i) = model_snapshot_ok(initialModel);
        if logical(field_number(targetManifest, 'RerunPerformed'))
            modelOk(i) = modelOk(i) && model_snapshot_ok(finalModel);
        end
        [harnessOk(i), targetOk(i)] = inspect_phase( ...
            initialModel, initialFilters, targetManifest, cfg);
        if logical(field_number(targetManifest, 'RerunPerformed'))
            [finalHarnessOk, finalTargetOk] = inspect_phase( ...
                finalModel, finalFilters, targetManifest, cfg);
            harnessOk(i) = harnessOk(i) && finalHarnessOk;
            targetOk(i) = targetOk(i) && finalTargetOk;
        end
        updateCount = field_number(targetManifest, ...
            'ExpectedUpdatedCount');
        rerun = logical(field_number(targetManifest, 'RerunPerformed'));
        linkOk(i) = (updateCount <= 0 && ~rerun) || ...
            (updateCount > 0 && rerun && model_snapshot_ok(finalModel));
        runOk(i) = strcmpi(field_text(targetManifest, 'Status'), 'PASS') && ...
            strcmpi(field_text(targetManifest, ...
                'FilterRestoreStatus'), 'OK') && ...
            ~ismember(upper(string(field_text(targetManifest, ...
                'InitialOutcome'))), ["","NOT_RUN","UNKNOWN"]);
        targetMessages(i) = "OK";
    catch ME
        modelOk(i) = false;
        harnessOk(i) = false;
        targetOk(i) = false;
        linkOk(i) = false;
        runOk(i) = false;
        targetMessages(i) = string(ME.message);
    end
end

bits(2) = ~isempty(targets) && all(modelOk);
bits(3) = ~isempty(targets) && all(harnessOk);
bits(4) = ~isempty(targets) && all(targetOk);
bits(5) = ~isempty(targets) && all(linkOk);
sourceSafe = isfield(manifest, 'SourceState') && ...
    logical(field_number(manifest.SourceState, 'Safe'));
bits(6) = ~isempty(targets) && all(runOk) && sourceSafe && ...
    artifact_rows_ok(manifest);
messages(2) = summary_message(modelOk, targetMessages, ...
    'Standalone model snapshots exist and match checksums');
messages(3) = summary_message(harnessOk, targetMessages, ...
    'Harness CVFs exclude only the exported CUT from top-level scope');
messages(4) = summary_message(targetOk, targetMessages, ...
    'Target CVFs match direct-child Subsystem policy');
messages(5) = summary_message(linkOk, targetMessages, ...
    'Expected updates and final re-exports are linked');
messages(6) = summary_message(runOk & sourceSafe, targetMessages, ...
    'Execution, restoration, source state, and artifacts passed');

CheckId = "S" + string((1:6).');
Name = ["RUN_ROOT";"MODEL_SNAPSHOTS";"HARNESS_SCOPE_CVF"; ...
    "TARGET_POLICY_CVF";"EXPECTED_REEXPORT";"RUN_INTEGRITY"];
Pass = bits(:);
Message = messages;
details = table(CheckId, Name, Pass, Message);
code = char(join(string(double(bits)), ''));
fprintf(['STANDALONE-CHECK-v1 CODE=%s RUN_DIRECTORY="%s" ' ...
    'LEGEND="S1:ROOT S2:MODELS S3:HARNESS_CVF S4:TARGET_CVF ' ...
    'S5:REEXPORT S6:INTEGRITY"\n'], code, runDirectory);
if strcmp(code, '111111')
    st_log(cfg, 'INFO', 'Standalone self-check complete | code=%s', code);
else
    st_log(cfg, 'WARN', ...
        'Standalone self-check found non-passing checks | code=%s', code);
end
end

function [harnessOk, targetOk] = inspect_phase( ...
        modelInfo, filters, target, cfg)
modelPath = field_text(modelInfo, 'ModelPath');
modelName = field_text(modelInfo, 'ModelName');
directory = fileparts(modelPath);
addpath(directory, '-begin');
pathCleanup = onCleanup(@() remove_path(directory)); %#ok<NASGU>
load_system(modelPath);
modelCleanup = onCleanup(@() close_model(modelName)); %#ok<NASGU>
cut = st_resolve_exported_cut(modelName, struct2table_row(target), cfg);

topBlocks = find_system(modelName, 'SearchDepth', 1, ...
    'FollowLinks', 'on', 'LookUnderMasks', 'all', 'Type', 'Block');
topBlocks = string(topBlocks(:));
expectedHarness = sort(topBlocks(topBlocks ~= string(cut.ExportedPath)));
actualHarness = sort(field_strings(filters.Harness, 'RulePaths'));
harnessPath = field_text(filters.Harness, 'Path');
harnessTypes = strings(numel(expectedHarness),1);
for i = 1:numel(expectedHarness)
    if strcmp(get_param(char(expectedHarness(i)), 'BlockType'), 'SubSystem')
        harnessTypes(i) = string( ...
            slcoverage.BlockSelectorType.SubsystemAllContent);
    else
        harnessTypes(i) = string( ...
            slcoverage.BlockSelectorType.BlockInstance);
    end
end
harnessModes = repmat(string(slcoverage.FilterMode.Exclude), ...
    numel(expectedHarness), 1);
harnessRationales = repmat( ...
    "Test Harness infrastructure; not design under test", ...
    numel(expectedHarness), 1);
harnessSignature = st_file_signature(harnessPath);
harnessOk = isfile(harnessPath) && ...
    strcmpi(harnessSignature.SHA256, ...
        field_text(filters.Harness, 'SHA256')) && ...
    isequal(expectedHarness, actualHarness) && ...
    ~any(field_strings(filters.Harness, 'RuleSIDs') == string(cut.SID)) && ...
    stored_rule_metadata_ok(filters.Harness, expectedHarness, ...
        harnessTypes, harnessModes, harnessRationales);

mode = upper(string(field_text(target, 'CoverageFilterMode')));
if mode == "OFF"
    targetOk = strcmpi(field_text(filters.Target, 'Status'), 'OFF') && ...
        isempty(field_text(filters.Target, 'Path'));
else
    childBlocks = find_system(cut.ExportedPath, 'SearchDepth', 1, ...
        'FollowLinks', 'on', 'LookUnderMasks', 'all', ...
        'LookInsideSubsystemReference', 'on', ...
        'MatchFilter', @Simulink.match.allVariants, ...
        'Type', 'Block', 'BlockType', 'SubSystem');
    childBlocks = string(childBlocks(:));
    childBlocks = sort(childBlocks(childBlocks ~= string(cut.ExportedPath)));
    targetPath = field_text(filters.Target, 'Path');
    if mode == "SUBSYSTEM"
        targetType = string(slcoverage.BlockSelectorType.BlockInstance);
    else
        targetType = string( ...
            slcoverage.BlockSelectorType.SubsystemAllContent);
    end
    targetTypes = repmat(targetType, numel(childBlocks), 1);
    if upper(string(field_text(target, 'CoverageFilterAction'))) == "EXCLUDE"
        targetMode = string(slcoverage.FilterMode.Exclude);
    else
        targetMode = string(slcoverage.FilterMode.Justify);
    end
    targetModes = repmat(targetMode, numel(childBlocks), 1);
    targetRationales = repmat(string(field_text( ...
        target, 'CoverageFilterRationale')), numel(childBlocks), 1);
    targetSignature = st_file_signature(targetPath);
    targetOk = isfile(targetPath) && ...
        strcmpi(targetSignature.SHA256, ...
            field_text(filters.Target, 'SHA256')) && ...
        isequal(childBlocks, sort(field_strings( ...
            filters.Target, 'RulePaths'))) && ...
        ~any(field_strings(filters.Target, 'RuleSIDs') == string(cut.SID)) && ...
        stored_rule_metadata_ok(filters.Target, childBlocks, ...
            targetTypes, targetModes, targetRationales);
end
end

function ok = stored_rule_metadata_ok(info, paths, types, modes, rationales)
[paths, expectedOrder] = sort(string(paths(:)));
actualPaths = field_strings(info, 'RulePaths');
[actualPaths, actualOrder] = sort(actualPaths(:));
actualTypes = field_strings(info, 'SelectorTypes');
actualModes = field_strings(info, 'Modes');
actualRationales = field_strings(info, 'Rationales');
ok = isequal(actualPaths, paths) && ...
    numel(actualTypes) == numel(paths) && ...
    numel(actualModes) == numel(paths) && ...
    numel(actualRationales) == numel(paths);
if ~ok, return; end
types = string(types(:));
modes = string(modes(:));
rationales = string(rationales(:));
ok = isequal(actualTypes(actualOrder), types(expectedOrder)) && ...
    isequal(actualModes(actualOrder), modes(expectedOrder)) && ...
    isequal(actualRationales(actualOrder), rationales(expectedOrder));
end

function row = struct2table_row(target)
row = table(field_number(target, 'No'), ...
    string(field_text(target, 'CUTName')), ...
    string(field_text(target, 'CUTPath')), ...
    string(field_text(target, 'TestCaseName')), ...
    'VariableNames', {'No','CUTName','CUTPath','TestCaseName'});
end

function ok = model_snapshot_ok(info)
path = field_text(info, 'ModelPath');
signature = st_file_signature(path);
ok = isfile(path) && strcmpi(signature.SHA256, ...
    field_text(info, 'ModelSHA256')) && ...
    ~isempty(field_text(info, 'ExportedCUTPath')) && ...
    ~isempty(field_text(info, 'ExportedCUTSID'));
end

function ok = artifact_rows_ok(manifest)
ok = true;
if ~isfield(manifest, 'Artifacts'), ok = false; return; end
artifacts = manifest.Artifacts;
for i = 1:numel(artifacts)
    path = field_text(artifacts(i), 'Path');
    if strcmpi(field_text(artifacts(i), 'Status'), 'FAIL') || ...
            (~isempty(path) && ~isfile(path) && ~isfolder(path))
        ok = false;
        return;
    end
end
end

function [directory, pointer] = resolve_run(requested, cfg)
pointer = struct();
if strcmpi(requested, 'LATEST')
    pointer = read_json(cfg.StandaloneLatestPointer);
    directory = field_text(pointer, 'RunDirectory');
else
    directory = requested;
end
if ~isfolder(directory)
    error('simtest:StandaloneCheckRunMissing', ...
        'Standalone run directory is missing: %s', directory);
end
end

function message = pointer_error(pointer, manifest, manifestPath, summaryPath)
message = '';
if isempty(fieldnames(pointer)), return; end
if ~strcmp(field_text(pointer, 'RunId'), field_text(manifest, 'RunId')) || ...
        ~same_path(field_text(pointer, 'Manifest'), manifestPath) || ...
        ~same_path(field_text(pointer, 'Summary'), summaryPath)
    message = 'Latest pointer mismatch';
end
end

function value = read_json(path)
if ~isfile(path)
    error('simtest:StandaloneCheckFileMissing', ...
        'Required JSON is missing: %s', path);
end
value = jsondecode(fileread(path));
end

function value = field_text(value, name)
if isstruct(value) && isfield(value, name)
    value = char(string(value.(name)));
else
    value = '';
end
end

function value = field_number(item, name)
if isstruct(item) && isfield(item, name)
    value = double(item.(name));
else
    value = 0;
end
end

function values = field_strings(item, name)
if isstruct(item) && isfield(item, name)
    values = string(item.(name));
    values = values(:);
else
    values = strings(0,1);
end
end

function message = summary_message(mask, details, success)
if ~isempty(mask) && all(mask)
    message = string(success);
else
    failed = details(~mask & strlength(details) > 0);
    if isempty(failed), message = "One or more checks failed";
    else, message = strjoin(unique(failed, 'stable'), ' | '); end
end
end

function value = ternary(condition, yesValue, noValue)
if condition, value = yesValue; else, value = noValue; end
end

function remove_path(directory)
try, rmpath(directory); catch, end
end

function close_model(modelName)
if bdIsLoaded(modelName), close_system(modelName, 0); end
end

function tf = same_path(left, right)
if isempty(left) || isempty(right), tf = false; return; end
left = char(java.io.File(char(left)).getCanonicalPath());
right = char(java.io.File(char(right)).getCanonicalPath());
if ispc, tf = strcmpi(left, right); else, tf = strcmp(left, right); end
end
