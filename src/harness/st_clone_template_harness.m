function [status, message] = st_clone_template_harness(row, cfg)
%ST_CLONE_TEMPLATE_HARNESS Clone and prepare one target as a recoverable unit.
owner = st_normalize_cut_path(row.CUTPath,cfg.TopModel);
name = char(row.HarnessName);
source = char(row.SourceCUTPath);
source(source == char(92)) = '/';
source = regexprep(source,'^/+','');
sourceName = char(row.SourceHarnessName);
status = "SKIP";
message = "Harness already exists";
existing = sltest.harness.find(owner,'SearchDepth',0,'Name',name);
if ~isempty(existing) && ~cfg.OverwriteHarness
    st_log(cfg,'INFO','Harness clone SKIP | CUT=%s | Harness=%s | overwrite=false',owner,name);
    return;
end
st_log(cfg,'INFO','Harness clone start | Source=%s | CUT=%s | Harness=%s',source,owner,name);
if isempty(source) || isempty(sourceName) || ~contains(source,'/')
    error('simtest:CloneSourceMissing', ...
        'HARNESS_CLONE requires a full SourceCUTPath (model/subsystem) and SourceHarnessName.');
end
sourceModel = strtok(source,'/');
loadedHere = ~bdIsLoaded(sourceModel);
modelCleanup = onCleanup(@() close_source(sourceModel,loadedHere)); %#ok<NASGU>
st_log(cfg,'DEBUG','Template load start | Model=%s',sourceModel);
load_system(sourceModel);
st_log(cfg,'DEBUG','Template load end | Model=%s',sourceModel);
source = st_normalize_cut_path(source,sourceModel);
if strcmp(source,owner) && strcmp(sourceName,name)
    error('simtest:CloneTemplateIsTarget','Cannot replace the Template itself.');
end
if strcmp(get_param(sourceModel,'Dirty'),'on') || ...
        ~strcmp(get_param(sourceModel,'SimulationStatus'),'stopped')
    error('simtest:CloneSourceUnsaved','Save and stop the Template model before cloning: %s',sourceModel);
end
template = sltest.harness.find(source,'SearchDepth',0,'Name',sourceName);
if numel(template) ~= 1
    error('simtest:CloneTemplateMissing','Expected one Template Harness: %s / %s',source,sourceName);
end
if bdIsLoaded(sourceName) || bdIsLoaded(name)
    error('simtest:CloneHarnessOpen','Close source and destination Harnesses before cloning.');
end
% Reuse the compiled port/bus analyzer separately for each owning model.
sourceCfg = cfg;
sourceCfg.TopModel = sourceModel;
sourceSignature = st_clone_cut_interfaces({source},sourceCfg);
targetSignature = st_clone_cut_interfaces({owner},cfg);
if ~strcmp(sourceSignature(source),targetSignature(owner))
    error('simtest:CloneInterfaceMismatch','Template and destination CUT interfaces differ: %s / %s',source,owner);
end
open_logged(source,sourceName,cfg);
templateCleanup = onCleanup(@() close_harness(source,sourceName,cfg));
signal = st_find_signal_editor_block(sourceName);
st_find_assessment_block(sourceName);
inputFile = st_resolve_data_file(get_param(signal,'Filename'),sourceModel);
if ~isfile(inputFile)
    error('simtest:CloneInputMissing','Template input MAT is missing: %s',inputFile);
end
clear templateCleanup;

