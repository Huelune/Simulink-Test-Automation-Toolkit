function [verifyAction, verifyCount] = ...
    st_build_verify_action( ...
        targets, ...
        modelName, ...
        verifyFirstBusElementOnly)
%ST_BUILD_VERIFY_ACTION Build verify statements for Assessment step2.
%
% Scalar:
%   verify(A == 0);
%
% Numeric array:
%   verify(A(1) == 0);
%   verify(A(2) == 0);
%
% Bus:
%   verify(data(1,1).NAME == 0);
%
% verifyFirstBusElementOnly == true:
%   repeated Bus array instances are reduced to the first instance only.
%   Numeric arrays inside Bus leaf elements are still fully verified.

if nargin < 2
    modelName = '';
end

if nargin < 3
    verifyFirstBusElementOnly = false;
end

modelName = char(modelName);


if isempty(targets)

    verifyAction = '';
    verifyCount = 0;
    return;
end


requiredColumns = { ...
    'Name', ...
    'Width'};

for k = 1:numel(requiredColumns)

    if ~ismember( ...
            requiredColumns{k}, ...
            targets.Properties.VariableNames)

        error( ...
            'Verify target table is missing column: %s', ...
            requiredColumns{k});
    end
end


lines = {};


for i = 1:height(targets)

    symbolName = ...
        char(targets.Name(i));

    if ~isvarname(symbolName)

        error( ...
            'Assessment symbol is not a valid MATLAB identifier: %s', ...
            symbolName);
    end


    width = ...
        double(targets.Width(i));

    if isempty(width) || ...
            ~isfinite(width) || ...
            width < 1 || ...
            mod(width,1) ~= 0

        error( ...
            'Invalid verify width for symbol %s: %g', ...
            symbolName, ...
            width);
    end


    dims = ...
        get_target_dimensions( ...
            targets, ...
            i, ...
            width);

    dataType = ...
        get_target_datatype( ...
            targets, ...
            i);

    busName = ...
        parse_bus_name(dataType);


    %% ========================================================
    % Non-Bus
    %% ========================================================

    if isempty(busName)

        if width == 1

            lines{end+1,1} = ...
                sprintf( ...
                    'verify(%s == 0);', ...
                    symbolName); %#ok<AGROW>

        else

            for m = 1:width

                lines{end+1,1} = ...
                    sprintf( ...
                        'verify(%s(%d) == 0);', ...
                        symbolName, ...
                        m); %#ok<AGROW>
            end
        end

        continue;
    end


    %% ========================================================
    % Bus
    %% ========================================================

    if isempty(modelName)

        error( ...
            'Top model name is required to resolve Bus type %s.', ...
            busName);
    end

    busObj = ...
        resolve_bus_object( ...
            modelName, ...
            busName);


    if verifyFirstBusElementOnly

        busExpressions = { ...
            build_first_bus_expression( ...
                symbolName, ...
                dims)};

    else

        busExpressions = ...
            build_indexed_expressions( ...
                symbolName, ...
                dims, ...
                true);
    end


    for b = 1:numel(busExpressions)

        busLines = ...
            expand_bus_leaves( ...
                busExpressions{b}, ...
                busObj, ...
                modelName, ...
                verifyFirstBusElementOnly);

        lines = [ ...
            lines; ...
            busLines(:)]; %#ok<AGROW>
    end
end


verifyCount = ...
    numel(lines);

if verifyCount == 0

    verifyAction = '';

else

    verifyAction = ...
        strjoin( ...
            lines, ...
            sprintf('\n'));
end

end


%% ============================================================
% Target dimensions
%% ============================================================

function dims = ...
    get_target_dimensions( ...
        targets, ...
        row, ...
        width)

