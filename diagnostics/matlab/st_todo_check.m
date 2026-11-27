function st_todo_check(section)
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% No argument: section 17. Run the second model's clone through the manual
% for the first time, Excel check to team tree, keeping its Harnesses
% (st_run_model_first).
% 18: unit test, then the range and format of every CUT input
% (st_show_input_ranges). Read-only.
cfg = st_config();
if nargin < 1, section = 17; end
switch section
    case 18
        st_log(cfg, 'INFO', 'todo check start | CUT input ranges');
        results = [];
        file = fullfile(st_project_root(), 'tests', 'unit', 'test_show_input_ranges.m');
        try
            evalc('results = runtests(file);');
        catch ME
            clc;
            fprintf('단위 테스트 실행 오류 | %s | 이 화면을 보내 주세요\n', ME.identifier);
            return;
        end
        if isempty(results) || any([results.Failed] | [results.Incomplete])
            clc;
            fprintf('단위 테스트 실패 | 모델을 읽지 않았습니다. 이 화면을 보내 주세요\n');
            st_log(cfg, 'WARN', 'todo check stopped | input range unit test failed');
            return;
        end
        st_show_input_ranges();
    otherwise
        st_log(cfg, 'INFO', 'todo check start | first run of this clone''s model');
        st_run_model_first();
end
end
