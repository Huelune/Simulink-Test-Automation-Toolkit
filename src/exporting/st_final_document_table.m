function document = st_final_document_table(cfg, specification, outcomes, source)
%ST_FINAL_DOCUMENT_TABLE Build the customer sheet and its result sheet.
% One specification row becomes one customer row. The customer form has no
% remarks column, so every reason lives on the result sheet, which stays
% row-for-row aligned with the customer sheet.
%
% The failed verify text is deliberately not extracted. The result sheet
% says which row to look at and which saved ResultSet to open, and no
% .mldatx is read here.
naText = string(config_value(cfg, 'FinalDocumentNAText', 'N/A'));

count = height(specification);
st_log(cfg, 'INFO', 'Final document table start | Rows=%d', count);
[identifier, caseId, idReasons] = build_identifiers(specification);
expected = column_text(specification, 'verify 내용');
action = replace_not_applicable(column_text(specification, 'input 시나리오 내용'), naText);
material = replace_not_applicable(column_text(specification, ...
    '하네스 input 파일명'), naText);

document.ResultHeaders = {'Row', 'Test Case ID', 'TestCaseName', ...
    'Iteration명', '판정 결과', '확인 필요', '확인 사유', '확인 위치', '추출상태'};
document.DisplayHeaders = {'Test Case ID', 'ID', '-', 'Pre Condition', ...
    'Description', 'Test Steps.Action', 'Test Steps.Expected result', ...
    '-', '-', '-', '-', '출력값', '판정 결과', '테스트 자료'};
blank = repmat("", count, 1);
document.Sheet1 = table(identifier, caseId, blank, ...
    column_number(specification, 'MaxTime'), ...
    column_text(specification, 'DecisionBlocks'), action, expected, ...
    blank, blank, blank, blank, expected, blank, material, ...
    'VariableNames', {'TestCaseID','CaseId','Dash03','PreCondition', ...
    'Description','Action','ExpectedResult','Dash08','Dash09','Dash10', ...
    'Dash11','OutputValue','Judgement','TestData'});

[judgement, results] = resolve_judgements( ...
    cfg, specification, outcomes, source, identifier, idReasons);
document.Sheet1.Judgement = judgement;
document.Results = results;
document.Results = append_source_notes(document.Results, outcomes.Notes);
st_log(cfg, 'INFO', ...
    'Final document table end | Rows=%d | Flagged=%d | ResultRows=%d', ...
    count, sum(document.Results.('확인 필요') == "Y"), height(document.Results));
end

function value = config_value(cfg, name, fallback)
value = fallback;
if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
    value = cfg.(name);
end
end


function text = column_text(T, name)
if ~ismember(name, T.Properties.VariableNames)
    text = repmat("", height(T), 1);
    return;
end
text = string(T.(name));
text = text(:);
text(ismissing(text)) = "";
end


function value = column_number(T, name)
if ~ismember(name, T.Properties.VariableNames)
    value = nan(height(T), 1);
    return;
end
value = double(T.(name));
value = value(:);
end


function text = replace_not_applicable(text, naText)
% The collector marks an OFF target without a Signal Editor in Korean. The
% customer sheet writes the same N/A that the coverage sheet uses.
text(strtrim(text) == "해당 없음") = naText;
end


