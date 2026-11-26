function [lines, ok] = st_delete_old_results()
%ST_DELETE_OLD_RESULTS Delete the earlier runs' results for a start from nothing.
%
% [lines, ok] = st_delete_old_results()
%
% Asked for by the user (2026-11-26) before the rebuild of todo.md section
% 11. Cannot be undone. Deletes:
%   1. Every generated artifact st_cleanup_results knows under result/ (step 1
%      runs and their pointers, SLDV results, workflow state, CVFs, reports,
%      exports, verification).
%   2. result/final_document_*.xlsx and result/test_specification_*.xlsx.
%   3. Under the standalone root, what st_old_standalone_items picks: run
%      folders, team trees and latest.json. Path entries under deleted run
%      folders come off the MATLAB path.
% Keeps result/logs (this run writes there), runtime_target.mat, and any
% entry of the standalone root it does not recognise. The caller closes
% models and Test Manager first, since an open file cannot be deleted.
% Returns one screen line of counts (and one of failures) and whether all
% deletions succeeded. Paths go only to tempdir/st_todo_check.txt.
cfg = st_config();
st_log(cfg, 'INFO', 'Delete old results start | standalone root %s', cfg.StandaloneCoverageRootDir);
lines = {};
failures = strings(0, 1);

% Variables that evalc assigns are named first, or MATLAB may take them for functions.
cleanupPlan = [];
generated = 0;
try
    evalc('cleanupPlan = st_cleanup_results(''Scope'', ''ALL'', ''Apply'', true);');
    generated = sum(cleanupPlan.Status == "DELETED");
    bad = cleanupPlan(cleanupPlan.Status == "FAIL", :);
    for k = 1:height(bad), failures(end+1) = bad.Path(k) + " | " + bad.Message(k); end %#ok<AGROW>
catch ME
    failures(end+1) = "st_cleanup_results | " + string(ME.identifier);
end

documents = 0;
for pattern = {'final_document_*.xlsx', 'test_specification_*.xlsx'}
    listing = dir(fullfile(cfg.ResultDir, pattern{1}));
    for k = 1:numel(listing)
        file = fullfile(listing(k).folder, listing(k).name);
        try
            delete_file(file);
            documents = documents + 1;
        catch ME
            failures(end+1) = string(file) + " | " + string(ME.message); %#ok<AGROW>
        end
    end
end

[items, kept] = st_old_standalone_items(cfg.StandaloneCoverageRootDir);
removed = false(height(items), 1);
for k = 1:height(items)
    target = char(items.Path(k));
    try
        if items.Kind(k) == "LATEST"
            delete_file(target);
        else
            if items.Kind(k) == "RUN", remove_from_path(target); end
            [done, message] = rmdir(target, 's');
            if ~done, error('simtest:DeleteOldResultsFailed', '%s', message); end
        end
        removed(k) = true;
    catch ME
        failures(end+1) = string(target) + " | " + string(ME.message); %#ok<AGROW>
    end
end

lines{end+1} = sprintf(['예전 결과 지움 | result 생성물 %d | 최종 문서·사양서 %d | standalone 실행 폴더 %d | ' ...
    '팀 제출 트리 %d | 최근 표시 %d | 남김 %d'], generated, documents, ...
    sum(removed & items.Kind == "RUN"), sum(removed & items.Kind == "TREE"), ...
    sum(removed & items.Kind == "LATEST"), kept);
ok = isempty(failures);
if ~ok
    lines{end+1} = sprintf(['  지우지 못함 %d | 열린 파일이 있으면 MATLAB·탐색기·Excel에서 닫고 다시 돌려 주세요 | ' ...
        '목록 st_todo_check.txt (임시 폴더)'], numel(failures));
    fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
    if fid >= 0
        fprintf(fid, '[예전 결과 지우기]\n%s\n\n', strjoin(failures, newline));
        fclose(fid);
    end
    st_log(cfg, 'WARN', 'Delete old results incomplete | failures %d', numel(failures));
end
st_log(cfg, 'INFO', ['Delete old results complete | generated %d | documents %d | ' ...
    'standalone items %d of %d | kept %d'], generated, documents, sum(removed), height(items), kept);
end


function delete_file(file)
% delete only warns when it cannot delete, so look again.
delete(file);
if isfile(file)
    error('simtest:DeleteOldResultsFailed', 'The file is still there (open elsewhere?).');
end
end


function remove_from_path(folder)
entries = strsplit(path, pathsep);
inside = entries(startsWith(lower(entries), lower([folder filesep])) | strcmpi(entries, folder));
if ~isempty(inside), rmpath(inside{:}); end
end
