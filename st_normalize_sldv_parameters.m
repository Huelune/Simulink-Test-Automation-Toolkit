function normalized = st_normalize_sldv_parameters(params, sourceIndex)
%ST_NORMALIZE_SLDV_PARAMETERS Normalize sldvsimdata parameter metadata.

if nargin < 2
    sourceIndex = NaN;
end

normalized = struct('Name', {}, 'Value', {}, 'Source', {});
if isempty(params)
    return;
end
if ~isstruct(params)
    error('SLDV TestCase %g parameters are not a structure array.', sourceIndex);
end

for i = 1:numel(params)
    nameField = find_field(params, {'name','Name'});
    valueField = find_field(params, {'value','Value'});
    sourceField = find_field(params, {'source','Source'});

    if isempty(nameField) || isempty(valueField)
        error('SLDV TestCase %g parameter %d has no name/value.', ...
            sourceIndex, i);
    end

    nameValue = string(params(i).(nameField));
    if ~isscalar(nameValue) || ismissing(nameValue)
        error('SLDV TestCase %g parameter %d name is not scalar.', ...
            sourceIndex, i);
    end
    name = strtrim(char(nameValue));
    if isempty(name)
        error('SLDV TestCase %g parameter %d has an empty name.', ...
            sourceIndex, i);
    end

    source = '';
    if ~isempty(sourceField) && ~isempty(params(i).(sourceField))
        sourceValue = string(params(i).(sourceField));
        if ~isscalar(sourceValue)
            error('SLDV TestCase %g parameter %d source is not scalar.', ...
                sourceIndex, i);
        end
        if ~ismissing(sourceValue)
            source = strtrim(char(sourceValue));
        end
    end

    normalized(i).Name = name; %#ok<AGROW>
    normalized(i).Value = params(i).(valueField); %#ok<AGROW>
    normalized(i).Source = source; %#ok<AGROW>
end
end


function name = find_field(value, candidates)
name = '';
fields = fieldnames(value);
for i = 1:numel(candidates)
    row = find(strcmpi(fields, candidates{i}), 1, 'first');
    if ~isempty(row)
        name = fields{row};
        return;
    end
end
end
