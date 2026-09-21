function profile = st_get_sldv_profile(targetRow, cfg)
%ST_GET_SLDV_PROFILE Return the prepared SLDV runtime profile for one row.

if nargin < 2
    cfg = st_config();
end

mode = upper(strtrim(char(targetRow.SldvMode)));
if isempty(mode)
    mode = 'OFF';
end
dataFileFormat = target_text(targetRow, 'DataFileFormat', 'SLDV');
matVariableName = target_text(targetRow, 'MatVariableName', '');
if ~strcmp(mode, 'FILE')
    dataFileFormat = 'SLDV';
    matVariableName = '';
else
    dataFileFormat = char(st_resolve_data_file_formats( ...
        string(mode), string(dataFileFormat)));
    if ~strcmp(dataFileFormat, 'MAT'), matVariableName = ''; end
end

if strcmp(mode, 'OFF')
    profile = st_empty_sldv_profile();
    profile.No = double(targetRow.No);
    profile.CUTName = char(targetRow.CUTName);
    profile.CUTPath = st_normalize_cut_path( ...
        targetRow.CUTPath, cfg.TopModel);
    profile.HarnessName = char(targetRow.HarnessName);
    profile.TestCaseName = char(targetRow.TestCaseName);
    profile.Mode = 'OFF';
    profile.DataFileFormat = 'SLDV';
    profile.MatVariableName = '';
    profile.RequestedDataFile = char(targetRow.SldvDataFile);
    profile.SourceDataFile = char(targetRow.SldvDataFile);
    profile.ScenarioNames = {st_scenario_name(targetRow.CUTName, 1)};
    profile.SourceIndices = [];
    profile.EndTimes = [];
    profile.Tmax = NaN;
    profile.ParameterCounts = 0;
    profile.EffectiveDataFile = '';
    profile.SignalEditorDataFile = '';
    profile.AtomicAction = 'NOT_APPLICABLE';
    profile.Status = 'OK';
    profile.Message = 'Legacy single-scenario workflow';
    return;
end

if ~isfile(cfg.SldvManifestFile)
    error(['SLDV manifest is missing. Run st_prepare_sldv_targets before ' ...
        'the configuration stages: %s'], cfg.SldvManifestFile);
end

loaded = load(cfg.SldvManifestFile, 'manifest');
if ~isfield(loaded, 'manifest') || ...
        ~strcmp(char(loaded.manifest.TopModel), char(cfg.TopModel))
    error('SLDV manifest is invalid or belongs to another TopModel.');
end

ownerPath = st_normalize_cut_path(targetRow.CUTPath, cfg.TopModel);
profiles = loaded.manifest.Profiles;
matched = false;
for i = 1:numel(profiles)
    requestedFileMatches = ~strcmp(mode, 'FILE') || ...
        (isfield(profiles, 'RequestedDataFile') && ...
        strcmp(profiles(i).RequestedDataFile, char(targetRow.SldvDataFile)));
    profileFormat = profile_text(profiles(i), 'DataFileFormat', 'SLDV');
    profileVariable = profile_text(profiles(i), 'MatVariableName', '');
    sourceFormatMatches = ~strcmp(mode, 'FILE') || ...
        (strcmpi(profileFormat, dataFileFormat) && ...
        strcmp(profileVariable, matVariableName));
    if double(profiles(i).No) == double(targetRow.No) && ...
            strcmp(profiles(i).CUTName, char(targetRow.CUTName)) && ...
            strcmp(profiles(i).CUTPath, ownerPath) && ...
            strcmp(profiles(i).HarnessName, char(targetRow.HarnessName)) && ...
            strcmp(profiles(i).TestCaseName, char(targetRow.TestCaseName)) && ...
            strcmp(profiles(i).Mode, mode) && ...
            requestedFileMatches && sourceFormatMatches
        profile = profiles(i);
        matched = true;
        break;
    end
end

if ~matched
    target = struct( ...
        'No', double(targetRow.No), ...
        'CUTName', char(targetRow.CUTName), ...
        'CUTPath', ownerPath, ...
        'HarnessName', char(targetRow.HarnessName), ...
        'TestCaseName', char(targetRow.TestCaseName), ...
        'Mode', mode, ...
        'DataFileFormat', dataFileFormat, ...
        'MatVariableName', matVariableName, ...
        'RequestedDataFile', char(targetRow.SldvDataFile));
    error('simtest:SldvManifestRowMissing', '%s', ...
        describe_missing_profile(target, profiles, cfg.SldvManifestFile));
