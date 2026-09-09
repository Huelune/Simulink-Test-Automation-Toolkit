function signature = st_clone_template_signature(row, cfg)
%ST_CLONE_TEMPLATE_SIGNATURE Include saved template and input artifacts.
signature = struct('Owner',char(row.SourceCUTPath), ...
    'Harness',char(row.SourceHarnessName),'Model',[],'External',[],'Input',[]);
source = char(row.SourceCUTPath);
source(source == char(92)) = '/';
source = regexprep(source,'^/+','');
model = strtok(source,'/');
loadedHere = false;
try
    loadedHere = ~bdIsLoaded(model);
    st_log(cfg,'DEBUG','Template fingerprint load start | Model=%s',model);
    load_system(model);
    st_log(cfg,'DEBUG','Template fingerprint load end | Model=%s',model);
    cleanup = onCleanup(@() close_model(model,loadedHere)); %#ok<NASGU>
    if strcmp(get_param(model,'Dirty'),'on')
        error('simtest:CloneSourceUnsaved','Save the Template model before planning.');
    end
    signature.Model = st_file_signature(get_param(model,'FileName'));
    info = sltest.harness.find(source,'SearchDepth',0,'Name',char(row.SourceHarnessName));
    if numel(info) ~= 1, error('simtest:CloneTemplateMissing','Template not found.'); end
    if isfield(info,'harnessFilePath') && ~isempty(info.harnessFilePath)
        signature.External = st_file_signature(info.harnessFilePath);
    end
    name = char(row.SourceHarnessName);
    if bdIsLoaded(name)
        error('simtest:CloneHarnessOpen','Close the Template Harness before planning.');
    end
    sltest.harness.open(source,name);
    harnessCleanup = onCleanup(@() sltest.harness.close(source,name)); %#ok<NASGU>
    block = st_find_signal_editor_block(name);
    file = st_resolve_data_file(get_param(block,'Filename'),model);
    signature.Input = st_file_signature(file);
    clear harnessCleanup;
    st_log(cfg,'DEBUG','Template fingerprint complete | Source=%s',source);
catch ME
    signature.Error = ME.message;
    st_log(cfg,'WARN','Template fingerprint incomplete | Source=%s | %s',source,ME.message);
end
end

function close_model(model,loadedHere)
if loadedHere && bdIsLoaded(model), close_system(model,0); end
end
