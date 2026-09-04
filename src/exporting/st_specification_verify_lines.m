function [text, notes, count] = st_specification_verify_lines(action)
%ST_SPECIFICATION_VERIFY_LINES Summarize simple verifies without evaluating RHS.
% Mask comments/strings before scanning balanced calls; keep complex calls intact.
action = char(action);
masked = mask_noncode(action);
starts = regexp(masked, '(?<![\w.])verify\s*\(', 'start');
lines = cell(0,1);
notes = cell(0,1);
lastEnd = 0;
for n = 1:numel(starts)
    first = starts(n);
    if first <= lastEnd, continue; end
    open = first + find(masked(first:end) == '(', 1) - 1;
    depth = 1;
    last = open;
    while last < length(masked) && depth > 0
        last = last + 1;
        if masked(last) == '(', depth = depth + 1; end
        if masked(last) == ')', depth = depth - 1; end
    end
    if depth ~= 0
        lines{end+1,1} = strtrim(action(first:end)); %#ok<AGROW>
        notes{end+1,1} = 'Unclosed verify call preserved.'; %#ok<AGROW>
        break;
    end
    body = action(open+1:last-1);
    code = masked(open+1:last-1);
    equality = regexp(code, '==', 'start');
    simple = numel(equality) == 1;
    if simple
        lhs = strtrim(body(1:equality-1));
        rhs = strtrim(body(equality+2:end));
        index = '\(\s*\d+\s*(,\s*\d+\s*)*\)';
        symbol = ['[A-Za-z]\w*(' index ')?'];
        validLhs = ['^' symbol '(\.' symbol ')*$'];
        rhsCode = code(equality+2:end);
        simple = ~isempty(regexp(lhs, validLhs, 'once')) && ...
            ~isempty(rhs) && isempty(regexp(rhsCode, '[<>=~&|]', 'once')) && ...
            ~has_top_level_comma(rhsCode);
    end
    lastEnd = last;
    tail = last + 1;
    while tail <= length(action) && isspace(action(tail)), tail = tail + 1; end
    if tail <= length(action) && action(tail) == ';', lastEnd = tail; end
    if simple
        lines{end+1,1} = [lhs ': ' rhs]; %#ok<AGROW>
    else
        lines{end+1,1} = strtrim(action(first:lastEnd)); %#ok<AGROW>
        notes{end+1,1} = 'Complex verify preserved; see AssessmentDetails for context.'; %#ok<AGROW>
    end
end
text = string(strjoin(lines, newline));
notes = string(strjoin(unique(notes, 'stable'), ' | '));
count = numel(lines);
end

function tf = has_top_level_comma(code)
depth = 0;
tf = false;
for c = code
    if any(c == '([{'), depth = depth + 1; end
    if any(c == ')]}'), depth = depth - 1; end
    if c == ',' && depth == 0, tf = true; return; end
end
end

function masked = mask_noncode(source)
masked = source;
i = 1;
while i <= length(source)
    c = source(i);
    if c == '%'
        first = i;
        if i < length(source) && source(i+1) == '{'
            ending = strfind(source(i+2:end), '%}');
            if isempty(ending), i = length(source) + 1;
            else, i = i + ending(1) + 3; end
        else
            while i <= length(source) && source(i) ~= newline, i = i + 1; end
        end
        masked(first:i-1) = ' ';
    elseif c == '"' || (c == '''' && ~is_transpose(source, i))
        quote = c;
        first = i;
        i = i + 1;
        while i <= length(source)
            if source(i) == quote
                i = i + 1;
                if i <= length(source) && source(i) == quote
                    i = i + 1;
                else
                    break;
                end
            else
                i = i + 1;
            end
        end
        masked(first:i-1) = ' ';
    else
        i = i + 1;
    end
end
end

function tf = is_transpose(source, i)
tf = i > 1 && ~isempty(regexp(source(i-1), '[\w\)\]\}.]', 'once'));
end
