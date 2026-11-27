function upToDate = st_todo_up_to_date()
%ST_TODO_UP_TO_DATE Stop a todo check run from a clone that has not pulled.
%
% upToDate = st_todo_up_to_date()
%
% Each model has its own clone, and a clone that was not pulled still runs
% the check of an earlier todo.md section (2026-11-27: the second model's
% clone made a third clone instead of running section 17). Fetches
% origin/main and counts the commits this clone's HEAD lacks. When there
% are any, it prints why and what to do and returns false. When the fetch
% fails (no network, no sign-in) it cannot tell, so it returns true and
% leaves a WARN in the run log. git's own output is not shown.
cfg = st_config();
root = st_project_root();
upToDate = true;
st_log(cfg, 'INFO', 'todo check freshness start');
% No console prompt: without a sign-in the fetch fails instead of waiting.
[status, ~] = system(sprintf('set GIT_TERMINAL_PROMPT=0&& git -C "%s" fetch -q origin main', root));
if status ~= 0
    st_log(cfg, 'WARN', 'todo check freshness unknown | fetch failed | the check runs anyway');
    return;
end
[status, output] = system(sprintf('git -C "%s" rev-list --count HEAD..origin/main', root));
behind = str2double(strtrim(output));
if status ~= 0 || isnan(behind)
    st_log(cfg, 'WARN', 'todo check freshness unknown | count failed | the check runs anyway');
    return;
end
if behind > 0
    upToDate = false;
    clc;
    fprintf('MATLAB %s | todo 점검 멈춤\n', version('-release'));
    fprintf('이 클론이 최신이 아닙니다 | origin/main보다 %d커밋 뒤 | 예전 todo 절의 점검이 돌 수 있어 멈췄습니다\n', behind);
    fprintf('할 일 | cmd에서 이 클론 폴더로 가서 git pull을 한 뒤 같은 블록을 다시 돌리세요\n');
    st_log(cfg, 'WARN', 'todo check stopped | clone behind origin/main by %d', behind);
    return;
end
st_log(cfg, 'INFO', 'todo check freshness end | up to date');
end