end
profile = st_normalize_sldv_profile_schema(profile);
% Older incremental runs could persist the reporting-only CACHED state in
% the runtime manifest. Treat it as a successful reusable profile and
% normalize it so the next manifest write repairs the stored state.
if strcmp(profile.Status, 'CACHED')
    profile.Status = 'OK';
elseif ~strcmp(profile.Status, 'OK')
    error('SLDV target preparation was not successful: %s', profile.Message);
end
if isempty(profile.EffectiveDataFile) || ~isfile(profile.EffectiveDataFile)
    error('Prepared FILE/SLDV data file is missing: %s', ...
        profile.EffectiveDataFile);
end
end


function value = target_text(row, field, fallback)
value = fallback;
if ismember(field, row.Properties.VariableNames)
    candidate = string(row.(field));
    if isscalar(candidate) && ~ismissing(candidate)
        value = char(strtrim(candidate));
    end
end
end


function text = describe_missing_profile(target, profiles, manifestFile)
%DESCRIBE_MISSING_PROFILE Name the nearest manifest rows and how they differ.
% A bare "no matching row" leaves the operator guessing whether the Excel
% row was renamed, renumbered, switched mode, or simply never prepared
% (for example it was Enabled=false when st_prepare_sldv_targets last ran).
lines = {sprintf(['No matching target row exists in the SLDV manifest. ' ...
    'Target: No=%g | CUT=%s | Harness=%s | TestCase=%s | SldvMode=%s'], ...
    target.No, target.CUTName, target.HarnessName, ...
    target.TestCaseName, target.Mode)};
lines{end+1} = sprintf('Manifest: %s (%d rows)', ...
    manifestFile, numel(profiles));
compared = {'CUTName','CUTPath','HarnessName','TestCaseName','Mode'};
if strcmp(target.Mode, 'FILE')
    compared = [compared, ...
        {'RequestedDataFile','DataFileFormat','MatVariableName'}];
end
shown = 0;
for i = 1:numel(profiles)
    candidate = profiles(i);
    sameNo = double(candidate.No) == target.No;
    sameHarness = strcmp(profile_text(candidate, 'CUTName', ''), ...
        target.CUTName) && strcmp( ...
        profile_text(candidate, 'HarnessName', ''), target.HarnessName);
    sameCase = strcmp(profile_text(candidate, 'TestCaseName', ''), ...
        target.TestCaseName);
    if ~(sameNo || sameHarness || sameCase), continue; end
    differences = {};
    if ~sameNo
        differences{end+1} = sprintf('No: manifest=%g, Excel=%g', ...
            double(candidate.No), target.No); %#ok<AGROW>
    end
    for k = 1:numel(compared)
        name = compared{k};
        value = profile_text(candidate, name, '');
        if ~strcmp(value, target.(name))
            differences{end+1} = sprintf('%s: manifest=%s, Excel=%s', ...
                name, value, target.(name)); %#ok<AGROW>
        end
    end
    if isempty(differences)
        differences = {'no compared field differs (manifest row malformed)'};
    end
    lines{end+1} = sprintf('  Closest manifest row %d: %s', ...
        i, strjoin(differences, ' | ')); %#ok<AGROW>
    shown = shown + 1;
    if shown == 3, break; end
end
if shown == 0
    lines{end+1} = ['  No manifest row shares this No, CUT/Harness, or ' ...
        'Test Case: the row was never prepared (it was probably ' ...
        'Enabled=false when the manifest was written).'];
end
lines{end+1} = ['Fix: run st_prepare_sldv_targets with this row enabled ' ...
    '(or st_run_from_harness(''PreparationMode'',''FORCE'',' ...
    '''FromStage'',''SLDV'')) so sldv_manifest.mat covers it, then retry.'];
text = strjoin(lines, newline);
end


function value = profile_text(profile, field, fallback)
value = fallback;
if isfield(profile, field)
    candidate = string(profile.(field));
    if isscalar(candidate) && ~ismissing(candidate)
        value = char(strtrim(candidate));
    end
end
end
