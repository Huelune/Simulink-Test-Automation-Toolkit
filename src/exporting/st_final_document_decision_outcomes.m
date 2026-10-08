function outcomes = st_final_document_decision_outcomes(cfg, source)
%ST_FINAL_DOCUMENT_DECISION_OUTCOMES Read which way each branch went, per row.
% Reads the DecisionOutcomes sheets of the workbooks st_final_document_run_source
% listed: the same files, and the same stage, the verdicts come from.
%
% outcomes.Lookup(testCaseName, iterationName, relativePath) returns a
% struct. UnitFound says whether that row's test unit was scanned at all.
% Counts holds one [TrueCount FalseCount] row per decision of the block, in
% decision order, and is empty for a block with no two-way decision.
% Texts holds the recorded decision text for each row of Counts, with
% whitespace runs collapsed, so a D line that names its coverage decision
% can be paired by text rather than by position. A row
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
texts = containers.Map('KeyType', 'char', 'ValueType', 'any');
conflicts = strings(0,1);
for i = 1:height(source.Workbooks)
    entry = source.Workbooks(i,:);
    % A workbook that cannot be read is skipped whole, so its rows read as
    % unavailable and the export goes on.
    try
        rows = read_rows(cfg, entry.File);
        if isempty(rows), continue; end
        if ~ismember("DecisionText", string(rows.Properties.VariableNames))
            st_log(cfg, 'WARN', ...
                ['Final document decision outcomes workbook has no DecisionText ' ...
                 'column; text-paired blocks will read as mismatched | File=%s'], ...
                entry.File);
        end
        entries = workbook_entries(select_stage(rows, entry.Stage));
    catch ME
        st_log(cfg, 'WARN', ...
            'Final document decision outcomes workbook skipped | File=%s | %s', ...
            entry.File, ME.message);
        continue;
    end
    for r = 1:numel(entries.Unit)
        if entries.IsUnit(r)
            units(char(entries.Unit(r))) = true;
            continue;
        end
        key = char(entries.Key(r));
        index = entries.Index(r);
        value = entries.Value(r,:);
        current = nan(0,2);
        if isKey(decisions, key), current = decisions(key); end
        if size(current, 1) >= index && ~any(isnan(current(index,:))) && ...
                ~isequal(current(index,:), value)
            conflicts(end+1,1) = string(key); %#ok<AGROW>
        end
        current(size(current,1)+1:index, :) = NaN;
        current(index,:) = value;
        decisions(key) = current;
        recorded = strings(0,1);
        if isKey(texts, key), recorded = texts(key); end
        recorded(end+1:index, 1) = "";
        recorded(index) = entries.Text(r);
        texts(key) = recorded;
    end
end
for key = unique(conflicts).'
    remove(decisions, char(key));
    remove(texts, char(key));
    outcomes.Notes = [outcomes.Notes; table(NaN, extractBefore(key, "|"), ...
        "DECISION_OUTCOME_AMBIGUOUS", "Different counts recorded for " + key, ...
        'VariableNames', {'No','TestCaseName','Reason','Message'})];
    st_log(cfg, 'WARN', 'Final document decision outcome ambiguous | Key=%s', key);
end
% A gap in the decision order cannot be paired with D lines by position.
for key = string(keys(decisions))
    if any(isnan(decisions(char(key))), 'all')
        remove(decisions, char(key));
        remove(texts, char(key));
        st_log(cfg, 'WARN', 'Final document decision outcome incomplete | Key=%s', key);
    end
end
outcomes.Units = units.Count;
outcomes.Lookup = @(testCaseName, iterationName, relativePath) ...
    lookup(units, decisions, texts, testCaseName, iterationName, relativePath);
st_log(cfg, 'INFO', ...
    'Final document decision outcomes end | Units=%d | Blocks=%d | Notes=%d', ...
    units.Count, decisions.Count, height(outcomes.Notes));
end


function result = lookup(units, decisions, texts, testCaseName, iterationName, relativePath)
if ~st_is_real_iteration_name(iterationName)
    iterationName = "";
end
unit = unit_key(testCaseName, iterationName);
result = struct('UnitFound', isKey(units, char(unit)), 'Counts', zeros(0,2), ...
    'Texts', strings(0,1));
key = char(unit + "|" + squash(relativePath));
if isKey(decisions, key)
    result.Counts = decisions(key);
    result.Texts = texts(key);
end
end


function entries = workbook_entries(rows)
% Every row is checked before any is kept, so a bad row drops its whole
% workbook instead of leaving half of it behind.
count = height(rows);
entries = struct('Unit', strings(count,1), 'IsUnit', false(count,1), ...
    'Key', strings(count,1), 'Index', zeros(count,1), 'Value', zeros(count,2), ...
    'Text', strings(count,1));
hasText = ismember("DecisionText", string(rows.Properties.VariableNames));
for r = 1:count
    entries.Unit(r) = unit_key(rows.TestCaseName(r), rows.IterationName(r));
    entries.IsUnit(r) = rows.Kind(r) == "UNIT";
    if entries.IsUnit(r), continue; end
    index = double(rows.DecisionIndex(r));
    if ~isscalar(index) || ~isfinite(index) || index < 1 || index ~= fix(index)
        error('simtest:DecisionOutcomeIndex', ...
            'DecisionIndex must be a positive integer | TestCase=%s | Path=%s', ...
            rows.TestCaseName(r), rows.RelativePath(r));
    end
    entries.Key(r) = entries.Unit(r) + "|" + squash(rows.RelativePath(r));
    entries.Index(r) = index;
    entries.Value(r,:) = double([rows.TrueCount(r) rows.FalseCount(r)]);
    if hasText
        entries.Text(r) = squash(rows.DecisionText(r));
    end
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
