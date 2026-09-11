function [bundlePaths, details] = st_export_standalone_harnesses( ...
        sourceModelFile, topModel, targets, destination, bundleRoot, varargin)
%ST_EXPORT_STANDALONE_HARNESSES Export Harnesses from a disposable copy.

p = inputParser;
addParameter(p, 'ModelNameMode', 'HARNESS', ...
    @(x) ismember(upper(string(x)), ["HARNESS","TARGET_HARNESS"]));
addParameter(p, 'LogConfig', [], @(x) isempty(x) || isstruct(x));
parse(p, varargin{:});
modelNameMode = upper(char(string(p.Results.ModelNameMode)));
logConfig = p.Results.LogConfig;

totalTimer = tic;
log_message(logConfig, 'INFO', ...
    'Standalone Harness export start | Targets=%d | NameMode=%s', ...
    height(targets), modelNameMode);

if ~isfile(sourceModelFile)
    error('simtest:AssetModelMissing', ...
        'Source model is missing: %s', sourceModelFile);
end
if ~isfolder(destination), mkdir(destination); end

bundlePaths = strings(height(targets), 1);
details = repmat(empty_detail(), height(targets), 1);
% tempname() adds a ~38-character GUID segment. destination is already
% deeply nested (template/workspace/standalone/...), and each per-target
% output folder created below inherits that full prefix, so a short token
% here matters for the Windows 260-character MAX_PATH budget.
workRoot = short_work_directory(destination);
mkdir(workRoot);

% Session state for cleanup_export_session is kept in a containers.Map
% (a handle/reference object) rather than plain local variables. A plain
% onCleanup(@nestedFunction) shares this function's own workspace, and
% that combination has been observed to fail during exception unwinding
% with "attempted to read or write a variable ... already removed from
% the workspace of the existing function". A Map is an independent object
% on the heap: mutating it (state('SourceDetached') = true, etc.) is
% always visible to the cleanup callback regardless of how this function's
% stack frame is torn down.
state = containers.Map();
state('WorkRoot') = workRoot;
state('TopModel') = char(topModel);
state('SourceModelFile') = char(sourceModelFile);
state('SourceWasLoaded') = bdIsLoaded(topModel);
state('SourceWasOpen') = false;
state('OpenHarnesses') = repmat(struct( ...
    'Owner', '', 'Name', '', 'WasOpen', false), 0, 1);
state('SourceDetached') = false;
sessionCleanup = onCleanup(@() cleanup_export_session(state)); %#ok<NASGU>

[~, sourceName, extension] = fileparts(sourceModelFile);
if ~strcmp(sourceName, char(topModel))
    error('simtest:AssetModelNameMismatch', ...
        'Model file name must match TopModel: %s | %s', ...
        sourceName, char(topModel));
end
% Internal Harness metadata retains owner paths. Keep the original model
% name and isolate by directory instead of renaming the copied model.
temporaryModel = char(topModel);
temporaryModelFile = fullfile(workRoot, [sourceName extension]);
copy_checked(sourceModelFile, temporaryModelFile);

if state('SourceWasLoaded')
    try
        state('SourceWasOpen') = strcmp(get_param(topModel, 'Open'), 'on');
    catch
    end
end
if ~state('SourceWasLoaded'), load_system(sourceModelFile); end
state('OpenHarnesses') = close_open_source_harnesses(topModel);
try
    close_system(topModel, 0);
catch ME
    if bdIsLoaded(topModel)
        restore_source_harnesses(state('OpenHarnesses'));
    else
        state('SourceDetached') = true;
    end
    rethrow(ME);
end
state('SourceDetached') = true;

load_system(temporaryModelFile);
loadedTemporaryFile = char(get_param(temporaryModel, 'FileName'));
if ~same_path(loadedTemporaryFile, temporaryModelFile)
    error('simtest:AssetTempModelLoadMismatch', ...
        ['Refusing Harness export because MATLAB loaded a different ' ...
         'model file: %s'], loadedTemporaryFile);
end

