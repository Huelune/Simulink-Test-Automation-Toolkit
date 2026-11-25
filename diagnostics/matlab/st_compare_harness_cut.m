function st_compare_harness_cut()
%ST_COMPARE_HARNESS_CUT Find unconnected lines in a target's Harness and standalone model.
%
% st_compare_harness_cut
%
% A user saw input lines drawn unconnected (red dashed) in a model reached
% from Test Manager, while the same lines in the Top Model's CUT are
% connected (2026-11-25). Test runs happen in that model, so those inputs
% read 0 there. A first version looked only inside each Harness's CUT and
% found nothing, so this looks at the whole Harness and at the packaged
% standalone model, which carries the Harness's name.
%
% For every target with a Harness it counts the line ends that meet no port:
% inside the Top Model's CUT, inside and outside the Harness's CUT, and
% inside and outside the standalone model's CUT. Ends found only in the
% Harness or standalone CUT, or outside a CUT, are grouped by Simulink block
% type; for an input that is connected in the Top Model it also reports the
% block that feeds it there, that block's output port count in each model,
% and its library link status in each model. It prints the Harness
% synchronization settings.
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
    % A packaged standalone model carries a Harness's name; both cannot be loaded.
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
    [standaloneManifest, standaloneNote] = standalone_targets(cfg);
    if strlength(standaloneNote) > 0, lines{end+1} = char(standaloneNote); end
    topWasDirty = strcmp(get_param(cfg.TopModel, 'Dirty'), 'on');
    for r = 1:height(config)
        [targetLines, targetReport] = compare_target(config(r, :), cfg, standaloneManifest);
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


function [manifest, note] = standalone_targets(cfg)
manifest = [];
note = "";
try
    manifest = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir, 'LATEST');
catch ME
    note = "standalone 매니페스트를 읽지 못함 | " + string(id_of(ME));
end
end


function [out, report] = compare_target(row, cfg, standaloneManifest)
no = double(row.No);
report = "";
harness = char(strtrim(string(row.HarnessName)));
owner = '';
original = strings(0, 1);
counts = nan(1, 5);   % original CUT, Harness CUT, Harness outside, standalone CUT, outside
settings = '-';
groups = {};
harnessInfo = struct('Sources', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'EditorPorts', NaN, 'EditorFile', '-');
standaloneLines = {};
loadedHere = false;
failures = {};
try
    owner = char(st_normalize_cut_path(row.CUTPath, cfg.TopModel));
    original = dangling_ends(owner, owner);
    counts(1) = numel(original);
    settings = harness_settings(owner, harness);
    loadedHere = ~bdIsLoaded(harness);
    sltest.harness.load(owner, harness);
    harnessCut = [harness '/' strrep(get_param(owner, 'Name'), '/', '//')];
    if getSimulinkBlockHandle(harnessCut) == -1
        error('simtest:CompareNoHarnessCut', 'Harness에 CUT 이름의 블록이 없습니다');
    end
    [inside, outside] = dangling_ends(harness, harnessCut);
    counts(2:3) = [numel(inside), numel(outside)];
    harnessInfo = source_side(harness, harnessCut, fileparts(char(cfg.ModelFile)));
    standaloneLines{end+1} = ['Harness Signal Editor | ' harnessInfo.EditorFile];
    groups = [groups, labelled('Harness CUT 안', describe_inside(setdiff(inside, original), owner, harnessCut)), ...
        labelled('Harness CUT 밖', describe_outside(outside, harness, harnessCut))];
catch ME
    failures{end+1} = sprintf('Harness %s%s', id_of(ME), own_reason(ME));
    report = report + sprintf("[대상 %d Harness]\n%s\n\n", no, getReport(ME, 'extended', 'hyperlinks', 'off'));
end
if loadedHere && ~isempty(owner)
    try
        sltest.harness.close(owner, harness);
    catch
    end
end
try
    [groupsHere, standaloneCounts, standaloneNotes] = scan_standalone( ...
        row, standaloneManifest, original, owner, harnessInfo, cfg);
    counts(4:5) = standaloneCounts;
    standaloneLines = [standaloneLines, standaloneNotes];
    groups = [groups, groupsHere];
catch ME
    failures{end+1} = sprintf('standalone %s%s', id_of(ME), own_reason(ME));
    report = report + sprintf("[대상 %d standalone]\n%s\n\n", no, getReport(ME, 'extended', 'hyperlinks', 'off'));
end
out = {strrep(sprintf(['대상 %d | 끊긴 선 끝 | 원래 CUT %g | Harness CUT 안 %g 밖 %g | ' ...
    'standalone CUT 안 %g 밖 %g'], no, counts), 'NaN', '-')};
