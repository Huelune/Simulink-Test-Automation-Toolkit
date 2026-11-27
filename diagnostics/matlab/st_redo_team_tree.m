function line = st_redo_team_tree()
%ST_REDO_TEAM_TREE Make the team tree of the latest standalone run again, quietly.
%
% line = st_redo_team_tree()
%
% A tree classified before the saved Test Manager result went into it has
% no result to open (st_show_team_tree_results). This makes the tree of
% the latest standalone run again (it replaces the one next to the run)
% with the newest final document in result/ as the team's specification,
% as step 4 does; without one, the tree gets no specification. Nothing else
% runs. Returns one screen line of counts.
cfg = st_config();
st_log(cfg, 'INFO', 'Team tree redo start');
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
manifest = [];
classified = [];
try
    evalc('manifest = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir, ''LATEST'');');
    pipelineId = char(string(manifest.PipelineId));
    documents = dir(fullfile(cfg.ResultDir, 'final_document_*.xlsx'));
    specification = '';
    if ~isempty(documents)
        [~, newest] = max([documents.datenum]);
        specification = fullfile(documents(newest).folder, documents(newest).name);
    end
    evalc(['classified = st_classify_standalone_results(''PipelineId'', pipelineId, ' ...
        '''SpecificationFile'', specification);']);
    line = sprintf('4단계 분류 다시 | CUT %d | Test Manager 결과 넣음 %s | 최종 문서 넣음 %s', ...
        numel(classified.CutFolders), yes_no(~isempty(classified.ResultFile)), ...
        yes_no(~isempty(classified.SpecificationFile)));
    st_log(cfg, 'INFO', 'Team tree redo end | CUT %d | result %d', numel(classified.CutFolders), ...
        ~isempty(classified.ResultFile));
catch ME
    place = st_error_place(ME);
    if ~isempty(place), place = [' | ' place]; end
    line = sprintf('4단계 분류 다시 실패 | %s%s', ME.identifier, place);
    st_log(cfg, 'ERROR', 'Team tree redo failed | %s', ME.identifier);
end
end


function text = yes_no(flag)
text = '아니오';
if flag, text = '예'; end
end
