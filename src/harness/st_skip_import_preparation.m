function selection = st_skip_import_preparation(T, selection, cfg)
%ST_SKIP_IMPORT_PREPARATION Protect imported content even for direct stage calls.
mask = st_is_harness_import(T);
if any(mask & selection.Run)
    st_log(cfg, 'INFO', 'Generated preparation skipped for %d imported Harnesses', ...
        sum(mask & selection.Run));
end
selection.Run(mask) = false;
selection.Action(mask) = "SKIP";
selection.Reason(mask) = "HARNESS_IMPORT preserves copied test content";
end
