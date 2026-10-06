function [blockType, objectPath] = st_decision_object_path(blockPath, root)
%ST_DECISION_OBJECT_PATH Which catalog type a CUT child is, and where coverage keeps it.
% Returns the catalog type this block stands for and the path to ask
% coverage about, or an empty type when the block is not a decision at all.
% st_collect_decision_points and st_collect_decision_outcomes walk the same
% direct children and must agree on which of them are decisions.
objectPath = blockPath;
blockType = read_block_type(blockPath);
% A port block is reported through the subsystem that owns it, so seeing
% it on its own would record the same branch twice.
if any(strcmp(blockType, {'EnablePort', 'TriggerPort', 'ResetPort'}))
    blockType = '';
    return;
end
if ~any(strcmp(blockType, {'SubSystem', 'ModelReference', ''}))
    return;
end
% Only the CUT itself counts as conditional. A child subsystem's enable
% belongs to that child, the same reason a nested branch is out of scope.
if ~strcmp(blockType, 'SubSystem') || ~strcmp(blockPath, root)
    blockType = '';
    return;
end
for portType = {'EnablePort', 'TriggerPort', 'ResetPort'}
    port = conditional_port(blockPath, portType{1});
    if ~isempty(port)
        blockType = portType{1};
        objectPath = port;
        return;
    end
end
blockType = '';
end


function blockType = read_block_type(blockPath)
blockType = '';
try
    blockType = char(string(get_param(blockPath, 'BlockType')));
catch
    % A block whose type cannot be read cannot be matched to a catalog
    % entry either, so it is left out rather than guessed at.
end
end


function port = conditional_port(blockPath, portType)
port = '';
try
    found = find_system(blockPath, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'BlockType', portType);
catch
    return;
end
if ~isempty(found)
    port = char(string(found{1}));
end
end
