function lines = st_explain_block_logic(startBlock, varargin)
%ST_EXPLAIN_BLOCK_LOGIC Print the logic behind a block as name-free equations.
%
%   st_explain_block_logic            % the selected block (gcb)
%   st_explain_block_logic(block)
%   st_explain_block_logic(block, 'MaxLines', 40)
%
% Unsatisfiable SLDV objectives often sit behind feedback loops wired with
% Goto/From across Subsystem boundaries, which are hard to follow by eye.
% This walks the signals feeding a block and prints them as equations:
%
%   Switch(선택 블록) = (D1 >= 1) ? T1 : T2
%   Enable(Enabled Subsystem) = In3 < (D2 + 1)
%   D1 (초기값 0) 다음 값 = ((T3 > 0) ? 0 : T4)
%
% Unit Delay / Delay / Memory become D1, D2...; CUT inputs In1, In2... (the
% CUT is found from the workbook, or pass 'Boundary', since SLDV treats the
% CUT's input ports as free inputs);
% long sub-expressions T1, T2...; constants given by a variable print the
% resolved number. No block, signal or variable name is printed, so the
% screen can leave the company. Goto/From, Subsystem ports and masked
% Compare To Constant/Zero blocks are followed. Nothing is changed or saved.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'MaxLines', 40, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Boundary', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
parse(p, varargin{:});
if nargin < 1 || isempty(startBlock)
    startBlock = gcb;
end
startBlock = getfullname(startBlock);

cfg = [];
try, cfg = st_config(); catch, end
log_line(cfg, 'INFO', 'Block logic explain start | BlockType=%s', ...
    get_param(startBlock, 'BlockType'));

state = struct();
state.Symbols = containers.Map();      % block|port key -> symbol
state.Pending = {};                    % {symbol, kind, path, port}
state.Counts = struct('D', 0, 'In', 0, 'T', 0, 'P', 0);
state.Lines = {};
% SLDV analyzes the CUT alone, so its input ports are free inputs: stop there.
state.Boundary = char(string(p.Results.Boundary));
if isempty(state.Boundary)
    state.Boundary = find_cut(startBlock);
end

% The start block and, if any, the Enabled Subsystem around it.
[startExpr, state] = describe_block(startBlock, state, 0);
state.Lines{end+1} = sprintf('선택 블록(%s) = %s', ...
    get_param(startBlock, 'BlockType'), startExpr);
enabled = enclosing_enabled(startBlock);
if ~isempty(enabled)
    handles = get_param(enabled, 'PortHandles');
    [enableExpr, state] = input_expr(handles.Enable, state, 0);
    enablePort = find_system(enabled, 'SearchDepth', 1, 'FollowLinks', 'on', ...
        'LookUnderMasks', 'all', 'BlockType', 'EnablePort');
    held = '';
    if ~isempty(enablePort)
        held = sprintf(' | 켜질 때 상태: %s', get_param(enablePort{1}, 'StatesWhenEnabling'));
    end
    state.Lines{end+1} = sprintf('Enable(감싼 Enabled Subsystem) = %s%s', enableExpr, held);
end

% Define every delay and long sub-expression that came up, breadth first.
while ~isempty(state.Pending) && numel(state.Lines) < p.Results.MaxLines
    item = state.Pending(1, :);
    state.Pending(1, :) = [];
    switch item{2}
        case 'D'
            handles = get_param(item{3}, 'PortHandles');
            [nextExpr, state] = input_expr(handles.Inport(1), state, 0);
            initial = resolve_text(get_param(item{3}, 'InitialCondition'), item{3}, state);
            where = '';
            if ~isempty(enclosing_enabled(item{3}))
                where = ' [Enabled Subsystem 안]';
            end
            state.Lines{end+1} = sprintf('%s (초기값 %s) 다음 값 = %s%s', ...
                item{1}, initial, nextExpr, where);
        case 'T'
            [body, state] = describe_block(item{3}, state, 0);
            state.Lines{end+1} = sprintf('%s = %s', item{1}, body);
    end
end
if ~isempty(state.Pending)
    state.Lines{end+1} = sprintf('... 정의하지 못한 기호 %d개(줄 수 제한)', size(state.Pending, 1));
end

for k = 1:numel(state.Lines)
    fprintf('%s\n', state.Lines{k});
end
lines = state.Lines;
log_line(cfg, 'INFO', 'Block logic explain complete | Lines=%d | Delays=%d | Inputs=%d', ...
    numel(lines), state.Counts.D, state.Counts.In);
end


function [expr, state] = describe_block(blockPath, state, depth)
%DESCRIBE_BLOCK Expression for a block's output from its inputs.
handles = get_param(blockPath, 'PortHandles');
type = get_param(blockPath, 'BlockType');
args = cell(1, numel(handles.Inport));
for k = 1:numel(handles.Inport)
    [args{k}, state] = input_expr(handles.Inport(k), state, depth + 1);
end
switch type
    case 'Switch'
        criteria = get_param(blockPath, 'Criteria');
        threshold = resolve_text(get_param(blockPath, 'Threshold'), blockPath, state);
        switch criteria
            case 'u2 >= Threshold', cond = sprintf('%s >= %s', args{2}, threshold);
            case 'u2 > Threshold', cond = sprintf('%s > %s', args{2}, threshold);
            otherwise, cond = sprintf('%s ~= 0', args{2});
        end
        expr = sprintf('(%s) ? %s : %s', cond, args{1}, args{3});
    case 'Sum'
        signs = strrep(get_param(blockPath, 'Inputs'), '|', '');
        if all(isstrprop(signs, 'digit')), signs = repmat('+', 1, numel(args)); end
        expr = '';
        for k = 1:numel(args)
            sign = signs(min(k, numel(signs)));
            if k == 1 && sign == '+', expr = args{k}; else, expr = [expr ' ' sign ' ' args{k}]; end %#ok<AGROW>
        end
        expr = ['(' strtrim(expr) ')'];
    case 'Product'
        ops = get_param(blockPath, 'Inputs');
        if all(isstrprop(ops, 'digit')), ops = repmat('*', 1, numel(args)); end
        expr = args{1};
        for k = 2:numel(args), expr = [expr ' ' ops(min(k, numel(ops))) ' ' args{k}]; end %#ok<AGROW>
        expr = ['(' expr ')'];
    case 'RelationalOperator'
        expr = sprintf('(%s %s %s)', args{1}, get_param(blockPath, 'Operator'), args{min(2, numel(args))});
    case 'Logic'
        operator = get_param(blockPath, 'Operator');
        if strcmp(operator, 'NOT'), expr = sprintf('NOT(%s)', args{1});
        else, expr = ['(' strjoin(args, [' ' operator ' ']) ')']; end
    case 'MinMax'
        expr = sprintf('%s(%s)', get_param(blockPath, 'Function'), strjoin(args, ', '));
    case 'Saturate'
        expr = sprintf('sat(%s, %s, %s)', args{1}, ...
            resolve_text(get_param(blockPath, 'LowerLimit'), blockPath, state), ...
            resolve_text(get_param(blockPath, 'UpperLimit'), blockPath, state));
    case 'Gain'
        expr = sprintf('(%s * %s)', resolve_text(get_param(blockPath, 'Gain'), blockPath, state), args{1});
    case 'DataTypeConversion'
        expr = sprintf('%s(%s)', short_type(get_param(blockPath, 'OutDataTypeStr')), args{1});
    case 'Abs'
        expr = sprintf('abs(%s)', args{1});
    otherwise
        expr = sprintf('%s(%s)', type, strjoin(args, ', '));
end
end


function [expr, state] = input_expr(portHandle, state, depth)
%INPUT_EXPR Expression for whatever drives an input port.
line = get_param(portHandle, 'Line');
if line < 0
    expr = '?';
    return;
end
source = get_param(line, 'SrcBlockHandle');
sourcePort = get_param(get_param(line, 'SrcPortHandle'), 'PortNumber');
[expr, state] = source_expr(getfullname(source), sourcePort, state, depth);
end


function [expr, state] = source_expr(sourcePath, sourcePort, state, depth)
type = get_param(sourcePath, 'BlockType');
key = sprintf('%s|%d', sourcePath, sourcePort);
if isKey(state.Symbols, key)
    expr = state.Symbols(key);
    return;
end
switch type
    case 'Constant'
        expr = resolve_text(get_param(sourcePath, 'Value'), sourcePath, state);
    case 'Ground'
        expr = '0';
    case {'UnitDelay', 'Delay', 'Memory'}
        [expr, state] = new_symbol(state, 'D', key, sourcePath, sourcePort);
    case 'From'
        gotoBlocks = find_system(bdroot(sourcePath), 'FollowLinks', 'on', ...
            'LookUnderMasks', 'all', 'BlockType', 'Goto', 'GotoTag', get_param(sourcePath, 'GotoTag'));
        if isempty(gotoBlocks), expr = '?From'; return; end
        handles = get_param(gotoBlocks{1}, 'PortHandles');
        [expr, state] = input_expr(handles.Inport(1), state, depth);
    case 'Inport'
        parentPath = get_param(sourcePath, 'Parent');
        if strcmp(parentPath, bdroot(sourcePath)) || strcmp(parentPath, state.Boundary)
            [expr, state] = new_symbol(state, 'In', key, sourcePath, sourcePort);
            return;
        end
        handles = get_param(parentPath, 'PortHandles');
        portNumber = str2double(get_param(sourcePath, 'Port'));
        if portNumber > numel(handles.Inport) || get_param(handles.Inport(portNumber), 'Line') < 0
            [expr, state] = new_symbol(state, 'In', key, sourcePath, sourcePort);
            return;
        end
        [expr, state] = input_expr(handles.Inport(portNumber), state, depth);
    case 'SubSystem'
        maskType = get_param(sourcePath, 'MaskType');
        if any(strcmp(maskType, {'Compare To Constant', 'Compare To Zero'}))
            handles = get_param(sourcePath, 'PortHandles');
            [inner, state] = input_expr(handles.Inport(1), state, depth + 1);
            constant = '0';
            if strcmp(maskType, 'Compare To Constant')
                constant = resolve_text(get_param(sourcePath, 'const'), sourcePath, state);
            end
            expr = sprintf('(%s %s %s)', inner, get_param(sourcePath, 'relop'), constant);
            return;
        end
        outport = find_system(sourcePath, 'SearchDepth', 1, 'FollowLinks', 'on', ...
            'LookUnderMasks', 'all', 'BlockType', 'Outport', 'Port', num2str(sourcePort));
        if isempty(outport), expr = '?Subsystem'; return; end
        handles = get_param(outport{1}, 'PortHandles');
        [expr, state] = input_expr(handles.Inport(1), state, depth);
    otherwise
        if depth >= 3
            % Keep lines short: name the deeper computation and define it later.
            [expr, state] = new_symbol(state, 'T', key, sourcePath, sourcePort);
        else
            state.Symbols(key) = '…';   % guards algebraic recursion while describing
            [expr, state] = describe_block(sourcePath, state, depth);
            remove(state.Symbols, key);
        end
end
end


function [symbol, state] = new_symbol(state, kind, key, blockPath, port)
state.Counts.(kind) = state.Counts.(kind) + 1;
symbol = sprintf('%s%d', kind, state.Counts.(kind));
state.Symbols(key) = symbol;
if any(strcmp(kind, {'D', 'T'}))
    state.Pending(end+1, :) = {symbol, kind, blockPath, port};
end
end


function text = resolve_text(value, blockPath, state) %#ok<INUSD>
%RESOLVE_TEXT Number for a block setting; a variable resolves to its value.
text = strtrim(char(string(value)));
if ~isempty(str2num(text)) %#ok<ST2NM>
    return;
end
try
    resolved = slResolve(text, blockPath);
    if isa(resolved, 'Simulink.Parameter'), resolved = resolved.Value; end
    text = mat2str(double(resolved));
catch
    text = 'P?';
end
end


function name = short_type(typeText)
name = char(string(typeText));
if startsWith(name, 'Inherit'), name = 'conv'; end
end


function enabled = enclosing_enabled(blockPath)
enabled = '';
current = blockPath;
while ~strcmp(get_param(current, 'Parent'), bdroot(current))
    current = get_param(current, 'Parent');
    handles = get_param(current, 'PortHandles');
    if ~isempty(handles.Enable)
        enabled = current;
        return;
    end
end
end


function cutPath = find_cut(blockPath)
%FIND_CUT The workbook CUT that contains the block, or '' when none does.
cutPath = '';
try
    cfg = st_config();
    rows = st_load_targets(cfg.OnlyEnabled);
    for k = 1:height(rows)
        candidate = char(st_normalize_cut_path(rows.CUTPath(k), cfg.TopModel));
        if startsWith(blockPath, [candidate '/']) && numel(candidate) > numel(cutPath)
            cutPath = candidate;
        end
    end
catch
end
end


function log_line(cfg, level, varargin)
if isempty(cfg), return; end
try, st_log(cfg, level, varargin{:}); catch, end
end
