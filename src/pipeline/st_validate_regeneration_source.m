function [manifest, manifestPath, manifestHash] = st_validate_regeneration_source(cfg,id,stage)
%ST_VALIDATE_REGENERATION_SOURCE Validate before creating any retry output.
id = char(string(id)); stage = upper(char(string(stage)));
if isempty(id) || strcmpi(id,'LATEST')
    error('simtest:RestartSourceRequired','Specify an explicit SourcePipelineId, not LATEST.');
end
[manifest,manifestPath] = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,id);
manifestHash = st_file_signature(manifestPath).SHA256;
if ~isequaln(jsondecode(fileread(manifestPath)),manifest)
    error('simtest:RestartSourceChanged','Source manifest changed during readback.');
end
if ~st_same_path(manifest.PipelineRoot,fileparts(manifestPath))
    error('simtest:RestartSourceLocation','Source root does not match the selected pipeline.');
end
if isfield(manifest,'SourcePipelineId') && ~st_regeneration_contract(manifest)
    error('simtest:RestartProvenanceInvalid','Source pipeline provenance is invalid.');
end
if ~ismember(stage,{'PACKAGE','SUMMARY'})
    error('simtest:RestartStageInvalid','Regeneration starts at PACKAGE or SUMMARY.');
end
if ~st_same_path(manifest.SourceBefore.Model.Path,cfg.ModelFile) || ...
        ~st_same_path(manifest.SourceBefore.ManagementExcel.Path,cfg.ManagementExcel)
    error('simtest:RestartProfileMismatch','Select the profile associated with SourcePipelineId.');
end
st_log(cfg,'INFO','Regeneration evidence validation start | Source=%s | Stage=%s',id,stage);
try
if strcmp(stage,'PACKAGE')
    if ~ismember(upper(string(manifest.Actions.EXECUTE.Status)),["OK","WARN"])
        error('simtest:RestartExecuteIncomplete','EXECUTE did not complete; start at EXECUTE.');
    end
    if ~manifest.CanResumePackage
        error('simtest:RestartResultNotSaved','Result was not saved; start a new EXECUTE with SaveTestResult=true.');
    end
    st_require_file_hash(manifest.ResultFile,manifest.ResultSHA256);
    if ~isfield(manifest,'ReplayInputs') || isempty(manifest.ReplayInputs)
        error('simtest:RestartLegacyEvidence','Execution input hashes are unavailable; start a new EXECUTE.');
    end
    for i = 1:numel(manifest.ReplayInputs)
        st_require_file_hash(manifest.ReplayInputs(i).Path,manifest.ReplayInputs(i).SHA256);
    end
    requiredInputs = [{manifest.TestManagerWorkFile}, {manifest.Targets.StandaloneModelFile}, ...
        {manifest.Targets.SignalEditorInput}];
    for i = 1:numel(requiredInputs)
        if isempty(requiredInputs{i}), continue; end
        matches = arrayfun(@(entry) st_same_path(entry.Path,requiredInputs{i}),manifest.ReplayInputs);
        if sum(matches) ~= 1
            error('simtest:RestartReplayInputMissing','Execution input hash missing or ambiguous: %s',requiredInputs{i});
        end
    end
    for i = 1:numel(manifest.Targets)
        item = manifest.Targets(i);
        if strcmpi(item.ExecutionStatus,'EXCEPT'), continue; end
        if strcmpi(item.ExecutionStatus,'FAIL') || ~strcmpi(item.PackageEvidenceStatus,'OK')
            error('simtest:RestartCaptureIncomplete','Coverage capture failed for %s; start at EXECUTE.',item.TestCaseName);
        end
        st_require_file_hash(item.ExecutionCVFPath,item.CVFSHA256);
        st_require_file_hash(item.PackageEvidence,item.PackageEvidenceSHA256);
        evidence = jsondecode(fileread(item.PackageEvidence));
        if evidence.Version ~= 2 || evidence.No ~= item.No || ...
                ~strcmp(evidence.TestCaseName,item.TestCaseName) || ...
                ~strcmp(evidence.StandaloneModel,item.StandaloneModel)
            error('simtest:RestartEvidenceIdentity','Captured evidence identity mismatch.');
        end
        st_require_file_hash(evidence.CoverageResult,evidence.CoverageResultSHA256);
        st_require_file_hash(evidence.CoverageReportZip,evidence.CoverageReportZipSHA256);
    end
else
    if ~ismember(upper(string(manifest.Actions.PACKAGE.Status)),["OK","WARN"])
        error('simtest:RestartPackageIncomplete','PACKAGE did not complete; start at PACKAGE.');
    end
    if ~isfield(manifest,'PackageInventory') || isempty(manifest.PackageInventory)
        error('simtest:RestartLegacyEvidence','Package hashes are unavailable; regenerate PACKAGE first.');
    end
    actual = st_package_inventory(manifest);
    if ~isequal(actual(:),manifest.PackageInventory(:))
        error('simtest:RestartPackageChanged','Delivery files changed or disappeared; start at PACKAGE.');
    end
    for i = 1:numel(manifest.Targets)
        item = manifest.Targets(i);
        for field = {'DecisionCovered','DecisionTotal','ExecutionCovered','ExecutionTotal'}
            value = item.(field{1});
            if ~isnumeric(value) || ~(isscalar(value) || isempty(value))
                error('simtest:RestartMetricInvalid','Invalid scalar metric for %s.',item.TestCaseName);
            end
        end
    end
end
st_require_file_hash(manifestPath,manifestHash);
st_log(cfg,'INFO','Regeneration evidence validation complete | Source=%s',id);
catch ME
    st_log(cfg,'ERROR','Regeneration evidence validation failed | Source=%s | %s: %s',id,ME.identifier,ME.message);
    rethrow(ME);
end
end
