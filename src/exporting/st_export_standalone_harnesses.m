function bundlePaths = st_export_standalone_harnesses( ...
        sourceModelFile, topModel, targets, destination, bundleRoot, varargin)
%ST_EXPORT_STANDALONE_HARNESSES Export Harnesses from a disposable copy.

p = inputParser;
addParameter(p, 'ModelNames', strings(0,1), ...
    @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'FlatOutput', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'LogConfig', struct(), @isstruct);
parse(p, varargin{:});

modelNames = string(p.Results.ModelNames(:));
if isempty(modelNames)
    modelNames = string(targets.HarnessName);
elseif numel(modelNames) ~= height(targets)
    error('simtest:StandaloneModelNameCountMismatch', ...
        'ModelNames must contain one name per target row.');
end
flatOutput = logical(p.Results.FlatOutput);
logCfg = p.Results.LogConfig;

if ~isempty(fieldnames(logCfg))
    st_log(logCfg, 'INFO', ...
        'Standalone Harness export start | targets=%d | destination=%s', ...
        height(targets), destination);
end

if ~isfile(sourceModelFile)
    error('simtest:AssetModelMissing', ...
        'Source model is missing: %s', sourceModelFile);
end
if ~isfolder(destination), mkdir(destination); end

bundlePaths = strings(height(targets), 1);
workRoot = tempname(destination);
mkdir(workRoot);
sourceWasLoaded = bdIsLoaded(topModel);
sourceWasOpen = false;
openHarnesses = repmat(struct( ...
    'Owner', '', 'Name', '', 'WasOpen', false), 0, 1);
sourceDetached = false;
sessionCleanup = onCleanup(@cleanup_export_session); %#ok<NASGU>

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

if sourceWasLoaded
    try
        sourceWasOpen = strcmp(get_param(topModel, 'Open'), 'on');
    catch
    end
end
if ~sourceWasLoaded, load_system(sourceModelFile); end
openHarnesses = close_open_source_harnesses(topModel);
try
    close_system(topModel, 0);
catch ME
    if bdIsLoaded(topModel)
        restore_source_harnesses(openHarnesses);
    else
        sourceDetached = true;
    end
    rethrow(ME);
end
sourceDetached = true;

load_system(temporaryModelFile);
loadedTemporaryFile = char(get_param(temporaryModel, 'FileName'));
if ~same_path(loadedTemporaryFile, temporaryModelFile)
    error('simtest:AssetTempModelLoadMismatch', ...
        ['Refusing Harness export because MATLAB loaded a different ' ...
         'model file: %s'], loadedTemporaryFile);
end

keys = strings(0,1);
keyPaths = strings(0,1);
for i = 1:height(targets)
    sourceOwner = char(st_normalize_cut_path( ...
        targets.CUTPath(i), topModel));
    harnessName = char(string(targets.HarnessName(i)));
    key = string(lower(sourceOwner)) + "|" + string(lower(harnessName)) + ...
        "|" + lower(modelNames(i));
    existing = find(keys == key, 1);
    if ~isempty(existing)
        bundlePaths(i) = keyPaths(existing);
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

    if flatOutput
        outputFolder = destination;
    else
        outputFolder = fullfile(destination, target_folder(targets(i,:)));
    end
    if ~isfolder(outputFolder), mkdir(outputFolder); end
    outputModel = standalone_model_name(char(modelNames(i)));
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
    catch ME
        if bdIsLoaded(outputModel), close_system(outputModel, 0); end
        rethrow(ME);
    end
    clear folderCleanup;

    relative = portable_path(st_export_relative_path(outputPath, bundleRoot));
    keys(end+1,1) = key; %#ok<AGROW>
    keyPaths(end+1,1) = string(relative); %#ok<AGROW>
    bundlePaths(i) = string(relative);
end
clear sessionCleanup;

if ~isempty(fieldnames(logCfg))
    st_log(logCfg, 'INFO', ...
        'Standalone Harness export complete | targets=%d', height(targets));
end

    function cleanup_export_session()
        restoreError = [];
        try
            if sourceDetached
                close_model(topModel);
                if sourceWasLoaded
                    load_system(sourceModelFile);
                    loadedSourceFile = char(get_param(topModel, 'FileName'));
                    if ~same_path(loadedSourceFile, sourceModelFile)
                        error('simtest:AssetSourceRestoreMismatch', ...
                            ['MATLAB restored a different source model ' ...
                             'file: %s'], loadedSourceFile);
                    end
                    if sourceWasOpen, open_system(topModel); end
                    restore_source_harnesses(openHarnesses);
                end
            end
        catch ME
            restoreError = ME;
        end
        remove_work_root(workRoot);
        if ~isempty(restoreError), rethrow(restoreError); end
    end
end

function folder = target_folder(row)
folder = sprintf('%04d_%s', round(double(row.No)), ...
    st_export_safe_name(char(string(row.CUTName))));
end

function name = standalone_model_name(harnessName)
name = char(harnessName);
if ~isvarname(name) || numel(name) > namelengthmax
    error('simtest:AssetHarnessNameInvalidForModel', ...
        ['HarnessName must also be a valid standalone Simulink model ' ...
         'name: %s'], name);
end
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
