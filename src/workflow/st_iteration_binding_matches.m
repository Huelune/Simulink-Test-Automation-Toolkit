function matches = st_iteration_binding_matches(parameters,names,scenario)
%ST_ITERATION_BINDING_MATCHES Match one key/value pair, not unrelated text.
matches = false;
if istable(parameters), parameters = table2struct(parameters); end
if isstruct(parameters)
    for i = 1:numel(parameters)
        item = parameters(i);
        for k = 1:numel(names)
            if isfield(item,names{k}) && exact_value(item.(names{k}),scenario)
                matches = true; return;
            end
        end
        for key = {'Name','Parameter','ParameterName'}
            if isfield(item,key{1}) && any(cellfun(@(n) exact_value(item.(key{1}),n),names))
                for value = {'Value','ParameterValue'}
                    if isfield(item,value{1}) && exact_value(item.(value{1}),scenario)
                        matches = true; return;
                    end
                end
            end
        end
    end
elseif iscell(parameters)
    if size(parameters,2) == 2 && size(parameters,1) > 1
        for i = 1:size(parameters,1)
            if any(cellfun(@(n) exact_value(parameters{i,1},n),names)) && exact_value(parameters{i,2},scenario)
                matches = true; return;
            end
        end
    else
        for i = 1:numel(parameters)-1
            if any(cellfun(@(n) exact_value(parameters{i},n),names)) && exact_value(parameters{i+1},scenario)
                matches = true; return;
            end
        end
    end
    for i = 1:numel(parameters)
        if st_iteration_binding_matches(parameters{i},names,scenario), matches = true; return; end
    end
elseif ischar(parameters) || isstring(parameters)
    % Accept only a complete serialized assignment; unknown formats block
    % readiness instead of accepting a scenario belonging to another key.
    for k = 1:numel(names)
        key = regexptranslate('escape',names{k});
        value = regexptranslate('escape',scenario);
        expression = ['^\s*' key '\s*[:=]\s*' value '\s*$'];
        if any(~cellfun(@isempty,regexp(cellstr(parameters),expression,'once')))
            matches = true; return;
        end
    end
end
end

function matches = exact_value(value,expected)
if iscell(value) && isscalar(value), value = value{1}; end
matches = (ischar(value) && isrow(value)) || (isstring(value) && isscalar(value));
if matches, matches = strcmp(string(value),string(expected)); end
end
