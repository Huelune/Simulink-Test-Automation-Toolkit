function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 7. Run the bundle and pipeline unit tests, run the standalone
% pipeline again with the input rebase fix, rebuild the final document from
% it, and count loose lines in the Harness and standalone models.
clc;
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | standalone pipeline rerun');
reportFile = fullfile(tempdir, 'st_todo_check.txt');
lines = {};
report = "";
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
pipelineInfo = [];
results = [];
files = fullfile(st_project_root(), 'tests', 'unit', ...
    {'test_export_bundle.m', 'test_standalone_coverage_pipeline.m'});
try
    evalc('results = runtests(files);');
    lines{end+1} = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d | 미완료 %d', numel(results), ...
        sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));
    failed = results([results.Failed] | [results.Incomplete]);
    for k = 1:numel(failed), lines{end+1} = sprintf('  실패 | %s', failed(k).Name); end %#ok<AGROW>
catch ME
    lines{end+1} = sprintf('단위 테스트 | 실행 오류 | %s', id_of(ME));
end
try
    evalc('pipelineInfo = st_run_standalone_coverage_pipeline(''SaveTestResult'', true);');
    lines{end+1} = sprintf('standalone 파이프라인 OK | 상태 %s', char(string(pipelineInfo.Status)));
catch ME
    lines{end+1} = sprintf('standalone 파이프라인 실패 | %s', id_of(ME));
    report = report + sprintf("[standalone 파이프라인]\n%s\n\n", getReport(ME, 'extended', 'hyperlinks', 'off'));
end
if ~isempty(pipelineInfo)
    try
        evalc('st_export_final_document(''CoveragePipelineId'', pipelineInfo.PipelineId);');
        lines{end+1} = '최종 문서 OK';
    catch ME
        lines{end+1} = sprintf('최종 문서 실패 | %s', id_of(ME));
        report = report + sprintf("[최종 문서]\n%s\n\n", getReport(ME, 'extended', 'hyperlinks', 'off'));
    end
end
if strlength(report) > 0
    fid = fopen(reportFile, 'w');
    if fid >= 0
        fprintf(fid, '%s', report);
        fclose(fid);
    end
    lines{end+1} = '파이프라인·최종 문서 오류 전문: st_todo_check.txt (임시 폴더)';
end
st_log(cfg, 'INFO', 'todo check complete | pipeline %d', ~isempty(pipelineInfo));
st_compare_harness_cut(lines);
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
