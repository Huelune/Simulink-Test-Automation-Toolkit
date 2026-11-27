function st_run_model_first()
%ST_RUN_MODEL_FIRST Run this clone's model through the manual for the first time, Excel check to team tree.
%
% For todo.md, after a clone was made for another model (st_make_model_clone)
% and its TestManagement.xlsx put in place. Steps 1, 3, 4 and 5 of the
% manual like st_rebuild_all, but nothing is deleted: a Harness already in
% the model is kept, as st_run_from_harness does.
%   1. Runs the unit tests of the code this run goes through. Any failure
%      stops it before the model is touched.
%   2. Stops on unsaved models; otherwise closes every model and clears
%      Test Manager.
%   3. st_pre_validate_targets: any target whose CUTPath is not a Subsystem
%      of the model stops it, with the kind of each failure, since step 1
%      would make Harnesses on the wrong block.
%   4. st_rebuild_harnesses_and_tests(lines, false): step 1 with PER_CUT and
%      the result collection, scenario alignment as a count.
%   5. When step 1 finished, st_rebuild_standalone_and_document: steps 3, 5
%      and 4, then one line per target and run.
% The screen fits about 11 targets. No names reach it; long error reports go
% to tempdir/st_todo_check.txt.
title = '이 클론의 모델 처음 돌리기';
cfg = st_config();
st_log(cfg, 'INFO', 'Model first run start');
reportFile = fullfile(tempdir, 'st_todo_check.txt');
if isfile(reportFile), delete(reportFile); end
lines = {};
passed = false;
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
results = [];
checked = table();
files = fullfile(st_project_root(), 'tests', 'unit', {'test_defect_criteria.m', ...
    'test_open_standalone_test_manager.m', 'test_rebase_standalone_manifest.m', ...
    'test_classify_standalone_results.m', 'test_final_document_defects.m'});
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
if ~passed
    show(title, [lines, {'단위 테스트가 통과하지 않아 모델을 건드리지 않았습니다. 이 화면을 보내 주세요'}]);
    st_log(cfg, 'WARN', 'Model first run stopped | unit tests');
    return;
end

loaded = find_system('type', 'block_diagram');
if ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
    show(title, [lines, {'저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요'}]);
    st_log(cfg, 'WARN', 'Model first run stopped | unsaved models');
    return;
end
if ~isempty(loaded), bdclose('all'); end
try
    sltest.testmanager.clearResults;
    sltest.testmanager.clear;
catch
end

try
    evalc('checked = st_pre_validate_targets();');
catch ME
    show(title, [lines, {sprintf('Excel 검사 실패 | %s | 모델 고르기와 TestManagement.xlsx를 확인하세요', ...
        id_of(ME)), write_report(ME, 'Excel 검사')}]);
    st_log(cfg, 'WARN', 'Model first run stopped | pre-validation error');
    return;
end
bad = [];
if height(checked) > 0, bad = find(string(checked.Status) ~= "OK"); end
lines{end+1} = sprintf('Excel 검사 | 대상 %d | OK %d | 실패 %d', height(checked), ...
    height(checked) - numel(bad), numel(bad));
for k = reshape(bad, 1, [])
    lines{end+1} = sprintf('  대상 %d | %s', double(checked.No(k)), reason_kind(checked.Message(k))); %#ok<AGROW>
end
if height(checked) == 0
    show(title, [lines, {'돌릴 대상이 없습니다. TestManagement.xlsx의 Targets 시트와 Enabled 칸을 확인하세요'}]);
    st_log(cfg, 'WARN', 'Model first run stopped | no targets');
    return;
end
if ~isempty(bad)
    show(title, [lines, {'Excel의 CUTPath를 고친 뒤 다시 돌려 주세요. 이대로면 Harness를 엉뚱한 블록에 만듭니다'}]);
    st_log(cfg, 'WARN', 'Model first run stopped | pre-validation %d failed of %d', numel(bad), height(checked));
    return;
end

[lines, ok] = st_rebuild_harnesses_and_tests(lines, false);
if ~ok
    show(title, [lines, {'1단계가 끝나지 않아 3단계부터는 돌리지 않았습니다'}]);
    st_log(cfg, 'WARN', 'Model first run stopped | step 1');
    return;
end
st_log(cfg, 'INFO', 'Model first run | step 1 done, standalone next');
st_rebuild_standalone_and_document(lines, title);
st_log(cfg, 'INFO', 'Model first run complete');
end


function text = reason_kind(message)
% st_pre_validate_targets' messages carry the path; only their kind is shown.
message = string(message);
if startsWith(message, 'CUTPath is empty')
    text = 'CUTPath 빈 칸';
elseif startsWith(message, 'CUT block not found')
    text = '블록 없음(경로 오타나 빠진 중간 Subsystem)';
elseif startsWith(message, 'Target exists but is not a Subsystem')
    text = ['Subsystem 아님(블록 종류 ' char(strtrim(extractAfter(message, 'BlockType='))) ')'];
else
    text = '기타 | 전문 st_todo_check.txt (임시 폴더)';
    fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
    if fid >= 0
        fprintf(fid, '[Excel 검사]\n%s\n\n', message);
        fclose(fid);
    end
end
end


function line = write_report(ME, stage)
line = sprintf('  %s 오류 전문: st_todo_check.txt (임시 폴더)', stage);
fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
if fid < 0, line = sprintf('  %s 오류 전문을 쓰지 못함', stage); return; end
fprintf(fid, '[%s]\n%s\n\n', stage, getReport(ME, 'extended', 'hyperlinks', 'off'));
fclose(fid);
end


function show(title, lines)
clc;
lines = [{sprintf('MATLAB %s | %s', version('-release'), title)}, lines];
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
