function info = st_prepare_standalone_harness_model( ...
        targetRow, phase, targetDirectory, cfg)
%ST_PREPARE_STANDALONE_HARNESS_MODEL Export and snapshot one execution SUT.

phase = lower(strtrim(char(string(phase))));
phaseDirectory = fullfile(targetDirectory, phase);
modelDirectory = fullfile(phaseDirectory, 'model');
inputDirectory = fullfile(targetDirectory, 'inputs');
if ~isfolder(modelDirectory), mkdir(modelDirectory); end
if ~isfolder(inputDirectory), mkdir(inputDirectory); end

modelName = st_standalone_model_name(targetRow, phase);
st_log(cfg, 'INFO', ...
    ['Standalone model preparation start | TestCase=%s | phase=%s | ' ...
     'model=%s'], char(targetRow.TestCaseName), upper(phase), modelName);
timerValue = tic;

relative = st_export_standalone_harnesses( ...
    cfg.ModelFile, cfg.TopModel, targetRow, modelDirectory, ...
    targetDirectory, 'ModelNames', string(modelName), ...
    'FlatOutput', true, 'LogConfig', cfg);
modelPath = fullfile(targetDirectory, ...
    strrep(char(relative(1)), '/', filesep));
if ~isfile(modelPath)
    error('simtest:StandaloneModelExportMissing', ...
        'Exported standalone model is missing: %s', modelPath);
end

pathCleanup = add_model_path(modelDirectory, modelName, modelPath); %#ok<NASGU>
load_system(modelPath);
modelCleanup = onCleanup(@() close_model(modelName)); %#ok<NASGU>
assert_loaded_file(modelName, modelPath);
cut = st_resolve_exported_cut(modelName, targetRow, cfg);

inputs = snapshot_inputs(modelName, targetRow, inputDirectory, cfg, ...
    cut.InputCount);
save_system(modelName, modelPath);
dependencies = inspect_dependencies(modelName, modelPath);
signature = st_file_signature(modelPath);

info = struct( ...
    'Phase', upper(phase), ...
    'ModelName', modelName, ...
    'ModelPath', modelPath, ...
    'ModelSHA256', signature.SHA256, ...
    'ExportedCUTPath', cut.ExportedPath, ...
    'ExportedCUTSID', cut.SID, ...
    'InputCount', cut.InputCount, ...
    'OutputCount', cut.OutputCount, ...
    'Inputs', inputs, ...
    'InputSignatures', input_signatures(inputs), ...
    'Dependencies', dependencies, ...
    'Status', 'OK');

st_log(cfg, 'INFO', ...
    ['Standalone model preparation complete | TestCase=%s | phase=%s | ' ...
     'elapsed=%.3f sec'], char(targetRow.TestCaseName), ...
    upper(phase), toc(timerValue));
end

function inputs = snapshot_inputs( ...
        modelName, row, inputDirectory, cfg, directInputCount)
inputs = struct('SignalEditor', '', 'EffectiveSldv', '', ...
    'SourceSldv', '', 'SourceSignalEditor', '', ...
    'SourceEffectiveSldv', '', 'SourceSourceSldv', '');
try
    signalBlock = st_find_signal_editor_block(modelName);
    rawSource = get_param(signalBlock, 'Filename');
    try
        source = st_resolve_data_file(rawSource, cfg.TopModel);
    catch resolveME
        source = fullfile(fileparts(cfg.ModelFile), rawSource);
        if ~isfile(source), rethrow(resolveME); end
    end
    destination = copy_input(source, inputDirectory, ...
        sprintf('%03d_signal_editor_', double(row.No)));
    set_param(signalBlock, 'Filename', destination);
    inputs.SignalEditor = destination;
    inputs.SourceSignalEditor = source;
catch ME
    if directInputCount > 0 || row.SldvMode ~= "OFF"
        error('simtest:StandaloneSignalEditorInputFailed', ...
            'Cannot snapshot Signal Editor input for %s: %s', ...
            char(row.TestCaseName), ME.message);
    end
    st_log(cfg, 'WARN', ...
        ['Standalone Signal Editor input omitted for no-Inport target | ' ...
         'TestCase=%s | %s'], char(row.TestCaseName), ME.message);
end

if row.SldvMode ~= "OFF"
    profile = st_get_sldv_profile(row, cfg);
    inputs.EffectiveSldv = copy_input( ...
        profile.EffectiveDataFile, inputDirectory, ...
        sprintf('%03d_effective_', double(row.No)));
    inputs.SourceEffectiveSldv = profile.EffectiveDataFile;
    inputs.SourceSldv = copy_input( ...
        profile.SourceDataFile, inputDirectory, ...
        sprintf('%03d_source_', double(row.No)));
    inputs.SourceSourceSldv = profile.SourceDataFile;
end
end

