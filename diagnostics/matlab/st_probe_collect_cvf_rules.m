function st_probe_collect_cvf_rules(varargin)
%ST_PROBE_COLLECT_CVF_RULES Find which CVF rule empties a PER_CUT target's CUT coverage.
%
% st_probe_collect_cvf_rules            % first collected target of the latest PER_CUT run
% st_probe_collect_cvf_rules('No', n)   % the target on Excel row n
%
% After st_collect_per_cut_results attached the CVF it generated, CUT
% decision and execution coverage read 0/0. This loads the target's saved
% INITIAL ResultSet and that CVF, and reads CUT coverage without the CVF,
% with it, and with each rule alone. Each rule's block is placed relative to
% the CUT twice: by its SID in the Harness, and by the same SID number in the
% Top Model, in case the filter is resolved against the model the coverage
% is reported on. Prints one screen of counts, kinds and Simulink block
% types, never a model, block, test case or file name. Full error reports go
% to st_cvf_rule_probe.txt in tempdir.

p = inputParser;
addParameter(p, 'No', NaN, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
diagFile = 'st_cvf_rule_probe.txt';
lines = {sprintf('MATLAB %s | CVF 규칙 찾기', version('-release'))};
cfg = [];
stage = '모델 확인';
try
    loadedNames = find_system('type', 'block_diagram');
    if ~isempty(loadedNames) && any(strcmp(get_param(loadedNames, 'Dirty'), 'on'))
        fprintf('저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요\n');
        return;
    end
    bdclose('all');
    cfg = st_require_runtime_target();
    st_log(cfg, 'INFO', 'Collect CVF rule probe start');

    stage = '대상 찾기';
    % Variables that evalc assigns are named first, or MATLAB may take them for functions.
    source = [];
    config = table();
    evalc('source = st_final_document_run_source(cfg, ''PER_CUT'');');
    evalc('config = st_resolve_target_cut_paths(st_load_targets(cfg.OnlyEnabled), cfg);');
    books = source.Workbooks;
    if ~isnan(p.Results.No), books = books(books.No == p.Results.No, :); end
    if height(books) == 0
        error('simtest:ProbeNoTarget', '결과 정리된 대상이 없습니다');
    end
    no = double(books.No(1));
    row = config(double(config.No) == no, :);
    directory = fileparts(fileparts(char(books.File(1))));
    savedFile = fullfile(directory, 'initial', 'Results.mldatx');
    cvfs = dir(fullfile(directory, 'filter', '*.cvf'));
    if height(row) ~= 1
        error('simtest:ProbeNoTarget', 'Excel 대상 목록에서 이 대상을 찾지 못했습니다');
    end
    if ~isfile(savedFile) || isempty(cvfs)
        error('simtest:ProbeNoArtifacts', '저장된 결과나 CVF 파일이 없습니다. 결과 정리부터 하세요');
    end
    cvfFile = fullfile(cvfs(1).folder, cvfs(1).name);

    stage = '모델 열기';
    load_system(cfg.ModelFile);
    owner = char(st_normalize_cut_path(row.CUTPath, cfg.TopModel));
    harness = char(string(row.HarnessName));
    sltest.harness.load(owner, harness);
    harnessCut = [harness '/' strrep(get_param(owner, 'Name'), '/', '//')];
    cutPath = st_coverage_object_path(row);

    stage = '결과 읽기';
    imported = sltest.testmanager.importResults(savedFile);
    objects = st_collect_result_coverage_objects(imported(1));
    answering = find(cellfun(@(c) answers(c, cutPath), objects));
    lines{end+1} = sprintf('대상 %d | coverage 객체 %d개 | CUT에 답하는 것 %d개', ...
        no, numel(objects), numel(answering));
    if isempty(answering)
        error('simtest:ProbeNoAnswer', 'CUT 경로에 답하는 coverage 객체가 없습니다');
    end
    cvd = objects{answering(1)};
    lines{end+1} = sprintf('coverage 객체 | analyzedModel %s | ownerModel %s | 이미 걸린 CVF %d개', ...
        model_kind(info_field(cvd, 'analyzedModel'), harness, cfg.TopModel), ...
        model_kind(info_field(cvd, 'ownerModel'), harness, cfg.TopModel), filter_count(cvd));
    base = measure(cvd, cutPath, '');

    stage = 'CVF 읽기';
    allRules = rules(slcoverage.Filter(cvfFile));
    withAll = measure(cvd, cutPath, cvfFile);
    lines{end+1} = sprintf('CVF 없이 | 결정 %d/%d | 실행 %d/%d', base);
    lines{end+1} = sprintf('CVF 전체(규칙 %d개) | 결정 %d/%d | 실행 %d/%d', numel(allRules), withAll);

    stage = '규칙 하나씩';
    % slcoverage.Filter.save checks the current folder, so save from a scratch one.
    scratch = tempname(tempdir);
    mkdir(scratch);
    oldDir = cd(scratch);
    restoreDir = onCleanup(@() leave_scratch(oldDir, scratch)); %#ok<NASGU>
    n = numel(allRules);
    outcome = strings(n, 1);
    detail = strings(n, 1);
    sidKinds = strings(n, 1);
    harnessPlaces = strings(n, 1);
    topPlaces = strings(n, 1);
    rulePaths = strings(n, 1);
    for i = 1:n
        single = slcoverage.Filter;
        addRule(single, allRules(i));
        ruleBase = fullfile(scratch, sprintf('rule_%d', i));
        save(single, ruleBase);
        ruleFile = [ruleBase '.cvf'];
        if ~isfile(ruleFile) && isfile(ruleBase), ruleFile = ruleBase; end
        values = measure(cvd, cutPath, ruleFile);
        sid = char(string(allRules(i).Selector.Id));
        [sidModel, sidRest] = strtok(sid, ':');
        sidKinds(i) = model_kind(sidModel, harness, cfg.TopModel);
        [blockType, harnessPlaces(i), rulePaths(i)] = place_sid(sid, harnessCut);
        [~, topPlaces(i)] = place_sid([char(cfg.TopModel) sidRest], owner);
        if values(2) == 0 && values(4) == 0 && (base(2) > 0 || base(4) > 0)
            outcome(i) = "비움";
        elseif isequal(values, base)
            outcome(i) = "그대로";
        else
            outcome(i) = "줄임";
        end
        detail(i) = sprintf('규칙 %d | %s | %s | Harness: %s | Top 같은 번호: %s | 결정 %d/%d 실행 %d/%d', ...
            i, char(string(allRules(i).Selector.Type)), blockType, harnessPlaces(i), topPlaces(i), values);
    end
    lines{end+1} = sprintf('규칙 하나씩 | CUT을 비운 것 %d | 줄인 것 %d | 그대로 %d', ...
        sum(outcome == "비움"), sum(outcome == "줄임"), sum(outcome == "그대로"));
    lines{end+1} = ['규칙 SID의 모델 | ' count_text(sidKinds)];
    lines{end+1} = ['규칙 위치(Harness) | ' count_text(harnessPlaces)];
    lines{end+1} = ['같은 번호의 Top Model 블록 위치 | ' count_text(topPlaces)];
    % Candidate fix: the rules inside the CUT rebuilt on the Top Model's CUT,
    % found by the same path below the CUT.
    inside = reshape(find(harnessPlaces == "CUT 안"), 1, []);
    try
        topFilter = slcoverage.Filter;
        mapped = 0;
        for i = inside
            relative = char(extractAfter(rulePaths(i), [harnessCut '/']));
            try
                topSid = Simulink.ID.getSID([char(owner) '/' relative]);
            catch
                continue;
            end
            rule = slcoverage.FilterRule(slcoverage.BlockSelector( ...
                allRules(i).Selector.Type, topSid), ...
                allRules(i).Rationale, allRules(i).Mode);
            if addRule(topFilter, rule), mapped = mapped + 1; end
        end
        topBase = fullfile(scratch, 'top_model');
        save(topFilter, topBase);
        topFile = [topBase '.cvf'];
        if ~isfile(topFile) && isfile(topBase), topFile = topBase; end
        lines{end+1} = sprintf(['Top Model SID로 다시 만든 CVF(CUT 안 규칙 %d개 중 %d개) | ' ...
            '결정 %d/%d | 실행 %d/%d'], numel(inside), mapped, measure(cvd, cutPath, topFile));
    catch topError
        lines{end+1} = sprintf('Top Model SID로 다시 만든 CVF 실패 | %s', id_of(topError));
    end
    shown = detail(outcome == "비움");
    if isempty(shown), shown = detail(outcome == "줄임"); end
    for k = 1:min(20, numel(shown)), lines{end+1} = char(shown(k)); end %#ok<AGROW>
    if numel(shown) > 20, lines{end+1} = sprintf('%d줄 더 있음. 진단 파일에 모두 있습니다', numel(shown) - 20); end
    st_log(cfg, 'INFO', 'Collect CVF rule probe complete | rules=%d | emptied=%d', ...
        n, sum(outcome == "비움"));
catch ME
    text = '';
    if startsWith(ME.identifier, 'simtest:Probe'), text = [' | ' ME.message]; end
    lines{end+1} = sprintf('%s 실패 | %s%s', stage, id_of(ME), text);
    write_diag(diagFile, sprintf('[%s]\n%s\n', stage, getReport(ME, 'extended', 'hyperlinks', 'off')));
    if ~isempty(cfg)
        st_log(cfg, 'ERROR', 'Collect CVF rule probe failed | stage=%s | %s', stage, ME.identifier);
    end
end
clc;
for k = 1:numel(lines), fprintf('%s\n', lines{k}); end
fprintf('진단 전문 파일: %s (임시 폴더, 실패했을 때만)\n', diagFile);
end


function values = measure(cvd, cutPath, filterFile)
% [decision covered, total, execution covered, total]; 0/0 when nothing answers.
if ~isempty(filterFile), cvd.filter = filterFile; end
values = [pair(@decisioninfo), pair(@executioninfo)];
    function v = pair(metric)
        v = [0 0];
        try
            found = metric(cvd, cutPath);
            if ~isempty(found), v = double(found(1:2)); end
        catch
        end
    end
end


function tf = answers(cvd, cutPath)
tf = false;
try
    tf = ~isempty(decisioninfo(cvd, cutPath));
catch
end
end


function [blockType, place, blockPath] = place_sid(sid, cutPath)
% Where the block a SID names sits relative to the CUT: kinds for the screen,
% and the path for rebuilding the rule, never printed.
blockType = '-';
place = "없음";
blockPath = "";
try
    handle = Simulink.ID.getHandle(sid);
    blockPath = getfullname(handle);
    blockType = get_param(handle, 'BlockType');
catch
    return;
end
if strcmp(blockPath, cutPath)
    place = "CUT 자신";
elseif startsWith(blockPath, [cutPath '/'])
    place = "CUT 안";
elseif startsWith(cutPath, [blockPath '/'])
    place = "CUT 위";
else
    place = "CUT 밖";
end
end


function kind = model_kind(name, harness, topModel)
name = char(string(name));
if isempty(name)
    kind = "없음";
elseif strcmp(name, harness)
    kind = "Harness";
elseif strcmp(name, topModel)
    kind = "Top Model";
else
    kind = "기타";
end
end


function value = info_field(cvd, field)
value = "";
try
    info = cvd.modelinfo;
    raw = string({info.(field)});
    raw = raw(~ismissing(raw) & strlength(raw) > 0);
    if ~isempty(raw), value = raw(1); end
catch
end
end


function count = filter_count(cvd)
count = 0;
try
    names = string(cvd.filter);
    count = sum(strlength(names) > 0);
catch
end
end


function text = count_text(values)
kinds = unique(values, 'stable');
parts = strings(1, numel(kinds));
for k = 1:numel(kinds)
    parts(k) = sprintf('%s %d', kinds(k), sum(values == kinds(k)));
end
text = char(strjoin(parts, ' | '));
if isempty(text), text = '-'; end
end


function leave_scratch(oldDir, scratch)
cd(oldDir);
try
    rmdir(scratch, 's');
catch
end
end


function write_diag(diagFile, text)
fid = fopen(fullfile(tempdir, diagFile), 'w');
if fid < 0, return; end
fprintf(fid, '%s', text);
fclose(fid);
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
