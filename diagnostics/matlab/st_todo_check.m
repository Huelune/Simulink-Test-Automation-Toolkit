function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: the coverage-filter and PER_CUT unit tests, after a source-text test
% was brought in line with the CVF generator.
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | unit tests');
files = fullfile(st_project_root(), 'tests', 'unit', ...
    {'test_coverage_filters.m', 'test_per_cut_execution.m'});
results = [];
fprintf('MATLAB %s | 단위 테스트\n', version('-release'));
try
    evalc('results = runtests(files);');
catch ME
    fprintf('단위 테스트 | 실행 오류 | %s\n', ME.identifier);
    st_log(cfg, 'ERROR', 'todo check failed | %s', ME.identifier);
    return;
end
fprintf('단위 테스트 | %d | 통과 %d | 실패 %d | 미완료 %d\n', numel(results), ...
    sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));
failed = results([results.Failed] | [results.Incomplete]);
for k = 1:numel(failed), fprintf('  실패 | %s\n', failed(k).Name); end
st_log(cfg, 'INFO', 'todo check complete | tests=%d | failed=%d', ...
    numel(results), numel(failed));
end
