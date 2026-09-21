function outcomes = st_final_document_outcomes(cfg, source)
%ST_FINAL_DOCUMENT_OUTCOMES Read per-iteration verdicts from a resolved run.
% Reads only the Iterations and Targets sheets of the workbooks that
% st_final_document_run_source listed. No .mldatx is opened; the saved
% ResultSet path is carried through so the document can say where to look.
%
% outcomes.Iterations is keyed by TestCaseName and IterationName, and
% outcomes.Cases is the test-case level fallback for rows whose iteration
% name cannot be matched. Rows whose key repeats with different verdicts are
% marked Ambiguous instead of picking one.
outcomes = struct( ...
    'Iterations', empty_outcome_table(), ...
    'Cases', empty_outcome_table(), ...
    'Notes', source.Notes);
if isempty(source.Workbooks) || height(source.Workbooks) == 0
    return;
end
st_log(cfg, 'INFO', 'Final document outcomes start | Workbooks=%d', ...
    height(source.Workbooks));
for i = 1:height(source.Workbooks)
    entry = source.Workbooks(i,:);
    resultSet = result_set_for(source, entry);
    try
        [iterationRows, caseRows, notes] = read_workbook(cfg, entry, resultSet);
    catch ME
        outcomes.Notes = append_note(outcomes.Notes, entry.No, ...
            entry.TestCaseName, "RESULT_WORKBOOK_UNREADABLE", ME.message);
        st_log(cfg, 'WARN', 'Final document workbook unreadable | File=%s | %s', ...
            entry.File, ME.message);
        continue;
    end
    outcomes.Iterations = [outcomes.Iterations; iterationRows];
    outcomes.Cases = [outcomes.Cases; caseRows];
    outcomes.Notes = [outcomes.Notes; notes];
end
outcomes.Iterations = mark_ambiguous(outcomes.Iterations, ...
    ["TestCaseName","IterationName"]);
outcomes.Cases = mark_ambiguous(outcomes.Cases, "TestCaseName");
st_log(cfg, 'INFO', ...
    'Final document outcomes end | Iterations=%d | Cases=%d | Notes=%d', ...
    height(outcomes.Iterations), height(outcomes.Cases), height(outcomes.Notes));
end


function T = empty_outcome_table()
T = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), false(0,1), 'VariableNames', ...
    {'TestCaseName','IterationName','Verdict','Outcome','Stage','ResultSet','Ambiguous'});
end


function T = append_note(T, no, testCaseName, reason, message)
T = [T; table(double(no), string(testCaseName), string(reason), ...
    string(message), 'VariableNames', {'No','TestCaseName','Reason','Message'})];
end


function file = result_set_for(source, entry)
% PER_CUT records one ResultSet per target and stage. BATCH records one for
% the whole run, so its rows carry No 0 and an empty test case name.
file = "";
if isempty(source.ResultSets) || height(source.ResultSets) == 0
    return;
end
match = source.ResultSets.No == entry.No & ...
    source.ResultSets.Stage == entry.Stage;
if ~any(match)
    match = source.ResultSets.No == entry.No;
end
if ~any(match) && entry.Stage == "ANY"
    match = source.ResultSets.Stage == "FINAL";
    if ~any(match), match = true(height(source.ResultSets),1); end
end
if ~any(match), return; end
found = source.ResultSets.File(match);
file = found(end);
end


