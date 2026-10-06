function relative = st_cut_relative_path(blockPath, cutPath)
%ST_CUT_RELATIVE_PATH A block path below its CUT, as a lookup key.
% The recording session and the export session can reach the CUT under
% different absolute paths (a standalone bundle renames the model), so
% DecisionOutcomes is keyed by the path below the CUT. The CUT itself is
% ".", and a block outside the CUT gives "".
%
% Whitespace runs collapse to one space. Simulink default names carry a
% newline ("For<newline>Iterator") and readtable trims text cells, so raw
% text would not match between the sheet and the model.
relative = "";
blockPath = squash(blockPath);
cutPath = squash(cutPath);
if strlength(cutPath) == 0 || strlength(blockPath) == 0
    return;
end
if blockPath == cutPath
    relative = ".";
    return;
end
% A CUT whose name ends in a space keeps one space before the separator.
for prefix = [cutPath + "/", cutPath + " /"]
    if startsWith(blockPath, prefix)
        relative = extractAfter(blockPath, strlength(prefix));
        return;
    end
end
end

function text = squash(text)
text = string(text);
if ~isscalar(text) || ismissing(text)
    text = "";
    return;
end
text = strtrim(regexprep(text, '\s+', ' '));
end
