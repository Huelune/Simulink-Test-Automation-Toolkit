function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 16. Make a toolkit clone for the second model next to this
% one (st_make_model_clone); the unit tests of st_setup's clean-up of
% another clone's path run first and print under its screen.
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | make a clone for another model');
results = [];
testLines = {};
try
    evalc(['results = runtests(fullfile(st_project_root(), ''tests'', ''unit'', ' ...
        '''test_other_toolkit_path_entries.m''));']);
    bad = [results.Failed] | [results.Incomplete];
    testLines{end+1} = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d', numel(results), ...
        sum([results.Passed]), sum(bad));
    for k = find(bad), testLines{end+1} = sprintf('  실패 | %s', results(k).Name); end %#ok<AGROW>
catch ME
    testLines{end+1} = sprintf('단위 테스트 | 실행 오류 | %s', ME.identifier);
end
st_make_model_clone();
fprintf('%s\n', testLines{:});
end
