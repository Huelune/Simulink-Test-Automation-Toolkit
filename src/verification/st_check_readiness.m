function [summary, checks] = st_check_readiness(varargin)
%ST_CHECK_READINESS Inspect prerequisites without preparation or simulation.
p = inputParser;
addParameter(p,'Workflow','STANDALONE');
addParameter(p,'FromStage','');
addParameter(p,'SourcePipelineId','');
parse(p,varargin{:});
workflow = upper(char(string(p.Results.Workflow)));
[stages,index] = st_workflow_stages(workflow,p.Results.FromStage);
from = char(stages(index));
cfg = st_config();
st_log(cfg,'INFO','Readiness start | Workflow=%s | FromStage=%s',workflow,from);
checks = table(zeros(0,1),strings(0,1),strings(0,1),strings(0,1), ...
    strings(0,1),strings(0,1),'VariableNames', ...
    {'No','TestCaseName','Check','Status','Message','RequiredFromStage'});
oldPath = path; oldFolder = pwd; oldModels = {};
sourceHashes = struct([]);
if exist('bdIsLoaded','file'), oldModels = find_system('type','block_diagram'); end
guard = onCleanup(@() restore_session(oldModels,oldPath,oldFolder,cfg));
try
    if strcmp(workflow,'STANDALONE') && ~strcmp(from,'EXECUTE')
        st_validate_regeneration_source(cfg,p.Results.SourcePipelineId,from);
        checks(end+1,:) = {0,"","SAVED_EVIDENCE","OK","Saved inputs verified", ""};
    else
        cfg = st_require_runtime_target('LoadModel',false);
        sourcePaths = {cfg.ModelFile,cfg.ManagementExcel,cfg.TestFile};
        for k = 1:numel(sourcePaths)
            if isfile(sourcePaths{k})
                sourceHashes = [sourceHashes; st_file_signature(sourcePaths{k})]; %#ok<AGROW>
            end
        end
        T = st_load_targets(cfg.OnlyEnabled);
        if isempty(T), error('simtest:ReadinessNoTargets','No enabled targets.'); end
        if numel(unique(T.No)) ~= height(T) || numel(unique(T.TestCaseName)) ~= height(T) || ...
                numel(unique(T.HarnessName)) ~= height(T)
            error('simtest:ReadinessDuplicate','No, Test Case and Harness names must be unique.');
        end
        products = {'Simulink','Simulink_Test'};
        if strcmp(workflow,'STANDALONE') || any(st_coverage_filter_active(T))
            products{end+1} = 'Simulink_Coverage';
        end
        if any(T.SldvMode == "GENERATE"), products{end+1} = 'Simulink_Design_Verifier'; end
        for k = 1:numel(products)
            if ~license('test',products{k})
                error('simtest:ReadinessLicense','License unavailable: %s',products{k});
            end
        end
        checks(end+1,:) = {0,"","PRODUCTS","OK","License query passed; runtime checkout not guaranteed",""};
        if bdIsLoaded(cfg.TopModel)
            if ~st_same_path(get_param(cfg.TopModel,'FileName'),cfg.ModelFile) || ...
                    strcmp(get_param(cfg.TopModel,'Dirty'),'on') || ...
                    ~strcmp(get_param(cfg.TopModel,'SimulationStatus'),'stopped')
                error('simtest:ReadinessModelState','Save/stop the selected model; same-name conflicts must be closed manually.');
            end
            if strcmp(workflow,'STANDALONE')
                error('simtest:ReadinessModelOpen','Close the Top Model before Standalone EXECUTE.');
            end
        else
            st_log(cfg,'DEBUG','Readiness model load start | File=%s',cfg.ModelFile);
            load_system(cfg.ModelFile);
            st_log(cfg,'DEBUG','Readiness model load complete');
        end
        cfg.ExecutionMode = st_resolve_execution_mode(cfg.ExecutionMode,T);
        st_validate_clone_mapping(T,cfg);
        [state,~] = st_load_workflow_state(cfg);
        allStages = st_workflow_stages('FROM_HARNESS');
        limit = find(allStages == string(from),1)-1;
        if strcmp(workflow,'STANDALONE'), limit = 8; end
        for i = 1:height(T)
            row = T(i,:);
            owner = st_normalize_cut_path(row.CUTPath,cfg.TopModel);
            try
                newClone = st_is_harness_clone(row) && limit == 0;
                if ~newClone && (getSimulinkBlockHandle(owner) == -1 || ~strcmp(get_param(owner,'BlockType'),'SubSystem'))
                    error('simtest:ReadinessCUT','CUT is not an existing Subsystem: %s',owner);
                end
                if row.SldvMode == "FILE"
                    file = char(row.SldvDataFile);
                    if ~isfile(file), file = fullfile(fileparts(cfg.ManagementExcel),file); end
                    if ~isfile(file), error('simtest:ReadinessSourceInput','Input MAT is missing: %s',file); end
                    if row.DataFileFormat == "MAT"
                        vars = whos('-file',file);
                        names = {vars(strcmp({vars.class},'Simulink.SimulationData.Dataset')).name};
                        if isempty(names) || (strlength(row.MatVariableName)>0 && ~ismember(char(row.MatVariableName),names))
                            error('simtest:ReadinessDataset','Requested Dataset is absent from MAT file.');
                        end
                    end
                end
                if strcmp(workflow,'STANDALONE') && ...
                        (row.CoverageFilterMode ~= "ALL_CONTENT" || row.CoverageBoundaryMode ~= "CUT_ONLY" || ...
                        row.CoverageFilterAction ~= "EXCLUDE" || strlength(row.CoverageFilterRationale)==0 || ...
                        ~strcmpi(cfg.CoverageFilterExistingPolicy,'REPLACE'))
                    error('simtest:ReadinessFilterPolicy','Standalone requires ALL_CONTENT+CUT_ONLY+EXCLUDE, rationale and REPLACE.');
                end
                if st_is_harness_clone(row) && limit == 0
                    st_clone_template_signature(row,cfg);
                end
                checks(end+1,:) = {row.No,row.TestCaseName,"INPUTS","OK","Source inputs present",""}; %#ok<AGROW>
            catch ME
                checks(end+1,:) = {row.No,row.TestCaseName,"INPUTS","BLOCKED",string(ME.message),"HARNESS"}; %#ok<AGROW>
                continue;
            end
            inputs = st_stage_inputs(row,cfg);
            key = st_hash_value(struct('TopModel',char(cfg.TopModel),'CUTPath',char(row.CUTPath), ...
                'HarnessName',char(row.HarnessName),'TestCaseName',char(row.TestCaseName)));
            for s = 1:limit
                stage = char(allStages(s));
                try
                    output = st_inspect_preparation_stage(stage,row,cfg);
                    validate_record(state,key,stage,inputs.(stage),st_hash_value(output),row);
                    checks(end+1,:) = {row.No,row.TestCaseName,string(stage),"OK","Prerequisite readback verified",""}; %#ok<AGROW>
                catch ME
                    st_log(cfg,'WARN','Readiness prerequisite blocked | TC=%s | Stage=%s | %s: %s', ...
                        row.TestCaseName,stage,ME.identifier,ME.message);
                    requiredStage = string(stage);
                    if strcmp(ME.identifier,'simtest:ReadinessHarnessSync'), requiredStage = "HARNESS"; end
                    checks(end+1,:) = {row.No,row.TestCaseName,string(stage),"BLOCKED",string(ME.message),requiredStage}; %#ok<AGROW>
                    break;
                end
            end
        end
        probe_write(cfg.ResultDir);
        probe_write(fileparts(cfg.TestFile));
        if bdIsLoaded(cfg.TopModel) && strcmp(get_param(cfg.TopModel,'Dirty'),'on')
            error('simtest:ReadinessSourceChanged','Top Model became dirty during inspection; review it before execution.');
        end
    end
    if strcmp(workflow,'STANDALONE'), probe_write(cfg.StandaloneCoverageRootDir); end
    if strcmp(workflow,'STANDALONE') && strlength(string(cfg.StandaloneCoverageRootDir)) > 100
        checks(end+1,:) = {0,"","PATH_LENGTH","WARN","Choose a short Standalone output root",""};
    end
