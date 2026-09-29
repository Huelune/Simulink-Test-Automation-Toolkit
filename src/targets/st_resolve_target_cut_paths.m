function targets = st_resolve_target_cut_paths(targets, cfg)
%ST_RESOLVE_TARGET_CUT_PATHS Give every target row its full Simulink CUT path.
% The workbook may write CUTPath relative to the Top Model. Coverage objects
% name the CUT by its full path (ownerBlock), so a relative CUTPath matches
% no coverage object and every report built from it fails. Paths that are
% already full are returned unchanged.
if isempty(targets) || ~ismember('CUTPath', targets.Properties.VariableNames)
    return;
end
original = string(targets.CUTPath);
resolved = original;
for i = 1:numel(original)
    resolved(i) = string(st_normalize_cut_path(original(i), cfg.TopModel));
end
changed = sum(resolved ~= original);
targets.CUTPath = resolved;
if changed > 0
    st_log(cfg, 'DEBUG', ...
        'Target CUT paths resolved against Top Model | Model=%s | Changed=%d/%d', ...
        cfg.TopModel, changed, numel(original));
end
end
