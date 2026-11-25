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
outcome = string(read(criteriaResult, 'Outcome'));
if isempty(outcome), outcome = "없음"; end
records = read(criteriaResult, 'DiagnosticRecord');
failed = false;
defectCheck = false;
events = strings(0, 1);
for k = 1:numel(records)
    if iscell(records), record = records{k}; else, record = records(k); end
    exception = read(record, 'Exception');
    if raised(exception)
        kind = "오류";
        detail = string(exception(1).identifier);
        if strlength(detail) == 0, detail = "(식별자 없음)"; end
        return;
    end
    events = [events; reshape(string(read(record, 'Event')), [], 1)]; %#ok<AGROW>
    recordOutcome = string(read(record, 'Outcome'));
    % An unreadable record outcome follows the criteria's own.
    if isempty(recordOutcome), recordOutcome = outcome; end
    if any(strcmpi(recordOutcome, "Failed"))
        failed = true;
        defectCheck = defectCheck || contains(diagnostic_text(record), "실행 횟수");
    end
end
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


function value = read(object, name)
% A failed record of a saved result raised MATLAB:unassignedOutputs on
% reading; a property that cannot be read counts as empty.
value = [];
try, value = object.(name); catch, end
end


function tf = raised(exception)
% A record without an error may still hold an empty MException.
tf = ~isempty(exception) && isa(exception, 'MException') && ...
    (strlength(string(exception(1).identifier)) > 0 || strlength(string(exception(1).message)) > 0);
end


function text = diagnostic_text(record)
% The verify message sits in TestDiagnosticResult; Report repeats it.
% Either may hold diagnostic result objects instead of text.
text = "";
for name = {'TestDiagnosticResult', 'Report'}
    value = read(record, name{1});
    try
        if isobject(value) && ~isempty(value) && isprop(value(1), 'DiagnosticText')
            value = {value.DiagnosticText};
        end
        parts = string(value);
        if ~isempty(parts), text = text + " " + join(reshape(parts, 1, []), " "); end
    catch
        % Not text: it cannot be the defect check's message.
    end
end
end
