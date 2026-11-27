function text = st_error_place(ME)
%ST_ERROR_PLACE Where a failure happened, in toolkit names only, for a screen line.
%
% text = st_error_place(ME)
%
% The first stack frame of a toolkit function (its name starts with st_ or
% run_exported_tests) as '<function> <line>줄', so the screen says where it
% broke and nobody has to open the full report. For an undefined toolkit
% function the missing name is added. Frames of other code (model
% callbacks, the team's own functions) are never shown, since their names
% may be internal; neither is the message. '' when no toolkit frame is
% found. ME is an MException or a struct with its identifier, message and
% stack fields.
parts = strings(0, 1);
for k = 1:numel(ME.stack)
    name = string(ME.stack(k).name);
    if startsWith(name, "st_") || startsWith(name, "run_exported_tests")
        parts(end+1, 1) = sprintf('%s %d줄', name, ME.stack(k).line); %#ok<AGROW>
        break;
    end
end
if strcmp(ME.identifier, 'MATLAB:UndefinedFunction')
    missing = regexp(char(ME.message), '''(st_\w+)''', 'tokens', 'once');
    if ~isempty(missing), parts(end+1, 1) = "없는 함수 " + missing{1}; end
end
text = char(strjoin(parts, ' | '));
end
