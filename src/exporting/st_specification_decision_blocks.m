function [text, count, note] = st_specification_decision_blocks(cutPath, cfg, finder)
%ST_SPECIFICATION_DECISION_BLOCKS Export static control-decision candidates as JSON.
% Each JSON array item contains BlockType and the full Simulink Path. This
% is a static inventory, not the number of compiled coverage objectives.
if nargin < 3
    finder = @find_blocks;
end
blockTypes = ["If"; "MinMax"; "Switch"; "MultiPortSwitch"; "SwitchCase"];
pairs = strings(0,2);
notes = strings(0,1);
st_log(cfg, 'INFO', 'Specification decision block scan start | CUT=%s | Types=%d', ...
    cutPath, numel(blockTypes));
for k = 1:numel(blockTypes)
    blockType = blockTypes(k);
    st_log(cfg, 'DEBUG', 'Specification decision block type scan start | CUT=%s | BlockType=%s', ...
        cutPath, blockType);
    try
        paths = string(finder(char(cutPath), char(blockType)));
        paths = paths(:);
        paths = paths(strlength(paths) > 0);
        pairs = [pairs; repmat(blockType, numel(paths), 1) paths]; %#ok<AGROW>
        st_log(cfg, 'DEBUG', 'Specification decision block type scan end | CUT=%s | BlockType=%s | Count=%d', ...
            cutPath, blockType, numel(paths));
    catch ME
        message = string(sprintf('%s: %s', blockType, ME.message));
        notes(end+1,1) = message; %#ok<AGROW>
        st_log(cfg, 'WARN', 'Specification decision block type scan failed | CUT=%s | BlockType=%s | %s', ...
            cutPath, blockType, ME.message);
    end
end
if isempty(pairs)
    text = "[]";
    count = 0;
else
    pairs = unique(pairs, 'rows');
    pairs = sortrows(pairs, [2 1]);
    count = size(pairs,1);
    items = strings(count,1);
    for k = 1:count
        item = struct('BlockType', char(pairs(k,1)), 'Path', char(pairs(k,2)));
        items(k) = string(jsonencode(item));
    end
    text = "[" + newline + strjoin(items, "," + newline) + newline + "]";
end
note = strjoin(notes, ' | ');
st_log(cfg, 'INFO', 'Specification decision block scan end | CUT=%s | Count=%d | Warnings=%d', ...
    cutPath, count, numel(notes));
end

function paths = find_blocks(cutPath, blockType)
paths = find_system(cutPath, ...
    'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', ...
    'MatchFilter', @Simulink.match.allVariants, ...
    'Type', 'Block', ...
    'BlockType', blockType);
end