root = fullfile(cfg.ResultDir,'harness_clone');
if ~isfolder(root), mkdir(root); end
transaction = tempname(root);
mkdir(transaction);
backupName = '';
destinationTouched = false;
committed = false;
manifestBackup = fullfile(transaction,'sldv-manifest.mat');
hadManifest = isfile(cfg.SldvManifestFile);
if hadManifest, copyfile(cfg.SldvManifestFile,manifestBackup); end
try
    if ~isempty(existing)
        [~,token] = fileparts(transaction);
        backupName = matlab.lang.makeValidName(['clone_recovery_' token]);
        clone_logged(owner,name,owner,backupName,cfg);
        save_logged(cfg.TopModel,cfg);
        st_log(cfg,'INFO','Recovery Harness saved | CUT=%s | Harness=%s',owner,backupName);
    end
    destinationTouched = true;
    if ~isempty(existing), sltest.harness.delete(owner,name); end
    clone_logged(source,sourceName,owner,name,cfg);
    actual = sltest.harness.find(owner,'SearchDepth',0,'Name',name);
    if numel(actual) ~= 1 || ~strcmp(actual.ownerFullPath,owner)
        error('simtest:CloneOwnerMismatch','Cloned Harness owner is not %s.',owner);
    end
    open_logged(owner,name,cfg);
    harnessCleanup = onCleanup(@() close_harness(owner,name,cfg));
    signal = st_find_signal_editor_block(name);
    st_find_assessment_block(name);
    independentInput = fullfile(transaction,'input.mat');
    copyfile(inputFile,independentInput);
    set_param(signal,'Filename',independentInput);
    save_logged(name,cfg);
    clear harnessCleanup;
    save_logged(cfg.TopModel,cfg);

    scope = st_target_scope('enter',row); %#ok<NASGU>
    functions = {@st_prepare_sldv_targets,@st_configure_signal_editors, ...
        @st_configure_assessments,@st_configure_harnesses};
    for k = 1:numel(functions)
        label = func2str(functions{k});
        st_log(cfg,'INFO','Clone preparation start | CUT=%s | Stage=%s',owner,label);
        result = functions{k}();
        if height(result) ~= 1 || any(strcmpi(string(result.Status),'FAIL'))
            error('simtest:ClonePreparationFailed','%s failed for %s: %s', ...
                label,owner,strjoin(string(result.Message),'; '));
        end
        st_log(cfg,'INFO','Clone preparation end | CUT=%s | Stage=%s',owner,label);
    end
    open_logged(owner,name,cfg);
    finalCleanup = onCleanup(@() close_harness(owner,name,cfg));
    st_log(cfg,'INFO','Clone Harness update start | CUT=%s',owner);
    set_param(name,'SimulationCommand','update');
    st_log(cfg,'INFO','Clone Harness update end | CUT=%s',owner);
    save_logged(name,cfg);
    clear finalCleanup;
    if bdIsLoaded(name)
        error('simtest:CloneCloseFailed','Cloned Harness did not close: %s',name);
    end
    save_logged(cfg.TopModel,cfg);
    committed = true;
    if ~isempty(backupName)
        try
            sltest.harness.delete(owner,backupName);
            save_logged(cfg.TopModel,cfg);
        catch cleanupError
            st_log(cfg,'WARN','Clone committed; recovery cleanup failed | Harness=%s | %s', ...
                backupName,cleanupError.message);
        end
    end
    status = "OK";
    message = "Harness cloned; Input Scenario and Assessment configured";
    st_log(cfg,'INFO','Harness clone end | CUT=%s | Harness=%s | Status=OK',owner,name);
catch ME
    if committed, rethrow(ME); end
    close_harness(owner,name,cfg);
    st_log(cfg,'ERROR','Harness clone failed | CUT=%s | Harness=%s | %s',owner,name,ME.message);
    try
        if destinationTouched
            current = sltest.harness.find(owner,'SearchDepth',0,'Name',name);
            if ~isempty(current), sltest.harness.delete(owner,name); end
            if ~isempty(backupName)
                clone_logged(owner,backupName,owner,name,cfg);
                save_logged(cfg.TopModel,cfg);
                sltest.harness.delete(owner,backupName);
            end
            save_logged(cfg.TopModel,cfg);
        end
        if hadManifest
            copyfile(manifestBackup,cfg.SldvManifestFile,'f');
        elseif isfile(cfg.SldvManifestFile)
            delete(cfg.SldvManifestFile);
        end
        st_log(cfg,'WARN','Clone rollback complete | CUT=%s | Evidence=%s',owner,transaction);
    catch recovery
        st_log(cfg,'ERROR','Clone rollback failed | CUT=%s | RecoveryHarness=%s | Evidence=%s | %s', ...
            owner,backupName,transaction,recovery.message);
        ME = addCause(ME,recovery);
    end
    rethrow(ME);
end
end

function clone_logged(source,sourceName,owner,name,cfg)
st_log(cfg,'INFO','sltest.harness.clone start | Source=%s/%s | Destination=%s/%s',source,sourceName,owner,name);
sltest.harness.clone(source,sourceName,'DestinationOwner',owner,'Name',name);
st_log(cfg,'INFO','sltest.harness.clone end | CUT=%s | Harness=%s',owner,name);
end

function close_harness(owner,name,cfg)
try
    if bdIsLoaded(name)
        st_log(cfg,'DEBUG','Harness close start | CUT=%s | Harness=%s',owner,name);
        sltest.harness.close(owner,name);
        st_log(cfg,'DEBUG','Harness close end | CUT=%s | Harness=%s',owner,name);
    end
catch ME
    st_log(cfg,'WARN','Harness close failed | CUT=%s | Harness=%s | %s',owner,name,ME.message);
end
end

function close_source(model,loadedHere)
if loadedHere && bdIsLoaded(model), close_system(model,0); end
end

function save_logged(model,cfg)
st_log(cfg,'DEBUG','Clone save_system start | Model=%s',model);
save_system(model);
st_log(cfg,'DEBUG','Clone save_system end | Model=%s',model);
end

function open_logged(owner,name,cfg)
st_log(cfg,'DEBUG','Clone Harness open start | CUT=%s | Harness=%s',owner,name);
sltest.harness.open(owner,name);
st_log(cfg,'DEBUG','Clone Harness open end | CUT=%s | Harness=%s',owner,name);
end
