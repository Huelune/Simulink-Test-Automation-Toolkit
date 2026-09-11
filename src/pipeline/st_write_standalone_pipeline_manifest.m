function manifestPath = st_write_standalone_pipeline_manifest( ...
        outputRoot, manifest)
%ST_WRITE_STANDALONE_PIPELINE_MANIFEST Atomically persist pipeline state.

pipelineId = char(string(manifest.PipelineId));
if isempty(pipelineId) || ~strcmp(pipelineId, st_export_safe_name(pipelineId))
    error('simtest:StandalonePipelineIdInvalid', ...
        'PipelineId is not a safe directory name: %s', pipelineId);
end
pipelineRoot = fullfile(outputRoot, pipelineId);
if ~isfolder(pipelineRoot), mkdir(pipelineRoot); end
manifestPath = fullfile(pipelineRoot, 'pipeline-manifest.json');
write_json_atomic(manifestPath, manifest);
signature = st_file_signature(manifestPath);
write_text_atomic(fullfile(pipelineRoot, 'pipeline-manifest.sha256'), ...
    [signature.SHA256 newline]);
latest = struct( ...
    'Version', 1, ...
    'PipelineId', pipelineId, ...
    'Manifest', manifestPath, ...
    'ManifestSHA256', signature.SHA256, ...
    'UpdatedAt', timestamp_text());
write_json_atomic(fullfile(outputRoot, 'latest.json'), latest);
end

function write_text_atomic(path, value)
folder = fileparts(path);
temporary = [tempname(folder) '.txt'];
cleanup = onCleanup(@() delete_if_present(temporary)); %#ok<NASGU>
fileId = fopen(temporary, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:StandalonePipelineManifestWriteFailed', ...
        'Cannot write checksum: %s', path);
end
fileCleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', value);
clear fileCleanup;
[ok, message] = movefile(temporary, path, 'f');
if ~ok
    error('simtest:StandalonePipelineManifestWriteFailed', ...
        'Cannot replace %s: %s', path, message);
end
end

function write_json_atomic(path, value)
folder = fileparts(path);
if ~isfolder(folder), mkdir(folder); end
temporary = [tempname(folder) '.json'];
cleanup = onCleanup(@() delete_if_present(temporary)); %#ok<NASGU>
fileId = fopen(temporary, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:StandalonePipelineManifestWriteFailed', ...
        'Cannot write JSON: %s', path);
end
fileCleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(value, 'PrettyPrint', true));
clear fileCleanup;
[ok, message] = movefile(temporary, path, 'f');
if ~ok
    error('simtest:StandalonePipelineManifestWriteFailed', ...
        'Cannot replace %s: %s', path, message);
end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
