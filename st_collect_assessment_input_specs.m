function specs = st_collect_assessment_input_specs(assessmentBlock)
%ST_COLLECT_ASSESSMENT_INPUT_SPECS Collect Test Assessment Input Data Symbols.
%
% Output table columns:
%   Port       - Actual Test Assessment input port number
%   Name       - Assessment Input symbol name
%   Width      - Total number of elements
%   Dimensions - Numeric dimension vector stored as a cell value
%   SizeText   - Raw/normalized Size text for diagnostics
%   DataType   - Raw DataType property from readSymbol
%
% Symbols are sorted by actual Assessment input Port.
% No model compile is performed here.

assessmentBlock = char(assessmentBlock);

symbols = sltest.testsequence.findSymbol(assessmentBlock, ...
    'Kind', 'Data', ...
    'Scope', 'Input');
symbols = normalize_cellstr(symbols);

n = numel(symbols);
Port = nan(n,1);
Name = strings(n,1);
Width = zeros(n,1);
Dimensions = cell(n,1);
SizeText = strings(n,1);
DataType = strings(n,1);

for i = 1:n
    symbolName = symbols{i};
    info = sltest.testsequence.readSymbol(assessmentBlock, symbolName);

    Name(i) = string(symbolName);
    Port(i) = read_symbol_port(assessmentBlock, symbolName, info);

    if isfield(info, 'DataType') && ~isempty(info.DataType)
        DataType(i) = string(info.DataType);
    else
        DataType(i) = '';
    end

    if isfield(info, 'Size')
        dims = size_to_dims(info.Size, symbolName);
        SizeText(i) = string(size_to_text(info.Size));
    else
        dims = [1 1];
        SizeText(i) = '';
    end

    Dimensions{i} = dims;
    Width(i) = prod(double(dims));
end

if any(~isfinite(Port)) || ...
        any(Port < 1) || ...
        any(mod(Port,1) ~= 0)

    error( ...
        'Could not determine valid Assessment input Port values: %s', ...
        assessmentBlock);
end

if numel(unique(Port)) ~= numel(Port)
    error( ...
        'Duplicate Assessment input Port values were found: %s', ...
        assessmentBlock);
end

[Port, idx] = sort(Port);
Name = Name(idx);
Width = Width(idx);
Dimensions = Dimensions(idx);
SizeText = SizeText(idx);
DataType = DataType(idx);

specs = table(Port, Name, Width, Dimensions, SizeText, DataType);
end


function port = read_symbol_port(assessmentBlock, symbolName, info)
port = nan;

% Use readSymbol Port when exposed by the installed release.
if isfield(info, 'Port') && ~isempty(info.Port)
    value = double(info.Port);

    if isscalar(value) && ...
            isfinite(value)

        port = value;
        return;
    end
end

% R2025b fallback verified with Test Assessment:
% Stateflow.Data.Port is the actual Assessment input port number.
dataObjects = find( ...
    sfroot, ...
    '-isa', ...
    'Stateflow.Data');

matches = [];

for i = 1:numel(dataObjects)
    obj = dataObjects(i);

    try
        if ~strcmp(char(obj.Scope), 'Input')
            continue;
        end

        if ~strcmp(char(obj.Path), assessmentBlock)
            continue;
        end

        if ~strcmp(char(obj.Name), symbolName)
            continue;
        end

        matches(end+1,1) = i; %#ok<AGROW>
    catch
    end
end

if numel(matches) ~= 1
    error( ...
        ['Could not uniquely determine Assessment Port for symbol %s. ' ...
         'Matched Stateflow.Data objects=%d'], ...
        symbolName, ...
        numel(matches));
end

value = double(dataObjects(matches(1)).Port);

if ~isscalar(value) || ...
        ~isfinite(value)

    error( ...
        'Invalid Assessment Port for symbol %s.', ...
        symbolName);
end

port = value;
end


function dims = size_to_dims(value, symbolName)
if isempty(value)
    dims = [1 1];
    return;
end

if isnumeric(value)
    dims = double(value(:).');
else
    s = strtrim(char(string(value)));

    if isempty(s)
        dims = [1 1];
        return;
    end

    % Accept only explicit integer dimensions, for example:
    %   '1', '4', '[1 4]', '[2,3]', '[2;3]'
    if isempty(regexp(s, '^[\[\]\d\s,;]+$', 'once'))
        error(['Cannot determine Assessment Size for symbol %s: %s. ' ...
            'Use an explicit numeric Size.'], symbolName, s);
    end

    clean = regexprep(s, '[\[\],;]', ' ');
    dims = double(sscanf(clean, '%d').');
end

if isempty(dims)
    dims = [1 1];
end

if any(~isfinite(dims)) || any(dims < 1) || any(mod(dims,1) ~= 0)
    error('Invalid Assessment Size for symbol %s.', symbolName);
end

% A scalar Size value of 1 is normalized to the common Simulink scalar
% representation [1 1]. This is useful for Bus indexing such as data(1,1).
if numel(dims) == 1 && dims(1) == 1
    dims = [1 1];
end
end


function text = size_to_text(value)
if isempty(value)
    text = '';
elseif isnumeric(value)
    text = mat2str(value);
else
    text = char(string(value));
end
end


function c = normalize_cellstr(v)
if isempty(v)
    c = {};
elseif iscell(v)
    c = cellfun(@char, v(:), 'UniformOutput', false);
elseif isstring(v)
    c = cellstr(v(:));
elseif ischar(v)
    c = {v};
else
    c = cellstr(string(v(:)));
end
end
