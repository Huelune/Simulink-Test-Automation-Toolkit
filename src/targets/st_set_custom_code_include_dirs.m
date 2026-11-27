function dirs = st_set_custom_code_include_dirs(folder)
%ST_SET_CUSTOM_CODE_INCLUDE_DIRS Keep the folders of this model's C headers for the toolkit.
%
%   st_set_custom_code_include_dirs            % choose a folder in a dialog; adds it
%   st_set_custom_code_include_dirs(folder)    % adds that folder
%   st_set_custom_code_include_dirs('')        % forgets every folder
%
% A CUT whose C code (C Caller, C Function, custom code in Stateflow or a
% MATLAB Function) includes a header outside the model folder fails its
% simulation build in the toolkit's short build folder: Simulink looks in
% the working folder, the model folder, then the model's Include
% directories. The folders kept here go into the Include directories of
% every Harness the toolkit configures (step 1, HARNESS_CONFIG) and of every
% standalone copy it exports (step 3), as absolute paths. The Top Model is
% not changed. They are kept per clone in runtime_target.mat (local,
% untracked), like the model choice. Harnesses made before must be
% configured again (st_run_from_harness with PreparationMode FORCE, or a
% rebuild). Prints counts only, since paths name the project.
cfg = st_config();
dirs = cellstr(string(cfg.CustomCodeIncludeDirs));
dirs = dirs(~cellfun(@isempty, dirs));
if nargin < 1
    start = pwd;
    if isfield(cfg, 'ModelFile') && isfile(cfg.ModelFile), start = fileparts(cfg.ModelFile); end
    folder = uigetdir(start, 'C 헤더(.h)가 있는 폴더를 고르세요');
    if isequal(folder, 0)
        fprintf('C 헤더 폴더 | 고르지 않음 | 저장된 폴더 %d개 그대로\n', numel(dirs));
        return;
    end
end
folder = strtrim(char(string(folder)));
if isempty(folder)
    dirs = {};
    st_log(cfg, 'INFO', 'Custom code include folders cleared');
else
    if ~isfolder(folder)
        error('simtest:CustomCodeIncludeDirMissing', 'The chosen folder does not exist.');
    end
    folder = char(java.io.File(folder).getCanonicalPath());
    if ~any(strcmpi(dirs, folder)), dirs{end+1} = folder; end
    st_log(cfg, 'INFO', 'Custom code include folder kept | %s | Folders=%d', folder, numel(dirs));
end
st_save_runtime_target_fields(cfg.RuntimeTargetFile, ...
    struct('CustomCodeIncludeDirs', {dirs}));
fprintf('C 헤더 폴더 | 저장된 폴더 %d개 | 없는 폴더 %d개\n', numel(dirs), ...
    sum(~cellfun(@isfolder, dirs)));
end
