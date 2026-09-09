function profile = st_get_sldv_profile(targetRow, cfg)
%ST_GET_SLDV_PROFILE Return the prepared SLDV runtime profile for one row.

if nargin < 2
    cfg = st_config();
end

mode = upper(strtrim(char(targetRow.SldvMode)));
if isempty(mode)
    mode = 'OFF';
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
    if double(profiles(i).No) == double(targetRow.No) && ...
            strcmp(profiles(i).CUTName, char(targetRow.CUTName)) && ...
            strcmp(profiles(i).CUTPath, ownerPath) && ...
            strcmp(profiles(i).HarnessName, char(targetRow.HarnessName)) && ...
            strcmp(profiles(i).TestCaseName, char(targetRow.TestCaseName)) && ...
            strcmp(profiles(i).Mode, mode) && ...
            requestedFileMatches
        profile = profiles(i);
        matched = true;
        break;
    end
end

if ~matched
    error('No matching target row exists in the SLDV manifest.');
end
profile = normalize_profile_schema(profile);
% Older incremental runs could persist the reporting-only CACHED state in
% the runtime manifest. Treat it as a successful reusable profile and
% normalize it so the next manifest write repairs the stored state.
if strcmp(profile.Status, 'CACHED')
    profile.Status = 'OK';
elseif ~strcmp(profile.Status, 'OK')
    error('SLDV target preparation was not successful: %s', profile.Message);
end
if isempty(profile.EffectiveDataFile) || ~isfile(profile.EffectiveDataFile)
    error('Prepared SLDV data file is missing: %s', profile.EffectiveDataFile);
end
end


function normalized = normalize_profile_schema(profile)
normalized = st_empty_sldv_profile();
fields = fieldnames(normalized);
for i = 1:numel(fields)
    field = fields{i};
    if isfield(profile, field)
        normalized.(field) = profile.(field);
    end
end
end
