function store = st_model_profile_store(varargin)
%ST_MODEL_PROFILE_STORE Read/write local profiles; corruption never falls back.
path = fullfile(st_project_root(), 'model_profiles.mat');
if nargin
    store = varargin{1};
    st_atomic_save(path, struct('store', store));
    return;
end
store = struct('Version', 1, 'Profiles', struct([]));
if ~isfile(path), return; end
data = load(path, 'store');
if ~isfield(data, 'store') || ~isstruct(data.store) || ...
        ~isscalar(data.store) || ~isfield(data.store, 'Version') || ...
        data.store.Version ~= 1 || ~isfield(data.store, 'Profiles') || ...
        ~isstruct(data.store.Profiles)
    error('simtest:ModelProfilesInvalid', 'Invalid profile store: %s', path);
end
store = data.store;
if ~isempty(store.Profiles)
    required = {'Name','ModelFile','ManagementExcel','ManagementSheet','TestFile', ...
        'TestSuiteName','OutputRoot','StandaloneCoverageRootDir'};
    if ~all(isfield(store.Profiles,required)) || ...
            numel(unique(lower(string({store.Profiles.Name})))) ~= numel(store.Profiles)
        error('simtest:ModelProfilesInvalid','Profile fields/names are invalid: %s',path);
    end
    for i = 1:numel(store.Profiles)
        for k = 1:numel(required)
            value = store.Profiles(i).(required{k});
            if ~((ischar(value) && isrow(value)) || (isstring(value) && isscalar(value))) || ...
                    ismissing(string(value)) || strlength(strtrim(string(value))) == 0
                error('simtest:ModelProfilesInvalid','Invalid profile field %s in %s.',required{k},path);
            end
        end
    end
end
end
