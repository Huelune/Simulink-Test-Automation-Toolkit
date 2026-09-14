function cfg = st_set_standalone_coverage_root(rootDir)
%ST_SET_STANDALONE_COVERAGE_ROOT Set a local override for the standalone
% coverage pipeline's output root.
%
%   st_set_standalone_coverage_root('D:\stt_work')
%
% The standalone coverage pipeline (st_run_standalone_coverage_pipeline)
% nests exported Harness models several folders deep
% (template/workspace/standalone/{CUTName}/...). Combined with a deeply
% nested repository checkout, this can exceed the Windows 260-character
% MAX_PATH limit (MATLAB:cd:DirectoryNameTooLong). Pointing the pipeline's
% output root at a short path fixes this without changing the exported
% bundle's documented folder structure.
%
% The override is saved to the local, untracked runtime_target.mat (the
% same file st_select_target_model uses) so it is specific to this
% machine and does not affect the repository default in st_config.m.
%
% Pass an empty value to clear a previously saved override and go back to
% the tracked default (result/standalone_coverage under the repository).
%
%   st_set_standalone_coverage_root('')

if nargin < 1
    error('Usage: st_set_standalone_coverage_root(rootDir)');
end

rootDir = strtrim(char(string(rootDir)));

cfg = st_config();

if ~isempty(rootDir)

    parentDir = fileparts(rootDir);

    if ~isempty(parentDir) && ~isfolder(parentDir)
        error( ...
            'Parent folder does not exist: %s', ...
            parentDir);
    end

    if ~isfolder(rootDir)
        mkdir(rootDir);
    end

    rootDir = char( ...
        java.io.File(rootDir).getCanonicalPath());
end

StandaloneCoverageRootDir = rootDir; %#ok<NASGU>

if ~isempty(cfg.ActiveModelProfile)
    store = st_model_profile_store();
    index = find(strcmp({store.Profiles.Name}, cfg.ActiveModelProfile), 1);
    profile = store.Profiles(index);
    if isempty(rootDir), rootDir = fullfile(profile.OutputRoot, 'standalone_coverage'); end
    profile.StandaloneCoverageRootDir = rootDir;
    values = rmfield(profile, 'Name');
    args = reshape([fieldnames(values), struct2cell(values)]', 1, []);
    st_save_model_profile(profile.Name, args{:}, 'Overwrite', true);
    cfg = st_config();
    return;
end

st_save_runtime_target_fields( ...
    cfg.RuntimeTargetFile, ...
    struct( ...
        'StandaloneCoverageRootDir', StandaloneCoverageRootDir));

cfg = st_config();

fprintf('\n');
fprintf('============================================\n');

if isempty(rootDir)
    fprintf('Standalone coverage root override cleared\n');
    fprintf('Using tracked default: %s\n', cfg.StandaloneCoverageRootDir);
else
    fprintf('Standalone coverage root override set\n');
    fprintf('Root : %s\n', cfg.StandaloneCoverageRootDir);
end

fprintf('============================================\n');

end
