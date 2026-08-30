function archived = st_archive_verification_evidence(sourceJson, destination)
%ST_ARCHIVE_VERIFICATION_EVIDENCE Copy accepted manual evidence into the run.

archived = strings(0,1);
sourceJson = char(string(sourceJson));
if isempty(sourceJson), return; end
if ~isfile(sourceJson)
    error('simtest:VerificationEvidenceMissing', ...
        'Manual evidence JSON is missing: %s', sourceJson);
end
if ~isfolder(destination), mkdir(destination); end

jsonDestination = fullfile(destination, 'manual-evidence.json');
copy_checked(sourceJson, jsonDestination);
archived(end+1,1) = string(jsonDestination);

data = jsondecode(fileread(sourceJson));
if ~isfield(data, 'Checks'), return; end
sourceRoot = fileparts(sourceJson);
filesRoot = fullfile(destination, 'files');
for i = 1:numel(data.Checks)
    if ~isfield(data.Checks(i), 'EvidencePaths'), continue; end
    paths = text_list(data.Checks(i).EvidencePaths);
    for j = 1:numel(paths)
        source = paths{j};
        if ~isfile(source), source = fullfile(sourceRoot, source); end
        if ~isfile(source), continue; end
        [~, name, extension] = fileparts(source);
        output = fullfile(filesRoot, sprintf('%03d_%03d_%s%s', ...
            i, j, safe_name(name), extension));
        copy_checked(source, output);
        archived(end+1,1) = string(output); %#ok<AGROW>
    end
end
end

function copy_checked(source, destination)
parent = fileparts(destination);
if ~isfolder(parent), mkdir(parent); end
[ok, message] = copyfile(source, destination, 'f');
if ~ok
    error('simtest:VerificationEvidenceCopyFailed', ...
        'Cannot archive %s: %s', source, message);
end
end

function value = safe_name(value)
value = regexprep(char(string(value)), '[^A-Za-z0-9_.-]+', '_');
if isempty(value), value = 'evidence'; end
end

function values = text_list(value)
if isempty(value)
    values = {};
elseif ischar(value)
    values = {value};
else
    values = cellstr(string(value(:)));
end
end
