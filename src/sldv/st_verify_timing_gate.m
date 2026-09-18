function gate = st_verify_timing_gate(verifyResult, cfg, phase)
%ST_VERIFY_TIMING_GATE Classify SLDV verify timing rows without hiding failures.
%
% One Test Case owns one Iteration per Test Sequence scenario. A scenario
% whose verify results are missing or Untested is a real defect, but it must
% not stop the scenarios that ran correctly from reaching the expected-value
% update. The gate therefore aborts execution only when no evaluated scenario
% passed; a mixed run is reported as PARTIAL and continues.
%
% gate fields:
%   Status           'OK' | 'PARTIAL' | 'FAIL' | 'SKIP' | 'NOT_RUN'
%   Abort            true only when every evaluated scenario failed
%   EvaluatedCount   OK + FAIL rows (SKIP rows are not applicable)
%   OkCount / FailCount / SkipCount
%   FailedScenarios  "TestCase/Scenario" for each FAIL row
%   Message          joined failure text, empty when nothing failed

if nargin < 2 || isempty(cfg)
    cfg = st_require_runtime_target();
end
if nargin < 3 || isempty(phase)
    phase = 'initial';
end
phase = char(string(phase));

gate = struct( ...
    'Status', 'NOT_RUN', ...
    'Abort', false, ...
    'Phase', phase, ...
    'EvaluatedCount', 0, ...
    'OkCount', 0, ...
    'FailCount', 0, ...
    'SkipCount', 0, ...
    'FailedScenarios', strings(0,1), ...
    'Message', '');

if isempty(verifyResult) || ~istable(verifyResult) || height(verifyResult) == 0
    st_log(cfg, 'DEBUG', ...
        'Verify timing gate | phase=%s | no rows to evaluate', phase);
    return;
end

status = upper(string(verifyResult.Status));
gate.OkCount = sum(status == "OK");
gate.FailCount = sum(status == "FAIL");
gate.SkipCount = sum(status == "SKIP");
gate.EvaluatedCount = gate.OkCount + gate.FailCount;

if gate.EvaluatedCount == 0
    gate.Status = 'SKIP';
    st_log(cfg, 'INFO', ...
        ['Verify timing gate | phase=%s | Status=SKIP | ' ...
         'every row was not applicable (skip=%d)'], phase, gate.SkipCount);
    return;
end

if gate.FailCount == 0
    gate.Status = 'OK';
    st_log(cfg, 'INFO', ...
        ['Verify timing gate | phase=%s | Status=OK | ok=%d | skip=%d'], ...
        phase, gate.OkCount, gate.SkipCount);
    return;
end

failedRows = verifyResult(status == "FAIL", :);
gate.FailedScenarios = string(failedRows.TestCaseName) + "/" + ...
    string(failedRows.ScenarioName);
details = gate.FailedScenarios + ": " + string(failedRows.Message);
gate.Message = char(strjoin(details, ' | '));

if gate.OkCount > 0
    % Mixed outcome. Keep going so the healthy scenarios still get their
    % expected values updated, and carry PARTIAL into the final judgment.
    gate.Status = 'PARTIAL';
    gate.Abort = false;
    st_log(cfg, 'WARN', ...
        ['Verify timing gate | phase=%s | Status=PARTIAL | ok=%d | fail=%d | ' ...
         'skip=%d | continuing with the passing scenarios | %s'], ...
        phase, gate.OkCount, gate.FailCount, gate.SkipCount, gate.Message);
    return;
end

gate.Status = 'FAIL';
gate.Abort = true;
st_log(cfg, 'ERROR', ...
    ['Verify timing gate | phase=%s | Status=FAIL | fail=%d | skip=%d | ' ...
     'no scenario produced usable verify timing | %s'], ...
    phase, gate.FailCount, gate.SkipCount, gate.Message);
end
