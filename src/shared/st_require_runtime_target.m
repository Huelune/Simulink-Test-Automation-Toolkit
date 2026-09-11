function cfg = st_require_runtime_target(varargin)
%ST_REQUIRE_RUNTIME_TARGET Validate the selected runtime target.
%
% The target model can be selected by st_select_target_model,
% st_export_subsystem_paths, or st_find_target_paths and is stored in
% runtime_target.mat.
%
% By default the selected model is loaded for backward compatibility.
% Call st_require_runtime_target('LoadModel', false) when a caller only
% needs the validated paths and must keep the source model unloaded, such
% as a standalone replay that will load an isolated copy with the same
% model name.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'LoadModel', true, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

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

if p.Results.LoadModel && ~bdIsLoaded(cfg.TopModel)

    load_system(cfg.ModelFile);
end

end