function [identifier, caseId, reasons] = build_identifiers(specification)
%BUILD_IDENTIFIERS Split the scenario and test case names into two columns.
% Column 1 becomes UT_REQ_{CUT}_{ID}_{NUM} and column 2 the bare {ID}.
%
% The {ID} is taken by removing the CUT name prefix from the test case
% name, not by splitting on the last underscore, because a CUT name may
% contain underscores of its own.
%
% The composed value is built by splicing {ID} into the scenario name
% rather than reassembling it from the CUT name. st_scenario_name rewrites
% a CUT name that is not a valid identifier, replacing characters and
% appending a digest, so the scenario may read UT_REQ_A_B_C_3f9a2c_001. The
% splice keeps whatever that scenario actually is, so column 1 always
% matches a real scenario with only the ID added.
scenario = column_text(specification, 'Test Sequence scenario 명');
testCase = column_text(specification, '테스트 케이스명');
cutName = strtrim(column_text(specification, '대상 모델명'));
count = numel(scenario);
identifier = scenario;
caseId = testCase;
reasons = repmat("", count, 1);
for i = 1:count
    id = extract_case_id(testCase(i), cutName(i));
    [stem, number] = split_scenario(scenario(i));
    if strlength(id) == 0 || strlength(number) == 0
        % Keep both names as they are so no cell goes blank, and say which
        % row is off the convention.
        reasons(i) = "TESTCASE_ID_PATTERN_UNMATCHED";
        continue;
    end
    identifier(i) = stem + "_" + id + "_" + number;
    caseId(i) = id;
end
end


function id = extract_case_id(testCase, cutName)
% The convention is {CUT}_{codeBeamer ID}.
id = "";
prefix = cutName + "_";
if strlength(cutName) == 0 || ~startsWith(testCase, prefix)
    return;
end
id = extractAfter(testCase, strlength(prefix));
end


function [stem, number] = split_scenario(scenario)
% The convention is {anything}_{three digit index}.
stem = "";
number = "";
token = regexp(scenario, '^(.*)_(\d{3})$', 'tokens', 'once');
if isempty(token)
    return;
end
stem = string(token{1});
number = string(token{2});
end


function [judgement, results] = resolve_judgements(cfg, specification, outcomes, source, identifier, idReasons)
count = height(specification);
judgement = repmat("", count, 1);
testCaseName = column_text(specification, '테스트 케이스명');
iterationName = column_text(specification, 'Iteration명');
extractStatus = column_text(specification, '추출상태');
remarks = column_text(specification, '비고');
maxTime = column_number(specification, 'MaxTime');
location = repmat("", count, 1);
reasons = repmat("", count, 1);
needsReview = repmat("", count, 1);
duplicate = duplicate_identifiers(identifier);
blanket = blanket_reason(outcomes);

for i = 1:count
    [verdict, resultSet, reason] = lookup_verdict(outcomes, ...
        testCaseName(i), iterationName(i));
    if reason == "NO_MATCHING_TEST_RESULT" && strlength(blanket) > 0
        reason = blanket;
    end
    judgement(i) = verdict;
    location(i) = resultSet;
    reasons(i) = join_reasons(idReasons(i), reason);
    if verdict == "FAIL"
        reasons(i) = join_reasons(reasons(i), "FAILED");
    elseif strlength(verdict) > 0 && verdict ~= "PASS"
        reasons(i) = join_reasons(reasons(i), "NOT_PASSED:" + verdict);
    end
    if isnan(maxTime(i))
        reasons(i) = join_reasons(reasons(i), "MAXTIME_UNAVAILABLE");
    end
    if duplicate(i)
        reasons(i) = join_reasons(reasons(i), "DUPLICATE_TEST_CASE_ID");
    end
    if extractStatus(i) == "FAIL" || extractStatus(i) == "WARN"
        reasons(i) = join_reasons(reasons(i), remarks(i));
    end
    if strlength(reasons(i)) > 0 && ~only_informational(reasons(i))
        needsReview(i) = "Y";
    end
end
if isempty(source) || ~isfield(source, 'Mode') || strcmp(source.Mode, 'NONE')
    st_log(cfg, 'WARN', 'Final document judgements | No run was resolved');
end

% RowNumber, not Row: a table variable cannot repeat a dimension name and
% DimensionNames defaults to {'Row','Variables'}. The sheet still says Row,
% through ResultHeaders.
results = table((2:count+1)', identifier, testCaseName, iterationName, ...
    judgement, needsReview, reasons, location, extractStatus, ...
    'VariableNames', {'RowNumber','Test Case ID','TestCaseName','Iteration명', ...
    '판정 결과','확인 필요','확인 사유','확인 위치','추출상태'});
