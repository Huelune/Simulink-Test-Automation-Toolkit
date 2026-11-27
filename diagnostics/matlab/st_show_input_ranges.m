function lines = st_show_input_ranges(cutPaths)
%ST_SHOW_INPUT_RANGES Show the range and format of every CUT input, as counts.
%
% lines = st_show_input_ranges()          % CUTs of the Excel targets
% lines = st_show_input_ranges(cutPaths)  % given CUT Subsystem paths (tests)
%
% Reads each CUT's Inport blocks: declared type (OutDataTypeStr), the type
% after a model compile (CompiledPortDataType), dimensions and OutMin/OutMax.
% A Bus input is expanded to its leaf elements with their DataType/Min/Max.
% The full table, names included, goes to tempdir/st_input_ranges.csv for
% the user's own PC; the screen carries only counts and standard type names.
% Never saves the model. A range set only on a Simulink.Signal object or
% upstream of the CUT is not read (counted as 없음).
title = '입력 범위·형식';
cfg = st_config();
st_log(cfg, 'INFO', 'Input range check start');
csvFile = fullfile(tempdir, 'st_input_ranges.csv');
reportFile = fullfile(tempdir, 'st_todo_check.txt');
if isfile(reportFile), delete(reportFile); end
lines = {};

if nargin < 1
    checked = table();
    try
        if cfg.HasRuntimeTarget, load_system(cfg.ModelFile); end
        evalc('checked = st_pre_validate_targets();');
    catch ME
        lines = show(title, {sprintf('Excel 검사 실패 | %s | 모델 고르기와 TestManagement.xlsx를 확인하세요', ...
            id_of(ME)), write_report(ME, 'Excel 검사')});
        st_log(cfg, 'WARN', 'Input range check stopped | pre-validation error');
        return;
    end
    if height(checked) == 0
        lines = show(title, {'돌릴 대상이 없습니다. TestManagement.xlsx의 Targets 시트와 Enabled 칸을 확인하세요'});
        st_log(cfg, 'WARN', 'Input range check stopped | no targets');
        return;
    end
    ok = string(checked.Status) == "OK";
    targetNo = double(checked.No(ok));
    cutPaths = cellstr(checked.NormalizedCUTPath(ok));
    if any(~ok)
        lines{end+1} = sprintf('Excel 검사 실패 대상 %d개는 건너뜀', sum(~ok));
    end
else
    cutPaths = cellstr(cutPaths);
    targetNo = (1:numel(cutPaths))';
end

% Compile once so inherited types show what the CUT really gets.
models = unique(cellfun(@bdroot, cutPaths, 'UniformOutput', false));
compiledModels = {};
for m = 1:numel(models)
    try
        evalc('feval(models{m}, [], [], [], ''compile'');');
        compiledModels{end+1} = models{m}; %#ok<AGROW>
    catch ME
        lines{end+1} = sprintf('컴파일 실패 | %s | 상속 형식은 미확정으로 셉니다', id_of(ME)); %#ok<AGROW>
        lines{end+1} = write_report(ME, '컴파일'); %#ok<AGROW>
    end
end
compiled = numel(compiledModels) == numel(models) && ~isempty(models);
cleanup = onCleanup(@() terminate(compiledModels)); %#ok<NASGU>

rows = cell(0, 10);
for t = 1:numel(cutPaths)
    try
        rows = [rows; collect_cut(targetNo(t), cutPaths{t})]; %#ok<AGROW>
    catch ME
        lines{end+1} = sprintf('  대상 %d | 읽기 실패 | %s', targetNo(t), id_of(ME)); %#ok<AGROW>
        lines{end+1} = write_report(ME, sprintf('대상 %d', targetNo(t))); %#ok<AGROW>
    end
end
clear cleanup;
if isempty(rows)
    lines = show(title, [lines, {sprintf('대상 %d | 입력 0 | CUT에 Inport가 없거나 읽지 못했습니다', numel(cutPaths))}]);
    st_log(cfg, 'WARN', 'Input range check found no inputs | targets=%d', numel(cutPaths));
    return;
end
T = cell2table(rows, 'VariableNames', {'Target', 'CUT', 'Port', 'Input', 'Element', ...
    'DeclaredType', 'CompiledType', 'Dimensions', 'Min', 'Max'});
try
    writetable(T, csvFile, 'Encoding', 'UTF-8');
    fileLine = '표 전문: st_input_ranges.csv (임시 폴더, 이 PC에서만 보세요)';
catch
    fileLine = '표 전문을 쓰지 못함 | 임시 폴더 쓰기 권한을 확인하세요';
end

kinds = cellfun(@type_kind, T.DeclaredType, T.CompiledType, 'UniformOutput', false);
hasMin = ~cellfun(@is_unset, T.Min);
hasMax = ~cellfun(@is_unset, T.Max);
isBus = ~cellfun(@isempty, T.Element);
compileText = '컴파일 OK';
if ~compiled, compileText = '컴파일 안 됨'; end
head = {sprintf('대상 %d | 입력 %d | 그중 Bus 요소 %d | %s', numel(cutPaths), height(T), sum(isBus), compileText), ...
    ['형식 | ' kind_counts(kinds)], ...
    sprintf('범위 | 최소·최대 모두 %d | 한쪽만 %d | 없음 %d', sum(hasMin & hasMax), ...
        sum(xor(hasMin, hasMax)), sum(~hasMin & ~hasMax))};