out{end+1} = sprintf('대상 %d Harness 설정 | %s', no, settings);
for k = 1:numel(failures), out{end+1} = sprintf('대상 %d 실패 | %s', no, failures{k}); end %#ok<AGROW>
for k = 1:numel(standaloneLines), out{end+1} = sprintf('대상 %d %s', no, standaloneLines{k}); end %#ok<AGROW>
for k = 1:min(8, numel(groups)), out{end+1} = ['  ' groups{k}]; end %#ok<AGROW>
if numel(groups) > 8, out{end+1} = sprintf('  그 밖 %d가지', numel(groups) - 8); end
end


function [groups, counts, notes] = scan_standalone(row, manifest, original, owner, harnessInfo, cfg)
% The packaged standalone model of this target, loaded from its own file:
% first from the current folder, as Test Manager would, then from the
% model's own folder, where its relative Signal Editor file name resolves.
groups = {};
counts = [NaN NaN];
notes = {};
if isempty(manifest) || ~isfield(manifest, 'Targets'), return; end
% jsondecode gives a cell array when the target records differ in fields.
items = manifest.Targets;
if ~iscell(items), items = num2cell(items); end
item = [];
for k = 1:numel(items)
    if strcmp(field_of(items{k}, 'TestCaseName'), char(string(row.TestCaseName)))
        item = items{k};
        break;
    end
end
if isempty(item)
    error('simtest:CompareNoStandalone', 'standalone 매니페스트에 이 대상이 없습니다');
end
modelFile = field_of(item, 'PackagedStandaloneModel');
standaloneCut = field_of(item, 'StandaloneCUTPath');
if isempty(modelFile) || ~isfile(modelFile) || isempty(standaloneCut)
    error('simtest:CompareNoStandalone', 'standalone 모델 파일이나 CUT 경로가 없습니다');
end
[~, modelName] = fileparts(modelFile);
if bdIsLoaded(modelName)
    error('simtest:CompareNameTaken', '같은 이름의 모델이 열려 있어 standalone 모델을 열지 못했습니다');
end
load_system(modelFile);
closeModel = onCleanup(@() close_if_loaded(modelName)); %#ok<NASGU>
[inside, outside] = dangling_ends(modelName, standaloneCut);
counts = [numel(inside), numel(outside)];
notes{end+1} = char(editor_text(modelName, modelFile, harnessInfo.EditorPorts));
if isempty(owner)
    insideGroups = describe_outside(inside, standaloneCut, '');
else
    insideGroups = describe_inside(setdiff(inside, original), owner, standaloneCut);
end
groups = [labelled('standalone CUT 안', insideGroups), ...
    labelled('standalone CUT 밖', describe_outside(outside, modelName, standaloneCut, harnessInfo))];
% The same model opened from its own folder.
close_system(modelName, 0);
previousFolder = cd(fileparts(modelFile));
restoreFolder = onCleanup(@() cd(previousFolder)); %#ok<NASGU>
load_system(modelFile);
[insideAgain, outsideAgain] = dangling_ends(modelName, standaloneCut);
editorPorts = "?";
try
    ports = get_param(st_find_signal_editor_block(modelName), 'PortHandles');
    editorPorts = string(numel(ports.Outport));
catch
end
notes{end+1} = char(sprintf('standalone 모델 폴더에서 열면 | 끊긴 선 끝 CUT 안 %d 밖 %d | Signal Editor 출력 포트 %s', ...
    numel(insideAgain), numel(outsideAgain), editorPorts));
close_system(modelName, 0);
% The same model at the earlier steps: as exported (bundle template) and as
% prepared and run (execution workspace). Packaging copies the latter.
workFile = field_of(item, 'StandaloneModelFile');
workspace = field_of(manifest, 'Workspace');
templateFile = '';
if ~isempty(workFile) && ~isempty(workspace) && startsWith(workFile, [workspace filesep])
    templateFile = fullfile(field_of(manifest, 'BundleDirectory'), 'template', ...
        workFile(numel(workspace) + 2:end));
end
notes{end+1} = sprintf('단계별 CUT 밖 끊긴 선 끝 | 내보낸 원본 %s | 실행용 복사본 %s | 패키징본 %d', ...
    stage_count(templateFile, modelName, standaloneCut), ...
    stage_count(workFile, modelName, standaloneCut), numel(outsideAgain));
end


function text = stage_count(modelFile, modelName, cut)
% Loose ends outside the CUT in one saved copy of the standalone model.
text = '없음';
if isempty(modelFile) || ~isfile(modelFile), return; end
try
    load_system(modelFile);
    closeModel = onCleanup(@() close_if_loaded(modelName)); %#ok<NASGU>
    [~, outside] = dangling_ends(modelName, cut);
    text = sprintf('%d', numel(outside));
catch ME
    text = ['오류 ' id_of(ME)];
end
end


