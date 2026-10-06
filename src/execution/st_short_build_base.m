function base = st_short_build_base(cfg)
%ST_SHORT_BUILD_BASE Short folder that holds build and scratch folders.
% cfg.StandaloneBuildCacheDir when set, otherwise tempdir/stt_build. Kept
% short so Simulink, Stateflow, and SLDV output below it stays inside the
% Windows 260-character path limit.
base = '';
if isfield(cfg, 'StandaloneBuildCacheDir')
    base = strtrim(char(string(cfg.StandaloneBuildCacheDir)));
end
if isempty(base)
    base = fullfile(tempdir, 'stt_build');
end
end
