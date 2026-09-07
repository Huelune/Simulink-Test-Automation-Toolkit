function path = st_harness_import_file(row, cfg)
%ST_HARNESS_IMPORT_FILE Stable per-owner manifest; TestCase names may change.
identity = struct('Owner', st_normalize_cut_path(row.CUTPath, cfg.TopModel), ...
    'Harness', char(row.HarnessName));
path = fullfile(cfg.ResultDir, 'harness_import', 'manifests', ...
    [st_hash_value(identity) '.mat']);
end