catch ME
    requiredStage = "";
    if ismember(ME.identifier,{'simtest:RestartExecuteIncomplete','simtest:RestartResultNotSaved', ...
            'simtest:RestartReplayInputMissing','simtest:RestartCaptureIncomplete','simtest:RestartEvidenceIdentity'})
        requiredStage = "EXECUTE";
    elseif ismember(ME.identifier,{'simtest:RestartPackageIncomplete','simtest:RestartPackageChanged'})
        requiredStage = "PACKAGE";
    elseif strcmp(ME.identifier,'simtest:RestartLegacyEvidence')
        requiredStage = "EXECUTE";
        if strcmp(from,'SUMMARY'), requiredStage = "PACKAGE"; end
    elseif strcmp(ME.identifier,'simtest:RestartEvidenceInvalid')
        requiredStage = "EXECUTE";
        if strcmp(from,'SUMMARY'), requiredStage = "PACKAGE"; end
    end
    checks(end+1,:) = {0,"","ENVIRONMENT","BLOCKED",string(ME.identifier)+": "+string(ME.message),requiredStage};
end
try
    restore_session(oldModels,oldPath,oldFolder,cfg);
catch ME
    checks(end+1,:) = {0,"","SESSION_RESTORE","BLOCKED",string(ME.message),""};
