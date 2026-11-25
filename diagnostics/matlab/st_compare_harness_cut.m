function st_compare_harness_cut()
%ST_COMPARE_HARNESS_CUT Compare each target's CUT in the Top Model with the CUT in its Harness.
%
% st_compare_harness_cut
%
% Input lines inside a Harness's CUT were drawn unconnected (red dashed)
% while the same lines in the Top Model's CUT are connected (2026-11-25).
% Test runs happen in the Harness, so those inputs read 0 there. For every
% target with a Harness this counts the line ends that meet no port in both
% CUTs. For the ends found only in the Harness it reports, by Simulink block
% type, the block that receives the line, the block that feeds it in the Top
% Model, that block's output port count in each model, and its library link
% status in each model. It also prints the Harness synchronization settings.
%
% Nothing is saved. A Dirty flag the Top Model gets from loading a Harness is
% cleared. Only counts, block types and setting values are printed, never a
% model, block or file name. Full error reports go to
% st_harness_cut_compare.txt in tempdir.

clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
diagFile = 'st_harness_cut_compare.txt';
lines = {sprintf('MATLAB %s | Harness CUT 비교', version('-release'))};
report = "";
cfg = [];
try
    loadedNames = find_system('type', 'block_diagram');
    if ~isempty(loadedNames) && any(strcmp(get_param(loadedNames, 'Dirty'), 'on'))
        fprintf('저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요\n');
        return;
    end
    % A packaged standalone model carries a Harness's name; it must not be loaded.
    bdclose('all');
    cfg = st_require_runtime_target();
    st_log(cfg, 'INFO', 'Harness CUT compare start');
    % Variables that evalc assigns are named first, or MATLAB may take them for functions.
    config = table();
    evalc('config = st_resolve_target_cut_paths(st_load_targets(cfg.OnlyEnabled), cfg);');
    if ~ismember('HarnessName', config.Properties.VariableNames)
        error('simtest:CompareNoHarness', '대상 목록에 Harness 이름 열이 없습니다');
    end
    config = config(strlength(strtrim(string(config.HarnessName))) > 0, :);
    if height(config) == 0
        error('simtest:CompareNoHarness', 'Harness가 있는 대상이 없습니다');
    end
    topWasDirty = strcmp(get_param(cfg.TopModel, 'Dirty'), 'on');
    for r = 1:height(config)
        [targetLines, targetReport] = compare_target(config(r, :), cfg);
        lines = [lines, targetLines]; %#ok<AGROW>
        report = report + targetReport;
    end
    if ~topWasDirty && strcmp(get_param(cfg.TopModel, 'Dirty'), 'on')
        set_param(cfg.TopModel, 'Dirty', 'off');
        lines{end+1} = 'Harness를 불러오며 Top Model에 생긴 Dirty 표시를 지웠습니다(저장하지 않음)';
    end
    st_log(cfg, 'INFO', 'Harness CUT compare complete | targets=%d', height(config));
catch ME
    lines{end+1} = sprintf('실패 | %s%s', id_of(ME), own_reason(ME));
    report = report + sprintf("[전체]\n%s\n\n", getReport(ME, 'extended', 'hyperlinks', 'off'));
    if ~isempty(cfg)
        st_log(cfg, 'ERROR', 'Harness CUT compare failed | %s', ME.identifier);
    end
end
if strlength(report) > 0
    fid = fopen(fullfile(tempdir, diagFile), 'w');
    if fid >= 0
        fprintf(fid, '%s', report);
        fclose(fid);
    end
end
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
if strlength(report) > 0, fprintf('진단 전문 파일: %s (임시 폴더)\n', diagFile); end
end


function [out, report] = compare_target(row, cfg)
no = double(row.No);
out = {};
report = "";
harness = char(strtrim(string(row.HarnessName)));
owner = '';
loadedHere = false;
try
    owner = char(st_normalize_cut_path(row.CUTPath, cfg.TopModel));
    original = dangling_ends(owner);
    settings = harness_settings(owner, harness);
    loadedHere = ~bdIsLoaded(harness);
    sltest.harness.load(owner, harness);
    harnessCut = [harness '/' strrep(get_param(owner, 'Name'), '/', '//')];
    if getSimulinkBlockHandle(harnessCut) == -1
        error('simtest:CompareNoHarnessCut', 'Harness에 CUT 이름의 블록이 없습니다');
    end
    inHarness = dangling_ends(harnessCut);
    only = setdiff(inHarness, original);
    out{end+1} = sprintf('대상 %d | 끊긴 선 끝 원래 CUT %d | Harness CUT %d | Harness에만 %d', ...
        no, numel(original), numel(inHarness), numel(only));
    out{end+1} = sprintf('대상 %d Harness 설정 | %s', no, settings);
    groups = describe_only(only, owner, harnessCut);
    for k = 1:min(6, numel(groups)), out{end+1} = ['  ' groups{k}]; end %#ok<AGROW>
    if numel(groups) > 6, out{end+1} = sprintf('  그 밖 %d가지', numel(groups) - 6); end
catch ME
    out{end+1} = sprintf('대상 %d 실패 | %s%s', no, id_of(ME), own_reason(ME));
    report = sprintf("[대상 %d]\n%s\n\n", no, getReport(ME, 'extended', 'hyperlinks', 'off'));
end
if loadedHere && ~isempty(owner)
    try
        sltest.harness.close(owner, harness);
    catch
    end
end
end


