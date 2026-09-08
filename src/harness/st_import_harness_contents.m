function R = st_import_harness_contents(varargin)
%ST_IMPORT_HARNESS_CONTENTS Transactional import for selected Targets rows.
% st_import_harness_contents('DryRun',true)
% st_import_harness_contents('Force',true)
% st_import_harness_contents('SkipCompile',true)
% Uses saved source/destination Harnesses; no SLDV or expected-value updates.
p = inputParser;
addParameter(p, 'DryRun', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Force', false, @(x) islogical(x) && isvector(x));
addParameter(p, 'SkipCompile', false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
cfg = st_require_runtime_target();
T = st_load_targets(cfg.OnlyEnabled);
mask = st_is_harness_import(T);
forceRows = logical(p.Results.Force(:));
if isscalar(forceRows)
    forceRows = repmat(forceRows,height(T),1);
elseif numel(forceRows) ~= height(T)
    error('simtest:ImportForceSize', ...
        'Force must be scalar or have one value per selected Targets row.');
end
Status = repmat("SKIP",height(T),1);
Message = repmat("Existing preparation source",height(T),1);
InterfaceCheck = repmat("NOT_APPLICABLE",height(T),1);
InterfaceCheck(mask) = "COMPILED";
if p.Results.SkipCompile, InterfaceCheck(mask) = "STATIC_ONLY"; end
R = table(T.No, T.CUTPath, T.HarnessName, InterfaceCheck, Status, Message, ...
    'VariableNames', {'No','CUTPath','HarnessName','InterfaceCheck','Status','Message'});
if ~any(mask), return; end
st_log(cfg, 'INFO', ...
    'Harness import start | count=%d | DryRun=%d | Forced=%d | SkipCompile=%d', ...
    sum(mask), p.Results.DryRun, sum(mask & forceRows), p.Results.SkipCompile);
preflightIndex = 0;
try
owners = st_validate_import_mapping(T, cfg);
for i = find(mask).'
    sourceRow = struct('CUTPath',T.SourceCUTPath(i), ...
        'HarnessName',T.SourceHarnessName(i));
    sourceManifest = st_harness_import_file(sourceRow,cfg);
    if isfile(sourceManifest)
        error('simtest:ImportChain', ...
            'A previously imported Harness cannot be used as a source: %s / %s', ...
            owners(i,1),T.SourceHarnessName(i));
    end
end
if ~bdIsLoaded(cfg.TopModel), load_system(cfg.ModelFile); end
if ~isfile(cfg.ModelFile) || ~strcmpi( ...
        char(java.io.File(get_param(cfg.TopModel,'FileName')).getCanonicalPath()), ...
        char(java.io.File(cfg.ModelFile).getCanonicalPath()))
    error('simtest:ImportWrongModel','Loaded model differs from runtime ModelFile.');
end
if ~strcmp(get_param(cfg.TopModel, 'SimulationStatus'), 'stopped') || ...
        strcmp(get_param(cfg.TopModel, 'Dirty'), 'on')
    error('simtest:ImportUnsaved', 'Stop and save the Top Model before import.');
end
openHarnesses = sltest.harness.find(cfg.TopModel, 'OpenOnly','on');
for k = 1:numel(openHarnesses)
    if strcmp(get_param(openHarnesses(k).name,'Dirty'), 'on')
        error('simtest:ImportUnsaved', 'Save open Harness changes before import.');
    end
end
% Explicitly require a closed Harness session to avoid implicit synchronization.
if ~isempty(openHarnesses)
    error('simtest:ImportOpenHarness', 'Close open Harnesses before import; no session changes applied.');
end
interfaces = st_import_cut_interfaces(owners, cfg, p.Results.SkipCompile);
[~, tempName] = fileparts(tempname);
tempName = ['st_import_' tempName];
new_system(tempName);
tempCleanup = onCleanup(@() close_system(tempName,0)); %#ok<NASGU>
sources = cell(height(T),1); targets = sources;
changed = false(height(T),1);
for i = find(mask).'
    preflightIndex = i;
    st_log(cfg, 'DEBUG', 'Import preflight start | CUT=%s', owners(i,2));
    if ~strcmp(get_param(char(owners(i,1)), 'Name'), get_param(char(owners(i,2)), 'Name'))
        error('simtest:ImportCUTName', 'Source and destination CUT names differ: %s', owners(i,2));
    end
    if ~strcmp(interfaces(char(owners(i,1))), interfaces(char(owners(i,2))))
        kind = 'Compiled';
        if p.Results.SkipCompile, kind = 'Declared'; end
        error('simtest:ImportInterfaceMismatch', ...
            '%s CUT interface differs: %s', kind, owners(i,2));
    end
    storage = sprintf('%s/source_%d', tempName, i);
    add_block('built-in/SubSystem', storage);
    sources{i} = st_harness_content_snapshot(owners(i,1), ...
        T.SourceHarnessName(i), cfg, storage);
    targets{i} = st_harness_content_snapshot(owners(i,2), ...
        T.HarnessName(i), cfg, '', true);
    a = sources{i}; b = targets{i};
    if ~isequal(a.Structure, b.Structure) || ~isequal(wiring(a.Connections), wiring(b.Connections))
        error('simtest:ImportStructureMismatch', 'Standard block/port wiring differs: %s', owners(i,2));
    end
    changed(i) = forceRows(i) || ~cache_matches( ...
        T(i,:), a, b, cfg, ~p.Results.SkipCompile);
    R.Status(i) = "CACHED";
    R.Message(i) = "Source and copied content unchanged";
    if changed(i)
        R.Status(i) = "READY";
        R.Message(i) = "Compatible; test blocks, inputs and settings will be replaced";
        if p.Results.SkipCompile
            R.Message(i) = "Static checks passed; content will be replaced without compile";
        end
    end
    st_log(cfg, 'DEBUG', 'Import preflight end | CUT=%s | Changed=%d', owners(i,2), changed(i));
end
if p.Results.DryRun || ~any(changed)
    if ~p.Results.DryRun, st_write_result('HarnessImportResult', R); end
    st_log(cfg, 'INFO', 'Harness import end | applied=0 | DryRun=%d', p.Results.DryRun);
    return;
end
transaction = fullfile(cfg.ResultDir, 'harness_import', 'transactions', tempName);
mkdir(transaction);
files = {cfg.ModelFile};
for i = find(changed).'
    if ~isempty(targets{i}.HarnessFile), files{end+1} = targets{i}.HarnessFile; end %#ok<AGROW>
    files{end+1} = st_harness_import_file(T(i,:), cfg); %#ok<AGROW>
end
files = unique(files, 'stable');
backup = cell(size(files)); existed = false(size(files));
st_log(cfg, 'INFO', 'Import backup start | Directory=%s', transaction);
for k = 1:numel(files)
    existed(k) = isfile(files{k});
    if existed(k)
        backup{k} = fullfile(transaction, sprintf('backup_%d',k));
        copy_checked(files{k}, backup{k});
    end
end
save(fullfile(transaction,'recovery.mat'), 'files','backup','existed');
st_log(cfg, 'INFO', 'Import backup end | Directory=%s', transaction);
current = 0;
try
    for i = find(changed).'
        current = i;
        source = sources{i};
        inputFile = '';
        if source.Profile.HasSignalEditor
            inputFile = fullfile(transaction, sprintf('input_%d.mat',i));
            st_log(cfg,'DEBUG','Import input copy start | CUT=%s',owners(i,2));
            copy_checked(source.InputFile, inputFile);
            sig = st_file_signature(inputFile);
            if ~strcmp(sig.SHA256,source.InputSHA256)
                error('simtest:ImportSourceChanged','Source input changed during import.');
            end
            st_log(cfg,'DEBUG','Import input copy end | CUT=%s',owners(i,2));
        end
        st_apply_harness_content(source, targets{i}, inputFile, cfg);
        actual = st_harness_content_snapshot(owners(i,2), T.HarnessName(i), cfg);
        if ~strcmp(actual.Fingerprint, source.Fingerprint)
            error('simtest:ImportReadbackMismatch', 'Saved Harness content differs: %s', owners(i,2));
        end
        if p.Results.SkipCompile
            st_log(cfg,'WARN', ...
                'Import saved Harness update skipped | Harness=%s',T.HarnessName(i));
        else
            % Compile the newly imported Harness before committing its manifest.
            st_log(cfg,'DEBUG','Import saved Harness update start | Harness=%s',T.HarnessName(i));
            sltest.harness.load(char(owners(i,2)),char(T.HarnessName(i)));
            set_param(char(T.HarnessName(i)), 'SimulationCommand','update');
            sltest.harness.close(char(owners(i,2)),char(T.HarnessName(i)));
            st_log(cfg,'DEBUG','Import saved Harness update end | Harness=%s',T.HarnessName(i));
        end
        manifest = struct('Version',1,'Owner',char(owners(i,2)), ...
            'Harness',char(T.HarnessName(i)), 'SourceOwner',char(owners(i,1)), ...
            'SourceHarness',char(T.SourceHarnessName(i)), ...
            'SourceFingerprint',source.Fingerprint, 'TargetFingerprint',actual.Fingerprint, ...
            'InputSHA256',source.InputSHA256, 'Profile',source.Profile, ...
            'CompileValidated',~p.Results.SkipCompile);
        manifest.Profile.SignalEditorDataFile = inputFile;
        manifest.Profile.Tmax = str2double(source.Settings.StopTime);
        path = st_harness_import_file(T(i,:),cfg);
        if ~isfolder(fileparts(path)), mkdir(fileparts(path)); end
        save(path,'manifest');
        R.Status(i) = "IMPORTED";
        R.Message(i) = "Saved content verified; backup: " + string(transaction);
        if p.Results.SkipCompile
            R.Message(i) = "Saved content verified without compile; backup: " + ...
                string(transaction);
        end
    end
    for i = find(mask).'
        sourceNow = st_harness_content_snapshot(owners(i,1), T.SourceHarnessName(i), cfg);
        if ~strcmp(sourceNow.Fingerprint,sources{i}.Fingerprint)
            error('simtest:ImportSourceChanged','Source changed during import: %s',owners(i,1));
        end
    end
catch ME
    st_log(cfg,'ERROR','Import failed | Row=%d | Backup=%s | %s',current,transaction,ME.message);
    st_log(cfg,'WARN','Import rollback start | Backup=%s',transaction);
    try
        discard_loaded_harnesses(targets(changed));
        close_system(cfg.TopModel,0);
        st_restore_import_backup(files,backup,existed,cfg);
        load_system(cfg.ModelFile);
        R.Status(changed) = "ROLLED_BACK";
        if current > 0, R.Status(current) = "FAIL"; end
        R.Message(changed) = string(ME.message);
        st_log(cfg,'WARN','Import rollback end | Backup=%s',transaction);
    catch restoreError
        st_log(cfg,'ERROR','Import rollback failed | Backup=%s | %s',transaction,restoreError.message);
        combined = MException('simtest:ImportRollbackFailed', ...
            'Import and rollback failed. Recover from %s.',transaction);
        throw(addCause(addCause(combined,ME),restoreError));
    end
    st_write_result('HarnessImportResult',R);
    rethrow(ME);
end
st_write_result('HarnessImportResult',R);
st_log(cfg,'INFO','Harness import end | applied=%d | cached=%d',sum(changed),sum(mask & ~changed));
catch ME
    st_log(cfg,'ERROR','Harness import failed | Model=%s | %s: %s', ...
        cfg.TopModel,ME.identifier,ME.message);
    if ~p.Results.DryRun && ~any(R.Status == "FAIL")
        R.Status(mask) = "BLOCKED";
        if preflightIndex > 0, R.Status(preflightIndex) = "FAIL"; else, R.Status(mask) = "FAIL"; end
        R.Message(mask) = string(ME.message);
        st_write_result('HarnessImportResult',R);
    end
    st_log(cfg,'INFO','Harness import end | success=0');
    rethrow(ME);
end
end

function discard_loaded_harnesses(targets)
for i = 1:numel(targets)
    if isempty(targets{i}), continue; end
    harness = targets{i}.Harness;
    if bdIsLoaded(harness), close_system(harness,0); end
end
end

function value = wiring(value)
for i = 1:numel(value), value{i} = rmfield(value{i},'Logging'); end
end

function tf = cache_matches(row, source, target, cfg, requireCompileValidation)
tf = false;
try
    profile = st_get_test_profile(row,cfg);
    data = load(st_harness_import_file(row,cfg),'manifest');
    tf = strcmp(data.manifest.SourceFingerprint,source.Fingerprint) && ...
        strcmp(data.manifest.TargetFingerprint,target.Fingerprint);
    if requireCompileValidation && isfield(data.manifest,'CompileValidated')
        tf = tf && logical(data.manifest.CompileValidated);
    end
    if profile.HasSignalEditor
        tf = tf && strcmpi(char(java.io.File(target.InputFile).getCanonicalPath()), ...
            char(java.io.File(profile.SignalEditorDataFile).getCanonicalPath()));
    end
catch ME
    st_log(cfg,'DEBUG','Import cache invalid | CUT=%s | %s',row.CUTPath,ME.message);
end
end

function copy_checked(source,destination)
[ok,message] = copyfile(source,destination,'f');
if ~ok, error('simtest:ImportCopyFailed','%s',message); end
a = st_file_signature(source); b = st_file_signature(destination);
if ~strcmp(a.SHA256,b.SHA256)
    error('simtest:ImportCopyFailed','Copy checksum mismatch: %s',destination);
end
end
