function info = st_resolve_exported_cut(modelName, targetRow, cfg)
%ST_RESOLVE_EXPORTED_CUT Identify and validate the copied CUT in a model.

modelName = char(string(modelName));
originalPath = st_normalize_cut_path(targetRow.CUTPath, cfg.TopModel);
parts = split(string(originalPath), '/');
expectedName = char(parts(end));
if isempty(expectedName)
    expectedName = char(string(targetRow.CUTName));
end

candidates = find_system(modelName, ...
    'SearchDepth', 1, ...
    'FollowLinks', 'on', ...
    'LookUnderMasks', 'all', ...
    'Type', 'Block', ...
    'BlockType', 'SubSystem');
candidateNames = strings(numel(candidates),1);
for i = 1:numel(candidates)
    candidateNames(i) = string(get_param(candidates{i}, 'Name'));
end
candidates = candidates(candidateNames == string(expectedName));
if numel(candidates) ~= 1
    error('simtest:StandaloneCUTResolutionFailed', ...
        ['Expected exactly one top-level exported CUT named %s in %s, ' ...
         'found %d.'], expectedName, modelName, numel(candidates));
end
exportedPath = candidates{1};

originalLoadedHere = false;
if ~bdIsLoaded(cfg.TopModel)
    load_system(cfg.ModelFile);
    originalLoadedHere = true;
end
originalCleanup = onCleanup(@() close_if_loaded( ...
    cfg.TopModel, originalLoadedHere)); %#ok<NASGU>
if getSimulinkBlockHandle(originalPath) == -1 || ...
        ~strcmp(get_param(originalPath, 'BlockType'), 'SubSystem')
    error('simtest:StandaloneOriginalCUTInvalid', ...
        'Original CUT is missing or not a Subsystem: %s', originalPath);
end

[originalInputs, originalOutputs] = interface_counts(originalPath);
[exportedInputs, exportedOutputs] = interface_counts(exportedPath);
if originalInputs ~= exportedInputs || originalOutputs ~= exportedOutputs
    error('simtest:StandaloneCUTInterfaceMismatch', ...
        ['Exported CUT interface differs from the original. ' ...
         'Original=%d/%d, Exported=%d/%d.'], ...
        originalInputs, originalOutputs, exportedInputs, exportedOutputs);
end

info = struct( ...
    'OriginalPath', originalPath, ...
    'ExportedPath', exportedPath, ...
    'SID', Simulink.ID.getSID(exportedPath), ...
    'InputCount', exportedInputs, ...
    'OutputCount', exportedOutputs);
end

function [inputs, outputs] = interface_counts(path)
inputs = numel(find_system(path, 'SearchDepth', 1, ...
    'Type', 'Block', 'BlockType', 'Inport'));
outputs = numel(find_system(path, 'SearchDepth', 1, ...
    'Type', 'Block', 'BlockType', 'Outport'));
end

function close_if_loaded(model, closeModel)
if closeModel && bdIsLoaded(model)
    close_system(model, 0);
end
end