function [inside, outside] = dangling_ends(root, cut)
% One key per port that a line with a loose end still meets:
% "in|<receiving block>|<port type><n>" for a line with no source,
% "out|<sending block>|<n>" for a line that reaches no block, and
% "loose|<system>" for a line with neither end on a port. A key is inside
% when its block lies below cut (or, for a loose line, its system is cut),
% and its path is then relative to cut; otherwise it is relative to root.
inside = strings(0, 1);
outside = strings(0, 1);
cut = string(cut);
handles = find_system(root, 'FindAll', 'on', 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'Type', 'line');
for h = reshape(handles, 1, [])
    src = get_param(h, 'SrcPortHandle');
    dst = get_param(h, 'DstPortHandle');
    connected = dst(dst ~= -1);
    kinds = strings(0, 1);
    blocks = strings(0, 1);
    tails = strings(0, 1);
    if any(src == -1)
        for d = reshape(connected, 1, [])
            kinds(end+1, 1) = "in"; %#ok<AGROW>
            blocks(end+1, 1) = string(get_param(d, 'Parent')); %#ok<AGROW>
            tails(end+1, 1) = string(get_param(d, 'PortType')) + string(get_param(d, 'PortNumber')); %#ok<AGROW>
        end
        if isempty(connected)
            kinds(end+1, 1) = "loose";
            blocks(end+1, 1) = string(get_param(h, 'Parent'));
            tails(end+1, 1) = "";
        end
    elseif any(dst == -1)
        kinds(end+1, 1) = "out";
        blocks(end+1, 1) = string(get_param(src, 'Parent'));
        tails(end+1, 1) = string(get_param(src, 'PortNumber'));
    end
    for k = 1:numel(kinds)
        if startsWith(blocks(k), cut + "/") || (kinds(k) == "loose" && blocks(k) == cut)
            inside(end+1, 1) = kinds(k) + "|" + relative(blocks(k), cut) + "|" + tails(k); %#ok<AGROW>
        else
            outside(end+1, 1) = kinds(k) + "|" + relative(blocks(k), root) + "|" + tails(k); %#ok<AGROW>
        end
    end
end
inside = unique(inside);
outside = unique(outside);
end


function out = describe_inside(keys, owner, otherCut)
% Loose ends inside a copy of the CUT, compared with the Top Model's CUT.
kinds = strings(0, 1);
for key = reshape(keys, 1, [])
    parts = split(key, "|");
    switch parts(1)
        case "in"
            [srcType, outs, links] = original_source(owner, otherCut, parts(2), parts(3));
            kinds(end+1, 1) = sprintf("끊긴 입력 | 받는 %s | 원래 보내는 %s | 출력 포트 %s | 링크 %s", ...
                block_type(join_path(otherCut, parts(2))), srcType, outs, links); %#ok<AGROW>
        case "out"
            kinds(end+1, 1) = "받는 쪽 없음 | 보내는 " + block_type(join_path(otherCut, parts(2))); %#ok<AGROW>
        otherwise
            kinds(end+1, 1) = "양 끝 모두 끊김"; %#ok<AGROW>
    end
end
out = count_kinds(kinds);
end


function out = describe_outside(keys, root, cut, harnessInfo)
% Loose ends outside a CUT, by the type of the block they still meet. For a
% standalone model, an input the Harness feeds also names the Harness's
% source block and its output port count in both models.
if nargin < 4, harnessInfo = []; end
kinds = strings(0, 1);
for key = reshape(keys, 1, [])
    parts = split(key, "|");
    path = join_path(root, parts(2));
    if strcmp(path, char(cut))
        blockType = "CUT";
    else
        blockType = block_type(path);
    end
    switch parts(1)
        case "in"
            kinds(end+1, 1) = "끊긴 입력 | 받는 " + blockType + harness_source(key, root, harnessInfo); %#ok<AGROW>
        case "out"
            kinds(end+1, 1) = "받는 쪽 없음 | 보내는 " + blockType; %#ok<AGROW>
        otherwise
            kinds(end+1, 1) = "양 끝 모두 끊김"; %#ok<AGROW>
    end
end
out = count_kinds(kinds);
end


function text = harness_source(key, root, harnessInfo)
text = "";
if isempty(harnessInfo) || ~isKey(harnessInfo.Sources, char(key)), return; end
source = harnessInfo.Sources(char(key));
copyCount = "없음";
try
    copyPorts = get_param(join_path(root, source.Rel), 'PortHandles');
    copyCount = string(numel(copyPorts.Outport));
catch
end
text = " | Harness에서 보내는 " + source.Type + " | 출력 포트 Harness " + source.Outports + "→" + copyCount;
end


