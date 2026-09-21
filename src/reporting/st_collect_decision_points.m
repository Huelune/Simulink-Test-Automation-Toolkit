function points = st_collect_decision_points(cvd, root, cfg)
%ST_COLLECT_DECISION_POINTS List the blocks coverage recognised as decisions.
% Asks Simulink Coverage which blocks under root actually carry a Decision
% objective, instead of inferring it from saved block parameters. A model
% must be loaded for the block paths to resolve, which is the case while a
% result set is being reported.
%
% Aggregating containers are skipped. decisioninfo on a Subsystem returns
% the total of everything inside it, so keeping them would report every
% ancestor as a decision block.
%
% Returns BlockPath, BlockType and ObjectiveCount, one row per block.
if nargin < 3, cfg = []; end
points = empty_points();
root = char(string(root));
if isempty(root), return; end
timer = tic;
try
    blocks = find_system(root, 'LookUnderMasks', 'all', ...
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
    blockType = read_block_type(blockPath);
    if is_container(blockType), continue; end
    total = decision_objectives(cvd, blockPath);
    if total <= 0
        skipped = skipped + 1;
        continue;
    end
    points = [points; table(string(blockPath), string(blockType), total, ...
        'VariableNames', {'BlockPath','BlockType','ObjectiveCount'})]; %#ok<AGROW>
end
st_log(cfg, 'INFO', ...
    'Decision point scan complete | Root=%s | Blocks=%d | Decisions=%d | elapsed=%.3f sec', ...
    root, numel(blocks), height(points), toc(timer));
end


function T = empty_points()
T = table(strings(0,1), strings(0,1), zeros(0,1), ...
    'VariableNames', {'BlockPath','BlockType','ObjectiveCount'});
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


function tf = is_container(blockType)
tf = any(strcmp(blockType, {'SubSystem', 'ModelReference', ''}));
end


function total = decision_objectives(cvd, blockPath)
% decisioninfo returns [covered total] and an empty value for a block that
% carries no decision at all. Both mean the same thing here: not a
% decision point in this run.
total = 0;
try
    values = decisioninfo(cvd, blockPath);
catch
    return;
end
if isempty(values) || numel(values) < 2, return; end
total = double(values(2));
if ~isscalar(total) || ~isfinite(total), total = 0; end
end
