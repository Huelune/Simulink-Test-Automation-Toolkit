function profiles = st_list_model_profiles()
%ST_LIST_MODEL_PROFILES List saved local paths without loading models.
cfg = struct('VerboseLogging', true);
st_log(cfg, 'INFO', 'Model profile list start');
try
    store = st_model_profile_store();
    profiles = struct2table(store.Profiles);
    if nargout == 0, disp(profiles); end
    st_log(cfg, 'INFO', 'Model profile list complete | Count=%d', height(profiles));
catch ME
    st_log(cfg, 'ERROR', 'Model profile list failed | %s', ME.message);
    rethrow(ME);
end
end
