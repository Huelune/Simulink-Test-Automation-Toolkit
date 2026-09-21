function finder = st_decision_block_finder(entries)
%ST_DECISION_BLOCK_FINDER A find_system stand-in backed by recorded blocks.
% st_specification_decision_blocks takes its block search as an argument.
% Handing it this closure swaps the saved-parameter guess for the blocks
% Simulink Coverage actually recognised, and leaves the name reading,
% expression reading, D numbering and JSON assembly exactly as they are.
if isempty(entries) || height(entries) == 0
    finder = [];
    return;
end
finder = @(root, varargin) select_blocks(entries, root, varargin);
end


function paths = select_blocks(entries, root, args)
% The caller asks one BlockType at a time and limits find_system to the
% CUT's direct children. That limit is honoured here as well: a relative
% path with a separator in it sits inside a nested subsystem and belongs to
% that subsystem, not to this CUT. The recording side already filters these
% out, so this only guards a sheet written before it did.
paths = {};
index = find(strcmp(args, 'BlockType'), 1);
if isempty(index) || index >= numel(args)
    return;
end
blockType = char(string(args{index + 1}));
% Whether a subsystem is enabled or triggered is structural, so it is read
% from the model. Answering these from the recorded list would drop them
% whenever the list was written before this was supported, or whenever
% coverage attributed the branch somewhere this scan did not look.
if any(strcmp(blockType, {'EnablePort', 'TriggerPort'}))
    paths = st_conditional_subsystems(root, blockType);
    return;
end
keep = entries.BlockType == string(blockType) & ...
    ~contains(entries.RelativePath, "/");
if ~any(keep)
    return;
end
paths = cellstr(string(root) + "/" + entries.RelativePath(keep));
end
