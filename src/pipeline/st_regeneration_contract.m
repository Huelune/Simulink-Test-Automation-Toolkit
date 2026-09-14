function valid = st_regeneration_contract(manifest,depth)
%ST_REGENERATION_CONTRACT Verify provenance separately from local run counts.
valid = false;
if nargin < 2, depth = 0; end
if depth >= 64, return; end
try
    if manifest.Version ~= 3 || manifest.LocalExecutionCount ~= 0 || ...
            manifest.ResultExportCount ~= 0 || ...
            ~ismember(manifest.RestartFromStage,{'PACKAGE','SUMMARY'})
        return;
    end
    st_require_file_hash(manifest.SourceManifest,manifest.SourceManifestSHA256);
    source = jsondecode(fileread(manifest.SourceManifest));
    if isfield(source,'SourcePipelineId') && ~st_regeneration_contract(source,depth+1), return; end
    if ~strcmp(source.PipelineId,manifest.SourcePipelineId) || ...
            ~isequal(source.SourceBefore,manifest.SourceBefore) || ...
            ~isequal(source.SourceAfter,manifest.SourceAfter) || ...
            numel(source.Targets) ~= numel(manifest.Targets)
        return;
    end
    names = {'No','TestCaseName','StandaloneModel','StandaloneCUTPath','ExecutionStatus', ...
        'RunCount','ResultFilterAttachCount','FinalOutcome','FilterRestoreStatus', ...
        'ModelCleanupStatus','PathCleanupStatus','IterationSignature','InputReadbackStatus'};
    for i = 1:numel(source.Targets)
        for k = 1:numel(names)
            if ~isequal(source.Targets(i).(names{k}),manifest.Targets(i).(names{k})), return; end
        end
    end
    st_require_file_hash(manifest.ExecutionLog,manifest.SourceExecutionLogSHA256);
    if strcmp(manifest.RestartFromStage,'PACKAGE')
        valid = manifest.ResultImportCount == 1 && ...
            strcmp(manifest.PackageResultSource,'IMPORTED') && ...
            strcmp(manifest.ResultFile,source.ResultFile) && ...
            strcmp(manifest.ResultSHA256,source.ResultSHA256) && ~isempty(manifest.ResultSHA256);
        % Historical import provenance is not a new import requirement.
        % PACKAGE replay validates the actual Result separately; SUMMARY
        % must remain usable after that saved Result is archived elsewhere.
    else
        valid = manifest.ResultImportCount == 0 && ...
            strcmp(manifest.PackageResultSource,'REUSED_PACKAGE');
        for i = 1:numel(source.Targets)
            for name = {'DecisionCovered','DecisionTotal','DecisionPercentageText', ...
                    'ExecutionCovered','ExecutionTotal','ExecutionPercentageText'}
                if ~isequaln(source.Targets(i).(name{1}),manifest.Targets(i).(name{1})), valid = false; end
            end
        end
    end
catch
    valid = false;
end
end