keys = strings(0,1);
keyPaths = strings(0,1);
keyDetails = repmat(empty_detail(), 0, 1);
for i = 1:height(targets)
    sourceOwner = char(st_normalize_cut_path( ...
        targets.CUTPath(i), topModel));
    harnessName = char(string(targets.HarnessName(i)));
    key = string(lower(sourceOwner)) + "|" + string(lower(harnessName));
    if strcmp(modelNameMode, 'TARGET_HARNESS')
        key = string(round(double(targets.No(i)))) + "|" + key;
    end
    existing = find(keys == key, 1);
    if ~isempty(existing)
        bundlePaths(i) = keyPaths(existing);
        details(i) = keyDetails(existing);
        continue;
    end

    matches = sltest.harness.find( ...
        sourceOwner, 'SearchDepth', 0, 'Name', harnessName);
    if numel(matches) ~= 1
        error('simtest:AssetHarnessMissing', ...
            ['Expected one Harness in the copied model %s, found %d: ' ...
             '%s | %s'], temporaryModelFile, numel(matches), ...
            sourceOwner, harnessName);
    end

    outputFolder = fullfile(destination, target_folder(targets(i,:)));
    if ~isfolder(outputFolder), mkdir(outputFolder); end
    outputModel = standalone_model_name(harnessName, targets(i,:), ...
        modelNameMode);
    outputPath = fullfile(outputFolder, [outputModel '.slx']);

    previousFolder = pwd;
    folderCleanup = onCleanup(@() cd(previousFolder)); %#ok<NASGU>
    cd(outputFolder);
    try
        save_system(temporaryModel);
        sltest.harness.export( ...
            sourceOwner, harnessName, 'Name', outputModel);
        if bdIsLoaded(outputModel)
            save_system(outputModel, outputPath);
            close_system(outputModel, 0);
        end
        if ~isfile(outputPath)
            error('simtest:AssetHarnessExportMissing', ...
                'Standalone Harness file was not created: %s', outputPath);
        end
        load_system(outputPath);
        standaloneCutPath = identify_standalone_cut( ...
            sourceOwner, outputModel);
        close_system(outputModel, 0);
    catch ME
        if bdIsLoaded(outputModel), close_system(outputModel, 0); end
        rethrow(ME);
    end
    clear folderCleanup;

    relative = portable_path(st_export_relative_path(outputPath, bundleRoot));
    keys(end+1,1) = key; %#ok<AGROW>
    keyPaths(end+1,1) = string(relative); %#ok<AGROW>
    bundlePaths(i) = string(relative);
    details(i) = struct( ...
        'StandaloneModel', outputModel, ...
        'StandaloneModelFile', relative, ...
        'StandaloneCUTPath', standaloneCutPath);
    keyDetails(end+1,1) = details(i); %#ok<AGROW>
    log_message(logConfig, 'DEBUG', ...
        ['[StandaloneHarness %d/%d] exported | Source=%s | ' ...
         'Harness=%s | Model=%s | CUT=%s'], ...
        i, height(targets), sourceOwner, harnessName, ...
        outputModel, standaloneCutPath);
end
clear sessionCleanup;
log_message(logConfig, 'INFO', ...
    'Standalone Harness export complete | Targets=%d | elapsed=%.3f sec', ...
    height(targets), toc(totalTimer));
end

function cleanup_export_session(state)
%CLEANUP_EXPORT_SESSION Restore the source model session, then always
% remove the scratch work folder. state is a containers.Map so this plain
% (non-nested) function sees whatever the caller last wrote to it, even
% when invoked by onCleanup during exception unwinding.
restoreError = [];
try
    if state('SourceDetached')
        close_model(state('TopModel'));
        if state('SourceWasLoaded')
            load_system(state('SourceModelFile'));
            loadedSourceFile = char(get_param( ...
                state('TopModel'), 'FileName'));
            if ~same_path(loadedSourceFile, state('SourceModelFile'))
                error('simtest:AssetSourceRestoreMismatch', ...
                    ['MATLAB restored a different source model ' ...
                     'file: %s'], loadedSourceFile);
            end
            if state('SourceWasOpen'), open_system(state('TopModel')); end
            restore_source_harnesses(state('OpenHarnesses'));
        end
    end
catch ME
    restoreError = ME;
end
remove_work_root(state('WorkRoot'));
if ~isempty(restoreError), rethrow(restoreError); end
end

function folder = target_folder(row)
% The %04d No prefix already makes this folder name unique per target, so
% the CUT-name portion can be capped well below st_export_safe_name's
% general 80-character limit to leave headroom for the Windows 260-
% character MAX_PATH budget under a deeply nested destination.
maxNameLength = 32;
safeName = st_export_safe_name(char(string(row.CUTName)));
if numel(safeName) > maxNameLength
    safeName = safeName(1:maxNameLength);
end
folder = sprintf('%04d_%s', round(double(row.No)), safeName);
end

function directory = short_work_directory(parentDirectory)
%SHORT_WORK_DIRECTORY Create a compact, collision-safe scratch folder.
for attempt = 1:20
    uuid = char(java.util.UUID.randomUUID());
    token = uuid(~ismember(uuid, '-'));
    candidate = fullfile(parentDirectory, ['~w' token(1:6)]);
    if ~isfolder(candidate) && ~isfile(candidate)
        directory = candidate;
        return;
    end
end
error('simtest:StandaloneWorkDirectoryUnavailable', ...
    'Could not create a unique work directory under: %s', ...
    parentDirectory);
end

function name = standalone_model_name(harnessName, row, mode)
if strcmp(mode, 'TARGET_HARNESS')
    name = sprintf('st_h_%04d_%s', round(double(row.No)), ...
        st_export_safe_name(harnessName));
    name = matlab.lang.makeValidName(name);
    if numel(name) > namelengthmax
        name = name(1:namelengthmax);
    end
else
    name = char(harnessName);
