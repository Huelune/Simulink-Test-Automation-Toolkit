function inventory = st_collect_asset_inputs( ...
        targets, cfg, inputRoot, bundleRoot)
%ST_COLLECT_ASSET_INPUTS Copy Harness Signal Editor and SLDV inputs.

inventory = repmat(empty_item(), 0, 1);
for i = 1:height(targets)
    row = targets(i,:);
    item = empty_item();
    item.No = double(row.No);
    item.CUTName = char(row.CUTName);
    item.CUTPath = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
    item.HarnessName = char(row.HarnessName);
    item.TestCaseName = char(row.TestCaseName);
    item.SldvMode = char(row.SldvMode);

    needsSignalInput = true;
    if strcmpi(item.SldvMode, 'OFF')
        directInports = find_system(item.CUTPath, ...
            'SearchDepth', 1, 'Type', 'Block', 'BlockType', 'Inport');
        needsSignalInput = ~isempty(directInports);
    end

    if needsSignalInput
        harnessLoadedHere = false;
        try
            if ~bdIsLoaded(item.HarnessName)
                sltest.harness.load(item.CUTPath, item.HarnessName);
                harnessLoadedHere = true;
            end
            block = st_find_signal_editor_block(item.HarnessName);
            signalFile = st_resolve_data_file( ...
                get_param(block, 'Filename'), cfg.TopModel);
            outputFolder = fullfile(inputRoot, 'signal_editor', ...
                target_folder(item));
            outputPath = fullfile(outputFolder, file_name(signalFile));
            copy_checked(signalFile, outputPath);
            item.SignalEditorInput = bundle_path(bundleRoot, outputPath);
        catch ME
            if harnessLoadedHere
                close_harness(item.CUTPath, item.HarnessName);
            end
            error('simtest:AssetHarnessInputFailed', ...
                'Cannot collect Harness input for %s: %s', ...
                item.TestCaseName, ME.message);
        end
        if harnessLoadedHere
            close_harness(item.CUTPath, item.HarnessName);
        end
    end

    if ~strcmpi(item.SldvMode, 'OFF')
        profile = st_get_sldv_profile(row, cfg);
        outputFolder = fullfile(inputRoot, 'sldv', target_folder(item));
        item.EffectiveSldvInput = copy_required( ...
            profile, 'EffectiveDataFile', outputFolder, bundleRoot);
        item.SourceSldvInput = copy_required( ...
            profile, 'SourceDataFile', outputFolder, bundleRoot);
    end
    inventory(end+1,1) = item; %#ok<AGROW>
end
end

function output = copy_required(profile, fieldName, outputFolder, root)
if ~isfield(profile, fieldName)
    error('simtest:AssetSldvInputMissing', ...
        'SLDV profile has no %s field.', fieldName);
end
source = char(string(profile.(fieldName)));
if isempty(source) || ~isfile(source)
    error('simtest:AssetSldvInputMissing', ...
        'Required SLDV input is missing: %s', source);
end
prefix = lower(regexprep(fieldName, 'DataFile$', ''));
path = fullfile(outputFolder, [prefix '_' file_name(source)]);
copy_checked(source, path);
output = bundle_path(root, path);
end

function copy_checked(source, destination)
parent = fileparts(destination);
if ~isfolder(parent), mkdir(parent); end
[ok, message] = copyfile(source, destination, 'f');
if ~ok
    error('simtest:AssetCopyFailed', ...
        'Cannot copy %s to %s: %s', source, destination, message);
end
end

function close_harness(owner, harness)
try
    sltest.harness.close(owner, harness);
catch
end
end

function value = target_folder(item)
value = sprintf('%04d_%s', round(item.No), ...
    st_export_safe_name(item.CUTName));
end

function value = file_name(path)
[~, name, extension] = fileparts(path);
value = [name extension];
end

function value = bundle_path(root, path)
value = strrep(st_export_relative_path(path, root), '\', '/');
end

function item = empty_item()
item = struct( ...
    'No', 0, ...
    'CUTName', '', ...
    'CUTPath', '', ...
    'HarnessName', '', ...
    'TestCaseName', '', ...
    'SldvMode', '', ...
    'StandaloneHarness', '', ...
    'ResultPath', '', ...
    'SignalEditorInput', '', ...
    'EffectiveSldvInput', '', ...
    'SourceSldvInput', '');
end