function info = source_side(root, cut, topFolder)
% While the Harness is loaded: what feeds each input outside its CUT, keyed
% like dangling_ends, and the output port count of its Signal Editor. The
% standalone model has the same name, so the two are never loaded together.
info = struct('Sources', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'EditorPorts', NaN);
cutText = string(cut);
handles = find_system(root, 'FindAll', 'on', 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'Type', 'line');
for h = reshape(handles, 1, [])
    src = get_param(h, 'SrcPortHandle');
    if any(src == -1), continue; end
    sourceBlock = get_param(src, 'Parent');
    for d = reshape(get_param(h, 'DstPortHandle'), 1, [])
        if d == -1, continue; end
        target = string(get_param(d, 'Parent'));
        if startsWith(target, cutText + "/"), continue; end
        key = char("in|" + relative(target, root) + "|" + ...
            string(get_param(d, 'PortType')) + string(get_param(d, 'PortNumber')));
        ports = get_param(sourceBlock, 'PortHandles');
        info.Sources(key) = struct('Type', string(get_param(sourceBlock, 'BlockType')), ...
            'Rel', relative(sourceBlock, root), 'Outports', numel(ports.Outport));
    end
end
info.EditorFile = '-';
try
    editor = st_find_signal_editor_block(root);
    ports = get_param(editor, 'PortHandles');
    info.EditorPorts = numel(ports.Outport);
    info.EditorFile = file_text(char(string(get_param(editor, 'Filename'))), topFolder);
catch
end
end


function text = file_text(filename, modelFolder)
% How a Signal Editor file name resolves: as written (current folder or an
% absolute path), on the MATLAB path, beside the model. Kinds only.
kind = '상대';
if ~isempty(regexp(filename, '^([A-Za-z]:[\\/]|[\\/])', 'once')), kind = '절대'; end
text = sprintf('파일 이름 %s | 그대로 %s 경로 %s 모델 폴더 %s', kind, mark(isfile(filename)), ...
    mark(~isempty(which(filename))), mark(isfile(fullfile(modelFolder, filename))));
end


function text = editor_text(modelName, modelFile, harnessPorts)
% The standalone Signal Editor: its output ports against the Harness's, and
% whether its file name resolves as written, on the path, or beside the model.
text = "standalone Signal Editor 없음";
try
    editor = st_find_signal_editor_block(modelName);
    ports = get_param(editor, 'PortHandles');
    filename = char(string(get_param(editor, 'Filename')));
    absolute = ~isempty(regexp(filename, '^([A-Za-z]:[\\/]|[\\/])', 'once'));
    kind = "상대";
    if absolute, kind = "절대"; end
    text = sprintf(['standalone Signal Editor | 출력 포트 Harness %g→standalone %d | 파일 이름 %s | ' ...
        '그대로 %s 경로 %s 모델 폴더 %s'], harnessPorts, numel(ports.Outport), kind, ...
        mark(isfile(filename)), mark(~isempty(which(filename))), ...
        mark(isfile(fullfile(fileparts(modelFile), filename))));
catch ME
    text = "standalone Signal Editor 읽기 실패 | " + string(id_of(ME));
end
end


function text = mark(flag)
text = "X";
if flag, text = "O"; end
end


function close_if_loaded(modelName)
if bdIsLoaded(modelName), close_system(modelName, 0); end
end


function out = count_kinds(kinds)
[uniqueKinds, ~, index] = unique(kinds, 'stable');
counts = accumarray(index(:), 1);
out = cell(1, numel(uniqueKinds));
for k = 1:numel(uniqueKinds)
    out{k} = char(sprintf('%d개 | %s', counts(k), uniqueKinds(k)));
end
end


function out = labelled(label, groups)
out = cellfun(@(g) [label ' | ' char(g)], groups, 'UniformOutput', false);
end


function [srcType, outs, links] = original_source(owner, otherCut, rel, port)
% The block feeding this input in the Top Model, and how it differs in the
% copy: "원래→복사본" for the output port count and the link status.
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
    copyBlock = join_path(otherCut, relative(getfullname(sourceBlock), owner));
    if getSimulinkBlockHandle(copyBlock) == -1
        outs = numel(sourcePorts.Outport) + "→없음";
        links = originalLink + "→없음";
        return;
    end
    copyPorts = get_param(copyBlock, 'PortHandles');
    outs = numel(sourcePorts.Outport) + "→" + numel(copyPorts.Outport);
    links = originalLink + "→" + string(get_param(copyBlock, 'LinkStatus'));
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


function value = field_of(item, name)
value = '';
if isstruct(item) && isfield(item, name) && ~isempty(item.(name))
    value = char(string(item.(name)));
end
end


function rel = relative(block, base)
% Path below base; "." for base itself.
block = string(block);
if block == string(base)
    rel = ".";
else
    rel = extractAfter(block, strlength(string(base)) + 1);
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
