function [lines, ok] = st_rebuild_harnesses_and_tests(lines, fresh)
%ST_REBUILD_HARNESSES_AND_TESTS Delete the targets' Harnesses and the Test File, then run step 1 again.
%
% st_rebuild_harnesses_and_tests(lines)
% [lines, ok] = st_rebuild_harnesses_and_tests(lines)
% [lines, ok] = st_rebuild_harnesses_and_tests(lines, false)
%
% fresh=false (a model's first run, st_run_model_first) deletes nothing and
% runs step 1 with the default preparation mode: a Harness already in the
% model is kept, as st_run_from_harness does.
%
% With outputs it prints nothing and skips step 5: it returns its lines and
% whether step 1 finished, for a caller that goes on (st_rebuild_all).
%
% For todo.md: rebuild every target from nothing and count what came out.
%   1. Stops when a model has unsaved changes.
%   2. Deletes the Harness each Excel target names (no other), saves the Top
%      Model, then closes and deletes the Test File.
%   3. Runs st_run_from_harness('PreparationMode','FORCE','ExecutionMode',
%      'PER_CUT','AutoCollect',true) with its progress on screen. PER_CUT,
%      because step 5 reads the saved PER_CUT results.
%   4. Reads st_validate_scenario_alignment: per target the SLDV scenarios
%      (defect copies included), the Signal Editor and Test Assessment
%      scenarios and the Test Manager iterations.
%   5. Hands the lines to st_check_defect_criteria, which adds each target's
%      iteration outcomes and defect Custom Criteria kinds, and prints.
% lines go under the title. No names reach the screen; long error reports
% go to tempdir/st_todo_check.txt.
if nargin < 1, lines = {}; end
if nargin < 2, fresh = true; end
ok = false;
quiet = nargout > 0;
title = 'Harness·Test 처음부터 다시 만들기';
cfg = st_config();
st_log(cfg, 'INFO', 'Rebuild from scratch start');
loaded = find_system('type', 'block_diagram');
if ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
    lines = stop(lines, title, '저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요', [], quiet);
    return;
end

% A standalone model left open holds a Harness name; close everything first.
if ~isempty(loaded), bdclose('all'); end
if fresh
    try
        cfg = st_require_runtime_target();
        targets = st_load_targets(cfg.OnlyEnabled);
        deleted = 0;
        for i = 1:height(targets)
            owner = st_normalize_cut_path(targets.CUTPath(i), cfg.TopModel);
            name = char(targets.HarnessName(i));
            if isempty(sltest.harness.find(owner, 'SearchDepth', 0, 'Name', name)), continue; end
            try, sltest.harness.close(owner, name); catch, end
            sltest.harness.delete(owner, name);
            deleted = deleted + 1;
        end
        save_system(cfg.TopModel);
        st_log(cfg, 'INFO', 'Rebuild from scratch | Harnesses deleted %d of %d', deleted, height(targets));
        lines{end+1} = sprintf('Harness 지움 %d / 대상 %d | Test File 지움 %s', ...
            deleted, height(targets), yes_no(delete_test_file(cfg.TestFile)));
    catch ME
        lines = stop(lines, title, sprintf('지우기 실패 | %s | 모델을 저장하지 말고 닫은 뒤 다시 돌려 주세요', ...
            id_of(ME)), ME, quiet);
        return;
    end
else
    lines{end+1} = 'Harness·Test File 지우지 않음(있는 Harness는 그대로 씀)';
end

options = {'ExecutionMode', 'PER_CUT', 'AutoCollect', true};
if fresh, options = [{'PreparationMode', 'FORCE'}, options]; end
try
    st_run_from_harness(options{:});
    lines{end+1} = sprintf('1단계(%s, 결과 정리 포함) OK', ternary(fresh, 'FORCE', '기본 준비'));
    ok = true;
catch ME
    lines{end+1} = sprintf('1단계 실패 | %s | 실행 로그(result/logs)를 보세요', id_of(ME));
    lines{end+1} = write_report(ME, '1단계');
end

alignment = table();
try
    evalc('alignment = st_validate_scenario_alignment();');
catch ME
    lines{end+1} = sprintf('시나리오 맞춤 확인 실패 | %s', id_of(ME));
    lines{end+1} = write_report(ME, '시나리오 맞춤');
end
% Matching targets are a count; only the others get a line, so many targets still fit one screen.
matched = true(height(alignment), 1);
if height(alignment) > 0
    matched = ismember(string(alignment.Status), ["OK", "CACHED"]);
    lines{end+1} = sprintf('시나리오 맞춤 OK %d / 대상 %d', sum(matched), height(alignment));
end
for i = find(~matched(:))'
    lines{end+1} = sprintf(['대상 %d | 시나리오 SLDV+결함 %d | Signal Editor %d | ' ...
        'Test Assessment %d | Iteration %d | %s'], double(alignment.No(i)), ...
        alignment.ExpectedScenarioCount(i), alignment.SignalEditorScenarioCount(i), ...
        alignment.AssessmentScenarioCount(i), alignment.TestManagerIterationCount(i), ...
        alignment.Status(i)); %#ok<AGROW>
end
st_log(cfg, 'INFO', 'Rebuild from scratch complete | targets %d', height(alignment));
if ~quiet, st_check_defect_criteria(lines, title, false); end
end


function removed = delete_test_file(testFile)
removed = false;
[~, name, extension] = fileparts(testFile);
openFiles = sltest.testmanager.getTestFiles;
for k = 1:numel(openFiles)
    % By name: FilePath can spell a tempdir 8.3 short path in full.
    [~, openName, openExtension] = fileparts(openFiles(k).FilePath);
    if strcmpi([openName openExtension], [name extension]), close(openFiles(k)); end
end
if isfile(testFile)
    delete(testFile);
    removed = true;
end
end


function lines = stop(lines, title, message, ME, quiet)
%STOP Add the reason; print the screen unless the caller prints it.
lines = [reshape(lines, 1, []), {message}];
if ~isempty(ME), lines{end+1} = write_report(ME, '지우기'); end
if quiet, return; end
clc;
fprintf('%s\n', sprintf('MATLAB %s | %s', version('-release'), title), lines{:});
end


function line = write_report(ME, stage)
%WRITE_REPORT Append the full report; return the screen line that points at it.
line = sprintf('  %s 오류 전문: st_todo_check.txt (임시 폴더)', stage);
fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
if fid < 0, line = sprintf('  %s 오류 전문을 쓰지 못함', stage); return; end
fprintf(fid, '[%s]\n%s\n\n', stage, getReport(ME, 'extended', 'hyperlinks', 'off'));
fclose(fid);
end


function text = ternary(flag, yes, no)
text = no;
if flag, text = yes; end
end


function text = yes_no(flag)
text = '아니오';
if flag, text = '예'; end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
