function info = st_regenerate_standalone_results(cfg,sourceId,stage)
%ST_REGENERATE_STANDALONE_RESULTS Create a derived delivery, never rerun tests.
stage = upper(char(string(stage)));
[source,sourcePath,sourceHash] = st_validate_regeneration_source(cfg,sourceId,stage);
uuid = char(java.util.UUID.randomUUID());
id = [char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '_' uuid(1:8)];
root = fullfile(cfg.StandaloneCoverageRootDir,id);
if isfolder(root), error('simtest:RestartDestinationExists','Destination already exists.'); end
mkdir(root);
manifest = source;
manifest.Version = 3;
manifest.PipelineId = id;
manifest.PipelineRoot = root;
manifest.CreatedAt = char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
manifest.UpdatedAt = manifest.CreatedAt;
manifest.SourcePipelineId = char(sourceId);
manifest.SourceManifest = fullfile(root,'.provenance','source-manifest.json');
manifest.SourceManifestSHA256 = sourceHash;
manifest.RestartFromStage = stage;
manifest.LocalExecutionCount = 0;
manifest.ResultExportCount = 0;
manifest.ResultImportCount = 0;
manifest.PublishLatest = false;
manifest.Status = 'RUNNING';
manifest.Action = stage;
manifest.Actions.SUMMARY = action('NOT_RUN','Derived SUMMARY pending');
manifest.CoverageSummary = ''; manifest.CoverageSummarySHA256 = '';
manifest.ExecutionLog = fullfile(root,'logs','execution-origin.log');
st_log(cfg,'INFO','Result regeneration start | Source=%s | New=%s | Stage=%s',sourceId,id,stage);
try
    copy_checked(sourcePath,manifest.SourceManifest,sourceHash);
    manifest.SourceExecutionLogSHA256 = st_file_signature(source.ExecutionLog).SHA256;
    copy_checked(source.ExecutionLog,manifest.ExecutionLog,manifest.SourceExecutionLogSHA256);
    if strcmp(stage,'PACKAGE')
        manifest.Actions.PACKAGE = action('NOT_RUN','Derived PACKAGE pending');
        manifest.PackageInventory = struct([]);
        for i = 1:numel(manifest.Targets)
            item = manifest.Targets(i);
            % Clear only prior packaging output, not execution verdict/evidence.
            names = {'OutputDirectory','TargetManifest','PackagedStandaloneModel','PackagedInput', ...
                'PackagedCVF','PackagedStandaloneModelSHA256','PackagedInputSHA256','PackagedCVFSHA256', ...
                'CoverageResult','CoverageResultSHA256','TestReport','ReportHTML'};
            for k = 1:numel(names), item.(names{k}) = ''; end
            item.PackageStatus = 'NOT_RUN'; item.SummaryStatus = 'NOT_RUN';
            item.MetricSource = ''; item.MetricSourceStatus = 'NOT_RUN';
            for metric = {'Decision','Execution'}
                for field = {'Covered','Total','Percentage'}
                    item.([metric{1} field{1}]) = NaN;
                end
                item.([metric{1} 'PercentageText']) = 'N/A';
                item.([metric{1} 'MetricStatus']) = 'NOT_RUN';
            end
            item.PackageFailure = struct('Identifier','','Message','', ...
                'Stack',repmat(struct('Name','','File','','Line',0),0,1));
            manifest.Targets(i) = item;
        end
        st_write_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,manifest);
        clear st_package_standalone_coverage_artifacts;
        rehash;
        manifest = st_package_standalone_coverage_artifacts(cfg.StandaloneCoverageRootDir,manifest,struct());
    else
        % The package already contains relative model-input references. Copy
        % bytes and rebase JSON paths only; do not load/save any model.
        for i = 1:numel(source.PackageInventory)
            relative = source.PackageInventory(i).RelativePath;
            destination = st_absolute_path(fullfile(root,relative));
            if ~startsWith(lower(destination),[lower(st_absolute_path(root)) filesep])
                error('simtest:RestartPackagePath','Inventory path escapes destination: %s',relative);
            end
            copy_checked(fullfile(source.PipelineRoot,relative),destination,source.PackageInventory(i).SHA256);
        end
        manifest = rebase_package(manifest,source.PipelineRoot,root);
        manifest.PackageResultSource = 'REUSED_PACKAGE';
        manifest.PackageInventory = st_package_inventory(manifest);
    end
    manifest = st_export_standalone_coverage_summary(cfg.StandaloneCoverageRootDir,manifest);
    % Do not publish a candidate whose historical evidence changed mid-copy.
    st_require_file_hash(sourcePath,sourceHash);
    st_validate_regeneration_source(cfg,sourceId,stage);
    manifest.Action = 'SUMMARY';
    manifest.PublishLatest = strcmp(manifest.Status,'OK');
    st_write_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,manifest);
    info = struct('PipelineId',id,'PipelineRoot',root,'SourcePipelineId',char(sourceId), ...
        'Manifest',fullfile(root,'pipeline-manifest.json'),'CoverageSummary',manifest.CoverageSummary, ...
        'Status',manifest.Status,'LocalExecutionCount',0);
    st_log(cfg,'INFO','Result regeneration complete | New=%s | Status=%s | NewRuns=0',id,manifest.Status);
catch ME
    % Reload the last per-target checkpoint rather than discarding partial evidence.
    try
        [manifest,~] = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,id);
    catch
    end
    manifest.PublishLatest = false;
    manifest.Status = 'FAIL';
    manifest.Failure = struct('Identifier',ME.identifier,'Message',ME.message);
    st_write_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,manifest);
    st_log(cfg,'ERROR','Result regeneration failed | New=%s | Prior delivery preserved | %s',id,ME.message);
    rethrow(ME);
end
end

function manifest = rebase_package(manifest,previous,root)
fields = {'TestManagerFile','TestManagerLauncher'};
for i = 1:numel(fields), manifest.(fields{i}) = rebase(manifest.(fields{i}),previous,root); end
for i = 1:numel(manifest.Targets)
    item = manifest.Targets(i);
    names = {'OutputDirectory','TargetManifest','PackagedStandaloneModel','PackagedInput', ...
        'PackagedCVF','CoverageResult','TestReport','ReportHTML'};
    for k = 1:numel(names), item.(names{k}) = rebase(item.(names{k}),previous,root); end
    item.SummaryStatus = 'NOT_RUN';
    st_write_json_atomic(item.TargetManifest,item);
    manifest.Targets(i) = item;
end
end

function value = rebase(value,previous,root)
if isempty(value), return; end
prefix = [st_absolute_path(previous) filesep];
path = st_absolute_path(value);
if ~startsWith(lower(path),lower(prefix))
    error('simtest:RestartPackagePath','Package path is outside its recorded root: %s',value);
end
value = fullfile(root,path(numel(prefix)+1:end));
end

function copy_checked(source,destination,expectedHash)
if ~isfile(source), error('simtest:RestartSourceMissing','Missing source: %s',source); end
st_require_file_hash(source,expectedHash);
folder = fileparts(destination); if ~isfolder(folder), mkdir(folder); end
[ok,message] = copyfile(source,destination);
if ~ok, error('simtest:RestartCopyFailed','%s',message); end
st_require_file_hash(destination,expectedHash);
end

function value = action(status,message)
value = struct('Status',status,'Message',message,'UpdatedAt',char(datetime('now')));
end
