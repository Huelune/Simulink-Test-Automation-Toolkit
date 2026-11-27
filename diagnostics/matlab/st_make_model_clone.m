function st_make_model_clone()
%ST_MAKE_MODEL_CLONE Make a toolkit clone for another model, next to this one.
%
% One clone remembers one model: runtime_target.mat (the model and the
% standalone root), TestManagement.xlsx and result/ (latest pointers and
% workflow state; a start from nothing deletes all of it). So each model
% gets its own clone. Steps:
%   1. Asks for the new folder's name. It goes next to this clone, since the
%      toolkit looks for models below the folder above the clone.
%   2. git clone from this clone (on disk, no sign-in), then origin points
%      at this clone's origin, so later pulls come from the same remote.
%   3. Moves the current folder into the new clone and runs its st_setup,
%      which takes this clone off the MATLAB path. The current folder stays
%      there, since st_project_root reads the current folder first.
%   4. st_select_target_model(true) there (choose the other model), then
%      the standalone root the way this clone has it.
% TestManagement.xlsx is not tracked, so the new clone has none; the screen
% says so. Counts and fixed messages only; git's output and error reports
% go to tempdir/st_todo_check.txt.
title = '두 번째 모델용 클론 만들기';
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
cfg = st_config();
st_log(cfg, 'INFO', 'Model clone start');
lines = {sprintf('MATLAB %s | %s', version('-release'), title)};
root = st_absolute_path(st_project_root());
[parent, name, extension] = fileparts(root);
oldModel = cfg.TopModel;

answer = inputdlg({'새 클론 폴더 이름 (지금 클론 옆에 만듭니다)'}, title, [1 60], {[name extension '_2']});
if isempty(answer)
    stop(cfg, lines, '폴더 이름을 넣지 않아 멈췄습니다', 'no name');
    return;
end
newName = strtrim(answer{1});
if isempty(newName) || any(ismember(newName, '\/:*?"<>|'))
    stop(cfg, lines, '폴더 이름이 비었거나 쓸 수 없는 글자(\ / : * ? " < > |)가 있습니다', 'bad name');
    return;
end
destination = fullfile(parent, newName);
if isfolder(destination) || isfile(destination)
    stop(cfg, lines, '지금 클론 옆에 그 이름이 이미 있습니다. 다른 이름으로 다시 돌리세요', 'exists');
    return;
end

[status, url] = git(root, 'remote get-url origin');
if status ~= 0
    stop(cfg, lines, ['원격 주소를 읽지 못했습니다. cmd에서 git이 되는지, 지금 클론에 원격이 있는지 보세요 | ' ...
        'git 출력 st_todo_check.txt (임시 폴더)'], 'remote', url);
    return;
end
[status, output] = system(sprintf('git clone --no-hardlinks "%s" "%s"', root, destination));
if status == 0
    [status, output] = git(destination, sprintf('remote set-url origin "%s"', strtrim(url)));
end
if status ~= 0
    stop(cfg, lines, '복제 실패 | git 출력 st_todo_check.txt (임시 폴더)', 'clone', output);
    return;
end
[~, branch] = git(destination, 'rev-parse --abbrev-ref HEAD');
branchText = 'main';
if ~strcmp(strtrim(branch), 'main'), branchText = 'main 아님(새 클론에서 git checkout main)'; end
lines{end+1} = sprintf('새 클론 | 지금 클론 옆에 만듦 | 원격 연결 OK | 브랜치 %s', branchText);

before = numel(entries_under(root));
try
    cd(destination);
    clear st_setup st_config st_project_root
    evalc('st_setup');
catch ME
    report(ME, 'st_setup');
    stop(cfg, lines, sprintf(['새 클론 st_setup 실패 %s | 새 클론은 만들어졌습니다. 그 폴더로 옮겨 st_setup을 하세요 | ' ...
        '전문 st_todo_check.txt (임시 폴더)'], id_of(ME)), 'setup');
    return;
