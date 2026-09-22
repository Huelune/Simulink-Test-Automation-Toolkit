function paths = st_conditional_subsystems(root, portType)
%ST_CONDITIONAL_SUBSYSTEMS Direct child subsystems that carry a given port.
% An Enabled or Triggered Subsystem holds its branch on a port block one
% level inside it, so a depth 1 search for that port type finds nothing.
% This finds the subsystems instead, which is also the name a reader
% recognises: the port block is called Enable in every model.
%
% Only direct children count, the same rule the ordinary decision blocks
% follow. The CUT itself is not reported even when it is an Enabled
% Subsystem: its enable belongs to whatever instantiates the CUT, not to
% the contents this row describes.
%
% Whether a subsystem is enabled or triggered is structural. It is read
% from the model rather than asked of coverage, so it does not depend on a
% result having been collected.
paths = {};
root = char(string(root));
if isempty(root)
    return;
end
try
    children = find_system(root, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'BlockType', 'SubSystem');
catch
    return;
end
for i = 1:numel(children)
    child = char(string(children{i}));
    % find_system reports the root itself when the root is a Subsystem.
    if strcmp(child, root)
        continue;
    end
    if has_port(child, portType)
        paths{end+1,1} = child; %#ok<AGROW>
    end
end
end


function tf = has_port(blockPath, portType)
tf = false;
try
    tf = ~isempty(find_system(blockPath, 'SearchDepth', 1, ...
        'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', portType));
catch
    % A block that cannot be searched is not reported as conditional.
end
end