end
if ~isvarname(name) || numel(name) > namelengthmax
    error('simtest:AssetHarnessNameInvalidForModel', ...
        ['HarnessName must also be a valid standalone Simulink model ' ...
         'name: %s'], name);
end
end

function path = identify_standalone_cut(sourceOwner, standaloneModel)
sourceName = get_param(sourceOwner, 'Name');
sourceSignature = interface_signature(sourceOwner);
candidates = find_system(standaloneModel, ...
    'SearchDepth', 1, 'Type', 'Block');
candidates = cellstr(string(candidates(:)));
candidates = candidates(~strcmp(candidates, standaloneModel));
matches = strings(0,1);
for i = 1:numel(candidates)
    if ~strcmp(get_param(candidates{i}, 'Name'), sourceName)
        continue;
    end
    if isequal(interface_signature(candidates{i}), sourceSignature)
        matches(end+1,1) = string(candidates{i}); %#ok<AGROW>
    end
end
if numel(matches) ~= 1
    error('simtest:StandaloneCUTIdentificationFailed', ...
        ['Expected exactly one exported CUT matching name and interface. ' ...
         'Source=%s | Model=%s | Matches=%d'], ...
        sourceOwner, standaloneModel, numel(matches));
end
path = char(matches(1));
end

function signature = interface_signature(block)
ports = find_system(block, 'SearchDepth', 1, 'Type', 'Block');
ports = cellstr(string(ports(:)));
ports = ports(~strcmp(ports, block));
rows = strings(0,1);
for i = 1:numel(ports)
    blockType = get_param(ports{i}, 'BlockType');
    if ~ismember(blockType, {'Inport','Outport','EnablePort', ...
            'TriggerPort','ResetPort'})
        continue;
    end
    portNumber = '';
    try, portNumber = get_param(ports{i}, 'Port'); catch, end
    rows(end+1,1) = string(blockType) + "|" + ...
        string(portNumber) + "|" + string(get_param(ports{i}, 'Name')); %#ok<AGROW>
end
signature = sort(rows);
end

function value = empty_detail()
value = struct('StandaloneModel', '', ...
    'StandaloneModelFile', '', 'StandaloneCUTPath', '');
end

function log_message(cfg, level, formatText, varargin)
if isempty(cfg), return; end
st_log(cfg, level, formatText, varargin{:});
end

function openHarnesses = close_open_source_harnesses(topModel)
openHarnesses = repmat(struct( ...
    'Owner', '', 'Name', '', 'WasOpen', false), 0, 1);
harnesses = sltest.harness.find(topModel, 'OpenOnly', 'on');
try
    for i = 1:numel(harnesses)
        owner = char(harnesses(i).ownerFullPath);
        name = char(harnesses(i).name);
        if bdIsLoaded(name) && strcmp(get_param(name, 'Dirty'), 'on')
            error('simtest:AssetUnsavedHarness', ...
                'Save the open Harness before asset export: %s', name);
        end
        wasOpen = logical_value(harnesses(i).isOpen);
        try
            sltest.harness.close(owner, name);
        catch ME
            error('simtest:AssetHarnessCloseFailed', ...
                'Cannot temporarily close open Harness %s: %s', ...
                name, ME.message);
        end
        openHarnesses(end+1,1) = struct( ...
            'Owner', owner, 'Name', name, ...
            'WasOpen', wasOpen); %#ok<AGROW>
    end
catch ME
    restore_source_harnesses(openHarnesses);
    rethrow(ME);
end
end

function value = logical_value(raw)
value = false;
if isempty(raw), return; end
if islogical(raw) || isnumeric(raw)
    value = logical(raw(1));
    return;
end
text = lower(strtrim(char(string(raw))));
value = ismember(text, {'true','1','yes','on'});
end

function restore_source_harnesses(openHarnesses)
for i = 1:numel(openHarnesses)
    try
        if openHarnesses(i).WasOpen
            sltest.harness.open( ...
                openHarnesses(i).Owner, openHarnesses(i).Name);
        else
            sltest.harness.load( ...
                openHarnesses(i).Owner, openHarnesses(i).Name);
        end
    catch ME
        warning('simtest:AssetHarnessRestoreFailed', ...
            'Cannot restore previously open Harness %s: %s', ...
            openHarnesses(i).Name, ME.message);
    end
end
end

function copy_checked(source, destination)
[ok, message] = copyfile(source, destination, 'f');
if ~ok
    error('simtest:AssetCopyFailed', ...
        'Cannot copy %s to %s: %s', source, destination, message);
end
end

function close_model(model)
if bdIsLoaded(model), close_system(model, 0); end
end

function remove_work_root(path)
if isfolder(path)
    try
        rmdir(path, 's');
    catch
    end
end
end

function value = portable_path(path)
value = strrep(char(path), '\', '/');
end

function tf = same_path(left, right)
left = char(java.io.File(char(left)).getCanonicalPath());
right = char(java.io.File(char(right)).getCanonicalPath());
if ispc
    tf = strcmpi(left, right);
else
    tf = strcmp(left, right);
end
end
