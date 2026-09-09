function profiles = st_merge_scoped_sldv_profiles(profiles, cfg)
%ST_MERGE_SCOPED_SLDV_PROFILES Keep other targets during one-target clone prep.
if ~st_target_scope('active') || ~isfile(cfg.SldvManifestFile), return; end
loaded = load(cfg.SldvManifestFile,'manifest');
if ~isfield(loaded,'manifest') || ...
        ~strcmp(loaded.manifest.TopModel,cfg.TopModel), return; end
previous = loaded.manifest.Profiles;
keep = true(numel(previous),1);
for i = 1:numel(profiles)
    for j = 1:numel(previous)
        if strcmp(previous(j).CUTPath,profiles(i).CUTPath) && ...
                strcmp(previous(j).HarnessName,profiles(i).HarnessName)
            keep(j) = false;
        end
    end
end
previous = previous(keep);
profiles = [previous(:); profiles(:)];
end