function keys = dangling_ends(cut)
% One key per port that a line with a loose end still meets:
% "in|<receiving block>|<port type><n>" for a line with no source,
% "out|<sending block>|<n>" for a line that reaches no block, and
% "loose|<system>" for a line with neither end on a port. Block and system
% paths are relative to cut, so the two models can be compared.
keys = strings(0, 1);
handles = find_system(cut, 'FindAll', 'on', 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'Type', 'line');
for h = reshape(handles, 1, [])
    src = get_param(h, 'SrcPortHandle');
    dst = get_param(h, 'DstPortHandle');
    connected = dst(dst ~= -1);
    if any(src == -1)
        for d = reshape(connected, 1, [])
            keys(end+1, 1) = "in|" + relative(get_param(d, 'Parent'), cut) + "|" + ...
                string(get_param(d, 'PortType')) + string(get_param(d, 'PortNumber')); %#ok<AGROW>
        end
        if isempty(connected)
            keys(end+1, 1) = "loose|" + relative(get_param(h, 'Parent'), cut); %#ok<AGROW>
        end
    elseif any(dst == -1)
        keys(end+1, 1) = "out|" + relative(get_param(src, 'Parent'), cut) + "|" + ...
            string(get_param(src, 'PortNumber')); %#ok<AGROW>
    end
end
keys = unique(keys);
end


function out = describe_only(only, owner, harnessCut)
% Group the Harness-only loose ends by what they look like, as kinds only.
kinds = strings(0, 1);
for key = reshape(only, 1, [])
    parts = split(key, "|");
    switch parts(1)
        case "in"
            [srcType, outs, links] = original_source(owner, harnessCut, parts(2), parts(3));
            kinds(end+1, 1) = sprintf("끊긴 입력 | 받는 %s | 원래 보내는 %s | 출력 포트 %s | 링크 %s", ...
                block_type(join_path(harnessCut, parts(2))), srcType, outs, links); %#ok<AGROW>
        case "out"
            kinds(end+1, 1) = sprintf("받는 쪽 없음 | 보내는 %s", ...
                block_type(join_path(harnessCut, parts(2)))); %#ok<AGROW>
        otherwise
            kinds(end+1, 1) = "양 끝 모두 끊김"; %#ok<AGROW>
    end
end
[unique_kinds, ~, index] = unique(kinds, 'stable');
counts = accumarray(index(:), 1);
out = cell(1, numel(unique_kinds));
for k = 1:numel(unique_kinds)
    out{k} = sprintf('%d개 | %s', counts(k), unique_kinds(k));
end
end


function [srcType, outs, links] = original_source(owner, harnessCut, rel, port)
% The block feeding this input in the Top Model, and how it differs in the
% Harness: "원래→Harness" for the output port count and the link status.
srcType = "?";
outs = "?";
links = "?";
try
    portType = char(regexp(port, '^[a-z]+', 'match', 'once'));
    number = str2double(regexp(port, '\d+$', 'match', 'once'));
    if ~strcmp(portType, 'inport')
        srcType = "(" + portType + " 포트)";
        return;
    end
    ports = get_param(join_path(owner, rel), 'PortHandles');
    lineHandle = get_param(ports.Inport(number), 'Line');
    sourceBlock = -1;
    if lineHandle ~= -1, sourceBlock = get_param(lineHandle, 'SrcBlockHandle'); end
    if sourceBlock == -1
        srcType = "원래도 없음";
        return;
    end
    srcType = string(get_param(sourceBlock, 'BlockType'));
    sourcePorts = get_param(sourceBlock, 'PortHandles');
    originalLink = string(get_param(sourceBlock, 'LinkStatus'));
    harnessBlock = join_path(harnessCut, relative(getfullname(sourceBlock), owner));
    if getSimulinkBlockHandle(harnessBlock) == -1
        outs = numel(sourcePorts.Outport) + "→Harness에 없음";
        links = originalLink + "→Harness에 없음";
        return;
    end
    harnessPorts = get_param(harnessBlock, 'PortHandles');
    outs = numel(sourcePorts.Outport) + "→" + numel(harnessPorts.Outport);
    links = originalLink + "→" + string(get_param(harnessBlock, 'LinkStatus'));
catch
end
end


function text = harness_settings(owner, harness)
text = '설정을 읽지 못함';
try
    found = sltest.harness.find(owner);
    item = found(strcmp({found.name}, harness));
    if isempty(item)
        text = 'Harness 목록에 없음';
        return;
    end
    item = item(1);
    parts = strings(0, 1);
    for field = {'synchronizationMode', 'rebuildOnOpen', 'saveExternally'}
        if isfield(item, field{1})
            parts(end+1, 1) = string(field{1}) + " " + string(item.(field{1})); %#ok<AGROW>
        end
    end
    text = char(strjoin(parts, ' | '));
catch
end
end


function rel = relative(block, cut)
% Path below cut; "." for cut itself.
block = string(block);
if block == string(cut)
    rel = ".";
else
    rel = extractAfter(block, strlength(string(cut)) + 1);
end
end


function path = join_path(base, rel)
if rel == "."
    path = char(base);
else
    path = char(string(base) + "/" + rel);
end
end


function text = block_type(path)
text = "?";
try
    text = string(get_param(path, 'BlockType'));
catch
end
end


function text = own_reason(ME)
% Only the messages this file wrote are fixed text safe for the screen.
text = '';
if startsWith(ME.identifier, 'simtest:Compare'), text = [' | ' ME.message]; end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
