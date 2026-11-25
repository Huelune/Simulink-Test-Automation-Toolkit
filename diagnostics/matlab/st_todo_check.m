function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 6. Run the unit tests of the defect scenario change. Only
% when they all pass, delete the targets' Harnesses and the Test File and
% run step 1 again from nothing (st_rebuild_harnesses_and_tests).
clc;
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | rebuild with defect scenarios');
reportFile = fullfile(tempdir, 'st_todo_check.txt');
if isfile(reportFile), delete(reportFile); end
lines = {};
passed = false;
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
results = [];
files = fullfile(st_project_root(), 'tests', 'unit', {'test_expected_iteration_bindings.m', ...
    'test_unreachable_objectives.m', 'test_sldv_template_selection.m', ...
    'test_defect_settings.m', 'test_defect_criteria.m'});
try
    evalc('results = runtests(files);');
    lines{end+1} = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d | 미완료 %d', numel(results), ...
        sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));
    failed = results([results.Failed] | [results.Incomplete]);
    for k = 1:numel(failed), lines{end+1} = sprintf('  실패 | %s', failed(k).Name); end %#ok<AGROW>
    passed = isempty(failed) && ~isempty(results);
catch ME
    lines{end+1} = sprintf('단위 테스트 | 실행 오류 | %s', id_of(ME));
end
st_log(cfg, 'INFO', 'todo check | tests %d | passed %d', numel(results), passed);
if ~passed
    clc;
    fprintf('MATLAB %s | Harness·Test 처음부터 다시 만들기\n', version('-release'));
    fprintf('%s\n', lines{:});
    fprintf('단위 테스트가 통과하지 않아 Harness와 Test File을 지우지 않았습니다. 이 화면을 보내 주세요\n');
    return;
end
st_rebuild_harnesses_and_tests(lines);
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
