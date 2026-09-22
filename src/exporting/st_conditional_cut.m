function paths = st_conditional_cut(root, portType)
%ST_CONDITIONAL_CUT The CUT itself when it is an Enabled or Triggered Subsystem.
% Returns the CUT path when it carries the given port block, and nothing
% otherwise. The return is a cell array so it can stand in for find_system.
%
% Only the CUT itself is reported. A child subsystem's enable belongs to
% that child, and the Description column describes one CUT, so a child's
% branch is out of scope exactly as a nested one is.
%
% The branch sits on a port block one level inside the subsystem, so a
% depth 1 search for the port type from above never sees it. That is why
% this exists: the CUT is reported, not the port. The port block is called
% Enable in every model and would say nothing about which CUT it is.
%
% Whether a CUT is enabled or triggered is structural. It is read from the
% model rather than asked of coverage, so it does not depend on a result
% having been collected.
paths = {};
root = char(string(root));
if isempty(root)
    return;
end
try
    found = find_system(root, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'BlockType', portType);
catch
    % A block that cannot be searched is not reported as conditional.
    return;
end
if ~isempty(found)
    paths = {root};
end
end
