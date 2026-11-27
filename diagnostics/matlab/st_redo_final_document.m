function st_redo_final_document()
%ST_REDO_FINAL_DOCUMENT Make the final document and team tree again from the latest standalone run.
%
% For todo.md, after the defect rows changed to keep the whole D list:
%   1. Runs the final document defect and classification unit tests. Any
%      failure stops it before anything is made.
%   2. st_export_final_document from the latest standalone pipeline, then
%      st_classify_standalone_results with that document as the team's
%      specification (the tree is made again).
%   3. Per target (in the order of the document's case IDs): its rows by
%      verdict, the D line count of a PASS row and of each FAIL row, and for
%      each FAIL row the PASS row nearest to it and how many lines differ.
%      A defect iteration copies its source scenario (the last by default),
%      so a defect row written as if its outcome ran has the same count and
%      1 changed line against that row.
% Counts only; long error reports go to tempdir/st_todo_check.txt.
title = '최종 문서·팀 제출 트리 다시 만들기';
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
cfg = st_config();
st_log(cfg, 'INFO', 'Redo final document start');
lines = {sprintf('MATLAB %s | %s', version('-release'), title)};
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
results = [];
manifest = [];
document = table();
finalFile = '';
classified = [];
files = fullfile(st_project_root(), 'tests', 'unit', ...
    {'test_final_document_defects.m', 'test_classify_standalone_results.m'});
try
    evalc('results = runtests(files);');
    bad = [results.Failed] | [results.Incomplete];
    lines{end+1} = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d', numel(results), ...
        sum([results.Passed]), sum(bad));
    for k = find(bad), lines{end+1} = sprintf('  실패 | %s', results(k).Name); end %#ok<AGROW>
    passed = ~any(bad) && ~isempty(results);
catch ME
    lines{end+1} = sprintf('단위 테스트 | 실행 오류 | %s', id_of(ME));
    passed = false;
end
if ~passed
    lines{end+1} = '단위 테스트가 통과하지 않아 아무것도 만들지 않았습니다. 이 화면을 보내 주세요';
    show(lines);
    st_log(cfg, 'WARN', 'Redo final document stopped | unit tests');
    return;
end

try
    evalc('manifest = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir, ''LATEST'');');
    pipelineId = char(string(manifest.PipelineId));
    evalc('[document, finalFile] = st_export_final_document(''CoveragePipelineId'', pipelineId);');
    lines{end+1} = '5단계 최종 문서 OK';
    evalc(['classified = st_classify_standalone_results(''PipelineId'', pipelineId, ' ...
        '''SpecificationFile'', finalFile);']);
    lines{end+1} = sprintf('4단계 분류 OK | CUT %d | 최종 문서 넣음 %s', numel(classified.CutFolders), ...
        yes_no(~isempty(classified.SpecificationFile)));
catch ME
    lines{end+1} = sprintf('만들기 실패 | %s | 전문 st_todo_check.txt (임시 폴더)', id_of(ME));
    fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
    if fid >= 0
        fprintf(fid, '[최종 문서 다시 만들기]\n%s\n\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        fclose(fid);
    end
    st_log(cfg, 'ERROR', 'Redo final document failed | %s', id_of(ME));
end

if height(document) > 0
    caseIds = unique(string(document.CaseId), 'stable');
    for k = 1:numel(caseIds)
        rows = string(document.CaseId) == caseIds(k);
        verdicts = string(document.Judgement(rows));
        descriptions = string(document.Description(rows));
        normal = descriptions(find(verdicts == "PASS", 1));
        failed = descriptions(verdicts == "FAIL");
        if isempty(normal), normal = ""; end
        failCounts = arrayfun(@d_lines, failed);
        [changed, nearest] = arrayfun(@(text) closest(text, descriptions(verdicts == "PASS")), failed);
        lines{end+1} = sprintf(['대상 %d | 행 %d (PASS %d, FAIL %d) | PASS 행 D 줄 %d | ' ...
            'FAIL 행 D 줄 %s | 가까운 PASS 행 %s | 다른 줄 %s'], k, numel(verdicts), ...
            sum(verdicts == "PASS"), sum(verdicts == "FAIL"), d_lines(normal), ...
            join_counts(failCounts), join_counts(nearest), join_counts(changed)); %#ok<AGROW>
    end
    lines{end+1} = ['결함 행이 맞으면 FAIL 행 D 줄 수가 PASS 행과 같고, 가까운 PASS 행(원본 시나리오, ' ...
        '기본은 마지막)과 다른 줄은 1입니다'];
end
st_log(cfg, 'INFO', 'Redo final document complete | rows %d', height(document));
show(lines);
end


function count = d_lines(text)
parts = split(string(text), newline);
count = sum(~cellfun(@isempty, regexp(cellstr(parts), '^D\d+ \[', 'once')));
end


function [count, at] = closest(text, references)
% A defect row copies its source scenario's row (the last one unless the
% Targets sheet picks another), so it is compared with the PASS row nearest
% to it, not with the first. AT is that row's place among the PASS rows.
count = NaN;
at = NaN;
if isempty(references), return; end
[count, at] = min(arrayfun(@(reference) changed_lines(text, reference), references));
end


function count = changed_lines(text, reference)
mine = split(string(text), newline);
theirs = split(string(reference), newline);
n = min(numel(mine), numel(theirs));
count = abs(numel(mine) - numel(theirs)) + sum(mine(1:n) ~= theirs(1:n));
end


function text = join_counts(values)
if isempty(values)
    text = '없음';
else
    text = char(strjoin(string(values(:)'), ', '));
end
end


function show(lines)
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end


function text = yes_no(flag)
text = '아니오';
if flag, text = '예'; end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