end
clear guard;
for k = 1:numel(sourceHashes)
    if ~strcmp(st_file_signature(sourceHashes(k).Path).SHA256,sourceHashes(k).SHA256)
        checks(end+1,:) = {0,"","SOURCE_INTEGRITY","BLOCKED", ...
            "Source changed during inspection: "+string(sourceHashes(k).Path),""};
    end
end
ready = ~any(checks.Status == "BLOCKED");
recommended = "";
required = checks.RequiredFromStage(checks.Status == "BLOCKED" & checks.RequiredFromStage ~= "");
ordered = [st_workflow_stages('FROM_HARNESS'),"PACKAGE","SUMMARY"];
for stage = ordered
    if any(required == stage), recommended = stage; break; end
end
summary = struct('Ready',ready,'Workflow',workflow,'FromStage',from, ...
    'RecommendedFromStage',char(recommended),'Status','NOT_READY');
if ready, summary.Status = 'READY'; end
if nargout == 0, disp(checks); disp(summary); end
level = 'INFO'; if ~ready, level = 'WARN'; end
st_log(cfg,level,'Readiness complete | Status=%s | RecommendedFromStage=%s',summary.Status,recommended);
end

function validate_record(state,key,stage,inputHash,outputHash,row)
record = [];
if isfield(state,'RestartEvidence') && ~isempty(state.RestartEvidence)
    list = state.RestartEvidence;
    index = find(strcmp({list.Key},key) & strcmp({list.Stage},stage),1);
    if ~isempty(index), record = list(index); end
end
if isempty(record)
    % Structural readback can bootstrap legacy Harness/connection checks.
    % Prepared FILE/GENERATE inputs and Assessment code need captured intent.
    if strcmp(stage,'ASSESSMENT') || (strcmp(stage,'SLDV') && row.SldvMode ~= "OFF")
        error('simtest:RestartEvidenceMissing','No verifiable checkpoint for %s; restart there once.',stage);
    end
    return;
end
if ~strcmp(record.Status,'OK') || ~strcmp(record.InputHash,inputHash) || ~strcmp(record.OutputHash,outputHash)
    error('simtest:RestartPrerequisiteChanged','%s checkpoint/input/output changed; restart from %s.',stage,stage);
end
end

function probe_write(folder)
if isempty(folder), return; end
folder = st_absolute_path(folder);
ancestor = folder;
while ~isfolder(ancestor)
    if isfile(ancestor), error('simtest:ReadinessOutput','Output directory conflicts with a file: %s',ancestor); end
    parent = fileparts(ancestor);
    if isempty(parent) || strcmp(parent,ancestor), error('simtest:ReadinessOutput','No existing output ancestor.'); end
    ancestor = parent;
end
file = [tempname(ancestor) '.probe'];
id = fopen(file,'w');
if id < 0, error('simtest:ReadinessOutput','Output is not writable: %s',ancestor); end
fclose(id); delete(file);
end

function restore_session(oldModels,oldPath,oldFolder,cfg)
if exist('bdIsLoaded','file')
    current = find_system('type','block_diagram');
    added = setdiff(current,oldModels);
    for i = numel(added):-1:1
        st_log(cfg,'DEBUG','Readiness model close start | Model=%s',added{i});
        close_system(added{i},0);
        st_log(cfg,'DEBUG','Readiness model close complete | Model=%s',added{i});
    end
end
path(oldPath);
if ~strcmp(pwd,oldFolder), cd(oldFolder); end
end
