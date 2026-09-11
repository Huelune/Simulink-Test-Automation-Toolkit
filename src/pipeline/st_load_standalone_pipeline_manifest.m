function [manifest, manifestPath] = ...
        st_load_standalone_pipeline_manifest(outputRoot, pipelineId)
%ST_LOAD_STANDALONE_PIPELINE_MANIFEST Load and validate resumable state.

pipelineId = strtrim(char(string(pipelineId)));
expectedHash = '';
if isempty(pipelineId) || strcmpi(pipelineId, 'LATEST')
    latestPath = fullfile(outputRoot, 'latest.json');
    if ~isfile(latestPath)
        error('simtest:StandalonePipelineLatestMissing', ...
            'No standalone pipeline latest pointer exists: %s', latestPath);
    end
    latest = decode_json(latestPath);
    require_field(latest, 'PipelineId', latestPath);
    pipelineId = char(string(latest.PipelineId));
    if isfield(latest, 'ManifestSHA256')
        expectedHash = char(string(latest.ManifestSHA256));
    end
end
if isempty(pipelineId) || ~strcmp(pipelineId, st_export_safe_name(pipelineId))
    error('simtest:StandalonePipelineIdInvalid', ...
        'PipelineId is not a safe directory name: %s', pipelineId);
end
manifestPath = fullfile(outputRoot, pipelineId, ...
    'pipeline-manifest.json');
if ~isfile(manifestPath)
    error('simtest:StandalonePipelineManifestMissing', ...
        'Pipeline manifest is missing: %s', manifestPath);
end
checksumPath = fullfile(outputRoot, pipelineId, ...
    'pipeline-manifest.sha256');
if ~isfile(checksumPath)
    error('simtest:StandalonePipelineManifestChecksumMissing', ...
        'Pipeline manifest checksum is missing: %s', checksumPath);
end
storedHash = strtrim(fileread(checksumPath));
if ~isempty(expectedHash) && ~strcmpi(storedHash, expectedHash)
    error('simtest:StandalonePipelineManifestChecksumMismatch', ...
        'The latest pointer and pipeline checksum disagree: %s', ...
        manifestPath);
end
actual = st_file_signature(manifestPath);
if ~strcmpi(actual.SHA256, storedHash)
    error('simtest:StandalonePipelineManifestChecksumMismatch', ...
        'The pipeline manifest checksum does not match: %s', ...
        manifestPath);
end
manifest = decode_json(manifestPath);
require_field(manifest, 'Version', manifestPath);
require_field(manifest, 'PipelineId', manifestPath);
if double(manifest.Version) ~= 1 || ...
        ~strcmp(char(string(manifest.PipelineId)), pipelineId)
    error('simtest:StandalonePipelineManifestInvalid', ...
        'Pipeline manifest identity/version is invalid: %s', manifestPath);
end
end

function value = decode_json(path)
try
    value = jsondecode(fileread(path));
catch ME
    error('simtest:StandalonePipelineManifestInvalid', ...
        'Cannot decode pipeline JSON %s: %s', path, ME.message);
end
end

function require_field(value, name, path)
if ~isstruct(value) || ~isfield(value, name)
    error('simtest:StandalonePipelineManifestInvalid', ...
        'Required field %s is missing from %s.', name, path);
end
end
