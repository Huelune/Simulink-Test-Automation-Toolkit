function cfg = st_select_model_profile(name)
%ST_SELECT_MODEL_PROFILE Select by name, list dialog, or '' for legacy paths.
logCfg = struct('VerboseLogging', true);
st_log(logCfg, 'INFO', 'Model profile selection start');
try
    store = st_model_profile_store();
    names = {};
    if ~isempty(store.Profiles), names = {store.Profiles.Name}; end
    if nargin == 0
        [index, ok] = listdlg('ListString', [{'[Legacy settings]'}, names], ...
            'SelectionMode','single','Name','Model Profile');
        if ~ok
            st_log(logCfg, 'WARN', 'Model profile selection cancelled; settings unchanged');
            cfg = st_config(); return;
        end
        if index == 1, name = ''; else, name = names{index-1}; end
    end
    name = strtrim(char(string(name)));
    if ~isempty(name)
        index = find(strcmpi(names, name));
        if numel(index) ~= 1
            error('simtest:ModelProfileMissing', 'Unknown profile: %s', name);
        end
        profile = store.Profiles(index);
        name = profile.Name;
        if ~isfile(profile.ModelFile) || ~isfile(profile.ManagementExcel)
            error('simtest:ModelProfileInputMissing', 'Model or Excel is missing for %s.', name);
        end
        [~, model] = fileparts(profile.ModelFile);
        if exist('bdIsLoaded','file') && bdIsLoaded(model) && ...
                ~st_same_path(get_param(model,'FileName'), profile.ModelFile)
            error('simtest:ModelProfileIsolation', 'A different model named %s is loaded.', model);
        end
    end
    st_save_runtime_target_fields(fullfile(st_project_root(),'runtime_target.mat'), ...
        struct('ActiveModelProfile', name));
    cfg = st_config();
    st_log(logCfg, 'INFO', 'Model profile selection complete | Name=%s', name);
catch ME
    st_log(logCfg, 'ERROR', 'Model profile selection failed | %s: %s', ME.identifier, ME.message);
    rethrow(ME);
end
end
