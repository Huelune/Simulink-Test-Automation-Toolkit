function [lines, ok] = st_check_targets_before_run(lines)
%ST_CHECK_TARGETS_BEFORE_RUN Stop a rebuild before it deletes or makes anything for an Excel it cannot run.
%
% [lines, ok] = st_check_targets_before_run(lines)
%
% For st_rebuild_all and st_run_model_first, before anything is deleted:
%   - every enabled target has CUTName, HarnessName and TestCaseName. Step 1
%     names the Harness and the Test Case after them; an empty HarnessName
%     once stopped the Harness deletion after the earlier results were
%     already gone (2026-11-27).
%   - st_pre_validate_targets: CUTPath is a Subsystem of the model, else
%     step 1 makes Harnesses on the wrong block.
% Adds the lines of st_target_failure_lines and, on failure, what to do.
% ok is false when any target failed or there is none.
ok = false;
cfg = st_config();
st_log(cfg, 'INFO', 'Targets check before run start');
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
targets = table();
checked = table();
try
    evalc('targets = st_load_targets(cfg.OnlyEnabled);');
    evalc('checked = st_pre_validate_targets();');
catch ME
    lines{end+1} = sprintf('Excel 검사 실패 | %s | 모델 고르기와 TestManagement.xlsx를 확인하세요', id_of(ME));
    write_report(ME);
    st_log(cfg, 'WARN', 'Targets check before run failed | %s', ME.identifier);
    return;
end
if height(checked) == 0 || height(checked) ~= height(targets)
    lines{end+1} = '돌릴 대상이 없습니다. TestManagement.xlsx의 Targets 시트와 Enabled 칸을 확인하세요';
    st_log(cfg, 'WARN', 'Targets check before run | no targets');
    return;
end
emptyFields = [blank(targets.CUTName), blank(targets.HarnessName), blank(targets.TestCaseName)];
found = st_target_failure_lines(checked.No, emptyFields, checked.Status, checked.Message);
lines = [reshape(lines, 1, []), found];
ok = numel(found) == 1;
if ~ok
    lines{end+1} = 'Excel을 고친 뒤 다시 돌려 주세요. 아무것도 지우거나 만들지 않았습니다';
end
st_log(cfg, 'INFO', 'Targets check before run end | targets %d | ok %d', height(checked), ok);
end


function flags = blank(values)
values = string(values);
values(ismissing(values)) = "";
flags = strlength(strtrim(values(:))) == 0;
end


function write_report(ME)
fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
if fid < 0, return; end
fprintf(fid, '[Excel 검사]\n%s\n\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
fclose(fid);
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
place = st_error_place(ME);
if ~isempty(place), text = [text ' | ' place]; end
end
