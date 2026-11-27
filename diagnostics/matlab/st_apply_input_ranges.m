function lines = st_apply_input_ranges(file)
%ST_APPLY_INPUT_RANGES Set the Min/Max filled in st_input_ranges.csv on the model.
%
% lines = st_apply_input_ranges()      % asks for the file
% lines = st_apply_input_ranges(file)  % .csv, or .xlsx when DRM encrypted the csv
%
% The file is the table st_show_input_ranges writes, with Min/Max filled in.
% A row without Bus sets OutMin/OutMax of the Inport CUT/Input. A row with
% Bus sets Min/Max of that element in the Bus object, found in the model
% workspace first, then the model's data dictionary. A Bus only in the base
% workspace is not changed: it would be gone when MATLAB restarts.
% Values are numbers, or empty/[] for none. Every changed model and
% dictionary is saved. Stops before touching anything when a model has
% unsaved changes. The screen carries counts and kinds only.
title = '입력 범위 넣기';
cfg = st_config();
st_log(cfg, 'INFO', 'Input range apply start');
lines = {};
if nargin < 1
    [name, folder] = uigetfile({'*.csv;*.xlsx', '범위 표 (*.csv, *.xlsx)'}, ...
        'Min/Max를 채운 st_input_ranges 파일을 고르세요', fullfile(tempdir, 'st_input_ranges.csv'));
    if isequal(name, 0)
        lines = show(title, {'파일을 고르지 않아 아무것도 바꾸지 않았습니다'});
        return;
    end
    file = fullfile(folder, name);
end

try
    T = read_table(file);
catch ME
    lines = show(title, {sprintf('표 읽기 실패 | %s | %s', id_of(ME), read_hint(file))});
    st_log(cfg, 'WARN', 'Input range apply stopped | table read failed');
    return;
end
need = {'CUT', 'Input', 'Bus', 'Element', 'Min', 'Max'};
if ~all(ismember(need, T.Properties.VariableNames))
    lines = show(title, {'표에 CUT, Input, Bus, Element, Min, Max 열이 없습니다. 18절을 다시 돌려 새 표를 받아 주세요'});
    st_log(cfg, 'WARN', 'Input range apply stopped | missing columns');
    return;
end
T.Bus(ismissing(T.Bus)) = "";
T.Element(ismissing(T.Element)) = "";

if nargin < 1 && cfg.HasRuntimeTarget, load_system(cfg.ModelFile); end
models = unique(arrayfun(@(c) string(strtok(char(c), '/')), T.CUT));
for m = reshape(models, 1, [])
    try
        load_system(char(m));
    catch
    end
end
loaded = find_system('type', 'block_diagram');
if ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
    lines = show(title, {'저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요'});
    st_log(cfg, 'WARN', 'Input range apply stopped | unsaved models');
    return;
end

counts = struct('inport', 0, 'element', 0, 'same', 0);
fails = containers.Map();
dirtyModels = strings(0, 1);
dictionaries = strings(0, 1);
for r = 1:height(T)
    try
        model = string(strtok(char(T.CUT(r)), '/'));
        if T.Bus(r) == ""
            changed = set_inport(T.CUT(r) + "/" + T.Input(r), T.Min(r), T.Max(r));
            if changed, counts.inport = counts.inport + 1; dirtyModels(end+1) = model; end %#ok<AGROW>
        else
            [lo, hi] = parse_range(T.Min(r), T.Max(r));
            [changed, where, dict] = set_element(char(model), char(T.Bus(r)), char(T.Element(r)), lo, hi);
            if changed
                counts.element = counts.element + 1;
                if where == "model", dirtyModels(end+1) = model; end %#ok<AGROW>
                if where == "dictionary", dictionaries(end+1) = dict; end %#ok<AGROW>
            end
        end
        if ~changed, counts.same = counts.same + 1; end
    catch ME
        kind = fail_kind(ME);
        if isKey(fails, kind), fails(kind) = fails(kind) + 1; else, fails(kind) = 1; end
    end
end

saveFail = 0;
for m = reshape(unique(dirtyModels), 1, [])
    try
        save_system(char(m));
    catch
        saveFail = saveFail + 1;
    end
end
dictionaries = unique(dictionaries);
for d = 1:numel(dictionaries)
    try
        saveChanges(Simulink.data.dictionary.open(char(dictionaries(d))));
    catch
        saveFail = saveFail + 1;
    end
end

nFail = sum(cell2mat(values(fails)));
lines{end+1} = sprintf('표 %d줄 | Inport 바꿈 %d | Bus 요소 바꿈 %d | 그대로 %d | 실패 %d', height(T), ...
    counts.inport, counts.element, counts.same, nFail);
kinds = keys(fails);
for k = 1:numel(kinds)
    lines{end+1} = sprintf('  실패 %d | %s', fails(kinds{k}), kinds{k}); %#ok<AGROW>
end
if saveFail > 0
    lines{end+1} = sprintf('저장 실패 %d | 모델·dictionary가 읽기 전용인지 확인하세요', saveFail);
else
    lines{end+1} = sprintf('저장 | 모델 %d | dictionary %d', numel(unique(dirtyModels)), numel(dictionaries));
end
lines{end+1} = '바뀐 값은 18절을 다시 돌려 확인하세요';
lines = show(title, lines);
if nFail > 0 || saveFail > 0
    st_log(cfg, 'WARN', 'Input range apply finished with failures | failed=%d | saveFailed=%d', nFail, saveFail);
