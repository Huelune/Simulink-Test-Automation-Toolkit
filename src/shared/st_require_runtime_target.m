function cfg = st_require_runtime_target()
%ST_REQUIRE_RUNTIME_TARGET Validate and load the selected runtime model.
%
% The target model can be selected by st_select_target_model,
% st_export_subsystem_paths, or st_find_target_paths and is stored in
% runtime_target.mat.

cfg = st_config();

if ~cfg.HasRuntimeTarget

    error( ...
        ['Target model is not selected. ' ...
         'Run st_select_target_model first.']);
end

if ~isfile(cfg.ModelFile)

    error( ...
        'Selected model file does not exist: %s', ...
        cfg.ModelFile);
end

if ~bdIsLoaded(cfg.TopModel)

    load_system(cfg.ModelFile);
end

end
