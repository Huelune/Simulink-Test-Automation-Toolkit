function code = st_executable_source(source)
%ST_EXECUTABLE_SOURCE Blank comments and literals so scans see only code.
% Static scans look for forbidden calls in a source file. A call spelled
% inside a comment or inside a documentation string is not a call, so the
% scan must not see it. Blanked spans are replaced by spaces rather than
% removed, which keeps every line and column in place.
source = char(source);
code = source;
count = numel(code);
index = 1;
previous = ' ';
while index <= count
    character = code(index);
    if character == '%' || is_continuation(code, index, count)
        stop = line_end(code, index, count);
        code(index:stop) = ' ';
        index = stop + 1;
        previous = ' ';
        continue;
    end
    if character == '"' || (character == '''' && ~is_transpose(previous))
        stop = literal_end(code, index, count, character);
        code(index:stop) = ' ';
        index = stop + 1;
        previous = ' ';
        continue;
    end
    if ~isspace(character)
        previous = character;
    end
    index = index + 1;
end
end


function tf = is_continuation(code, index, count)
% Whatever follows a line continuation on that line is a comment.
tf = index + 2 <= count && strcmp(code(index:index+2), '...');
end


function stop = line_end(code, index, count)
stop = index;
while stop <= count && code(stop) ~= newline
    stop = stop + 1;
end
stop = stop - 1;
end


function stop = literal_end(code, index, count, quote)
% A quote inside a literal is written twice. A literal never spans a line,
% so an unterminated one ends with its line.
stop = index + 1;
while stop <= count
    if code(stop) == newline
        stop = stop - 1;
        return;
    end
    if code(stop) == quote
        if stop + 1 <= count && code(stop + 1) == quote
            stop = stop + 2;
            continue;
        end
        return;
    end
    stop = stop + 1;
end
stop = count;
end


function tf = is_transpose(previous)
% A quote directly after a value is the transpose operator, not a literal.
tf = isletter(previous) || any(previous == '0123456789_)]}.''');
end
