function profile = st_get_test_profile(row, cfg)
%ST_GET_TEST_PROFILE Resolve generated or imported tests without SLDV coupling.
if ~st_is_harness_import(row)
    profile = st_get_sldv_profile(row, cfg);
    return;
end
path = st_harness_import_file(row, cfg);
if ~isfile(path)
    error('simtest:ImportNotPrepared', 'Run st_import_harness_contents first: %s', path);
end
data = load(path, 'manifest');
m = data.manifest;
if m.Version ~= 1 || ~strcmp(m.Owner, ...
        st_normalize_cut_path(row.CUTPath, cfg.TopModel)) || ...
        ~strcmp(m.Harness, char(row.HarnessName)) || ...
        ~strcmp(m.SourceOwner, st_normalize_cut_path(row.SourceCUTPath, cfg.TopModel)) || ...
        ~strcmp(m.SourceHarness, char(row.SourceHarnessName))
    error('simtest:ImportManifestMismatch', 'Import mapping changed; import again.');
end
profile = m.Profile;
profile.No = double(row.No);
profile.CUTName = char(row.CUTName);
profile.CUTPath = m.Owner;
profile.HarnessName = m.Harness;
profile.TestCaseName = char(row.TestCaseName);
if profile.HasSignalEditor
    sig = st_file_signature(profile.SignalEditorDataFile);
    if ~sig.Exists || ~strcmp(sig.SHA256, m.InputSHA256)
        error('simtest:ImportInputChanged', 'Imported input missing/changed; import again.');
    end
end
end
