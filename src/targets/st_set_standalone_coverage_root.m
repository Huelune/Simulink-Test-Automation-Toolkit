function cfg = st_set_standalone_coverage_root(rootDir)
%ST_SET_STANDALONE_COVERAGE_ROOT Set a local override for the standalone
% coverage pipeline's output root.
%
%   st_set_standalone_coverage_root
%   st_set_standalone_coverage_root('D:\stt_work')
%
% Without an argument the root is D:\model_result\<TopModel> for the Top
% Model chosen with st_select_target_model, created if missing. Pass a
% path to use that instead.
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

cfg = st_config();

useDefault = nargin < 1;
if useDefault
    rootDir = st_default_standalone_coverage_root(cfg);
    st_log(cfg, 'INFO', ...
        'Standalone coverage root default chosen | TopModel=%s | Root=%s', ...
        cfg.TopModel, rootDir);
end

rootDir = strtrim(char(string(rootDir)));

if ~isempty(rootDir)

    parentDir = fileparts(rootDir);
    if useDefault && ~isempty(parentDir) && ~isfolder(parentDir)
        [created, message] = mkdir(parentDir);
        if ~created
            st_log(cfg, 'ERROR', ...
                'Standalone coverage default root unavailable | %s | %s', ...
                parentDir, message);
            error('simtest:StandaloneCoverageRootUnavailable', ...
                ['Cannot create %s: %s. Pass a root explicitly, for ' ...
                 'example st_set_standalone_coverage_root(''%s'').'], ...
                parentDir, message, 'C:\st_out');
        end
    end

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