end
lines{end+1} = sprintf('MATLAB 경로 | 지금 클론 항목 %d개 뺌 | 새 클론 올림 | 현재 폴더 새 클론', ...
    before - numel(entries_under(root)));

% Variables that evalc assigns are named first, or MATLAB may take them for functions.
newCfg = [];
chosen = false;
try
    evalc('newCfg = st_select_target_model(true);');
    chosen = newCfg.HasRuntimeTarget;
catch ME
    lines{end+1} = sprintf('모델 | 고르지 못함 %s | 새 클론에서 st_select_target_model(true)를 다시 하세요', id_of(ME));
    report(ME, '모델 고르기');
end
same = chosen && strcmp(newCfg.TopModel, oldModel);
if chosen && ~same
    lines{end+1} = '모델 | 고름 | 지금 클론과 다른 모델';
    lines{end+1} = ['결과 루트 | ' set_root(cfg, root, oldModel, newCfg.TopModel)];
elseif same
    lines{end+1} = '모델 | 지금 클론과 같은 모델이라 결과 루트를 정하지 않음 | 새 클론에서 st_select_target_model(true)';
end
if isfile(fullfile(destination, 'TestManagement.xlsx'))
    lines{end+1} = 'TestManagement.xlsx | 있음';
else
    lines{end+1} = 'TestManagement.xlsx | 없음 | 새 모델의 CUT 목록 파일을 새 클론 폴더에 두세요(지금 것을 복사해 고쳐도 됨)';
end
lines{end+1} = '다음 | 새 클론의 git pull은 지금처럼 cmd에서 | 지금 클론으로 돌아갈 때는 그 클론을 툴킷 폴더로 고르고 st_setup';
st_log(pick_cfg(cfg, newCfg), 'INFO', 'Model clone end | ModelChosen=%d | SameModel=%d', chosen, same);
show(lines);
end


function text = set_root(cfg, root, oldModel, newModel)
% The new clone keeps this clone's way: the clone's own result folder, a
% folder named after the model next to this clone's, or the default.
current = st_absolute_path(cfg.StandaloneCoverageRootDir);
if strcmpi(current, st_absolute_path(fullfile(root, 'result', 'standalone_coverage')))
    text = '클론 안 result 폴더(지금 클론과 같은 방식)';
    return;
end
[currentParent, currentName, currentExtension] = fileparts(current);
try
    if strcmpi([currentName currentExtension], oldModel)
        evalc('st_set_standalone_coverage_root(fullfile(currentParent, newModel));');
        text = '지금 클론의 결과 루트 옆, 모델 이름 폴더';
    else
        evalc('st_set_standalone_coverage_root;');
        text = '기본(D:\model_result\<Top Model>)';
    end
catch ME
    text = sprintf('정하지 못함 %s | 새 클론에서 st_set_standalone_coverage_root를 하세요', id_of(ME));
    report(ME, '결과 루트');
end
end


function entries = entries_under(folder)
entries = strsplit(path, pathsep);
entries = entries(strcmpi(entries, folder) | startsWith(lower(entries), lower([folder filesep])));
end


function [status, output] = git(folder, arguments)
[status, output] = system(sprintf('git -C "%s" %s', folder, arguments));
end


function stop(cfg, lines, message, kind, output)
lines{end+1} = message;
if nargin > 4
    fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
    if fid >= 0
        fprintf(fid, '[두 번째 모델용 클론 만들기 | %s]\n%s\n\n', kind, output);
        fclose(fid);
    end
end
st_log(cfg, 'WARN', 'Model clone stopped | %s', kind);
show(lines);
end


function report(ME, step)
fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
if fid >= 0
    fprintf(fid, '[두 번째 모델용 클론 만들기 | %s]\n%s\n\n', step, ...
        getReport(ME, 'extended', 'hyperlinks', 'off'));
    fclose(fid);
end
end


function cfg = pick_cfg(cfg, newCfg)
if isstruct(newCfg), cfg = newCfg; end
end


function show(lines)
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
