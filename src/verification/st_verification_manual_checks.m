function [checks, evidenceTable] = ...
    st_verification_manual_checks(catalog, options, targetFingerprint)
%ST_VERIFICATION_MANUAL_CHECKS Validate manual evidence for GUI checks.

checks = st_empty_verification_checks();
evidenceTable = empty_evidence_table();
manualIds = strings(0,1);
featureIds = strings(0,1);
for i = 1:height(catalog)
    ids = split_ids(catalog.ManualCheckIds(i));
    manualIds = [manualIds; ids]; %#ok<AGROW>
    featureIds = [featureIds; repmat(string(catalog.FeatureId(i)), ...
        numel(ids), 1)]; %#ok<AGROW>
end

if isempty(manualIds)
    return;
end
required = strcmp(options.Profile, 'CERTIFY') && ...
    ~strcmp(options.Target, 'FIXTURE');
if ~required
    for i = 1:numel(manualIds)
        checks = [checks; st_verification_check( ...
            manualIds(i), featureIds(i), options.Profile, ...
            options.Target, false, 'SKIP', ...
            'Manual evidence is required only for CURRENT certification')]; %#ok<AGROW>
    end
    return;
end

path = options.ManualEvidence;
if isempty(path)
    add_blocked('Manual evidence file was not supplied');
    return;
end
if ~isfile(path)
    add_blocked(['Manual evidence file is missing: ' path]);
    return;
end

try
    data = jsondecode(fileread(path));
    if ~isfield(data, 'Checks')
        error('Evidence JSON must contain Checks.');
    end
    entries = data.Checks;
catch ME
    add_blocked(['Manual evidence is invalid: ' ME.message]);
    return;
end

for i = 1:numel(manualIds)
    id = manualIds(i);
    match = find(arrayfun(@(x) isfield(x, 'CheckId') && ...
        strcmpi(char(string(x.CheckId)), char(id)), entries), 1);
    if isempty(match)
        status = 'BLOCKED'; message = "Evidence entry is missing";
        row = empty_evidence_row(id);
    else
        [status, message, row] = validate_entry( ...
            entries(match), id, targetFingerprint, fileparts(path));
    end
    evidenceTable = [evidenceTable; row]; %#ok<AGROW>
    checks = [checks; st_verification_check( ...
        id, featureIds(i), options.Profile, options.Target, true, ...
        status, message, path)]; %#ok<AGROW>
end

    function add_blocked(message)
        for k = 1:numel(manualIds)
            checks = [checks; st_verification_check( ...
                manualIds(k), featureIds(k), options.Profile, ...
                options.Target, true, 'BLOCKED', message, path)]; %#ok<AGROW>
            evidenceTable = [evidenceTable; ...
                empty_evidence_row(manualIds(k))]; %#ok<AGROW>
        end
    end
end

function [status, message, row] = validate_entry( ...
        entry, id, fingerprint, evidenceRoot)
fields = {'Status','VerifiedBy','VerifiedAt','TargetFingerprint', ...
    'Notes','EvidencePaths'};
missing = fields(~isfield(entry, fields));
if ~isempty(missing)
    status = 'BLOCKED';
    message = "Evidence fields are missing: " + strjoin(missing, ', ');
    row = empty_evidence_row(id);
    return;
end
entryStatus = upper(string(entry.Status));
if ~ismember(entryStatus, ["PASS","FAIL"])
    status = 'BLOCKED'; message = "Evidence status must be PASS or FAIL";
elseif strlength(strtrim(string(entry.VerifiedBy))) == 0
    status = 'BLOCKED'; message = "VerifiedBy must not be empty";
elseif ~valid_datetime(entry.VerifiedAt)
    status = 'BLOCKED'; message = "VerifiedAt must be a valid date and time";
elseif ~strcmp(char(string(entry.TargetFingerprint)), fingerprint)
    status = 'BLOCKED'; message = "Evidence target fingerprint is stale";
else
    paths = text_list(entry.EvidencePaths);
    missingFiles = false(numel(paths),1);
    for i = 1:numel(paths)
        candidate = paths{i};
        if ~isfile(candidate)
            candidate = fullfile(evidenceRoot, candidate);
        end
        missingFiles(i) = ~isfile(candidate);
    end
    if isempty(paths) || any(missingFiles)
        status = 'BLOCKED'; message = "Evidence file is missing";
    else
        status = char(entryStatus); message = "Manual evidence accepted";
    end
end
row = table(string(id), string(entryStatus), ...
    string(entry.VerifiedBy), string(entry.VerifiedAt), ...
    string(entry.TargetFingerprint), string(entry.Notes), ...
    string(strjoin(text_list(entry.EvidencePaths), ', ')), ...
    'VariableNames', {'CheckId','Status','VerifiedBy','VerifiedAt', ...
    'TargetFingerprint','Notes','EvidencePaths'});
end

function valid = valid_datetime(value)
valid = false;
if strlength(strtrim(string(value))) == 0, return; end
try
    parsed = datetime(string(value), 'TimeZone', 'local');
    valid = ~isnat(parsed);
catch
end
end

function T = empty_evidence_table()
T = table(strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'CheckId','Status','VerifiedBy','VerifiedAt', ...
    'TargetFingerprint','Notes','EvidencePaths'});
end

function row = empty_evidence_row(id)
row = table(string(id), "", "", "", "", "", "", ...
    'VariableNames', {'CheckId','Status','VerifiedBy','VerifiedAt', ...
    'TargetFingerprint','Notes','EvidencePaths'});
end

function values = split_ids(value)
value = strtrim(string(value));
if ismissing(value) || strlength(value) == 0
    values = strings(0,1);
else
    values = strtrim(split(value, ','));
    values = values(strlength(values) > 0);
end
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