for t = reshape(targetNo, 1, [])
    in = T.Target == t;
    if ~any(in), continue; end
    lines{end+1} = sprintf('  대상 %d | 입력 %d | 범위 없음 %d | 형식 미확정 %d', t, sum(in), ...
        sum(in & ~hasMin & ~hasMax), sum(in & strcmp(kinds, '미확정'))); %#ok<AGROW>
end
lines = show(title, [head, lines, {fileLine}]);
st_log(cfg, 'INFO', 'Input range check complete | targets=%d | inputs=%d | no range=%d', ...
    numel(cutPaths), height(T), sum(~hasMin & ~hasMax));
end


function rows = collect_cut(no, cutPath)
% One row per Inport, or per leaf element when the input is a Bus.
rows = cell(0, 10);
ports = find_system(cutPath, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'BlockType', 'Inport');
handles = get_param(cutPath, 'PortHandles');
for k = 1:numel(ports)
    p = ports{k};
    portNo = str2double(get_param(p, 'Port'));
    declared = get_param(p, 'OutDataTypeStr');
    compiledType = '';
    dims = get_param(p, 'PortDimensions');
    try
        compiledType = get_param(handles.Inport(portNo), 'CompiledPortDataType');
        dims = mat2str(get_param(handles.Inport(portNo), 'CompiledPortDimensions'));
    catch
        % Not compiled: keep the declared values.
    end
    name = get_param(p, 'Name');
    busName = bus_name(declared, compiledType);
    bus = [];
    if ~isempty(busName)
        try
            bus = slResolve(busName, cutPath);
        catch
            bus = [];
        end
    end
    if isa(bus, 'Simulink.Bus')
        leaves = bus_leaves(bus, '', cutPath);
        for e = 1:size(leaves, 1)
            rows(end+1, :) = {no, cutPath, portNo, name, leaves{e, 1}, leaves{e, 2}, '', ...
                leaves{e, 3}, leaves{e, 4}, leaves{e, 5}}; %#ok<AGROW>
        end
    else
        rows(end+1, :) = {no, cutPath, portNo, name, '', declared, compiledType, dims, ...
            get_param(p, 'OutMin'), get_param(p, 'OutMax')}; %#ok<AGROW>
    end
end
end


function leaves = bus_leaves(bus, prefix, context)
% {element path, DataType, Dimensions, Min, Max}; nested buses are walked.
leaves = cell(0, 5);
for e = 1:numel(bus.Elements)
    el = bus.Elements(e);
    path = el.Name;
    if ~isempty(prefix), path = [prefix '.' el.Name]; end
    inner = [];
    name = bus_name(el.DataType, '');
    if ~isempty(name)
        try
            inner = slResolve(name, context);
        catch
            inner = [];
        end
    end
    if isa(inner, 'Simulink.Bus')
        leaves = [leaves; bus_leaves(inner, path, context)]; %#ok<AGROW>
    else
        leaves(end+1, :) = {path, char(el.DataType), mat2str(el.Dimensions), ...
            num_text(el.Min), num_text(el.Max)}; %#ok<AGROW>
    end
end
end


function name = bus_name(declared, compiledType)
% A name that may be a Bus object; slResolve decides. An alias type resolves to a non-bus.
declared = char(declared);
if startsWith(declared, 'Bus:')
    name = strtrim(extractAfter(declared, 'Bus:'));
    return;
end
t = declared;
if startsWith(t, 'Inherit'), t = char(compiledType); end  % a compiled bus input reports the bus name
name = '';
if ~isempty(t) && strcmp(type_kind(t, ''), '기타'), name = t; end
end


function kind = type_kind(declared, compiledType)
% Standard MATLAB/Simulink type names only; anything named by the model is grouped.
t = char(declared);
if startsWith(t, 'Inherit')
    t = char(compiledType);
    if isempty(t), kind = '미확정'; return; end
end
builtin = {'double', 'single', 'half', 'boolean', 'int8', 'uint8', 'int16', 'uint16', ...
    'int32', 'uint32', 'int64', 'uint64'};
if any(strcmp(t, builtin))
    kind = t;
elseif startsWith(t, 'fixdt') || startsWith(t, 'sfix') || startsWith(t, 'ufix')
    kind = 'fixdt';
elseif startsWith(t, 'Enum')
    kind = 'Enum';
else
    kind = '기타';
end
end


function text = kind_counts(kinds)
[names, ~, idx] = unique(kinds);
counts = accumarray(idx(:), 1);
[counts, order] = sort(counts, 'descend');
parts = arrayfun(@(k) sprintf('%s %d', names{order(k)}, counts(k)), 1:numel(counts), ...
    'UniformOutput', false);
text = strjoin(parts, ' | ');
end


function tf = is_unset(value)
value = strtrim(char(string(value)));
tf = isempty(value) || strcmp(value, '[]');
end


function text = num_text(value)
if isempty(value), text = '[]'; else, text = mat2str(value); end
end


function terminate(models)
for m = 1:numel(models)
    try
        evalc('feval(models{m}, [], [], [], ''term'');');
    catch
    end
end
end


function line = write_report(ME, stage)
line = sprintf('  %s 오류 전문: st_todo_check.txt (임시 폴더)', stage);
fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
if fid < 0, line = sprintf('  %s 오류 전문을 쓰지 못함', stage); return; end
fprintf(fid, '[%s]\n%s\n\n', stage, getReport(ME, 'extended', 'hyperlinks', 'off'));
fclose(fid);
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
