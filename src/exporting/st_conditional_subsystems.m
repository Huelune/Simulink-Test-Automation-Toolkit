function paths = st_conditional_subsystems(root, portType)
%ST_CONDITIONAL_SUBSYSTEMS Subsystems that carry a given port, root included.
% An Enabled or Triggered Subsystem holds its branch on a port block one
% level inside it, so a depth 1 search for that port type finds nothing.
% This finds the subsystems instead, which is also the name a reader
% recognises: the port block is called Enable in every model.
%
% The CUT itself is tested as well as its direct children. A CUT is very
% often the Enabled Subsystem, and that enable is the one branch nothing
% else can report: it is not on a child, so a children-only scan loses it
% entirely. Nesting below a direct child is still excluded, which is the
% depth rule the ordinary decision blocks follow.
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
% find_system already returns the root when the root is a Subsystem, but
% not when it is a model, so the root is added explicitly and de-duplicated.
candidates = [{root}; children(:)];
seen = strings(0,1);
for i = 1:numel(candidates)
    candidate = char(string(candidates{i}));
    if any(seen == string(candidate))
        continue;
    end
    seen(end+1,1) = string(candidate); %#ok<AGROW>
    if has_port(candidate, portType)
        paths{end+1,1} = candidate; %#ok<AGROW>
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
