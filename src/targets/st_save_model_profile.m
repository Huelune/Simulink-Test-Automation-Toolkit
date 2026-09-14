function profile = st_save_model_profile(name, varargin)
%ST_SAVE_MODEL_PROFILE Save local paths; does not activate or load a model.
cfg = struct('VerboseLogging', true);
st_log(cfg, 'INFO', 'Model profile save start | Name=%s', char(string(name)));
try
    p = inputParser;
    addRequired(p, 'Name', @(v) ischar(v) || (isstring(v) && isscalar(v)));
    fields = {'ModelFile','ManagementExcel','OutputRoot','TestFile', ...
        'StandaloneCoverageRootDir'};
    for i = 1:numel(fields), addParameter(p, fields{i}, ''); end
    addParameter(p, 'ManagementSheet', 'Targets');
    addParameter(p, 'TestSuiteName', 'New Test Suite 1');
    addParameter(p, 'Overwrite', false, @(v) islogical(v) && isscalar(v));
    parse(p, name, varargin{:});
    profile = rmfield(p.Results, 'Overwrite');
    profile.Name = strtrim(char(string(name)));
    if isempty(profile.Name)
        error('simtest:ModelProfileNameRequired', 'Profile name must not be empty.');
    end
    for field = {'ModelFile','ManagementExcel','OutputRoot'}
        profile.(field{1}) = st_absolute_path(profile.(field{1}));
    end
    if ~isfile(profile.ModelFile) || ~isfile(profile.ManagementExcel)
        error('simtest:ModelProfileInputMissing', 'Model and management Excel must exist.');
    end
    [~, model, extension] = fileparts(profile.ModelFile);
    if ~ismember(lower(extension), {'.slx','.mdl'})
        error('simtest:ModelProfileModelInvalid', 'Select a .slx or .mdl model.');
    end
    if strlength(string(profile.TestFile)) == 0
        profile.TestFile = fullfile(profile.OutputRoot, [model '.mldatx']);
    end
    if strlength(string(profile.StandaloneCoverageRootDir)) == 0
        profile.StandaloneCoverageRootDir = fullfile(profile.OutputRoot, 'standalone_coverage');
    end
    for field = {'TestFile','StandaloneCoverageRootDir'}
        profile.(field{1}) = st_absolute_path(profile.(field{1}));
    end
    for field = {'ManagementSheet','TestSuiteName'}
        profile.(field{1}) = char(string(profile.(field{1})));
        if isempty(strtrim(profile.(field{1})))
            error('simtest:ModelProfileFieldRequired', '%s is required.', field{1});
        end
    end
    store = st_model_profile_store();
    index = [];
    if ~isempty(store.Profiles), index = find(strcmpi({store.Profiles.Name}, profile.Name)); end
    if ~isempty(index) && ~p.Results.Overwrite
        error('simtest:ModelProfileExists', 'Use Overwrite=true to replace %s.', profile.Name);
    end
    % Shared result/state roots would defeat model isolation.
    for i = setdiff(1:numel(store.Profiles), index)
        other = store.Profiles(i);
        roots = {profile.OutputRoot,profile.StandaloneCoverageRootDir};
        priorRoots = {other.OutputRoot,other.StandaloneCoverageRootDir};
        conflict = st_same_path(other.TestFile,profile.TestFile);
        for a = 1:2
            for b = 1:2
                left = [lower(st_absolute_path(roots{a})) filesep];
                right = [lower(st_absolute_path(priorRoots{b})) filesep];
                conflict = conflict || startsWith(left,right) || startsWith(right,left);
            end
        end
        if conflict
            error('simtest:ModelProfileOutputConflict', 'Output root is already owned by %s.', other.Name);
        end
    end
    if isempty(store.Profiles)
        store.Profiles = profile;
    elseif isempty(index)
        store.Profiles(end+1) = profile;
    else
        store.Profiles(index) = profile;
    end
    st_model_profile_store(store);
    st_log(cfg, 'INFO', 'Model profile save complete | Name=%s', profile.Name);
catch ME
    st_log(cfg, 'ERROR', 'Model profile save failed | %s: %s', ME.identifier, ME.message);
    rethrow(ME);
end
end
