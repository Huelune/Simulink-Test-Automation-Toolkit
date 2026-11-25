function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 6. Run the defect criteria unit tests, then read every defect
% iteration's Custom Criteria result in the standalone and PER_CUT runs and
% open the saved coverage reports (st_check_defect_criteria).
clc;
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | defect criteria');
lines = {};
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
results = [];
try
    evalc(['results = runtests(fullfile(st_project_root(), ''tests'', ''unit'', ' ...
        '''test_defect_criteria.m''));']);
    lines{end+1} = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d | 미완료 %d', numel(results), ...
        sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));
    failed = results([results.Failed] | [results.Incomplete]);
    for k = 1:numel(failed), lines{end+1} = sprintf('  실패 | %s', failed(k).Name); end %#ok<AGROW>
catch ME
    lines{end+1} = sprintf('단위 테스트 | 실행 오류 | %s', id_of(ME));
end
st_log(cfg, 'INFO', 'todo check complete | tests %d', numel(results));
st_check_defect_criteria(lines);
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