function records = input_signatures(inputs)
labels = {'SignalEditor','EffectiveSldv','SourceSldv'};
sourceFields = {'SourceSignalEditor','SourceEffectiveSldv', ...
    'SourceSourceSldv'};
records = repmat(struct('Type', '', 'Source', '', 'Copy', '', ...
    'SourceSHA256', '', 'CopySHA256', '', 'Match', false), 0, 1);
for i = 1:numel(labels)
    copyPath = inputs.(labels{i});
    sourcePath = inputs.(sourceFields{i});
    if isempty(copyPath), continue; end
    sourceSignature = st_file_signature(sourcePath);
    copySignature = st_file_signature(copyPath);
    records(end+1,1) = struct( ... %#ok<AGROW>
        'Type', labels{i}, 'Source', sourcePath, 'Copy', copyPath, ...
        'SourceSHA256', sourceSignature.SHA256, ...
        'CopySHA256', copySignature.SHA256, ...
        'Match', strcmp(sourceSignature.SHA256, copySignature.SHA256));
    if ~records(end).Match
        error('simtest:StandaloneInputChecksumMismatch', ...
            'Input snapshot checksum mismatch: %s', copyPath);
    end
end
end

function destination = copy_input(source, directory, prefix)
source = char(string(source));
if isempty(source) || ~isfile(source)
    error('simtest:StandaloneInputMissing', ...
        'Required standalone execution input is missing: %s', source);
end
[~, name, extension] = fileparts(source);
destination = fullfile(directory, [prefix name extension]);
if ~isfile(destination)
    [ok, message] = copyfile(source, destination);
    if ~ok
        error('simtest:StandaloneInputCopyFailed', ...
            'Cannot copy %s to %s: %s', source, destination, message);
    end
end
end

function dependencies = inspect_dependencies(modelName, modelPath)
blocks = find_system(modelName, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'Type', 'Block', ...
    'BlockType', 'ModelReference');
references = strings(numel(blocks),1);
for i = 1:numel(blocks)
    references(i) = string(get_param(blocks{i}, 'ModelName'));
end
dictionary = "";
try
    dictionary = string(get_param(modelName, 'DataDictionary'));
catch
end
customCode = strings(0,1);
parameters = {'SimUserSources','CustomSourceCode','CustomInclude'};
for i = 1:numel(parameters)
    try
        value = string(get_param(modelName, parameters{i}));
        if strlength(value) > 0
            customCode(end+1,1) = string(parameters{i}) + "=" + value; %#ok<AGROW>
        end
    catch
    end
end
referenceFiles = repmat(dependency_record('', ''), 0, 1);
for i = 1:numel(references)
    resolved = which(char(references(i)));
    if isempty(resolved)
        resolved = which([char(references(i)) '.slx']);
    end
    if isempty(resolved)
        resolved = which([char(references(i)) '.mdl']);
    end
    referenceFiles(end+1,1) = dependency_record( ... %#ok<AGROW>
        char(references(i)), resolved);
end
dictionaryFile = dependency_record(char(dictionary), '');
if strlength(dictionary) > 0
    resolvedDictionary = which(char(dictionary));
    if isempty(resolvedDictionary) && isfile(char(dictionary))
        resolvedDictionary = char(dictionary);
    end
    dictionaryFile = dependency_record( ...
        char(dictionary), resolvedDictionary);
end
dependencies = struct( ...
    'Model', modelPath, ...
    'ReferencedModels', referenceFiles, ...
    'DataDictionary', dictionaryFile, ...
    'CustomCodeSettings', customCode);
end

function record = dependency_record(name, path)
signature = st_file_signature(path);
record = struct('Name', name, 'Path', path, ...
    'Exists', logical(signature.Exists), 'SHA256', signature.SHA256);
end

function cleanup = add_model_path(directory, modelName, modelPath)
locations = which(modelName, '-all');
if ischar(locations), locations = {locations}; end
for i = 1:numel(locations)
    if ~same_path(locations{i}, modelPath)
        error('simtest:StandaloneModelShadowing', ...
            'Model name %s already resolves to another file: %s', ...
            modelName, locations{i});
    end
end
addpath(directory, '-begin');
cleanup = onCleanup(@() rmpath_if_present(directory));
end

function assert_loaded_file(modelName, expected)
actual = get_param(modelName, 'FileName');
if ~same_path(actual, expected)
    error('simtest:StandaloneModelLoadMismatch', ...
        'MATLAB loaded a different standalone model: %s', actual);
end
end

function tf = same_path(left, right)
left = char(java.io.File(char(left)).getCanonicalPath());
right = char(java.io.File(char(right)).getCanonicalPath());
if ispc, tf = strcmpi(left, right); else, tf = strcmp(left, right); end
end

function close_model(model)
if bdIsLoaded(model), close_system(model, 0); end
end

function rmpath_if_present(directory)
try
    rmpath(directory);
catch
end
end
