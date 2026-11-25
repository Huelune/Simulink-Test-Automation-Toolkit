function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 6. Run the bundle and pipeline unit tests again after the two
% stale static tests were brought up to date. Takes seconds; runs no model.
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | bundle unit tests');
fprintf('MATLAB %s | 번들 단위 테스트\n', version('-release'));
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
results = [];
files = fullfile(st_project_root(), 'tests', 'unit', ...
    {'test_export_bundle.m', 'test_standalone_coverage_pipeline.m'});
try
    evalc('results = runtests(files);');
    fprintf('단위 테스트 | %d | 통과 %d | 실패 %d | 미완료 %d\n', numel(results), ...
        sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));
    failed = results([results.Failed] | [results.Incomplete]);
    for k = 1:numel(failed), fprintf('  실패 | %s\n', failed(k).Name); end
catch ME
    fprintf('단위 테스트 | 실행 오류 | %s | 툴킷 폴더에서 st_setup 뒤 다시 돌려 주세요\n', id_of(ME));
end
st_log(cfg, 'INFO', 'todo check complete | tests %d', numel(results));
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
