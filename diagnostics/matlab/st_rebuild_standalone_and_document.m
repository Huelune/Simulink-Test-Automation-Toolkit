function st_rebuild_standalone_and_document(lines, title)
%ST_REBUILD_STANDALONE_AND_DOCUMENT Make the standalone pipeline, team tree and final document again, then read the defects.
%
% st_rebuild_standalone_and_document()
% st_rebuild_standalone_and_document(lines, title)
%
% Steps 3 to 5 of the manual from the current step 1 results.
%   1. Called alone: runs the defect criteria unit tests and stops when a
%      model has unsaved changes. Called with lines (st_rebuild_all, right
%      after step 1) it does neither: the caller tested and checked before
%      deleting anything, and step 1 leaves its own models for the pipeline,
%      which saves and closes them.
%   2. Runs st_run_standalone_coverage_pipeline('SaveTestResult', true) with
%      its progress on screen, then from that run st_check_standalone_coverage
%      (its code), st_classify_standalone_results (file counts) and
%      st_export_final_document.
%   3. Closes the models the run left open, unsaved changes discarded; the
%      count of such models is shown.
%   4. Hands the lines to st_check_defect_criteria with the standalone part:
%      saved coverage, and each run's iteration outcomes and defect kinds.
% lines go under the title. No names reach the screen; long error reports
% go to tempdir/st_todo_check.txt.
alone = nargin == 0;
if nargin < 1, lines = {}; end
if nargin < 2, title = 'standalone·최종 문서 다시 만들기'; end
cfg = st_config();
st_log(cfg, 'INFO', 'Standalone and final document rebuild start | alone %d', alone);
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
results = [];
checkCode = '';
classified = [];
if alone
    testFile = fullfile(st_project_root(), 'tests', 'unit', 'test_defect_criteria.m');
    try
        evalc('results = runtests(testFile);');
        lines{end+1} = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d | 미완료 %d', numel(results), ...
            sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));
        failed = results([results.Failed] | [results.Incomplete]);
        for k = 1:numel(failed), lines{end+1} = sprintf('  실패 | %s', failed(k).Name); end %#ok<AGROW>
    catch ME
        lines{end+1} = sprintf('단위 테스트 | 실행 오류 | %s', id_of(ME));
    end

    loaded = find_system('type', 'block_diagram');
    if ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
        stop(lines, title, '저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요');
        st_log(cfg, 'WARN', 'Standalone and final document rebuild stopped | unsaved models');
        return;
    end
end

pipelineInfo = [];
try
    pipelineInfo = st_run_standalone_coverage_pipeline('SaveTestResult', true);
    lines{end+1} = sprintf('standalone 파이프라인 OK | 상태 %s', char(string(pipelineInfo.Status)));
catch ME
    lines{end+1} = sprintf('standalone 파이프라인 실패 | %s | 실행 로그(result/logs)를 보세요', id_of(ME));
    lines{end+1} = write_report(ME, 'standalone 파이프라인');
end
if ~isempty(pipelineInfo)
    try
        evalc('checkCode = st_check_standalone_coverage(''PipelineId'', pipelineInfo.PipelineId);');
        lines{end+1} = sprintf('standalone 점검 코드 %s (모두 1이어야 함)', char(string(checkCode)));
    catch ME
        lines{end+1} = sprintf('standalone 점검 실패 | %s', id_of(ME));
        lines{end+1} = write_report(ME, 'standalone 점검');
    end
    try
        evalc('classified = st_classify_standalone_results(''PipelineId'', pipelineInfo.PipelineId);');
        lines{end+1} = sprintf('4단계 분류 OK | CUT %d | 테스트 케이스 %d | 보고서 %d | 프로젝트 %d | 건너뜀 %d', ...
            numel(classified.CutFolders), classified.TestCaseFiles, classified.ReportFiles, ...
            classified.ProjectFiles, numel(classified.Skipped));
    catch ME
        lines{end+1} = sprintf('4단계 분류 실패 | %s', id_of(ME));
        lines{end+1} = write_report(ME, '4단계 분류');
    end
    try
        evalc('st_export_final_document(''CoveragePipelineId'', pipelineInfo.PipelineId);');
        lines{end+1} = '최종 문서 OK';
    catch ME
        lines{end+1} = sprintf('최종 문서 실패 | %s', id_of(ME));
        lines{end+1} = write_report(ME, '최종 문서');
    end
end

% st_check_defect_criteria stops on unsaved models; what the run left is not the user's work.
loaded = find_system('type', 'block_diagram');
if ~isempty(loaded)
    dirty = sum(strcmp(get_param(loaded, 'Dirty'), 'on'));
    bdclose('all');
    if dirty > 0
        lines{end+1} = sprintf('실행 뒤 저장 안 된 모델 %d개를 저장하지 않고 닫음', dirty);
        st_log(cfg, 'WARN', 'Standalone and final document rebuild | closed %d unsaved models', dirty);
    end
end
st_log(cfg, 'INFO', 'Standalone and final document rebuild complete | pipeline %d', ~isempty(pipelineInfo));
st_check_defect_criteria(lines, title, true);
end


function stop(lines, title, message)
clc;
lines = [{sprintf('MATLAB %s | %s', version('-release'), title)}, reshape(lines, 1, []), {message}];
fprintf('%s\n', lines{:});
end


function line = write_report(ME, stage)
%WRITE_REPORT Append the full report; return the screen line that points at it.
line = sprintf('  %s 오류 전문: st_todo_check.txt (임시 폴더)', stage);
fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
if fid < 0, line = sprintf('  %s 오류 전문을 쓰지 못함', stage); return; end
fprintf(fid, '[%s]\n%s\n\n', stage, getReport(ME, 'extended', 'hyperlinks', 'off'));
fclose(fid);
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
