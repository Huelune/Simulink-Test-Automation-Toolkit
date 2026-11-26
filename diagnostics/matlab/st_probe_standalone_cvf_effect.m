function st_probe_standalone_cvf_effect()
%ST_PROBE_STANDALONE_CVF_EFFECT Why adding the CVFs to the standalone Result changes no value.
%
% The packaged CVFs were added by hand to the imported standalone Result in
% Test Manager (Coverage Filters, Add), and Aggregated Coverage Results did
% not change. Per target of the latest standalone pipeline, changing nothing
% on disk and leaving Test Manager as it is:
%   1. CVF: rule count by mode and selector type, how many selectors find a
%      block in the loaded standalone model, how many name another model.
%   2. Saved CVT: decision and execution of the whole standalone model and
%      of the CUT, without the CVF and with it. Equal model numbers mean the
%      CVF takes out nothing that Test Manager shows per model.
%   3. Test Manager: the coverage objects of the open Results for this
%      model, the filters they carry and whether this CVF is one, and the
%      same numbers without a filter and with the CVF set.
% Loads the packaged standalone models that are not loaded. Three lines per
% target; counts, MathWorks enumeration names and error identifiers only.
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
lines = {sprintf('MATLAB %s | standalone CVF 효과 보기', version('-release'))};
cfg = st_config();
st_log(cfg, 'INFO', 'Standalone CVF effect probe start');
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
manifest = [];
try
    evalc('manifest = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir, ''LATEST'');');
catch ME
    lines{end+1} = sprintf('준비 실패 | 최근 standalone 제출물 읽기 | %s', id_of(ME));
    st_log(cfg, 'WARN', 'Standalone CVF effect probe stopped | manifest | %s', id_of(ME));
    show(lines);
    return;
end
[objects, setCount] = result_coverage_objects();
lines{end+1} = sprintf('Test Manager 결과 %d개 | 커버리지 객체 %d개 | 값: 덮인/전체, 화살표 왼쪽 CVF 없이·오른쪽 CVF 걸고', ...
    setCount, numel(objects));
targets = manifest.Targets;
for k = 1:numel(targets)
    item = targets(k);
    cvf = field_text(item, 'PackagedCVF');
    cutPath = field_text(item, 'StandaloneCUTPath');
    modelFile = field_text(item, 'PackagedStandaloneModel');
    [~, modelName] = fileparts(modelFile);
    try
        ensure_loaded(modelName, modelFile);
    catch ME
        lines{end+1} = sprintf('대상 %d | standalone 모델 열기 실패 %s', k, id_of(ME)); %#ok<AGROW>
        continue;
    end
    lines{end+1} = sprintf('대상 %d | CVF %s', k, rule_text(cvf, modelName)); %#ok<AGROW>
    lines{end+1} = sprintf('대상 %d | 저장 CVT %s', k, ...
        cvt_text(field_text(item, 'CoverageResult'), cvf, modelName, cutPath)); %#ok<AGROW>
    lines{end+1} = sprintf('대상 %d | Test Manager %s', k, ...
        manager_text(objects, cvf, modelName, cutPath)); %#ok<AGROW>
end
st_log(cfg, 'INFO', 'Standalone CVF effect probe complete | targets %d', numel(targets));
show(lines);
end


function [objects, setCount] = result_coverage_objects()
objects = cell(0, 1);
setCount = 0;
try
    sets = sltest.testmanager.getResultSets;
    setCount = numel(sets);
    for s = 1:numel(sets)
        objects = [objects; st_collect_result_coverage_objects(sets(s))]; %#ok<AGROW>
    end
catch
end
end


function ensure_loaded(modelName, modelFile)
if isempty(modelFile) || ~isfile(modelFile)
    error('simtest:ProbeStandaloneModelMissing', 'The packaged standalone model is missing.');
end
if ~bdIsLoaded(modelName)
    load_system(modelFile);
elseif ~st_same_path(char(string(get_param(modelName, 'FileName'))), modelFile)
    error('simtest:ProbeOtherModelLoaded', 'A model of the same name from another folder is loaded.');
end
end


function text = rule_text(cvf, modelName)
if isempty(cvf) || ~isfile(cvf)
    text = '파일 없음';
    return;
end
try
    allRules = rules(slcoverage.Filter(cvf));
catch ME
    text = ['읽기 오류 ' id_of(ME)];
    return;
