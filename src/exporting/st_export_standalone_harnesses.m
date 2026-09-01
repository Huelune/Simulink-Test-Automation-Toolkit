function bundlePaths = st_export_standalone_harnesses( ...
        sourceModelFile, topModel, targets, destination, bundleRoot)
%ST_EXPORT_STANDALONE_HARNESSES Export Harnesses from a disposable copy.

if ~isfile(sourceModelFile)
    error('simtest:AssetModelMissing', ...
        'Source model is missing: %s', sourceModelFile);
end
if ~isfolder(destination), mkdir(destination); end

openHarnesses = close_open_source_harnesses(targets, topModel);
openHarnessCleanup = onCleanup(@() restore_source_harnesses( ...
    openHarnesses)); %#ok<NASGU>

bundlePaths = strings(height(targets), 1);
workRoot = tempname(destination);
mkdir(workRoot);
workCleanup = onCleanup(@() remove_work_root(workRoot)); %#ok<NASGU>

[~, ~, extension] = fileparts(sourceModelFile);
uuid = char(java.util.UUID.randomUUID());
temporaryModel = matlab.lang.makeValidName( ...
    ['asset_' uuid(1:8) '_' char(topModel)]);
if numel(temporaryModel) > namelengthmax
    temporaryModel = temporaryModel(1:namelengthmax);
end
temporaryModelFile = fullfile(workRoot, [temporaryModel extension]);
copy_checked(sourceModelFile, temporaryModelFile);

load_system(temporaryModelFile);
modelCleanup = onCleanup(@() close_model(temporaryModel)); %#ok<NASGU>

keys = strings(0,1);
keyPaths = strings(0,1);
for i = 1:height(targets)
    sourceOwner = char(st_normalize_cut_path( ...
        targets.CUTPath(i), topModel));
    harnessName = char(string(targets.HarnessName(i)));
    key = string(lower(sourceOwner)) + "|" + string(lower(harnessName));
    existing = find(keys == key, 1);
    if ~isempty(existing)
        bundlePaths(i) = keyPaths(existing);
        continue;
    end

    copiedOwner = copied_owner_path( ...
        sourceOwner, char(topModel), temporaryModel);
    matches = sltest.harness.find( ...
        copiedOwner, 'SearchDepth', 0, 'Name', harnessName);
    if numel(matches) ~= 1
        error('simtest:AssetHarnessMissing', ...
            ['Expected one Harness in the copied model, found %d: ' ...
             '%s | %s'], numel(matches), sourceOwner, harnessName);
    end

    outputFolder = fullfile(destination, target_folder(targets(i,:)));
    if ~isfolder(outputFolder), mkdir(outputFolder); end
    outputModel = standalone_model_name(harnessName);
    outputPath = fullfile(outputFolder, [outputModel '.slx']);

    previousFolder = pwd;
    folderCleanup = onCleanup(@() cd(previousFolder)); %#ok<NASGU>
    cd(outputFolder);
    try
        save_system(temporaryModel);
        sltest.harness.export( ...
            copiedOwner, harnessName, 'Name', outputModel);
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
end

function path = copied_owner_path(sourceOwner, topModel, copiedModel)
parts = strsplit(strrep(sourceOwner, '\', '/'), '/');
if isempty(parts) || ~strcmpi(parts{1}, topModel)
    error('simtest:AssetHarnessOwnerOutsideModel', ...
        'Harness owner is outside the selected model: %s', sourceOwner);
end
parts{1} = copiedModel;
path = strjoin(parts, '/');
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

function openHarnesses = close_open_source_harnesses(targets, topModel)
openHarnesses = repmat(struct('Owner', '', 'Name', ''), 0, 1);
keys = strings(0,1);
try
    for i = 1:height(targets)
        owner = char(st_normalize_cut_path(targets.CUTPath(i), topModel));
        name = char(string(targets.HarnessName(i)));
        key = string(lower(owner)) + "|" + string(lower(name));
        if any(keys == key), continue; end
        keys(end+1,1) = key; %#ok<AGROW>
        if ~bdIsLoaded(name), continue; end
        try
            sltest.harness.close(owner, name);
        catch ME
            error('simtest:AssetHarnessCloseFailed', ...
                'Cannot temporarily close open Harness %s: %s', ...
                name, ME.message);
        end
        openHarnesses(end+1,1) = struct( ...
            'Owner', owner, 'Name', name); %#ok<AGROW>
    end
catch ME
    restore_source_harnesses(openHarnesses);
    rethrow(ME);
end
end

function restore_source_harnesses(openHarnesses)
for i = 1:numel(openHarnesses)
    try
        sltest.harness.load( ...
            openHarnesses(i).Owner, openHarnesses(i).Name);
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