function [iterationRows, caseRows, notes] = read_workbook(cfg, entry, resultSet)
iterationRows = empty_outcome_table();
caseRows = empty_outcome_table();
notes = table(zeros(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','TestCaseName','Reason','Message'});
sheets = string(sheetnames(entry.File));
if ~any(sheets == "Iterations")
    notes = append_note(notes, entry.No, entry.TestCaseName, ...
        "RESULT_WORKBOOK_SHAPE_UNEXPECTED", ...
        sprintf('No Iterations sheet in %s', entry.File));
    return;
end
iterations = read_sheet(entry.File, 'Iterations');
required = ["Run","TestCaseName","IterationName","Outcome"];
if ~all(ismember(required, string(iterations.Properties.VariableNames)))
    notes = append_note(notes, entry.No, entry.TestCaseName, ...
        "RESULT_WORKBOOK_SHAPE_UNEXPECTED", ...
        sprintf('Iterations sheet is missing a required column in %s', entry.File));
    return;
end
[iterations, stage, stageNote] = select_stage(iterations, entry);
if strlength(stageNote) > 0
    notes = append_note(notes, entry.No, entry.TestCaseName, ...
        "NO_FINAL_RUN_USED_INITIAL", stageNote);
end
iterationRows = to_outcome_rows(iterations.TestCaseName, ...
    iterations.IterationName, iterations.Outcome, stage, resultSet);
if any(sheets == "Targets")
    targets = read_sheet(entry.File, 'Targets');
    if all(ismember(["Run","TestCaseName","Outcome"], ...
            string(targets.Properties.VariableNames)))
        targets = select_stage_rows(targets, stage);
        caseRows = to_outcome_rows(targets.TestCaseName, ...
            repmat("", height(targets), 1), targets.Outcome, stage, resultSet);
    end
end
st_log(cfg, 'DEBUG', ...
    'Final document workbook read | File=%s | Stage=%s | Iterations=%d', ...
    entry.File, stage, height(iterationRows));
end


function T = read_sheet(file, sheet)
T = readtable(file, 'Sheet', sheet, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
end


function [selected, stage, note] = select_stage(iterations, entry)
% A PER_CUT workbook holds one stage. The BATCH workbook holds both, and its
% FINAL rows are the ones the user saw last. FINAL rows exist even without a
% rerun, in which case they are a copy of INITIAL, so their presence says
% nothing about whether a rerun happened.
note = "";
if entry.Stage ~= "ANY"
    stage = entry.Stage;
    selected = select_stage_rows(iterations, stage);
    if height(selected) == 0, selected = iterations; end
    return;
end
stage = "FINAL";
selected = select_stage_rows(iterations, stage);
if height(selected) > 0, return; end
stage = "INITIAL";
selected = select_stage_rows(iterations, stage);
note = sprintf('No FINAL rows in %s, so the initial run is the final result.', ...
    entry.File);
if height(selected) == 0
    selected = iterations;
    stage = "ANY";
    note = "";
end
end


function selected = select_stage_rows(T, stage)
selected = T(upper(string(T.Run)) == upper(string(stage)), :);
end


function T = to_outcome_rows(testCaseName, iterationName, outcome, stage, resultSet)
count = numel(testCaseName);
outcomeText = normalize_text(outcome);
T = table(normalize_text(testCaseName), normalize_text(iterationName), ...
    verdict_of(outcomeText), outcomeText, ...
    repmat(string(stage), count, 1), repmat(string(resultSet), count, 1), ...
    false(count,1), 'VariableNames', ...
    {'TestCaseName','IterationName','Verdict','Outcome','Stage','ResultSet','Ambiguous'});
end


function text = normalize_text(value)
text = string(value);
text = text(:);
text(ismissing(text)) = "";
text = strtrim(text);
end


function verdict = verdict_of(outcome)
% Passed and Failed become the customer wording. Any other token is written
% through in upper case rather than hidden, because an Incomplete run is not
% a pass and must stay visible.
token = upper(outcome);
verdict = token;
verdict(token == "PASSED") = "PASS";
verdict(token == "FAILED") = "FAIL";
end


function T = mark_ambiguous(T, keyColumns)
% The same key can appear twice when a run holds more than one result for a
% test case. Agreeing duplicates are harmless; disagreeing ones must not be
% resolved by picking whichever came first.
if height(T) < 2, return; end
key = strings(height(T),1);
for i = 1:numel(keyColumns)
    key = key + string(char(31)) + T.(char(keyColumns(i)));
end
[unique_keys, ~, group] = unique(key);
for g = 1:numel(unique_keys)
    rows = group == g;
    if sum(rows) < 2, continue; end
    if numel(unique(T.Verdict(rows))) > 1
        T.Ambiguous(rows) = true;
    end
end
end
