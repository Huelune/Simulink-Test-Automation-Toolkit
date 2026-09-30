function cleanup = st_enter_short_build_directory(cfg, label)
%ST_ENTER_SHORT_BUILD_DIRECTORY Build and simulate from a short folder.
%
% Simulink builds slprj/ in pwd, and Stateflow simulation targets add
% slprj/_sfprj/<Harness>/_self/sfun/... below it. From a deep model folder
% that passes the Windows 260-character limit, the build fails and the Test
% Case records no coverage. Until the returned onCleanup is cleared, pwd,
% CacheFolder, and CodeGenFolder point at a short folder under
% cfg.StandaloneBuildCacheDir (empty: tempdir/stt_build). The caller's
% folder and the model folder go on the MATLAB path so files that were
% found through pwd still resolve. A caller already running inside that
% short base (the standalone bundle runner) is left as it is.

if nargin < 2 || strlength(strtrim(string(label))) == 0
    label = 'BUILD';
end
label = char(string(label));
base = st_short_build_base(cfg);
previousDirectory = pwd;
if is_under_root(previousDirectory, base)
    st_log(cfg, 'DEBUG', ...
        'Short build directory already active | Label=%s | Folder=%s', ...
        label, previousDirectory);
    cleanup = onCleanup(@() []);
    return;
end

[~, token] = fileparts(tempname);
folder = fullfile(base, [lower(label) '_' token(end-7:end)]);
[created, message] = mkdir(folder);
if ~created
    st_log(cfg, 'ERROR', ...
        'Short build directory unavailable | Label=%s | %s | %s', ...
        label, folder, message);
    error('simtest:ShortBuildDirectoryUnavailable', ...
        'Cannot create the short build folder %s: %s', folder, message);
end

previousPath = path;
previousConfig = Simulink.fileGenControl('getConfig');
try
    addpath(previousDirectory, '-begin');
    if isfield(cfg, 'ModelFile') && ~isempty(char(string(cfg.ModelFile)))
        modelFolder = fileparts(char(string(cfg.ModelFile)));
        if isfolder(modelFolder)
            addpath(modelFolder, '-begin');
        end
    end
    cd(folder);
    Simulink.fileGenControl('set', ...
        'CacheFolder', folder, 'CodeGenFolder', folder);
catch ME
    leave_short_build_directory(previousDirectory, previousPath, ...
        previousConfig, folder, label, cfg);
    rethrow(ME);
end
st_log(cfg, 'INFO', ...
    'Short build directory enter | Label=%s | Folder=%s | Length=%d | From=%s', ...
    label, folder, strlength(folder), previousDirectory);
cleanup = onCleanup(@() leave_short_build_directory(previousDirectory, ...
    previousPath, previousConfig, folder, label, cfg));
end

function leave_short_build_directory(previousDirectory, previousPath, ...
        previousConfig, folder, label, cfg)
try
    cd(previousDirectory);
catch ME
    st_log(cfg, 'WARN', ...
        'Short build directory could not return to %s | %s: %s', ...
        previousDirectory, ME.identifier, ME.message);
end
% A captured config object can be rejected once its folders are gone, so
% fall back to the explicit folders and finally to the factory default
% rather than leave later builds pointed at the folder deleted below.
attempts = { ...
    @() Simulink.fileGenControl('set', 'config', previousConfig), ...
    @() Simulink.fileGenControl('set', ...
        'CacheFolder', previousConfig.CacheFolder, ...
        'CodeGenFolder', previousConfig.CodeGenFolder), ...
    @() Simulink.fileGenControl('reset')};
for i = 1:numel(attempts)
    try
        attempts{i}();
        if i == numel(attempts)
            st_log(cfg, 'WARN', ...
                'Short build directory restore fell back to reset | Label=%s', ...
                label);
        end
        break;
    catch ME
        st_log(cfg, 'DEBUG', ...
            'Short build directory restore attempt %d failed | %s: %s', ...
            i, ME.identifier, ME.message);
    end
end
path(previousPath);
try
    if isfolder(folder), rmdir(folder, 's'); end
catch ME
    st_log(cfg, 'WARN', ...
        'Short build directory removal failed | %s | %s: %s', ...
        folder, ME.identifier, ME.message);
end
st_log(cfg, 'INFO', ...
    'Short build directory leave | Label=%s | To=%s', label, previousDirectory);
end

function tf = is_under_root(candidate, root)
candidate = strrep(char(candidate), '/', filesep);
root = strrep(char(root), '/', filesep);
if ~isempty(root) && root(end) == filesep
    root(end) = [];
end
if ispc
    candidate = lower(candidate);
    root = lower(root);
end
tf = strcmp(candidate, root) || startsWith(candidate, [root filesep]);
end
