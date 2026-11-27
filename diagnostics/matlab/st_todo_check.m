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
% No argument: no section is pending; it says so and runs nothing.
% 25: read-only, for each target the latest step 1 run marked EXCEPT, the C
% build blocks of its CUT and the custom code settings of the Top Model,
% its Harness and library (st_inspect_custom_code).
% 27: the unit tests of the final document's decision outcomes
% (test_decision_outcomes, test_final_document_defects), one screen.
% 26: choose the folder of the C headers in a dialog
% (st_set_custom_code_include_dirs), then rebuild all (st_rebuild_all), so
% every new Harness and standalone copy gets it in Include directories.
% 24: read-only, when the Test Assessment of those targets runs against
% Tmax (st_inspect_verify_timing).
% 23: read-only, why targets failed: each target's step 1 record and the
% logs' error identifiers (st_show_target_errors).
% 22 (and 20): for the model of the clone chosen in the block, delete the
% Harnesses, Test File and earlier results, then run the manual from step 1
% to the team tree (st_rebuild_all). Run once per model clone.
% 21: unit tests, then steps 3, 5 and 4 again from the current step 1
% results (st_rebuild_standalone_and_document).
% 18: unit test, then the range and format of every CUT input
% (st_show_input_ranges). Read-only.
% 19: unit test, then set the Min/Max filled in the range table on the
% model (st_apply_input_ranges). Saves the model.
if ~st_todo_up_to_date(), return; end
cfg = st_config();
if nargin < 1
    clc;
    fprintf('지금 todo.md에 MATLAB으로 돌릴 점검이 없습니다\n');
    st_log(cfg, 'INFO', 'todo check | no section pending');
    return;
end
switch section
    case 18
        st_log(cfg, 'INFO', 'todo check start | CUT input ranges');
        if unit_passed(cfg, 'test_show_input_ranges.m'), st_show_input_ranges(); end
    case 19
        st_log(cfg, 'INFO', 'todo check start | apply CUT input ranges');
        if unit_passed(cfg, 'test_apply_input_ranges.m'), st_apply_input_ranges(); end
    case 27
        st_log(cfg, 'INFO', 'todo check start | decision outcome unit tests');
        st_show_unit_tests({'test_decision_outcomes.m', 'test_final_document_defects.m'});
    case 26
        st_log(cfg, 'INFO', 'todo check start | C header folder, then rebuild all');
        if unit_passed(cfg, 'test_merge_include_dirs.m')
            if isempty(st_set_custom_code_include_dirs())
                fprintf('C 헤더 폴더가 없어 다시 만들기를 하지 않았습니다\n');
            else
                st_rebuild_all();
            end
        end
    case 25
        st_log(cfg, 'INFO', 'todo check start | custom code of failed targets');
        if unit_passed(cfg, 'test_build_error_kind.m'), st_inspect_custom_code(); end
    case 24
        st_log(cfg, 'INFO', 'todo check start | verify timing of failed targets');
        if unit_passed(cfg, 'test_build_error_kind.m'), st_inspect_verify_timing(); end
    case 23
        st_log(cfg, 'INFO', 'todo check start | why targets failed');
        if unit_passed(cfg, 'test_error_log_lines.m'), st_show_target_errors(); end
    case 21
        st_log(cfg, 'INFO', 'todo check start | standalone, final document and tree again');
        if unit_passed(cfg, 'test_other_toolkit_path_entries.m') && unit_passed(cfg, 'test_error_place.m')
            st_rebuild_standalone_and_document();
        end
    case {20, 22}
        st_log(cfg, 'INFO', 'todo check start | rebuild all from step 1');
        st_rebuild_all();
    otherwise
        % A wrong number must not reach the rebuild, which deletes results.
        clc;
        fprintf('todo.md에 그 번호의 절이 없습니다 | 블록 끝의 st_todo_check(번호)를 확인하세요\n');
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
