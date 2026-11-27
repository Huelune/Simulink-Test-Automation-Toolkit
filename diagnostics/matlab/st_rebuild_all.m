function st_rebuild_all()
%ST_REBUILD_ALL Delete the Harnesses and Test File, then run the manual from Harness creation to the team tree.
%
% For todo.md: everything again from nothing, steps 1, 3, 4 and 5 of the
% manual (step 2 is optional and left out). The final document is the
% team's specification and goes into the team tree's report folder.
%   1. Runs the unit tests of the code this run goes through. Any failure
%      stops it before anything is deleted.
%   2. Stops on unsaved models; otherwise closes every model and clears
%      Test Manager, then st_delete_old_results deletes the earlier runs'
%      results (the user asked for it; it cannot be undone).
%   3. st_rebuild_harnesses_and_tests: deletes the Harness each Excel target
%      names and the Test File, runs step 1 with FORCE, PER_CUT and the
%      result collection, and counts the scenarios.
%   4. When step 1 finished, st_rebuild_standalone_and_document: the
%      standalone pipeline with its saved Result, its check code, the final
%      document (step 5), the team tree with the final document (step 4),
%      then each target's iteration outcomes, defect kinds and CVF-applied
%      coverage on screen.
% No names reach the screen; long error reports go to tempdir/st_todo_check.txt.
title = '처음부터 분류까지 다시 만들기';
cfg = st_config();
st_log(cfg, 'INFO', 'Rebuild all start');
reportFile = fullfile(tempdir, 'st_todo_check.txt');
if isfile(reportFile), delete(reportFile); end
lines = {};
passed = false;
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
results = [];
files = fullfile(st_project_root(), 'tests', 'unit', {'test_defect_criteria.m', ...
    'test_open_standalone_test_manager.m', 'test_rebase_standalone_manifest.m', ...
    'test_standalone_run_folder.m', 'test_classify_standalone_results.m', ...
    'test_old_standalone_items.m', 'test_remove_moved_check_copy.m'});
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
    show(title, [lines, {'단위 테스트가 통과하지 않아 아무것도 지우지 않았습니다. 이 화면을 보내 주세요'}]);
    st_log(cfg, 'WARN', 'Rebuild all stopped | unit tests');
    return;
end

% An open model or Test File keeps its file from being deleted.
loaded = find_system('type', 'block_diagram');
if ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
    show(title, [lines, {'저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요'}]);
    st_log(cfg, 'WARN', 'Rebuild all stopped | unsaved models');
    return;
end
if ~isempty(loaded), bdclose('all'); end
try
    sltest.testmanager.clearResults;
    sltest.testmanager.clear;
catch
end
lines = [lines, st_delete_old_results()];

[lines, ok] = st_rebuild_harnesses_and_tests(lines);
if ~ok
    show(title, [lines, {'1단계가 끝나지 않아 3단계부터는 돌리지 않았습니다'}]);
    st_log(cfg, 'WARN', 'Rebuild all stopped | step 1');
    return;
end
st_log(cfg, 'INFO', 'Rebuild all | step 1 done, standalone next');
st_rebuild_standalone_and_document(lines, title);
st_log(cfg, 'INFO', 'Rebuild all complete');
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
