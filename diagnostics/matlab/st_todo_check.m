function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 15. Copy the latest standalone run folder elsewhere, open
% the copy and delete it afterwards (st_check_moved_run_folder); then the
% folder resolution, moved-folder and copy removal unit tests under its
% screen.
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | open and remove a copied standalone run folder');
results = [];
unitDir = fullfile(st_project_root(), 'tests', 'unit');
testFiles = {fullfile(unitDir, 'test_standalone_run_folder.m'), ...
    fullfile(unitDir, 'test_rebase_standalone_manifest.m'), ...
    fullfile(unitDir, 'test_remove_moved_check_copy.m')};
testLines = {};
try
    evalc('results = runtests(testFiles);');
    bad = [results.Failed] | [results.Incomplete];
    testLines{end+1} = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d', numel(results), ...
        sum([results.Passed]), sum(bad));
    for k = find(bad), testLines{end+1} = sprintf('  실패 | %s', results(k).Name); end %#ok<AGROW>
catch ME
    testLines{end+1} = sprintf('단위 테스트 | 실행 오류 | %s', ME.identifier);
end
st_check_moved_run_folder();
fprintf('%s\n', testLines{:});
end
