function points = st_collect_decision_points(cvd, root, cfg)
%ST_COLLECT_DECISION_POINTS List the blocks coverage recognised as decisions.
% Asks Simulink Coverage which blocks under root actually carry a Decision
% objective, instead of inferring it from saved block parameters. A model
% must be loaded for the block paths to resolve, which is the case while a
% result set is being reported.
%
% A plain Subsystem is skipped: decisioninfo on it returns the total of
% everything inside, so keeping it would report every ancestor as a
% decision block. An Enabled or Triggered Subsystem is kept, because the
% enable or trigger itself is a branch the CUT owns. Its objectives are
% read from the port block rather than from the subsystem, which is what
% keeps the inner total out.
%
% Only the CUT's direct children are listed, matching the static scan this
% replaces. What changes is which of them count as decisions: coverage is
% asked instead of the saved block parameters being guessed at.
%
% A block whose objectives were all excused by the registered coverage
% filter is left out too. With no filter registered nothing is excused and
% nothing is dropped.
%
% Returns BlockPath, BlockType, ObjectiveCount and JustifiedCount, one row
% per block.
if nargin < 3, cfg = []; end
points = empty_points();
root = char(string(root));
if isempty(root), return; end
timer = tic;
try
    % Direct children only, like the static scan it replaces. A decision
    % inside a nested subsystem belongs to that subsystem, not to this CUT,
    % and listing it makes the customer Description unreadable.
    % LookUnderMasks and FollowLinks stay on: without them a masked or
    % library-linked CUT reports no children at all.
    blocks = find_system(root, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'Type', 'Block');
catch ME
    st_log(cfg, 'WARN', ...
        'Decision point scan could not list blocks | Root=%s | %s', root, ME.message);
    return;
end
blocks = string(blocks(:));
skipped = 0;
for i = 1:numel(blocks)
    blockPath = char(blocks(i));
    [blockType, objectPath] = classify_block(blockPath, root);
    if isempty(blockType), continue; end
    [total, justified] = decision_objectives(cvd, objectPath);
    if total <= 0
        [total, justified] = own_objectives(cvd, blockPath);
    end
    if total <= 0 || active_objectives(total, justified) <= 0
        skipped = skipped + 1;
        continue;
    end
    points = [points; table(string(blockPath), string(blockType), ...
        total, justified, 'VariableNames', ...
        {'BlockPath','BlockType','ObjectiveCount','JustifiedCount'})]; %#ok<AGROW>
end
st_log(cfg, 'INFO', ...
    'Decision point scan complete | Root=%s | Blocks=%d | Decisions=%d | Filtered=%d | elapsed=%.3f sec', ...
    root, numel(blocks), height(points), skipped, toc(timer));
end


function T = empty_points()
T = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', {'BlockPath','BlockType','ObjectiveCount','JustifiedCount'});
end


function count = active_objectives(total, justified)
% An unreadable justified count is not zero justified objectives. Keeping
% the block is the safe reading: a filtered block shown is a nuisance, a
% real decision silently dropped is a wrong document.
if isnan(justified)
    count = total;
    return;
end
count = total - justified;
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


function [blockType, objectPath] = classify_block(blockPath, root)
% Returns the catalog type this block stands for and the path to ask
% coverage about, or an empty type when the block is not a decision at all.
objectPath = blockPath;
blockType = read_block_type(blockPath);
% A port block is reported through the subsystem that owns it, so seeing
% it on its own would record the same branch twice.
if any(strcmp(blockType, {'EnablePort', 'TriggerPort'}))
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
for portType = {'EnablePort', 'TriggerPort'}
    port = conditional_port(blockPath, portType{1});
    if ~isempty(port)
        blockType = portType{1};
        objectPath = port;
        return;
    end
end
blockType = '';
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


function [total, justified] = own_objectives(cvd, blockPath)
% Some releases attribute a conditional subsystem's branch to the
% subsystem rather than to its port block. Asking with descendants
% ignored keeps the inner blocks out of the count either way.
total = 0;
justified = 0;
try
    [values, description] = decisioninfo(cvd, blockPath, 1);
catch
    return;
end
if isempty(values) || numel(values) < 2, return; end
total = double(values(2));
if ~isscalar(total) || ~isfinite(total)
    total = 0;
    return;
end
justified = st_coverage_justified_count(description);
end


function [total, justified] = decision_objectives(cvd, blockPath)
% decisioninfo returns [covered total] and an empty value for a block that
% carries no decision at all. Both mean the same thing here: not a
% decision point in this run. The second output carries what the coverage
% filter excused.
total = 0;
justified = 0;
try
    [values, description] = decisioninfo(cvd, blockPath);
catch
    return;
end
if isempty(values) || numel(values) < 2, return; end
total = double(values(2));
if ~isscalar(total) || ~isfinite(total)
    total = 0;
    return;
end
justified = st_coverage_justified_count(description);
end