if ismember( ...
        'Dimensions', ...
        targets.Properties.VariableNames)

    value = ...
        targets.Dimensions{row};

    if isnumeric(value) && ...
            ~isempty(value)

        dims = ...
            double(value(:).');

        return;
    end
end

if width == 1
    dims = [1 1];
else
    dims = [1 width];
end

end


%% ============================================================
% Target DataType
%% ============================================================

function dataType = ...
    get_target_datatype( ...
        targets, ...
        row)

if ismember( ...
        'DataType', ...
        targets.Properties.VariableNames)

    dataType = ...
        char(targets.DataType(row));

else

    dataType = '';
end

end


%% ============================================================
% Bus type name
%% ============================================================

function busName = parse_bus_name(dataType)

dataType = ...
    strtrim(char(dataType));

busName = '';

if isempty(dataType)
    return;
end


token = ...
    regexp( ...
        dataType, ...
        '^Bus:\s*(.+)$', ...
        'tokens', ...
        'once');

if isempty(token)
    return;
end

busName = ...
    strtrim(token{1});

if length(busName) >= 2 && ...
        busName(1) == '<' && ...
        busName(end) == '>'

    busName = ...
        busName(2:end-1);
end

end


%% ============================================================
% Bus object
%% ============================================================

function busObj = ...
    resolve_bus_object( ...
        modelName, ...
        busName)

try

    busObj = ...
        Simulink.data.evalinGlobal( ...
            modelName, ...
            busName);

catch ME

    error( ...
        'Could not resolve Bus object %s: %s', ...
        busName, ...
        ME.message);
end

if ~isa(busObj, 'Simulink.Bus')

    error( ...
        'Resolved value is not a Simulink.Bus object: %s', ...
        busName);
end

end


%% ============================================================
% Bus leaf expansion
%% ============================================================

function lines = ...
    expand_bus_leaves( ...
        parentExpr, ...
        busObj, ...
        modelName, ...
        verifyFirstBusElementOnly)

lines = {};

elements = ...
    busObj.Elements;


for i = 1:numel(elements)

    elem = ...
        elements(i);

    fieldName = ...
        char(elem.Name);

    fieldExpr = ...
        [parentExpr '.' fieldName];

    fieldDims = ...
        normalize_bus_dimensions( ...
            elem.Dimensions);

    nestedBusName = ...
        parse_bus_name( ...
            elem.DataType);


    %% Nested Bus

    if ~isempty(nestedBusName)

        nestedBus = ...
            resolve_bus_object( ...
                modelName, ...
                nestedBusName);

        if prod(fieldDims) == 1

            nestedExprs = {fieldExpr};

        elseif verifyFirstBusElementOnly

            nestedExprs = { ...
                build_first_bus_expression( ...
                    fieldExpr, ...
                    fieldDims)};

        else

            nestedExprs = ...
                build_indexed_expressions( ...
                    fieldExpr, ...
                    fieldDims, ...
                    true);
        end


        for n = 1:numel(nestedExprs)

            nestedLines = ...
                expand_bus_leaves( ...
                    nestedExprs{n}, ...
                    nestedBus, ...
                    modelName, ...
                    verifyFirstBusElementOnly);

            lines = [ ...
                lines; ...
                nestedLines(:)]; %#ok<AGROW>
        end

        continue;
    end


    %% Normal leaf

    leafWidth = ...
        prod(fieldDims);

    if leafWidth == 1

        lines{end+1,1} = ...
            sprintf( ...
                'verify(%s == 0);', ...
                fieldExpr); %#ok<AGROW>

    else

        for m = 1:leafWidth

            lines{end+1,1} = ...
                sprintf( ...
                    'verify(%s(%d) == 0);', ...
                    fieldExpr, ...
                    m); %#ok<AGROW>
        end
    end
end

end


%% ============================================================
% Bus element dimensions
%% ============================================================

function dims = normalize_bus_dimensions(value)

if isempty(value)

    dims = [1 1];

elseif isnumeric(value)

    dims = ...
        double(value(:).');

else

    s = ...
        strtrim(char(string(value)));

    clean = ...
        regexprep( ...
            s, ...
            '[\[\],;]', ...
            ' ');

    dims = ...
        double(sscanf(clean, '%d').');
end

if isempty(dims)
    dims = [1 1];
end

if any(~isfinite(dims)) || ...
        any(dims < 1) || ...
        any(mod(dims,1) ~= 0)

    error('Unsupported Bus element dimensions.');
end

if numel(dims) == 1 && ...
        dims(1) == 1

    dims = [1 1];
end

end


%% ============================================================
% First Bus array instance
%% ============================================================

function expr = ...
    build_first_bus_expression( ...
        baseName, ...
        dims)

% [1 1]   -> a(1,1)
% [1 3]   -> a(1,1)
% [2 4]   -> a(1,1)
% [2 3 4] -> a(1,1,1)

dims = ...
    double(dims(:).');

if isempty(dims)
    dims = [1 1];
end

indices = ...
    repmat( ...
        {'1'}, ...
        1, ...
        numel(dims));

expr = ...
    sprintf( ...
        '%s(%s)', ...
        baseName, ...
        strjoin(indices, ','));

end


%% ============================================================
% All array instances
%% ============================================================

function expressions = ...
    build_indexed_expressions( ...
        baseName, ...
        dims, ...
        forceIndex)

if nargin < 3
    forceIndex = false;
end

dims = ...
    double(dims(:).');

if isempty(dims)
    dims = [1 1];
end

width = ...
    prod(dims);

if width == 1 && ...
        ~forceIndex

    expressions = {baseName};
    return;
end

expressions = ...
    cell(width,1);

numDims = ...
    numel(dims);

for linearIndex = 1:width

    subs = ...
        cell(1, numDims);

    [subs{:}] = ...
        ind2sub( ...
            dims, ...
            linearIndex);

    subText = ...
        cell(1, numDims);

    for d = 1:numDims

        subText{d} = ...
            num2str(subs{d});
    end

    expressions{linearIndex} = ...
        sprintf( ...
            '%s(%s)', ...
            baseName, ...
            strjoin(subText, ','));
end

end
