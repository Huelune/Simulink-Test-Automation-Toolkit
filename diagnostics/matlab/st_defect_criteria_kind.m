function [kind, detail] = st_defect_criteria_kind(criteriaResult)
%ST_DEFECT_CRITERIA_KIND Name a defect iteration's Custom Criteria result, without names.
%
% [kind, detail] = st_defect_criteria_kind(criteriaResult)
%
% criteriaResult is what getCustomCriteriaResult returns for one iteration
% (Outcome and DiagnosticRecord). kind is a fixed word for a screen that
% leaves the company:
%   "verify 실패"  a failed record carries the defect check's "... 실행 횟수"
%                  message: the iteration failed as designed
%   "오류"         a record carries an exception (the criteria raised);
%                  detail is its identifier
%   "다른 실패"    failed, but not by the defect check; detail lists the
%                  records' event names (framework names)
%   "통과", "기준 없음", or "판정 <Outcome>" otherwise
% Diagnostic text and exception messages hold block names, so only an
% identifier and event names leave this function.
kind = "기준 없음";
detail = "";
if isempty(criteriaResult), return; end
records = criteriaResult.DiagnosticRecord;
failed = false;
defectCheck = false;
events = strings(0, 1);
for k = 1:numel(records)
    record = records(k);
    if raised(record.Exception)
        kind = "오류";
        detail = string(record.Exception(1).identifier);
        if strlength(detail) == 0, detail = "(식별자 없음)"; end
        return;
    end
    events = [events; reshape(string(record.Event), [], 1)]; %#ok<AGROW>
    if strcmpi(string(record.Outcome), "Failed")
        failed = true;
        defectCheck = defectCheck || contains(diagnostic_text(record), "실행 횟수");
    end
end
outcome = string(criteriaResult.Outcome);
if isempty(outcome), outcome = "없음"; end
if failed && defectCheck
    kind = "verify 실패";
elseif failed || strcmpi(outcome, "Failed")
    kind = "다른 실패";
    events = unique(events(strlength(events) > 0));
    if ~isempty(events), detail = join(events.', ","); end
elseif strcmpi(outcome, "Passed")
    kind = "통과";
else
    kind = "판정 " + outcome;
end
end


function tf = raised(exception)
% A record without an error may still hold an empty MException.
tf = ~isempty(exception) && isa(exception, 'MException') && ...
    (strlength(string(exception.identifier)) > 0 || strlength(string(exception.message)) > 0);
end


function text = diagnostic_text(record)
text = "";
try
    parts = string(record.TestDiagnosticResult);
    if ~isempty(parts), text = join(reshape(parts, 1, []), " "); end
catch
    % Not text: it cannot be the defect check's message.
end
end
