function [plan, state, context] = st_build_execution_plan(T, cfg, workflowKind, options)
%ST_BUILD_EXECUTION_PLAN Build a target- and stage-specific run plan.

workflowKind = upper(char(string(workflowKind)));
[state, stateLoadStatus] = st_load_workflow_state(cfg);

stages = ["HARNESS", "SLDV", "HARNESS_CONFIG", "SIGNAL_EDITOR", ...
    "ASSESSMENT", "TEST_MANAGER", "ALIGNMENT"];
n = height(T);

modelSignature = st_file_signature(cfg.ModelFile);
testFileSignature = st_file_signature(cfg.TestFile);
modelChanged = ~artifact_matches(state.Artifacts, 'Model', modelSignature);
testFileChanged = ~artifact_matches( ...
    state.Artifacts, 'TestFile', testFileSignature);
toolkitSignature = toolkit_signature();

Key = strings(n,1);
Mode = strings(n,1);
FromStage = strings(n,1);

runValues = false(n, numel(stages));
actionValues = strings(n, numel(stages));
reasonValues = strings(n, numel(stages));
signatureValues = strings(n, numel(stages));

for i = 1:n
    identity = target_identity(T(i,:), cfg);
    Key(i) = string(st_hash_value(identity));
    [mode, fromStage] = effective_policy(T(i,:), cfg, options, workflowKind);
    Mode(i) = string(mode);
    FromStage(i) = string(fromStage);

    signatures = target_stage_signatures( ...
        T(i,:), cfg, identity, toolkitSignature);
    stateIndex = find_state_target(state, char(Key(i)));

    dirty = false(1, numel(stages));
    reasons = repmat("Checkpoint matches", 1, numel(stages));

    if strcmp(workflowKind, 'FULL')
        dirty(1) = true;
        reasons(1) = "Harness existence is always checked";
    else
        reasons(1) = "Existing-Harness workflow";
    end

    if ~strcmp(stateLoadStatus, 'OK') || isempty(stateIndex)
        dirty(2:end) = true;
        reasons(2:end) = "No valid target checkpoint";
    else
        previousStages = state.Targets(stateIndex).StageSignatures;
        for s = 2:numel(stages)
            field = char(stages(s));
            if ~isfield(previousStages, field) || ...
                    ~strcmp(char(previousStages.(field)), ...
                    char(signatures.(field)))
                dirty(s) = true;
                reasons(s) = "Input signature changed";
            end
        end
    end

    if modelChanged
        dirty(2:end) = true;
        reasons(2:end) = "Model artifact changed";
    end

    if testFileChanged
        dirty(6:7) = true;
        reasons(6:7) = "Test File artifact changed";
    end

    if ~isfile(cfg.SldvManifestFile)
        dirty(2:end) = true;
        reasons(2:end) = "SLDV manifest is missing";
    elseif ~dirty(2)
        try
            st_get_sldv_profile(T(i,:), cfg);
        catch
            dirty(2:end) = true;
            reasons(2:end) = "Cached SLDV profile or artifact is invalid";
        end
    end

    if strcmp(mode, 'FORCE')
        forceIndex = find(stages == string(fromStage), 1);
        if isempty(forceIndex)
            forceIndex = 2;
        end
        dirty(forceIndex:end) = true;
        reasons(forceIndex:end) = "Forced from " + string(fromStage);
    end

    % A dirty upstream stage invalidates every downstream stage.
    firstDirty = find(dirty(2:end), 1);
    if ~isempty(firstDirty)
        firstDirty = firstDirty + 1;
        dirty(firstDirty:end) = true;
        for s = (firstDirty + 1):numel(stages)
            if reasons(s) == "Checkpoint matches"
                reasons(s) = "Upstream stage invalidated";
            end
        end
    end

    for s = 1:numel(stages)
        stage = char(stages(s));
        signatureValues(i,s) = string(signatures.(stage));
        runValues(i,s) = dirty(s);
        reasonValues(i,s) = reasons(s);
        if dirty(s)
            if startsWith(reasons(s), "Forced")
                actionValues(i,s) = "FORCE";
            else
                actionValues(i,s) = "RUN";
            end
        else
            actionValues(i,s) = "CACHED";
        end
    end
end

% Overwrite mode recreates the shared Test File, so a partial row update
% would remove cached Test Cases. Rebuild every selected row together.
if cfg.OverwriteTestFile && any(runValues(:,6))
    runValues(:,6:7) = true;
    actionValues(:,6:7) = "RUN";
    reasonValues(:,6:7) = "OverwriteTestFile requires a full Test File rebuild";
end

plan = table(Key, T.No, T.CUTName, T.CUTPath, T.HarnessName, ...
    T.TestCaseName, Mode, FromStage, ...
    'VariableNames', {'Key','No','CUTName','CUTPath','HarnessName', ...
    'TestCaseName','PreparationMode','PreparationFromStage'});

for s = 1:numel(stages)
    stage = char(stages(s));
    plan.(['Run' stage]) = runValues(:,s);
    plan.(['Action' stage]) = actionValues(:,s);
    plan.(['Reason' stage]) = reasonValues(:,s);
    plan.(['Signature' stage]) = signatureValues(:,s);
end

context = struct();
context.StateLoadStatus = stateLoadStatus;
context.ModelChanged = modelChanged;
context.TestFileChanged = testFileChanged;
context.ModelSignature = modelSignature;
context.TestFileSignature = testFileSignature;
context.ToolkitSignature = toolkitSignature;
context.WorkflowKind = workflowKind;
end

