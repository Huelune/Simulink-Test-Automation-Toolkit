function inventory = st_verification_source_inventory(cfg, strictInputs)
%ST_VERIFICATION_SOURCE_INVENTORY Hash every source needed by isolated runs.

if nargin < 2, strictInputs = true; end

paths = {cfg.ModelFile; cfg.TestFile; cfg.ManagementExcel};
if isfile(cfg.SldvManifestFile)
    paths{end+1,1} = cfg.SldvManifestFile; %#ok<AGROW>
end

try
    [dependencies, missing] = dependencies.fileDependencyAnalysis( ...
        cfg.ModelFile, 'AnalyzeToolboxFiles', false);
    missing = text_list(missing);
    if ~isempty(missing)
        error('simtest:VerificationDependencyMissing', ...
            'Model dependencies are missing: %s', strjoin(missing, ', '));
    end
    paths = [paths; text_list(dependencies)]; %#ok<AGROW>
catch ME
    if strcmp(ME.identifier, 'simtest:VerificationDependencyMissing')
        rethrow(ME);
    end
    error('simtest:VerificationDependencyAnalysisFailed', ...
        'Cannot inspect model dependencies: %s', ME.message);
end

openedModel = false;
if ~bdIsLoaded(cfg.TopModel)
    load_system(cfg.ModelFile);
    openedModel = true;
end
modelCleanup = onCleanup(@() close_model_if_opened( ...
    cfg.TopModel, openedModel)); %#ok<NASGU>

targets = st_load_targets(cfg.OnlyEnabled);
for i = 1:height(targets)
    row = targets(i,:);
    owner = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
    directInports = find_system(owner, 'SearchDepth', 1, ...
        'Type', 'Block', 'BlockType', 'Inport');
    needsSignalInput = ~isempty(directInports) || ...
        ~strcmpi(char(row.SldvMode), 'OFF');
    if needsSignalInput
        wasLoaded = bdIsLoaded(char(row.HarnessName));
        loadedHere = false;
        try
            if ~wasLoaded
                sltest.harness.load(owner, char(row.HarnessName));
                loadedHere = true;
            end
            block = st_find_signal_editor_block(char(row.HarnessName));
            inputPath = st_resolve_data_file( ...
                get_param(block, 'Filename'), cfg.TopModel);
            if isfile(inputPath), paths{end+1,1} = inputPath; end %#ok<AGROW>
        catch ME
            if loadedHere, close_harness(owner, char(row.HarnessName)); end
            if strictInputs
                error('simtest:VerificationInputInspectionFailed', ...
                    'Cannot inspect target %g input: %s', row.No, ME.message);
            end
        end
        if loadedHere, close_harness(owner, char(row.HarnessName)); end
    end
    if ~strcmpi(char(row.SldvMode), 'OFF')
        try
            profile = st_get_sldv_profile(row, cfg);
        catch ME
            if strictInputs, rethrow(ME); end
            continue;
        end
        for field = {'SourceDataFile','EffectiveDataFile', ...
                'SignalEditorDataFile'}
            name = field{1};
            if isfield(profile, name)
                value = char(string(profile.(name)));
                if isfile(value), paths{end+1,1} = value; end %#ok<AGROW>
            end
        end
    end
end

paths = unique(cellfun(@canonical_path, paths, ...
    'UniformOutput', false), 'stable');
Path = string(paths(:));
SHA256 = strings(numel(paths),1);
Bytes = zeros(numel(paths),1);
for i = 1:numel(paths)
    signature = st_file_signature(paths{i});
    if ~signature.Exists
        error('simtest:VerificationSourceMissing', ...
            'A verification source file is missing: %s', paths{i});
    end
    SHA256(i) = string(signature.SHA256);
    Bytes(i) = signature.Bytes;
end
inventory = table(Path, SHA256, Bytes);
end

function close_harness(owner, harness)
try, sltest.harness.close(owner, harness); catch, end
end

function close_model_if_opened(model, opened)
if opened && bdIsLoaded(model), close_system(model, 0); end
end

function values = text_list(value)
if isempty(value)
    values = {};
elseif ischar(value)
    values = {value};
else
    values = cellstr(string(value(:)));
end
values = values(~cellfun('isempty', values));
end

function value = canonical_path(value)
value = char(java.io.File(char(string(value))).getCanonicalPath());
end
