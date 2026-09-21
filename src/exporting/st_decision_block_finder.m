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
% CUT's direct children. Coverage recognises decisions at any depth, so the
% depth limit is deliberately not applied to a recorded list.
paths = {};
index = find(strcmp(args, 'BlockType'), 1);
if isempty(index) || index >= numel(args)
    return;
end
keep = entries.BlockType == string(args{index + 1});
if ~any(keep)
    return;
end
paths = cellstr(string(root) + "/" + entries.RelativePath(keep));
end