end


function reason = blanket_reason(outcomes)
% When not one verdict was read, every row failing to match is a symptom.
% Reporting NO_MATCHING_TEST_RESULT on all of them buries the one thing
% the reader has to act on, so name the cause the run source already found.
reason = "";
if height(outcomes.Iterations) > 0 || height(outcomes.Cases) > 0
    return;
end
priority = ["NO_RESULT_RUN", "NOT_REPORTED", "NOT_COLLECTED", ...
    "PER_CUT_EXCEL_NOT_WRITTEN", "RESULT_WORKBOOK_SHAPE_UNEXPECTED"];
for i = 1:numel(priority)
    if any(outcomes.Notes.Reason == priority(i))
        reason = priority(i);
        return;
    end
end
end


function tf = only_informational(reason)
% MAXTIME_UNAVAILABLE on its own explains a blank cell that the exporter
% already reported; it does not by itself send anyone to Test Manager.
tf = strcmp(reason, "MAXTIME_UNAVAILABLE");
end


function value = join_reasons(varargin)
parts = strings(0,1);
for i = 1:numel(varargin)
    item = string(varargin{i});
    parts = [parts; item(:)]; %#ok<AGROW>
end
value = strjoin(parts(strlength(strtrim(parts)) > 0), ' | ');
end


function flags = duplicate_identifiers(identifier)
% The identifier is reported as it is. Making it unique would break the
% match with the test file and the specification.
flags = false(numel(identifier),1);
[values, ~, group] = unique(identifier);
for g = 1:numel(values)
    rows = group == g;
    if sum(rows) > 1, flags(rows) = true; end
end
end


function [verdict, resultSet, reason] = lookup_verdict(outcomes, testCaseName, iterationName)
verdict = "";
resultSet = "";
reason = "";
if strlength(testCaseName) == 0
    reason = "NO_MATCHING_TEST_RESULT";
    return;
end
usable = is_real_iteration_name(iterationName);
if usable && height(outcomes.Iterations) > 0
    rows = outcomes.Iterations.TestCaseName == testCaseName & ...
        outcomes.Iterations.IterationName == iterationName;
    if any(rows)
        [verdict, resultSet, reason] = take_match(outcomes.Iterations, rows);
        return;
    end
end
% A scripted or default iteration has no usable name, so fall back to the
% test case level rather than leaving the verdict blank.
if height(outcomes.Cases) > 0
    rows = outcomes.Cases.TestCaseName == testCaseName;
    if any(rows)
        [verdict, resultSet, reason] = take_match(outcomes.Cases, rows);
        reason = join_reasons(reason, "ITERATION_MATCHED_BY_TEST_CASE");
        return;
    end
end
reason = "NO_MATCHING_TEST_RESULT";
end


function tf = is_real_iteration_name(iterationName)
tf = strlength(strtrim(iterationName)) > 0 && ...
    ~ismember(strtrim(iterationName), ["<기본 설정>", "(단일 실행)", "연결 없음"]);
end


function [verdict, resultSet, reason] = take_match(T, rows)
reason = "";
matched = T(rows, :);
if any(matched.Ambiguous)
    verdict = "";
    resultSet = matched.ResultSet(1);
    reason = "AMBIGUOUS_TEST_RESULT";
    return;
end
verdict = matched.Verdict(end);
resultSet = matched.ResultSet(end);
end


function results = append_source_notes(results, notes)
% Run level and coverage level reasons have no customer row to sit on, so
% they are appended with an empty Row and the subject in the name column.
if isempty(notes) || height(notes) == 0, return; end
for i = 1:height(notes)
    results = [results; table(NaN, "", notes.TestCaseName(i), "", "", "Y", ...
        join_reasons(notes.Reason(i), notes.Message(i)), "", "", ...
        'VariableNames', results.Properties.VariableNames)]; %#ok<AGROW>
end
end
