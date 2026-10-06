function outcomes = st_final_document_decision_outcomes(cfg, source)
%ST_FINAL_DOCUMENT_DECISION_OUTCOMES Read which way each branch went, per row.
% Reads the DecisionOutcomes sheets of the workbooks st_final_document_run_source
% listed: the same files, and the same stage, the verdicts come from.
%
% outcomes.Lookup(testCaseName, iterationName, relativePath) returns a
% struct. UnitFound says whether that row's test unit was scanned at all.
% Counts holds one [TrueCount FalseCount] row per decision of the block, in
% decision order, and is empty for a block with no two-way decision. A row
% whose iteration name is a placeholder is looked up at the Test Case
% level, as its verdict is. Lookup is [] when no workbook was resolved, so
% a document made before any run carries no outcome reasons at all.
outcomes = struct('Units', 0, 'Notes', note_table(), 'Lookup', []);
if isempty(source) || ~isfield(source, 'Workbooks') || height(source.Workbooks) == 0
    return;
end
st_log(cfg, 'INFO', 'Final document decision outcomes start | Workbooks=%d', ...
    height(source.Workbooks));
units = containers.Map('KeyType', 'char', 'ValueType', 'logical');
decisions = containers.Map('KeyType', 'char', 'ValueType', 'any');
conflicts = strings(0,1);
for i = 1:height(source.Workbooks)
    entry = source.Workbooks(i,:);
    rows = read_rows(cfg, entry.File);
    if isempty(rows), continue; end
    rows = select_stage(rows, entry.Stage);
    for r = 1:height(rows)
        unit = unit_key(rows.TestCaseName(r), rows.IterationName(r));
        if rows.Kind(r) == "UNIT"
            units(char(unit)) = true;
            continue;
        end
        key = char(unit + "|" + squash(rows.RelativePath(r)));
        index = rows.DecisionIndex(r);
        value = [rows.TrueCount(r) rows.FalseCount(r)];
        current = nan(0,2);
        if isKey(decisions, key), current = decisions(key); end
        if size(current, 1) >= index && ~any(isnan(current(index,:))) && ...
                ~isequal(current(index,:), value)
            conflicts(end+1,1) = string(key); %#ok<AGROW>
        end
        current(size(current,1)+1:index, :) = NaN;
        current(index,:) = value;
        decisions(key) = current;
    end
end
for key = unique(conflicts).'
    remove(decisions, char(key));
    outcomes.Notes = [outcomes.Notes; table(NaN, extractBefore(key, "|"), ...
        "DECISION_OUTCOME_AMBIGUOUS", "Different counts recorded for " + key, ...
        'VariableNames', {'No','TestCaseName','Reason','Message'})];
    st_log(cfg, 'WARN', 'Final document decision outcome ambiguous | Key=%s', key);
end
% A gap in the decision order cannot be paired with D lines by position.
for key = string(keys(decisions))
    if any(isnan(decisions(char(key))), 'all')
        remove(decisions, char(key));
        st_log(cfg, 'WARN', 'Final document decision outcome incomplete | Key=%s', key);
    end
end
outcomes.Units = units.Count;
outcomes.Lookup = @(testCaseName, iterationName, relativePath) ...
    lookup(units, decisions, testCaseName, iterationName, relativePath);
st_log(cfg, 'INFO', ...
    'Final document decision outcomes end | Units=%d | Blocks=%d | Notes=%d', ...
    units.Count, decisions.Count, height(outcomes.Notes));
end


function result = lookup(units, decisions, testCaseName, iterationName, relativePath)
if ~st_is_real_iteration_name(iterationName)
    iterationName = "";
end
unit = unit_key(testCaseName, iterationName);
result = struct('UnitFound', isKey(units, char(unit)), 'Counts', zeros(0,2));
key = char(unit + "|" + squash(relativePath));
if isKey(decisions, key)
    result.Counts = decisions(key);
end
end


function rows = read_rows(cfg, file)
% A workbook written before this sheet existed simply has none.
rows = [];
text = ["Run","CUTName","TestCaseName","IterationName","Kind","RelativePath","DecisionText"];
try
    if ~any(string(sheetnames(file)) == "DecisionOutcomes"), return; end
    options = detectImportOptions(file, 'Sheet', 'DecisionOutcomes', ...
        'TextType', 'string', 'VariableNamingRule', 'preserve');
    % An all-blank column, or an iteration named "001", must not come back
    % as a number.
    options = setvartype(options, ...
        intersect(cellstr(text), options.VariableNames), 'string');
    rows = readtable(file, options);
catch ME
    st_log(cfg, 'WARN', 'Final document decision outcomes unreadable | File=%s | %s', ...
        file, ME.message);
    rows = [];
    return;
end
required = ["Run","TestCaseName","IterationName","Kind","RelativePath", ...
    "DecisionIndex","TrueCount","FalseCount"];
if ~all(ismember(required, string(rows.Properties.VariableNames)))
    st_log(cfg, 'WARN', 'Final document decision outcomes sheet is missing a column | File=%s', file);
    rows = [];
    return;
end
for name = intersect(text, string(rows.Properties.VariableNames))
    values = rows.(name);
    values(ismissing(values)) = "";
    rows.(name) = values;
end
end


function rows = select_stage(rows, stage)
% The verdict rule: a PER_CUT workbook names its stage, and a BATCH
% workbook holds both, FINAL first.
stage = upper(string(stage));
run = upper(rows.Run);
if stage ~= "ANY"
    picked = rows(run == stage, :);
elseif any(run == "FINAL")
    picked = rows(run == "FINAL", :);
else
    picked = rows(run == "INITIAL", :);
end
if height(picked) > 0, rows = picked; end
end


function key = unit_key(testCaseName, iterationName)
key = squash(testCaseName) + "|" + squash(iterationName);
end


function text = squash(text)
text = string(text);
if ~isscalar(text) || ismissing(text)
    text = "";
    return;
end
text = strtrim(regexprep(text, '\s+', ' '));
end


function T = note_table()
T = table(zeros(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','TestCaseName','Reason','Message'});
end