end
n = numel(allRules);
modes = strings(n, 1);
types = strings(n, 1);
found = 0;
other = 0;
for i = 1:n
    try, modes(i) = string(allRules(i).Mode); catch, modes(i) = "?"; end
    try, types(i) = string(allRules(i).Selector.Type); catch, types(i) = "?"; end
    sid = '';
    try, sid = char(string(allRules(i).Selector.Id)); catch, end
    if ~startsWith(sid, [modelName ':']), other = other + 1; end
    try
        Simulink.ID.getHandle(sid);
        found = found + 1;
    catch
    end
end
text = sprintf('규칙 %d개(%s | %s) | 모델에서 블록 찾음 %d | 다른 모델 SID %d', n, ...
    tally(modes), tally(types), found, other);
end


function text = cvt_text(cvt, cvf, modelName, cutPath)
if isempty(cvt) || ~isfile(cvt)
    text = '파일 없음';
    return;
end
try
    [~, data] = cvload(cvt);
    if iscell(data), data = data{1}; end
    saved = filter_count(data);
    try, data.filter = ''; catch, end
    before = measure(data, modelName, cutPath);
    data.filter = cvf;
    after = measure(data, modelName, cutPath);
catch ME
    text = ['읽기 오류 ' id_of(ME)];
    return;
end
text = sprintf('저장 때 걸린 필터 %d | %s', saved, compare(before, after));
end


function text = manager_text(objects, cvf, modelName, cutPath)
mine = {};
for i = 1:numel(objects)
    analyzed = info_field(objects{i}, 'analyzedModel');
    if extractBefore(analyzed + "/", "/") == string(modelName), mine{end+1} = objects{i}; end %#ok<AGROW>
end
if isempty(mine)
    text = '이 모델의 커버리지 객체 없음';
    return;
end
cvd = mine{1};
[~, cvfName, cvfExtension] = fileparts(cvf);
carried = filter_names(cvd);
hasThis = any(strcmpi(carried, [cvfName cvfExtension]));
try
    % Test Manager hands out a new instance per query, so this changes nothing it shows.
    try, cvd.filter = ''; catch, end
    before = measure(cvd, modelName, cutPath);
    cvd.filter = cvf;
    after = measure(cvd, modelName, cutPath);
catch ME
    text = ['읽기 오류 ' id_of(ME)];
    return;
end
text = sprintf('객체 %d | 걸린 필터 %d(이 CVF %s) | %s', numel(mine), numel(carried), ...
    yes_no(hasThis), compare(before, after));
end


function values = measure(data, modelName, cutPath)
%MEASURE [model decision, model execution, CUT decision, CUT execution] as covered/total pairs.
values = nan(1, 8);
places = {modelName, cutPath};
for p = 1:2
    values(4*p-3:4*p-2) = pick(@() decisioninfo(data, places{p}));
    values(4*p-1:4*p) = pick(@() executioninfo(data, places{p}));
end
end


function pair = pick(reader)
pair = [NaN NaN];
try
    value = reader();
    if isempty(value)
        pair = [0 0];
    else
        pair = double(value(1:2));
    end
catch
end
end


function text = compare(before, after)
text = sprintf('모델 결정 %s 실행 %s | CUT 결정 %s 실행 %s', arrow(before, after, 1), ...
    arrow(before, after, 3), arrow(before, after, 5), arrow(before, after, 7));
end


function text = arrow(before, after, i)
text = sprintf('%s→%s', fraction(before(i:i+1)), fraction(after(i:i+1)));
end


function text = fraction(pair)
if any(isnan(pair))
    text = '오류';
else
    text = sprintf('%d/%d', pair(1), pair(2));
end
end


function text = tally(values)
kinds = unique(values(:)).';
if isempty(kinds)
    text = '없음';
    return;
end
counts = arrayfun(@(x) sum(values == x), kinds);
text = char(strjoin(compose("%s %d", kinds, counts), ', '));
end


function names = filter_names(cvd)
%FILTER_NAMES File names (no folder) of the filters the coverage object carries.
names = strings(1, 0);
try
    raw = string(cvd.filter);
    raw = raw(strlength(raw) > 0);
    for i = 1:numel(raw)
        [~, name, extension] = fileparts(raw(i));
        if strlength(extension) == 0, extension = ".cvf"; end
        names(end+1) = name + extension; %#ok<AGROW>
    end
catch
end
end


function count = filter_count(cvd)
count = numel(filter_names(cvd));
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


function value = field_text(data, name)
value = '';
if isstruct(data) && isfield(data, name) && ~isempty(data.(name))
    value = char(string(data.(name)));
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
