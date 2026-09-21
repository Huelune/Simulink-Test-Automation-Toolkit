function decisions = st_final_document_decisions(cfg, source)
%ST_FINAL_DOCUMENT_DECISIONS Read the decision blocks coverage recognised.
% st_export_result_set_report writes a DecisionPoints sheet while it still
% holds the coverage object and the loaded model. This reads that sheet so
% the final document can describe the decisions the run actually measured
% instead of the ones inferred from saved block parameters.
%
% Block paths are kept relative to their CUT. The recording session and the
% export session reach the CUT by the same management Excel entry, but a
% standalone bundle renames the model, so an absolute path would not always
% match. A relative path rebuilt under the export session's CUT does.
%
% decisions.ByCut maps a CUT name to a table of BlockType and RelativePath.
decisions = struct('ByCut', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'Notes', empty_note_table(), 'Workbooks', strings(0,1));
if isempty(source) || ~isfield(source, 'Workbooks') || height(source.Workbooks) == 0
    return;
end
paths = containers.Map('KeyType', 'char', 'ValueType', 'char');
for i = 1:height(source.Workbooks)
    file = source.Workbooks.File(i);
    rows = read_sheet(file);
    if isempty(rows), continue; end
    decisions.Workbooks(end+1,1) = file; %#ok<AGROW>
    [decisions, paths] = merge_rows(decisions, paths, rows, file);
end
st_log(cfg, 'INFO', ...
    'Final document decision points read | Workbooks=%d | CUTs=%d', ...
    numel(decisions.Workbooks), decisions.ByCut.Count);
end


function rows = read_sheet(file)
rows = [];
try
    if ~any(string(sheetnames(file)) == "DecisionPoints"), return; end
    rows = readtable(file, 'Sheet', 'DecisionPoints', 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
catch
    % A workbook written before this sheet existed simply has no data.
    rows = [];
end
if isempty(rows), return; end
required = ["CUTName","CUTPath","BlockPath","BlockType"];
if ~all(ismember(required, string(rows.Properties.VariableNames)))
    rows = [];
end
end


function [decisions, paths] = merge_rows(decisions, paths, rows, file)
names = strtrim(string(rows.CUTName));
for i = 1:height(rows)
    name = char(names(i));
    if isempty(name), continue; end
    cutPath = strtrim(string(rows.CUTPath(i)));
    if isKey(paths, name) && ~strcmp(paths(name), char(cutPath))
        % Two CUTs of the same name would silently share a block list.
        decisions.Notes = append_note(decisions.Notes, names(i), ...
            "DECISION_SOURCE_AMBIGUOUS_CUT", ...
            sprintf('More than one CUT path recorded for this name in %s.', file));
        continue;
    end
    paths(name) = char(cutPath); %#ok<NASGU>
    relative = relative_path(string(rows.BlockPath(i)), cutPath);
    if strlength(relative) == 0, continue; end
    entry = table(strtrim(string(rows.BlockType(i))), relative, ...
        'VariableNames', {'BlockType','RelativePath'});
    if isKey(decisions.ByCut, name)
        decisions.ByCut(name) = unique([decisions.ByCut(name); entry], 'rows');
    else
        decisions.ByCut(name) = entry;
    end
end
end


function relative = relative_path(blockPath, cutPath)
% A block recorded outside its own CUT cannot be rebuilt under it, so it is
% dropped rather than guessed at.
relative = "";
blockPath = strtrim(blockPath);
prefix = cutPath + "/";
if strlength(cutPath) == 0 || ~startsWith(blockPath, prefix)
    return;
end
relative = extractAfter(blockPath, strlength(prefix));
end


function T = empty_note_table()
T = table(zeros(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','TestCaseName','Reason','Message'});
end


function T = append_note(T, name, reason, message)
T = [T; table(NaN, string(name), string(reason), string(message), ...
    'VariableNames', {'No','TestCaseName','Reason','Message'})];
end