else
    st_log(cfg, 'INFO', 'Input range apply complete | inports=%d | elements=%d', counts.inport, counts.element);
end
end


function T = read_table(file)
[~, ~, ext] = fileparts(file);
if strcmpi(ext, '.csv')
    fid = fopen(file, 'r');
    head = fread(fid, 5, '*char')';
    fclose(fid);
    if strcmp(head, 'SCDSA')
        error('st:apply:encrypted', 'encrypted');
    end
end
opts = detectImportOptions(file, 'TextType', 'string');
opts = setvartype(opts, opts.VariableNames, 'string');
if strcmpi(ext, '.csv')
    T = readtable(file, opts);
else
    T = readtable(file, opts, 'UseExcel', true);  % Excel opens a DRM-encrypted workbook
end
end


function text = read_hint(file)
[~, ~, ext] = fileparts(file);
if strcmpi(ext, '.csv')
    text = 'Excel 저장으로 CSV가 암호화됐으면 .xlsx로 저장해 그 파일을 고르세요';
else
    text = 'Excel에서 파일이 열리는지 확인하세요';
end
end


function [lo, hi] = parse_range(minText, maxText)
lo = to_number(minText);
hi = to_number(maxText);
if ~isempty(lo) && ~isempty(hi) && lo > hi
    error('st:apply:minAboveMax', 'min above max');
end
end


function value = to_number(text)
text = strtrim(string(text));
if ismissing(text) || text == "" || text == "[]"
    value = [];
    return;
end
value = str2double(text);
if isnan(value), error('st:apply:notNumber', 'not a number'); end
end


function changed = set_inport(block, minText, maxText)
block = char(block);
if getSimulinkBlockHandle(block) == -1
    error('st:apply:noBlock', 'no block');
end
% Text equal to what the block holds (an expression too) is left alone.
changed = ~same_text(get_param(block, 'OutMin'), minText) || ~same_text(get_param(block, 'OutMax'), maxText);
if changed
    [lo, hi] = parse_range(minText, maxText);
    set_param(block, 'OutMin', num_text(lo), 'OutMax', num_text(hi));
end
end


function [changed, where, dict] = set_element(model, busName, elementPath, lo, hi)
% The element is the last part of the path; busName owns it directly.
dict = "";
leaf = elementPath(find(['.' elementPath] == '.', 1, 'last'):end);
mws = get_param(model, 'ModelWorkspace');
if hasVariable(mws, busName)
    where = "model";
    bus = getVariable(mws, busName);
    [bus, changed] = set_bus_range(bus, leaf, lo, hi);
    if changed, assignin(mws, busName, bus); end
    return;
end
ddName = get_param(model, 'DataDictionary');
if ~isempty(ddName)
    dict = string(ddName);
    section = getSection(Simulink.data.dictionary.open(ddName), 'Design Data');
    if exist(section, busName)
        where = "dictionary";
        entry = getEntry(section, busName);
        [bus, changed] = set_bus_range(getValue(entry), leaf, lo, hi);
        if changed, setValue(entry, bus); end
        return;
    end
end
if evalin('base', sprintf('exist(''%s'', ''var'')', busName))
    error('st:apply:baseBus', 'bus only in base workspace');
end
error('st:apply:noBus', 'bus not found');
end


function [bus, changed] = set_bus_range(bus, leaf, lo, hi)
if ~isa(bus, 'Simulink.Bus'), error('st:apply:noBus', 'not a bus'); end
k = find(strcmp({bus.Elements.Name}, leaf), 1);
if isempty(k), error('st:apply:noElement', 'no element'); end
changed = ~isequal(bus.Elements(k).Min, lo) || ~isequal(bus.Elements(k).Max, hi);
bus.Elements(k).Min = lo;
bus.Elements(k).Max = hi;
end


function kind = fail_kind(ME)
switch ME.identifier
    case 'st:apply:notNumber', kind = 'Min/Max가 숫자가 아님(빈 칸이나 []는 됨)';
    case 'st:apply:minAboveMax', kind = 'Min이 Max보다 큼';
    case 'st:apply:noBlock', kind = 'Inport를 찾지 못함(CUT·Input 칸을 고쳤거나 블록 이름이 바뀜)';
    case 'st:apply:baseBus', kind = 'Bus 객체가 base workspace에만 있음(dictionary나 모델 workspace로 옮긴 뒤 다시)';
    case 'st:apply:noBus', kind = 'Bus 객체를 찾지 못함';
    case 'st:apply:noElement', kind = 'Bus 요소를 찾지 못함';
    otherwise, kind = ['기타 ' id_of(ME)];
end
end


function tf = same_text(current, wanted)
% '' and [] both mean "none"; numbers compare by value, anything else by text.
current = strtrim(string(current)); wanted = strtrim(string(wanted));
if ismissing(wanted), wanted = ""; end
if any(current == ["", "[]"]) && any(wanted == ["", "[]"]), tf = true; return; end
tf = current == wanted || (~isnan(str2double(current)) && str2double(current) == str2double(wanted));
end


function text = num_text(value)
if isempty(value), text = '[]'; else, text = mat2str(value); end
end


function lines = show(title, lines)
clc;
lines = [{sprintf('MATLAB %s | %s', version('-release'), title)}, lines];
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
