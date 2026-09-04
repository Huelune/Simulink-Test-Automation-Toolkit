function [value, note] = st_specification_parameter(parameters, aliases)
%ST_SPECIFICATION_PARAMETER Read exact named TestParams entries, without eval.
% Supports name/value matrices, flat pairs, nested pairs and struct entries.
values = strings(0,1);
visit(parameters);
values = unique(values, 'stable');
value = "";
note = "";
if numel(values) == 1
    value = values(1);
elseif numel(values) > 1
    note = "Ambiguous parameter " + strjoin(string(aliases), '/') + ...
        ": " + strjoin(values, ', ');
end

    function visit(raw)
        if isstruct(raw)
            for k = 1:numel(raw)
                if isfield(raw, 'Name') && isfield(raw, 'Value')
                    add(raw(k).Name, raw(k).Value);
                elseif isfield(raw, 'Parameter') && isfield(raw, 'Value')
                    add(raw(k).Parameter, raw(k).Value);
                else
                    fields = fieldnames(raw);
                    for f = 1:numel(fields), add(fields{f}, raw(k).(fields{f})); end
                end
            end
        elseif iscell(raw)
            if ismatrix(raw) && size(raw,2) == 2 && size(raw,1) > 1
                for k = 1:size(raw,1)
                    add(raw{k,1}, raw{k,2});
                    visit(raw{k,1});
                    if iscell(raw{k,2}) || isstruct(raw{k,2}), visit(raw{k,2}); end
                end
            else
                for k = 1:numel(raw)
                    if k < numel(raw), add(raw{k}, raw{k+1}); end
                    visit(raw{k});
                end
            end
        elseif (ischar(raw) && isrow(raw)) || (isstring(raw) && isscalar(raw))
            raw = char(raw);
            for a = 1:numel(aliases)
                token = regexp(raw, ['^\s*' regexptranslate('escape', aliases{a}) ...
                    '\s*[:=]\s*(.*?)\s*$'], 'tokens', 'once');
                if ~isempty(token), add(aliases{a}, token{1}); end
            end
        end
    end

    function add(name, raw)
        if ~(ischar(name) || (isstring(name) && isscalar(name))), return; end
        if ~any(strcmp(strtrim(string(name)), string(aliases))), return; end
        if ~(ischar(raw) || (isstring(raw) && isscalar(raw))), return; end
        v = strtrim(string(raw));
        c = char(v);
        if numel(c) >= 2 && ((c(1) == '''' && c(end) == '''') || ...
                (c(1) == '"' && c(end) == '"'))
            v = string(c(2:end-1));
        end
        if ~ismissing(v) && strlength(v) > 0, values(end+1,1) = v; end
    end
end
