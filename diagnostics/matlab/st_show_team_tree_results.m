function st_show_team_tree_results(folder, extraLines)
%ST_SHOW_TEAM_TREE_RESULTS Open a team submission tree's results in Test Manager, wherever the tree is.
%
% st_show_team_tree_results            % choose the tree in a dialog
% st_show_team_tree_results(folder)
%
% The tree (st_classify_standalone_results) holds 테스트 케이스, 테스트 보고서
% and 프로젝트. Everything below is read from the tree itself, so a tree
% moved or copied elsewhere opens the same; nothing in it is changed.
%   - 테스트 보고서/StandaloneCoverageResults.mldatx is the run's saved Test
%     Manager result: Test Manager is cleared, the result imported and shown.
%     Its coverage values carry no CVF, as in step 6.
%   - Each CUT folder: the standalone model from 프로젝트/<CUT> is loaded and
%     its saved coverage (CVT) with its CVF goes to a report in the browser
%     (written to tempdir) and highlights the model.
% A folder inside the tree is taken for the tree. Stops when a model has
% unsaved changes; otherwise closes open models first, since a model of the
% same name loaded from elsewhere would be used instead of the tree's.
% extraLines go under the title. One line per Test Case: iterations by
% outcome. Counts and fixed messages only.
if nargin < 1, folder = ''; end
if nargin < 2, extraLines = {}; end
title = '팀 제출 트리 결과 보기';
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
cfg = st_config();
st_log(cfg, 'INFO', 'Team tree results view start');
lines = [{sprintf('MATLAB %s | %s', version('-release'), title)}, reshape(extraLines, 1, [])];
report = 'st_team_tree_results.txt';

if strlength(string(folder)) == 0
    folder = uigetdir(pwd, '팀 제출 트리 폴더(테스트 보고서가 든 폴더)를 고르세요');
    if isequal(folder, 0)
        show([lines, {'폴더를 고르지 않아 멈췄습니다'}]);
        return;
    end
end
root = tree_root(char(folder));
if isempty(root)
    show([lines, {'팀 제출 트리가 아닙니다 | 테스트 보고서 폴더가 든 트리(또는 그 안의 폴더)를 고르세요'}]);
    return;
end
reportDir = fullfile(root, '테스트 보고서');
resultFile = fullfile(reportDir, 'StandaloneCoverageResults.mldatx');
cuts = dir(reportDir);
cuts = cuts([cuts.isdir] & ~ismember({cuts.name}, {'.', '..'}));
lines{end+1} = sprintf('고른 폴더 | 팀 제출 트리 | CUT 폴더 %d | Test Manager 결과 파일 %s', ...
    numel(cuts), yes_no(isfile(resultFile)));
if ~isfile(resultFile)
    lines{end+1} = ['Test Manager 결과가 트리에 없습니다 | 결과를 저장한 실행으로 4단계 분류를 다시 하고 ' ...
        '트리를 다시 옮기세요'];
    show(lines);
    return;
end

loaded = find_system('type', 'block_diagram');
if ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
    show([lines, {'저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요'}]);
    return;
end
if ~isempty(loaded), bdclose('all'); end

% Variables that evalc assigns are named first, or MATLAB may take them for functions.
imported = [];
try
    evalc('sltest.testmanager.clearResults; sltest.testmanager.clear;');
    evalc('imported = sltest.testmanager.importResults(resultFile);');
    sltest.testmanager.view;
    caseResults = st_collect_test_case_results(imported);
    lines{end+1} = sprintf('Test Manager 결과 가져옴 | Test Case %d', numel(caseResults));
    for k = 1:numel(caseResults)
        iterations = getIterationResults(caseResults{k});
        outcomes = strings(numel(iterations), 1);
        for j = 1:numel(iterations), outcomes(j) = string(iterations(j).Outcome); end
        lines{end+1} = sprintf('  Test Case %d | Iteration %d | 통과 %d | 실패 %d', k, ...
            numel(iterations), sum(outcomes == "Passed"), sum(outcomes == "Failed")); %#ok<AGROW>
    end
catch ME
    lines{end+1} = sprintf('Test Manager 결과 가져오기 실패 | %s', id_of(ME));
    write_report(report, ME);
end

ok = 0;
failed = strings(0, 1);
for k = 1:numel(cuts)
    try
        coverage_report(root, cuts(k).name);
        ok = ok + 1;
    catch ME
        failed(end+1, 1) = string(id_of(ME)); %#ok<AGROW>
        write_report(report, ME);
    end
end
lines{end+1} = sprintf('CVF 적용 보고서 | OK %d | 실패 %d', ok, numel(failed));
for id = unique(failed, 'stable')'
    lines{end+1} = sprintf('  실패 | %s | %d개', id, sum(failed == id)); %#ok<AGROW>
end
if ~isempty(failed)
    lines{end+1} = sprintf('  전문 %s (임시 폴더, 밖으로 보내지 않음)', report);
end
lines{end+1} = 'Test Manager의 Coverage 값은 CVF가 빠진 값입니다. CVF를 건 값은 브라우저 보고서와 모델 색 표시로 보세요';
st_log(cfg, 'INFO', 'Team tree results view end | CUT %d | reports %d', numel(cuts), ok);
show(lines);
end


function coverage_report(root, cut)
% The CUT's standalone model must be loaded from the tree before its
% coverage loads, or a model of that name elsewhere on the path is used.
modelFolder = fullfile(root, '프로젝트', cut);
models = dir(fullfile(modelFolder, '*.slx'));
reportFolder = fullfile(root, '테스트 보고서', cut);
cvt = dir(fullfile(reportFolder, '*.cvt'));
cvf = dir(fullfile(reportFolder, '*.cvf'));
if isempty(models) || isempty(cvt)
    error('simtest:TeamTreeCoverageMissing', 'The CUT folder has no standalone model or saved coverage.');
end
addpath(modelFolder, '-begin');
load_system(fullfile(modelFolder, models(1).name));
[~, data] = cvload(fullfile(reportFolder, cvt(1).name));
if iscell(data), data = data{1}; end
if ~isempty(cvf), data.filter = fullfile(reportFolder, cvf(1).name); end
target = fullfile(tempdir, 'st_team_tree_coverage', cut);
if ~isfolder(target), mkdir(target); end
cvhtml(fullfile(target, 'report.html'), data);
try
    cvmodelview(data);
catch
    % The report already holds the numbers; colouring is a bonus.
end
end


function root = tree_root(folder)
% The chosen folder, or the tree it sits in (up to two levels).
root = '';
current = folder;
for k = 1:3
    if isfolder(fullfile(current, '테스트 보고서'))
        root = current;
        return;
    end
    parent = fileparts(current);
    if isempty(parent) || strcmp(parent, current), return; end
    current = parent;
end
end


function write_report(name, ME)
fid = fopen(fullfile(tempdir, name), 'a');
if fid < 0, return; end
fprintf(fid, '%s\n\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
fclose(fid);
end


function text = yes_no(flag)
text = '없음';
if flag, text = '있음'; end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
place = st_error_place(ME);
if ~isempty(place), text = [text ' | ' place]; end
end


function show(lines)
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end
