function st_export_import_profiles(T,cfg,templateRoot,inventory)
%ST_EXPORT_IMPORT_PROFILES Include portable prepared imports without source dependency.
for i = find(st_is_harness_import(T)).'
    st_log(cfg,'DEBUG','Import profile export start | CUT=%s',T.CUTPath(i));
    st_get_test_profile(T(i,:),cfg); % Require a verified, available input.
    originalPath = st_harness_import_file(T(i,:),cfg);
    data = load(originalPath,'manifest');
    manifest = data.manifest;
    match = find(strcmp({inventory.HarnessName},char(T.HarnessName(i))) & ...
        strcmp({inventory.CUTPath},manifest.Owner));
    if numel(match) ~= 1
        error('simtest:ImportExportMapping','Expected one exported target for import.');
    end
    inputPath = inventory(match).SignalEditorInput;
    manifest.Profile.SignalEditorDataFile = char(inputPath);
    manifest.Portable = true;
    destinationCfg = cfg;
    destinationCfg.ResultDir = fullfile(templateRoot,'result');
    path = st_harness_import_file(T(i,:),destinationCfg);
    if ~isfolder(fileparts(path)), mkdir(fileparts(path)); end
    save(path,'manifest');
    st_log(cfg,'DEBUG','Import profile export end | CUT=%s',T.CUTPath(i));
end
end
