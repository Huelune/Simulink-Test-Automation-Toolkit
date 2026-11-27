function st_inspect_custom_code()
%ST_INSPECT_CUSTOM_CODE Why a failed target's Harness cannot find a C header, in counts.
%
% For todo.md; it changes nothing (models load, compile and close unsaved).
% For each target the latest PER_CUT run marked EXCEPT:
%   - CUT blocks that need a C build: C Caller, C Function, S-Function
%     (with and without a compiled MEX), MATLAB Function, Stateflow chart,
%     Model reference; whether the CUT is a library link.
%   - Custom code settings (Simulation Target) of the Top Model, the Harness
%     and, for a library link, the library: which are set, how many include
%     folders and sources exist (relative paths resolved from the model
%     folder), and which settings differ between Top Model and Harness.
%   - How many headers that the Top Model's header code includes are found
%     in the model folder, its include folders or on the MATLAB path.
%   - Whether a MATLAB project is open, and how many .prj files sit in the
%     model folder or the three folders above it.
%   - Whether the Top Model itself builds from the short build folder.
% Counts, block types, MathWorks parameter names and fixed words only.
title = 'C 코드 설정 보기';
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
cfg = st_config();
st_log(cfg, 'INFO', 'Custom code inspection start');
lines = {sprintf('MATLAB %s | %s', version('-release'), title)};
try
    latest = jsondecode(fileread(cfg.PerCutLatestPointer));
    manifest = jsondecode(fileread(char(string(latest.Manifest))));
    records = manifest.Targets;
    if iscell(records), records = [records{:}]; end
    failedNo = [records(string({records.Status}) == "EXCEPT").No];
    evalc('cfg = st_require_runtime_target();');
    targets = st_load_targets(cfg.OnlyEnabled);
catch ME
    show([lines, {sprintf('준비 실패 | %s', ME.identifier)}]);
    return;
end
loaded = find_system('type', 'block_diagram');
if ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
    show([lines, {'저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요'}]);
    return;
end
modelFolder = fileparts(char(string(cfg.ModelFile)));
topSettings = custom_settings(cfg.TopModel, modelFolder);
lines{end+1} = ['Top Model Custom Code | ' topSettings.Text];
lines{end+1} = ['Top Model #include | ' header_text(cfg.TopModel, topSettings, modelFolder)];
lines{end+1} = project_text(modelFolder);
for no = reshape(failedNo, 1, [])
    row = targets(double(targets.No) == double(no), :);
    if height(row) ~= 1, continue; end
    lines = [lines, inspect_target(cfg, row, topSettings, modelFolder)]; %#ok<AGROW>
end
lines{end+1} = ['Top Model 짧은 폴더 컴파일 | ' compile_text(cfg, cfg.TopModel)];
st_log(cfg, 'INFO', 'Custom code inspection end | targets %d', numel(failedNo));
show(lines);
end


function lines = inspect_target(cfg, row, topSettings, modelFolder)
no = double(row.No);
owner = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
blockLines = block_text(owner);
lines = {sprintf('대상 %g | CUT 블록 | %s', no, blockLines{1}), ['  ' blockLines{2}]};
link = 'none';
try, link = get_param(owner, 'LinkStatus'); catch, end
lines{end+1} = sprintf('  CUT 라이브러리 링크 | %s', link);
if any(strcmp(link, {'resolved', 'implicit'}))
    try
        library = strtok(get_param(owner, 'ReferenceBlock'), '/');
        load_system(library);
        librarySettings = custom_settings(library, fileparts(get_param(library, 'FileName')));
        lines{end+1} = ['  라이브러리 Custom Code | ' librarySettings.Text];
    catch ME
        lines{end+1} = sprintf('  라이브러리 Custom Code 읽기 실패 | %s', ME.identifier);
    end
end
harness = char(row.HarnessName);
try
    sltest.harness.load(owner, harness);
    closeHarness = onCleanup(@() close_quiet(owner, harness)); %#ok<NASGU>
    harnessSettings = custom_settings(harness, modelFolder);
    lines{end+1} = ['  Harness Custom Code | ' harnessSettings.Text];
    different = topSettings.Names(~cellfun(@isequal, topSettings.Values, harnessSettings.Values));
    if isempty(different)
        lines{end+1} = '  Top Model과 다른 설정 | 없음';
    else
        lines{end+1} = ['  Top Model과 다른 설정 | ' strjoin(different, ', ')];
    end
catch ME
    lines{end+1} = sprintf('  Harness 읽기 실패 | %s', ME.identifier);
end
end


function settings = custom_settings(model, folder)
% The Simulation Target custom code settings, raw for comparison and as a
% count line. Relative paths resolve from the model folder (Simulink rule).
names = {'SimCustomHeaderCode', 'SimCustomSourceCode', 'SimUserIncludeDirs', 'SimUserSources', ...
    'SimUserLibraries', 'SimUserDefines', 'SimCustomInitializer', 'SimCustomTerminator'};
