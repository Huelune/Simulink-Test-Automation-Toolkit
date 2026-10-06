function rootDir = st_default_standalone_coverage_root(cfg)
%ST_DEFAULT_STANDALONE_COVERAGE_ROOT D:\model_result\<TopModel>.
% A short root on its own drive keeps the standalone pipeline's nested
% folders under the Windows path limit, and one folder per Top Model keeps
% different models' pipelines apart.
if ~isfield(cfg, 'TopModel') || isempty(strtrim(char(string(cfg.TopModel))))
    error('simtest:StandaloneCoverageRootNoTarget', ...
        ['Select a Top Model with st_select_target_model first, or pass ' ...
         'a root: st_set_standalone_coverage_root(''%s'').'], 'D:\st_out');
end
rootDir = fullfile('D:\', 'model_result', strtrim(char(string(cfg.TopModel))));
end
