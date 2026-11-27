function added = st_apply_custom_code_include_dirs(model, cfg)
%ST_APPLY_CUSTOM_CODE_INCLUDE_DIRS Put this clone's C header folders on a Harness or standalone model.
%
% added = st_apply_custom_code_include_dirs(model, cfg)
%
% cfg.CustomCodeIncludeDirs (st_set_custom_code_include_dirs, kept per clone
% in runtime_target.mat) are absolute folders. They are added to the
% model's Simulation Target Include directories (SimUserIncludeDirs) unless
% already there, so a CUT whose C code needs a header outside the model
% folder builds from the toolkit's short build folder and from a standalone
% copy. The Top Model is never changed. The caller saves. added counts the
% folders added; a model whose setting cannot be changed (a referenced
% configuration set) keeps it and gets a WARN.
added = 0;
dirs = {};
if isfield(cfg, 'CustomCodeIncludeDirs'), dirs = cellstr(string(cfg.CustomCodeIncludeDirs)); end
dirs = dirs(~cellfun(@isempty, dirs));
if isempty(dirs), return; end
try
    [merged, added] = st_merge_include_dirs(get_param(model, 'SimUserIncludeDirs'), dirs);
    if added > 0, set_param(model, 'SimUserIncludeDirs', merged); end
    st_log(cfg, 'DEBUG', 'Custom code include folders | Model=%s | Added=%d of %d', ...
        model, added, numel(dirs));
catch ME
    added = 0;
    st_log(cfg, 'WARN', ['Custom code include folders not set | Model=%s | %s | ' ...
        'Set Include directories by hand'], model, ME.identifier);
end
end
