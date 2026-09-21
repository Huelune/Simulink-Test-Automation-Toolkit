function document = st_final_document_table(cfg, specification, outcomes, source, idMode)
%ST_FINAL_DOCUMENT_TABLE Build the customer sheet and its result sheet.
% One specification row becomes one customer row. The customer form has no
% remarks column, so every reason lives on the result sheet, which stays
% row-for-row aligned with the customer sheet.
%
% The failed verify text is deliberately not extracted. The result sheet
% says which row to look at and which saved ResultSet to open, and no
% .mldatx is read here.
%
%   idMode  'COMBINED' (default) writes the scenario name and the test case
%           name on two lines of one cell. 'SCENARIO' writes the scenario
%           name only. Neither builds a new identifier, so the 80 character
%           truncation of st_export_safe_name cannot apply.
if nargin < 5 || isempty(idMode), idMode = ''; end
idMode = upper(strtrim(char(string(idMode))));
if isempty(idMode)
    idMode = upper(strtrim(char(string( ...
        config_value(cfg, 'FinalDocumentTestCaseIdMode', 'COMBINED')))));
end
if isempty(idMode), idMode = 'COMBINED'; end
if ~ismember(idMode, {'COMBINED','SCENARIO'})
    error('simtest:FinalDocumentTestCaseIdMode', ...
        'TestCaseIdMode must be COMBINED or SCENARIO.');
end
naText = string(config_value(cfg, 'FinalDocumentNAText', 'N/A'));

count = height(specification);
st_log(cfg, 'INFO', 'Final document table start | Rows=%d | TestCaseIdMode=%s', ...
    count, idMode);
identifier = build_identifier(specification, idMode);
expected = column_text(specification, 'verify 내용');
action = replace_not_applicable(column_text(specification, 'input 시나리오 내용'), naText);
material = replace_not_applicable(column_text(specification, ...
    '하네스 input 파일명'), naText);

document.ResultHeaders = {'Row', 'Test Case ID', 'TestCaseName', ...
    'Iteration명', '판정 결과', '확인 필요', '확인 사유', '확인 위치', '추출상태'};
document.DisplayHeaders = {'Test Case ID', '-', '-', 'Pre Condition', ...
    'Description', 'Test Steps.Action', 'Test Steps.Expected result', ...
    '-', '-', '-', '-', '출력값', '판정 결과', '테스트 자료'};
blank = repmat("", count, 1);
document.Sheet1 = table(identifier, blank, blank, ...
    column_number(specification, 'MaxTime'), ...
    column_text(specification, 'DecisionBlocks'), action, expected, ...
    blank, blank, blank, blank, expected, blank, material, ...
    'VariableNames', {'TestCaseID','Dash02','Dash03','PreCondition', ...
    'Description','Action','ExpectedResult','Dash08','Dash09','Dash10', ...
    'Dash11','OutputValue','Judgement','TestData'});

[judgement, results] = resolve_judgements( ...
    cfg, specification, outcomes, source, identifier, naText);
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


function identifier = build_identifier(specification, idMode)
scenario = column_text(specification, 'Test Sequence scenario 명');
testCase = column_text(specification, '테스트 케이스명');
if strcmp(idMode, 'SCENARIO')
    identifier = scenario;
    return;
end
% The cell is already wrapped, so the two lines show as two lines.
identifier = scenario;
join = strlength(testCase) > 0;
identifier(join) = scenario(join) + newline + testCase(join);
end


function [judgement, results] = resolve_judgements(cfg, specification, outcomes, source, identifier, naText) %#ok<INUSD>
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

for i = 1:count
    [verdict, resultSet, reason] = lookup_verdict(outcomes, ...
        testCaseName(i), iterationName(i));
    judgement(i) = verdict;
    location(i) = resultSet;
    reasons(i) = reason;
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
