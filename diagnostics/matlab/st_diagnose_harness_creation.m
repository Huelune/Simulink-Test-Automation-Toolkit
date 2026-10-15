function report = st_diagnose_harness_creation(cut, varargin)
%ST_DIAGNOSE_HARNESS_CREATION Gather what support asks for when a Harness cannot be created.
%
% report = st_diagnose_harness_creation(gcb)
% report = st_diagnose_harness_creation(cut, 'MakeReducedModel', false)
% report = st_diagnose_harness_creation(cut, 'OutputFolder', folder)
%
% Select the CUT in Simulink and pass gcb. The diagnosis answers the
% questions a support request about a failed Harness asks:
%
%   1. The release (the text of version).
%   2. The CUT interface: per port whether it is a bus, the data type
%      class, dimensions and sample time. Equal ports are counted together.
%   3. Whether sltest.harness.create fails with Signal Editor and a separate
%      Test Assessment block, with Signal Editor alone, and with Inport.
%   4. A reduced model holding only the CUT interface, with every bus and
%      element renamed (ReproBus_<n>, e<n>) and enumerations replaced by
%      int32, and whether the same attempts fail on it. The reduced model
%      is meant to be sent when it reproduces the failure.
%
% Every Harness the diagnosis creates is deleted again, but the model is
% left modified: close it without saving. Harness input files are written
% to a temporary folder, not to pwd.
%
% The console shows counts, Simulink block types and MathWorks error
% identifiers only, never a model, block, bus or path name. Full error
% reports go to <OutputFolder>/st_harness_diagnosis.txt.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'cut', @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(p, 'MakeReducedModel', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'OutputFolder', tempdir, @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(p, 'Print', true, @(x) islogical(x) && isscalar(x));
parse(p, cut, varargin{:});
cut = char(p.Results.cut);
outputFolder = char(p.Results.OutputFolder);

cfg = struct('ConsoleLogLevel', 'ERROR');
st_log(cfg, 'INFO', 'Harness creation diagnosis start');
model = bdroot(cut);
blockType = get_param(cut, 'BlockType');
if ~any(strcmp(blockType, {'SubSystem', 'ModelReference', 'S-Function'}))
    % gcb is often a block inside the CUT when the CUT was opened.
    error('simtest:HarnessDiagnosisOwnerType', ...
        'The selected block is a %s, not the CUT. Select the CUT from its parent level.', blockType);
end
reproFolder = fullfile(outputFolder, 'st_harness_repro');
report = struct( ...
    'Version', string(version), ...
    'BlockType', string(get_param(cut, 'BlockType')), ...
    'Atomic', is_atomic(cut), ...
    'OtherPorts', other_port_count(cut), ...
    'CompileIds', "", ...
    'Ports', empty_ports(), ...
    'Original', [], ...
    'Reduced', [], ...
    'ReducedNotes', struct('EnumsReplaced', 0, 'TypesReplaced', 0, 'UnresolvedBuses', 0), ...
    'ReducedFiles', strings(0, 1), ...
    'ReportFile', string(fullfile(outputFolder, 'st_harness_diagnosis.txt')));
details = strings(0, 1);

attempts = struct( ...
    'Label', {'Signal Editor + 별도 Test Assessment', 'Signal Editor, Test Assessment 없음', ...
        'Inport + 별도 Test Assessment'}, ...
    'Source', {'Signal Editor', 'Signal Editor', 'Inport'}, ...
    'Separate', {true, false, true});

report.Original = run_attempts(cut, attempts, "원래 모델");

try
    report.Ports = read_interface(model, cut);
catch ME
    report.CompileIds = error_ids(ME);
    details(end+1, 1) = "[인터페이스 컴파일]" + newline + report_text(ME);
    st_log(cfg, 'WARN', 'Harness diagnosis could not compile the model | %s', report.CompileIds);
end
[report.Ports, derived] = derive_bus_objects(model, report.Ports);
clearDerived = onCleanup(@() clear_base(derived)); %#ok<NASGU>

if p.Results.MakeReducedModel && ~isempty(report.Ports)
    try
        [reducedCut, report.ReducedNotes, report.ReducedFiles] = ...
            build_reduced_model(model, cut, report.Ports, reproFolder);
        report.Reduced = run_attempts(reducedCut, attempts, "축소 모델");
        save_system(bdroot(reducedCut));
        close_system(bdroot(reducedCut), 0);
    catch ME
        report.Reduced = struct('Label', "축소 모델 만들기", 'Ok', false, ...
            'Ids', error_ids(ME), 'WarningId', "", 'Text', report_text(ME));
        st_log(cfg, 'WARN', 'Harness diagnosis could not build the reduced model | %s', ...
            report.Reduced.Ids);
    end
end

for r = [report.Original(:); report.Reduced(:)]'
    if ~r.Ok
        details(end+1, 1) = "[" + r.Label + "]" + newline + r.Text; %#ok<AGROW>
    end
end
write_text(report.ReportFile, strjoin([report.Version; details], [newline newline]));
if p.Results.Print
    print_report(report);
end
st_log(cfg, 'INFO', 'Harness creation diagnosis end | Ports=%d', numel(report.Ports));
end

function results = run_attempts(owner, attempts, scope)
% Signal Editor writes <Harness>_HarnessInputs.mat into pwd.
work = tempname;
mkdir(work);
here = pwd;
restore = onCleanup(@() leave(here, work)); %#ok<NASGU>
cd(work);
results = struct('Label', {}, 'Ok', {}, 'Ids', {}, 'WarningId', {}, 'Text', {});
for k = 1:numel(attempts)
    a = attempts(k);
    name = sprintf('ST_Diag_Harness%d', k);
    delete_harness(owner, name);
    r = struct('Label', scope + " | " + a.Label, 'Ok', false, 'Ids', "", ...
        'WarningId', "", 'Text', "");
    lastwarn('');
    try
        % evalc keeps the console to the one-screen report.
        evalc(['sltest.harness.create(owner, ''Name'', name, ''Source'', a.Source, ' ...
            '''SeparateAssessment'', a.Separate)']);
        r.Ok = true;
    catch ME
        r.Ids = error_ids(ME);
        r.Text = report_text(ME);
    end
    [~, warningId] = lastwarn;
    r.WarningId = string(warningId);
    delete_harness(owner, name);
    results(end+1) = r; %#ok<AGROW>
end
end

function leave(here, work)
cd(here);
try
    rmdir(work, 's');
catch
end
end

function delete_harness(owner, name)
try
    if ~isempty(sltest.harness.find(owner, 'Name', name))
        sltest.harness.delete(owner, name);
    end
catch
end
end

function ports = read_interface(model, cut)
evalc('feval(model, [], [], [], ''compile'')');
compiled = onCleanup(@() feval(model, [], [], [], 'term')); %#ok<NASGU>
handles = get_param(cut, 'PortHandles');
ports = empty_ports();
directions = {'In', 'Out'};
lists = {handles.Inport, handles.Outport};
for d = 1:2
    for h = lists{d}
        port = struct();
        port.Direction = string(directions{d});
        port.BusType = string(get_param(h, 'CompiledBusType'));
        port.DataType = string(get_param(h, 'CompiledPortDataType'));
        port.Dimensions = get_param(h, 'CompiledPortDimensions');
        port.SampleTime = get_param(h, 'CompiledSampleTime');
        port.Complex = isequal(get_param(h, 'CompiledPortComplexSignal'), 1);
        port.Bus = [];
        if port.BusType ~= "NOT_BUS"
            port.Bus = bus_shape(model, port.DataType);
        end
        % The port whose output is the bus: the driving port for an input.
        port.BusSource = h;
        if d == 1
            wire = get_param(h, 'Line');
            port.BusSource = -1;
            if wire ~= -1, port.BusSource = get_param(wire, 'SrcPortHandle'); end
        end
        ports(end+1) = port; %#ok<AGROW>
    end
end
end

function ports = empty_ports()
ports = struct('Direction', {}, 'BusType', {}, 'DataType', {}, 'Dimensions', {}, ...
    'SampleTime', {}, 'Complex', {}, 'Bus', {}, 'BusSource', {});
end

function [ports, created] = derive_bus_objects(model, ports)
% A virtual bus from a Bus Creator has no bus object. Simulink derives one
% from the signal hierarchy, so the reduced model keeps the bus structure
% instead of falling back to Inherit: auto. The model must not be compiled.
created = {};
for k = 1:numel(ports)
    b = ports(k).Bus;
    if ports(k).BusType == "NOT_BUS" || (~isempty(b) && b.Resolved), continue; end
    source = ports(k).BusSource;
    if source == -1, continue; end
    % Try the port first; a release that takes only blocks gets the block
    % that drives the bus, when that block has a single output.
    candidates = {source};
    owner = get_param(source, 'Parent');
    outputs = get_param(owner, 'PortHandles');
    if isscalar(outputs.Outport), candidates{end+1} = owner; end %#ok<AGROW>
    before = evalin('base', 'who');
    info = [];
    for c = 1:numel(candidates)
        target = candidates{c};
        try
            evalc('info = Simulink.Bus.createObject(model, target);');
            break;
        catch
        end
    end
    created = union(created, setdiff(evalin('base', 'who'), before));
    if isempty(info) || ~isfield(info, 'busName') || isempty(info(1).busName), continue; end
    ports(k).DataType = string(info(1).busName);
    ports(k).Bus = bus_shape(model, info(1).busName);
end
end

function clear_base(names)
if ~isempty(names)
    evalin('base', ['clear ' strjoin(names, ' ')]);
end
end

function shape = bus_shape(model, busName)
% Counts only; the names stay inside the model.
shape = struct('Resolved', false, 'Leaves', 0, 'Depth', 0, 'BusArrays', 0, ...
    'Enums', 0, 'VariableSize', 0, 'NonScalar', 0);
bus = resolve(model, busName);
if ~isa(bus, 'Simulink.Bus'), return; end
shape.Resolved = true;
shape = walk(bus, 1, shape);

    function s = walk(b, depth, s)
        s.Depth = max(s.Depth, depth);
        for e = b.Elements(:)'
            type = strtrim(string(e.DataType));
            dims = dimensions_value(model, e.Dimensions);
            if startsWith(type, "Bus:")
                if prod(dims) > 1, s.BusArrays = s.BusArrays + 1; end
                child = resolve(model, strtrim(extractAfter(type, "Bus:")));
                if isa(child, 'Simulink.Bus'), s = walk(child, depth + 1, s); end
                continue;
            end
            s.Leaves = s.Leaves + 1;
            if startsWith(type, "Enum:") || is_enum(type), s.Enums = s.Enums + 1; end
            if strcmpi(string(e.DimensionsMode), "Variable"), s.VariableSize = s.VariableSize + 1; end
            if prod(dims) > 1, s.NonScalar = s.NonScalar + 1; end
        end
    end
end

function value = resolve(model, name)
value = [];
try
    value = Simulink.data.evalinGlobal(model, char(name));
catch
    % Derived bus objects live in the base workspace, which a model
    % linked to a data dictionary may not see.
    try
        value = evalin('base', char(name));
    catch
    end
end
end

function dims = dimensions_value(model, dims)
if ischar(dims) || isstring(dims)
    value = str2num(char(dims)); %#ok<ST2NM>
    if isempty(value), value = resolve(model, dims); end
    if isa(value, 'Simulink.Parameter'), value = value.Value; end
    dims = value;
end
if isempty(dims) || ~isnumeric(dims), dims = 1; end
end

function tf = is_enum(type)
tf = false;
try
    tf = ~isempty(enumeration(char(type)));
catch
end
end

function [reducedCut, notes, files] = build_reduced_model(model, cut, ports, folder)
name = 'ST_HarnessRepro';
if bdIsLoaded(name), close_system(name, 0); end
if ~isfolder(folder), mkdir(folder); end
busMap = containers.Map();
buses = struct();
notes = struct('EnumsReplaced', 0, 'TypesReplaced', 0, 'UnresolvedBuses', 0);

new_system(name);
copy_solver(model, name);
reducedCut = [name '/CUT'];
add_block('built-in/SubSystem', reducedCut, 'Position', [300 100 500 300]);
set_param(reducedCut, 'TreatAsAtomicUnit', on_off(is_atomic(cut)));

inIndex = 0; outIndex = 0;
for port = ports(:)'
    [type, dims, ts] = port_attributes(port);
    if port.Direction == "In"
        inIndex = inIndex + 1;
        inner = sprintf('%s/In%d', reducedCut, inIndex);
        add_block('built-in/Inport', inner, 'Position', [50 50*inIndex 80 50*inIndex+14]);
        set_port(inner, type, dims, ts, port);
        sink = sprintf('%s/Term%d', reducedCut, inIndex);
        add_block('built-in/Terminator', sink, 'Position', [150 50*inIndex 170 50*inIndex+20]);
        add_line(reducedCut, sprintf('In%d/1', inIndex), sprintf('Term%d/1', inIndex));
        outer = sprintf('%s/In%d', name, inIndex);
        add_block('built-in/Inport', outer, 'Position', [100 50*inIndex 130 50*inIndex+14]);
        set_port(outer, type, dims, ts, port);
        add_line(name, sprintf('In%d/1', inIndex), sprintf('CUT/%d', inIndex));
    else
        outIndex = outIndex + 1;
        source = sprintf('%s/Const%d', reducedCut, outIndex);
        add_block('built-in/Constant', source, 'Position', [150 50*outIndex 190 50*outIndex+20], ...
            'Value', zero_value(type, dims), 'OutDataTypeStr', type, 'SampleTime', ts);
        inner = sprintf('%s/Out%d', reducedCut, outIndex);
        add_block('built-in/Outport', inner, 'Position', [250 50*outIndex 280 50*outIndex+14]);
        add_line(reducedCut, sprintf('Const%d/1', outIndex), sprintf('Out%d/1', outIndex));
        outer = sprintf('%s/Out%d', name, outIndex);
        add_block('built-in/Outport', outer, 'Position', [600 50*outIndex 630 50*outIndex+14]);
        add_line(name, sprintf('CUT/%d', outIndex), sprintf('Out%d/1', outIndex));
    end
end

modelFile = fullfile(folder, [name '.slx']);
files = string(modelFile);
if ~isempty(fieldnames(buses))
    % The reduced model loads its renamed buses itself, from beside the file.
    busFile = fullfile(folder, [name '_buses.mat']);
    save(busFile, '-struct', 'buses');
    assign_buses(buses);
    set_param(name, 'PreLoadFcn', sprintf('load(''%s_buses.mat'');', name));
    files(end+1, 1) = string(busFile);
    addpath(folder);
end
save_system(name, modelFile);

    function [type, dims, ts] = port_attributes(port)
        ts = sample_time_text(port.SampleTime);
        dims = port.Dimensions;
        if numel(dims) >= 2 && dims(1) > 0
            dims = dims(2:1+dims(1));
        else
            dims = 1;
        end
        if port.BusType ~= "NOT_BUS"
            if isempty(port.Bus) || ~port.Bus.Resolved
                notes.UnresolvedBuses = notes.UnresolvedBuses + 1;
                type = 'Inherit: auto';
            else
                type = ['Bus: ' anon_bus(port.DataType)];
            end
            dims = 1;
        else
            type = anon_type(port.DataType);
        end
    end

    function newName = anon_bus(oldName)
        oldName = char(strtrim(oldName));
        if isKey(busMap, oldName)
            newName = busMap(oldName);
            return;
        end
        newName = sprintf('ReproBus_%d', busMap.Count + 1);
        busMap(oldName) = newName;
        bus = resolve(model, oldName);
        reduced = Simulink.Bus;
        elements = Simulink.BusElement.empty;
        for i = 1:numel(bus.Elements)
            e = bus.Elements(i);
            n = Simulink.BusElement;
            n.Name = sprintf('e%d', i);
            n.Dimensions = dimensions_value(model, e.Dimensions);
            n.DimensionsMode = e.DimensionsMode;
            n.Complexity = e.Complexity;
            n.SampleTime = e.SampleTime;
            n.DataType = anon_type(e.DataType);
            elements(end+1) = n; %#ok<AGROW>
        end
        reduced.Elements = elements;
        buses.(newName) = reduced;
    end

    function type = anon_type(type)
        type = char(strtrim(string(type)));
        builtins = {'double', 'single', 'boolean', 'half', 'int8', 'uint8', 'int16', ...
            'uint16', 'int32', 'uint32', 'int64', 'uint64'};
        if any(strcmp(type, builtins)) || startsWith(type, 'Inherit:') || startsWith(type, 'fixdt(')
            return;
        end
        if startsWith(type, 'Bus:')
            type = ['Bus: ' anon_bus(strtrim(extractAfter(type, 'Bus:')))];
            return;
        end
        if startsWith(type, 'Enum:') || is_enum(type)
            notes.EnumsReplaced = notes.EnumsReplaced + 1;
            type = 'int32';
            return;
        end
        if ~isempty(regexp(type, '^[su]fix\d+', 'once')) || startsWith(type, 'flt')
            type = sprintf('fixdt(''%s'')', type);
            return;
        end
        value = resolve(model, type);
        if isa(value, 'Simulink.AliasType')
            type = anon_type(value.BaseType);
        elseif isa(value, 'Simulink.NumericType')
            type = numeric_type(value);
        else
            notes.TypesReplaced = notes.TypesReplaced + 1;
            type = 'double';
        end
    end
end

function type = numeric_type(t)
switch t.DataTypeMode
    case 'Double', type = 'double';
    case 'Single', type = 'single';
    case 'Boolean', type = 'boolean';
    case 'Fixed-point: binary point scaling'
        type = sprintf('fixdt(%d,%d,%d)', strcmp(t.Signedness, 'Signed'), ...
            t.WordLength, t.FractionLength);
    otherwise
        type = sprintf('fixdt(%d,%d,%.17g,%.17g)', strcmp(t.Signedness, 'Signed'), ...
            t.WordLength, t.Slope, t.Bias);
end
end

function value = zero_value(type, dims)
if startsWith(type, 'Bus:') || prod(dims) == 1
    value = '0';
elseif isscalar(dims)
    value = sprintf('zeros(%d,1)', dims);
else
    value = sprintf('zeros(%s)', mat2str(dims));
end
end

function set_port(block, type, dims, ts, port)
set_param(block, 'OutDataTypeStr', type, 'SampleTime', ts);
if ~startsWith(type, 'Bus:')
    set_param(block, 'PortDimensions', mat2str(dims));
    if port.Complex, set_param(block, 'SignalType', 'complex'); end
elseif port.BusType == "NON_VIRTUAL_BUS"
    % Renamed in newer releases; whichever the release knows applies.
    try, set_param(block, 'BusOutputAsStruct', 'on'); catch, end
    try, set_param(block, 'OutputAsNonvirtualBus', 'on'); catch, end
end
end

function text = sample_time_text(ts)
if iscell(ts) || isempty(ts), text = '-1'; return; end
if isinf(ts(1)), text = 'inf'; return; end
if ts(1) <= 0, text = '-1'; return; end
if numel(ts) >= 2 && ts(2) ~= 0
    text = sprintf('[%.17g %.17g]', ts(1), ts(2));
else
    text = sprintf('%.17g', ts(1));
end
end

function copy_solver(model, name)
set_param(name, 'SolverType', get_param(model, 'SolverType'));
set_param(name, 'Solver', get_param(model, 'Solver'));
if strcmp(get_param(model, 'SolverType'), 'Fixed-step')
    step = get_param(model, 'CompiledStepSize');
    if isnumeric(step) && isfinite(step) && step > 0
        set_param(name, 'FixedStep', sprintf('%.17g', step));
    end
end
end

function assign_buses(buses)
names = fieldnames(buses);
for i = 1:numel(names)
    assignin('base', names{i}, buses.(names{i}));
end
end

function tf = is_atomic(block)
tf = true;
try
    tf = strcmp(get_param(block, 'TreatAsAtomicUnit'), 'on');
catch
end
end

function text = on_off(tf)
text = 'off';
if tf, text = 'on'; end
end

function n = other_port_count(block)
handles = get_param(block, 'PortHandles');
n = 0;
for field = {'Enable', 'Trigger', 'Ifaction', 'Reset', 'State'}
    if isfield(handles, field{1}), n = n + numel(handles.(field{1})); end
end
end

function ids = error_ids(ME)
list = strings(0, 1);
queue = {ME};
while ~isempty(queue)
    e = queue{1};
    queue(1) = [];
    id = string(e.identifier);
    if id == "", id = "(식별자 없음)"; end
    if ~any(list == id), list(end+1, 1) = id; end %#ok<AGROW>
    queue = [queue, reshape(e.cause, 1, [])]; %#ok<AGROW>
end
ids = strjoin(list, " > ");
end

function text = report_text(ME)
text = string(getReport(ME, 'extended', 'hyperlinks', 'off'));
end

function write_text(file, text)
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0, return; end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', text);
end

function print_report(report)
clc
fprintf('하네스 생성 진단\n');
fprintf('version: %s\n', report.Version);
fprintf('CUT 블록 종류 %s | 원자 단위 %s | 기타 포트(Enable·Trigger 등) %d\n', ...
    report.BlockType, yes_no(report.Atomic), report.OtherPorts);
fprintf('\n[CUT 인터페이스] 같은 구성의 포트는 묶어 개수로 적음\n');
if report.CompileIds ~= ""
    fprintf('  모델 컴파일 실패: %s\n', report.CompileIds);
end
lines = port_lines(report.Ports);
shown = min(numel(lines), 12);
for i = 1:shown, fprintf('  %s\n', lines(i)); end
if numel(lines) > shown, fprintf('  ... 외 %d종\n', numel(lines) - shown); end
print_attempts('[원래 모델에서 sltest.harness.create]', report.Original);
if ~isempty(report.Reduced)
    n = report.ReducedNotes;
    print_attempts(sprintf('[축소 모델에서] 이름 익명화, 열거형 %d개·기타 형식 %d개 대체, 버스 객체 못 찾음 %d', ...
        n.EnumsReplaced, n.TypesReplaced, n.UnresolvedBuses), report.Reduced);
end
fprintf('\n');
if ~isempty(report.ReducedFiles)
    [~, f, fe] = fileparts(report.ReducedFiles);
    fprintf('축소 모델: %s  (%%TEMP%%\\st_harness_repro)\n', strjoin(f + fe, ', '));
end
[~, f, fe] = fileparts(report.ReportFile);
fprintf('전체 오류 보고: %%TEMP%%\\%s%s  (회사 밖으로 보내기 전에 이름을 확인하세요)\n', f, fe);
fprintf('원래 모델은 저장하지 말고 닫으세요.\n');
end

function print_attempts(title, results)
fprintf('\n%s\n', title);
for r = results(:)'
    label = extractAfter(r.Label, " | ");
    if ismissing(label), label = r.Label; end
    if r.Ok
        fprintf('  %-38s 성공\n', label);
    else
        fprintf('  %-38s 실패  %s\n', label, r.Ids);
    end
    if r.WarningId ~= ""
        fprintf('  %-38s 경고  %s\n', '', r.WarningId);
    end
end
end

function lines = port_lines(ports)
labels = strings(0, 1);
for port = ports(:)'
    labels(end+1, 1) = port_key(port); %#ok<AGROW>
end
[unique_keys, ~, idx] = unique(labels, 'stable');
lines = strings(numel(unique_keys), 1);
for i = 1:numel(unique_keys)
    lines(i) = sprintf('%3d개 %s', sum(idx == i), unique_keys(i));
end
end

function key = port_key(port)
side = "입력";
if port.Direction == "Out", side = "출력"; end
ts = string(sample_time_text(port.SampleTime));
if port.BusType == "NOT_BUS"
    dims = port.Dimensions;
    if numel(dims) >= 2 && dims(1) > 0, dims = dims(2:1+dims(1)); end
    key = sprintf('%s %s 크기 %s Ts %s', side, type_class(port.DataType), mat2str(dims), ts);
    if port.Complex, key = key + " 복소수"; end
    return;
end
kind = "가상 버스";
if port.BusType == "NON_VIRTUAL_BUS", kind = "비가상 버스"; end
b = port.Bus;
if isempty(b) || ~b.Resolved
    key = sprintf('%s %s (버스 객체 없음) Ts %s', side, kind, ts);
    return;
end
key = sprintf('%s %s 잎 %d 깊이 %d 배열요소 %d 버스배열 %d 열거형 %d 가변크기 %d Ts %s', ...
    side, kind, b.Leaves, b.Depth, b.NonScalar, b.BusArrays, b.Enums, b.VariableSize, ts);
end

function name = type_class(type)
builtins = ["double" "single" "boolean" "half" "int8" "uint8" "int16" "uint16" ...
    "int32" "uint32" "int64" "uint64"];
type = string(type);
if any(type == builtins)
    name = type;
elseif ~isempty(regexp(type, '^(s|u)?fix|^flt', 'once'))
    name = "fixdt";
elseif is_enum(type)
    name = "열거형";
else
    name = "기타";
end
end

function text = yes_no(tf)
text = '아니오';
if tf, text = '예'; end
end
