function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 10. Choose a standalone folder in a dialog and open that
% run's results (st_show_standalone_results), then the folder resolution
% unit tests as one line under its screen.
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | show standalone results of a chosen folder');
results = [];
testFile = fullfile(st_project_root(), 'tests', 'unit', 'test_standalone_run_folder.m');
try
    evalc('results = runtests(testFile);');
    testLine = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d', numel(results), ...
        sum([results.Passed]), sum([results.Failed] | [results.Incomplete]));
catch ME
    testLine = sprintf('단위 테스트 | 실행 오류 | %s', ME.identifier);
end
st_show_standalone_results();
fprintf('%s\n', testLine);
end
