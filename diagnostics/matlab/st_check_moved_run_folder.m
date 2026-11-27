function st_check_moved_run_folder()
%ST_CHECK_MOVED_RUN_FOLDER Open a copy of the latest standalone run from another folder.
%
% For todo.md, so nobody has to copy and pick a folder by hand:
%   1. Copies the latest run folder to <standalone root>_moved_check (an
%      earlier check's copy there is deleted first).
%   2. Counts the copy's recorded paths of its own run folder after the
%      rebase: all must point into the copy, none at the original.
%   3. Opens the copy with st_show_standalone_results, whose second line
%      must say the folder moved. The count line goes under its screen.
%   4. Deletes the copy (st_remove_moved_check_copy): Test Manager is
%      cleared and the copy's models close. The browser reports stay,
%      since they are written to tempdir.
% Long error reports go to tempdir/st_todo_check.txt.
cfg = st_config();
st_log(cfg, 'INFO', 'Moved run folder check start');
try
    root = regexprep(st_absolute_path(cfg.StandaloneCoverageRootDir), '[\\/]+$', '');
    latest = st_load_standalone_pipeline_manifest(root, 'LATEST');
    pipelineId = char(string(latest.PipelineId));
    % A copy left by a check that stopped halfway goes first.
    clear_test_manager();
    [~, copyRoot] = st_remove_moved_check_copy(cfg);
    copyRun = fullfile(copyRoot, pipelineId);
    mkdir(copyRoot);
    [copied, message] = copyfile(fullfile(root, pipelineId), copyRun);
    if ~copied, error('simtest:MovedCheckCopyFailed', '%s', message); end
    manifest = st_load_standalone_pipeline_manifest(copyRoot, pipelineId);
catch ME
    clc;
    fprintf('MATLAB %s | 복사한 실행 폴더 열기\n', version('-release'));
    fprintf('복사 실패 | %s | 전문 st_todo_check.txt (임시 폴더)\n', id_of(ME));
    fprintf('%s\n', copy_hint(ME));
    fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
    if fid >= 0
        fprintf(fid, '[복사한 실행 폴더 열기]\n%s\n\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        fclose(fid);
    end
    st_log(cfg, 'ERROR', 'Moved run folder check failed | %s', id_of(ME));
    return;
end
rebased = st_rebase_standalone_manifest(manifest, copyRun);
[intoCopy, intoOriginal] = count_paths(rebased, copyRun, fullfile(root, pipelineId));
st_show_standalone_results(copyRun);
% The numbers are on the screen and the reports live in tempdir, so the
% copy goes now; Test Manager and the copy's models close with it.
try
    clear_test_manager();
    st_remove_moved_check_copy(cfg);
    removedText = '복사본 지움(Test Manager 비우고 복사본 모델 닫음, 브라우저 보고서는 남음)';
catch ME
    removedText = sprintf('복사본 못 지움 %s | MATLAB을 다시 시작한 뒤 다시 돌리세요', id_of(ME));
    st_log(cfg, 'WARN', 'Moved run folder copy not removed | %s', id_of(ME));
end
fprintf('복사본 | 기록 경로 중 복사본 아래 %d, 원래 자리 %d | %s\n', intoCopy, intoOriginal, removedText);
st_log(cfg, 'INFO', 'Moved run folder check end | IntoCopy=%d | IntoOriginal=%d', intoCopy, intoOriginal);
end


function clear_test_manager()
% Test Manager may keep the copy's test file open, which stops the delete.
sltest.testmanager.clearResults;
sltest.testmanager.clear;
end


function [intoCopy, intoOriginal] = count_paths(manifest, copyRun, originalRun)
% The same fields st_rebase_standalone_manifest rewrites: top-level text of
% the manifest and of each target.
items = {manifest};
if isfield(manifest, 'Targets') && isstruct(manifest.Targets)
    items = [items, num2cell(manifest.Targets(:)')];
end
intoCopy = 0;
intoOriginal = 0;
for i = 1:numel(items)
    names = fieldnames(items{i});
    for j = 1:numel(names)
        value = items{i}.(names{j});
        if ~ischar(value) || isempty(value), continue; end
        intoCopy = intoCopy + under(value, copyRun);
        intoOriginal = intoOriginal + under(value, originalRun);
    end
end
end


function flag = under(value, folder)
flag = strcmpi(value, folder) || startsWith(lower(value), lower([folder filesep]));
end


function text = copy_hint(ME)
if contains(ME.identifier, 'StandalonePipelineLatest')
    text = '최근 standalone 실행이 없습니다. 실행부터 하세요';
elseif strcmp(ME.identifier, 'simtest:MovedCheckCopyNotRemoved')
    text = '예전 복사본을 지우지 못했습니다. MATLAB을 다시 시작한 뒤 다시 돌리세요';
elseif strcmp(ME.identifier, 'simtest:MovedCheckCopyFailed')
    text = '복사하지 못했습니다. 디스크 공간과 경로 길이(260자)를 확인하세요';
else
    text = '전문을 확인하세요';
end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
