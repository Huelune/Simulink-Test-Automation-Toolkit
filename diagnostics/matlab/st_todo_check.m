function st_todo_check(section)
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% It starts with st_todo_up_to_date: each model has its own clone, and one
% that has not pulled would run an earlier section's check. Keep that line
% when pointing this at another section.
%
% No argument: section 20. Delete the Harnesses, Test File and earlier
% results, then run the manual from step 1 to the team tree (st_rebuild_all),
% now that the CUT inputs have Min/Max.
% 18: unit test, then the range and format of every CUT input
% (st_show_input_ranges). Read-only.
% 19: unit test, then set the Min/Max filled in the range table on the
% model (st_apply_input_ranges). Saves the model.
if ~st_todo_up_to_date(), return; end
cfg = st_config();
if nargin < 1, section = 20; end
switch section
    case 18
        st_log(cfg, 'INFO', 'todo check start | CUT input ranges');
        if unit_passed(cfg, 'test_show_input_ranges.m'), st_show_input_ranges(); end
    case 19
        st_log(cfg, 'INFO', 'todo check start | apply CUT input ranges');
        if unit_passed(cfg, 'test_apply_input_ranges.m'), st_apply_input_ranges(); end
    otherwise
        st_log(cfg, 'INFO', 'todo check start | rebuild all from step 1');
        st_rebuild_all();
end
end


function ok = unit_passed(cfg, name)
% The check's own unit test first; a failure leaves the model untouched.
ok = false;
results = [];
file = fullfile(st_project_root(), 'tests', 'unit', name);
try
    evalc('results = runtests(file);');
catch ME
    clc;
    fprintf('단위 테스트 실행 오류 | %s | 이 화면을 보내 주세요\n', ME.identifier);
    st_log(cfg, 'WARN', 'todo check stopped | unit test error');
    return;
end
if isempty(results) || any([results.Failed] | [results.Incomplete])
    clc;
    fprintf('단위 테스트 실패 | 모델을 건드리지 않았습니다. 이 화면을 보내 주세요\n');
    st_log(cfg, 'WARN', 'todo check stopped | unit test failed');
    return;
end
ok = true;
end