values = cell(size(names));
for k = 1:numel(names)
    try, values{k} = strtrim(char(string(get_param(model, names{k})))); catch, values{k} = '(없음)'; end
end
settings = struct('Names', {names}, 'Values', {values}, 'IncludeDirs', {{}});
[dirs, existing, relative] = path_list(values{3}, folder);
settings.IncludeDirs = dirs(existing);
[sources, sourceExisting] = path_list(values{4}, folder);
[libraries, libraryExisting] = path_list(values{5}, folder);
settings.Text = sprintf(['헤더 코드 %s | 소스 코드 %s | include 폴더 %d(상대 %d, 없음 %d) | ' ...
    '소스 %d(없음 %d) | 라이브러리 %d(없음 %d)'], yes_no(values{1}), yes_no(values{2}), ...
    numel(dirs), sum(relative), sum(~existing), numel(sources), sum(~sourceExisting), ...
    numel(libraries), sum(~libraryExisting));
end


function [paths, existing, relative] = path_list(text, folder)
items = regexp(text, '"[^"]+"|[^\s;,]+', 'match');
paths = strrep(items, '"', '');
existing = false(size(paths));
relative = false(size(paths));
for k = 1:numel(paths)
    relative(k) = ~java.io.File(paths{k}).isAbsolute();
    if relative(k), paths{k} = fullfile(folder, paths{k}); end
    existing(k) = isfolder(paths{k}) || isfile(paths{k});
end
end


function text = header_text(model, settings, folder)
code = '';
try, code = char(string(get_param(model, 'SimCustomHeaderCode'))); catch, end
headers = regexp(code, '#include\s*[<"]([^>"]+)[>"]', 'tokens');
found = 0;
for k = 1:numel(headers)
    name = headers{k}{1};
    places = [{folder}, settings.IncludeDirs];
    hit = any(cellfun(@(place) isfile(fullfile(place, name)), places)) || ~isempty(which(name));
    found = found + hit;
end
text = sprintf('헤더 %d개 | 찾음 %d | 못 찾음 %d', numel(headers), found, numel(headers) - found);
end


function text = block_text(owner)
% Two lines: C build blocks, then charts, references and links.
blocks = find_system(owner, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Block');
types = string(get_param(blocks, 'BlockType'));
sfTypes = strings(size(types));
for k = find(types == "SubSystem")'
    try, sfTypes(k) = string(get_param(blocks{k}, 'SFBlockType')); catch, end
end
mex = 0;
for k = find(types == "S-Function")'
    try, mex = mex + (exist(get_param(blocks{k}, 'FunctionName'), 'file') == 3); catch, end
end
links = 0;
for k = 1:numel(blocks)
    try, links = links + any(strcmp(get_param(blocks{k}, 'LinkStatus'), {'resolved', 'implicit'})); catch, end
end
text = {sprintf('C Caller %d | C Function %d | S-Function %d(MEX 있음 %d)', sum(types == "CCaller"), ...
    sum(types == "CFunction"), sum(types == "S-Function"), mex), ...
    sprintf('MATLAB Function %d | Stateflow 차트 %d | Model 참조 %d | 안쪽 라이브러리 링크 %d', ...
    sum(sfTypes == "MATLAB Function"), sum(sfTypes == "Chart"), sum(types == "ModelReference"), links)};
end


function text = project_text(folder)
isOpen = '아니오';
try
    if ~isempty(matlab.project.rootProject), isOpen = '예'; end
catch
end
count = 0;
current = folder;
for k = 1:4
    count = count + numel(dir(fullfile(current, '*.prj')));
    parent = fileparts(current);
    if strcmp(parent, current), break; end
    current = parent;
end
text = sprintf('MATLAB 프로젝트 | 열림 %s | 모델 폴더와 위 3단계의 .prj %d개', isOpen, count);
end


function text = compile_text(cfg, model)
shortBuild = []; %#ok<NASGU>
compiled = false;
try
    shortBuild = st_enter_short_build_directory(cfg, 'INSPECT'); %#ok<NASGU>
    feval(model, [], [], [], 'compile');
    compiled = true;
    text = 'OK';
catch ME
    text = ['실패 | ' st_build_error_kind(ME)];
    fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
    if fid >= 0
        fprintf(fid, '[C 코드 설정 보기 Top Model 컴파일]\n%s\n\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        fclose(fid);
    end
end
if compiled
    try, feval(model, [], [], [], 'term'); catch, end
end
clear shortBuild
end


function text = yes_no(value)
text = '없음';
if ~isempty(value) && ~strcmp(value, '(없음)'), text = '있음'; end
end


function close_quiet(owner, harness)
try, sltest.harness.close(owner, harness); catch, end
end


function show(lines)
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end