function [mode, fromStage] = effective_policy(row, cfg, options, workflowKind)
mode = upper(strtrim(char(string(cfg.PreparationMode))));
if ~ismember(mode, {'AUTO','FORCE'})
    error('simtest:InvalidPreparationMode', ...
        'cfg.PreparationMode must be AUTO or FORCE.');
end
if row.PreparationMode ~= "DEFAULT"
    mode = char(row.PreparationMode);
end
if ~isempty(options.PreparationMode)
    mode = options.PreparationMode;
end

fromStage = upper(strtrim(char(string(cfg.PreparationFromStage))));
if row.PreparationFromStage ~= "DEFAULT"
    fromStage = char(row.PreparationFromStage);
end
if ~isempty(options.FromStage)
    fromStage = options.FromStage;
end
if strcmp(fromStage, 'START')
    if strcmp(workflowKind, 'FULL')
        fromStage = 'HARNESS';
    else
        fromStage = 'SLDV';
    end
end
if strcmp(workflowKind, 'AFTER_HARNESS') && strcmp(fromStage, 'HARNESS')
    error('simtest:InvalidPreparationFromStage', ...
        ['HARNESS is not available in st_run_after_harness. ' ...
         'Use st_run_from_harness instead.']);
end
end

function identity = target_identity(row, cfg)
identity = struct( ...
    'TopModel', char(cfg.TopModel), ...
    'CUTPath', char(row.CUTPath), ...
    'HarnessName', char(row.HarnessName), ...
    'TestCaseName', char(row.TestCaseName));
end

function signatures = target_stage_signatures(row, cfg, identity, toolkit)
common = struct('Identity', identity, ...
    'MATLABRelease', version('-release'), ...
    'Toolkit', toolkit);

harness = common;
harness.CreateWithoutCompile = false;
signatures.HARNESS = st_hash_value(harness);

sldv = common;
sldv.SldvMode = char(row.SldvMode);
sldv.SldvDataFile = char(row.SldvDataFile);
sldv.SldvDataSignature = sldv_source_signature(row, cfg);
sldv.TmaxResolution = cfg.SldvTmaxResolution;
sldv.AutoEnableAtomic = cfg.AutoEnableAtomicForSldvGenerate;
signatures.SLDV = st_hash_value(sldv);

harnessConfig = struct('Upstream', signatures.SLDV, ...
    'HarnessStopTime', cfg.HarnessStopTime);
signatures.HARNESS_CONFIG = st_hash_value(harnessConfig);

signalEditor = struct('Upstream', signatures.HARNESS_CONFIG, ...
    'SampleTime', cfg.SignalEditorSampleTime);
signatures.SIGNAL_EDITOR = st_hash_value(signalEditor);

assessment = struct('Upstream', signatures.SIGNAL_EDITOR, ...
    'VerifyHarnessOutportsOnly', cfg.VerifyHarnessOutportsOnly, ...
    'VerifyFirstBusElementOnly', cfg.VerifyFirstBusElementOnly, ...
    'VerifyAtSampleTimeOnly', cfg.VerifyAtSampleTimeOnly, ...
    'ExpectedValueSampleTime', cfg.ExpectedValueSampleTime);
signatures.ASSESSMENT = st_hash_value(assessment);

testManager = struct('Upstream', signatures.ASSESSMENT, ...
    'TestFile', cfg.TestFile, ...
    'TestSuiteName', cfg.TestSuiteName, ...
    'OverwriteTestFile', cfg.OverwriteTestFile, ...
    'CoverageStructuralLevel', cfg.CoverageStructuralLevel, ...
    'CoverageMetricSettings', cfg.CoverageMetricSettings, ...
    'CoverageIncludeReferencedModels', ...
        cfg.CoverageIncludeReferencedModels);
signatures.TEST_MANAGER = st_hash_value(testManager);
signatures.ALIGNMENT = st_hash_value(struct( ...
    'Upstream', signatures.TEST_MANAGER, 'RuleVersion', 1));
end

function signature = sldv_source_signature(row, cfg)
signature = struct('Path', char(row.SldvDataFile), 'Exists', false, ...
    'Bytes', 0, 'Modified', '', 'SHA256', '');
if row.SldvMode ~= "FILE" || strlength(row.SldvDataFile) == 0
    return;
end
try
    path = st_resolve_data_file(row.SldvDataFile, cfg.TopModel);
catch
    path = char(row.SldvDataFile);
end
signature = st_file_signature(path);
end

function digest = toolkit_signature()
rootDir = st_project_root();
files = dir(fullfile(rootDir, 'src', '**', '*.m'));
paths = strings(numel(files),1);
hashes = strings(numel(files),1);
for i = 1:numel(files)
    fullPath = fullfile(files(i).folder, files(i).name);
    paths(i) = string(erase(fullPath, [rootDir filesep]));
    info = st_file_signature(fullPath);
    hashes(i) = string(info.SHA256);
end
[paths, order] = sort(paths);
hashes = hashes(order);
digest = st_hash_value(struct('Paths', paths, 'Hashes', hashes));
end

function tf = artifact_matches(artifacts, field, current)
tf = false;
if ~isstruct(artifacts) || ~isfield(artifacts, field)
    return;
end
previous = artifacts.(field);
if ~isstruct(previous) || ~isfield(previous, 'Exists') || ...
        ~isfield(previous, 'SHA256')
    return;
end
tf = logical(previous.Exists) == logical(current.Exists) && ...
    strcmp(char(previous.SHA256), char(current.SHA256));
end

function index = find_state_target(state, key)
index = [];
if ~isfield(state, 'Targets') || isempty(state.Targets)
    return;
end
index = find(strcmp({state.Targets.Key}, key), 1, 'first');
end
