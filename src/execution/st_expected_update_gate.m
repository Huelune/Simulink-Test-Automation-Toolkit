function gate = st_expected_update_gate(updateResult, cfg, phase)
%ST_EXPECTED_UPDATE_GATE Classify expected-value update rows per scenario.
%
% st_update_expected_from_results processes one row per Test Sequence
% scenario and isolates each row's failure. This helper turns that table into
% a single judgment so both execution paths (BATCH and PER_CUT) react the same
% way: a scenario that could not be updated never discards the scenarios that
% were updated, and the run is reported as PARTIAL instead of passing quietly.
%
% gate fields:
%   Status          'OK' | 'PARTIAL' | 'FAIL' | 'SKIP' | 'NOT_RUN'
%   EvaluatedCount  OK + FAIL rows (SKIP rows had nothing to update)
%   OkCount / FailCount / SkipCount
%   UpdatedCount    total verify lines rewritten
%   FailedScenarios "TestCase/Scenario" for each FAIL row
%   Message         joined failure text, empty when nothing failed

if nargin < 2 || isempty(cfg)
    cfg = st_require_runtime_target();
end
if nargin < 3 || isempty(phase)
    phase = 'initial';
end
phase = char(string(phase));

gate = struct( ...
    'Status', 'NOT_RUN', ...
    'Phase', phase, ...
    'EvaluatedCount', 0, ...
    'OkCount', 0, ...
    'FailCount', 0, ...
    'SkipCount', 0, ...
    'UpdatedCount', 0, ...
    'FailedScenarios', strings(0,1), ...
    'Message', '');

if isempty(updateResult) || ~istable(updateResult) || height(updateResult) == 0
    st_log(cfg, 'DEBUG', ...
        'Expected update gate | phase=%s | no rows to evaluate', phase);
    return;
end

status = upper(string(updateResult.Status));
gate.OkCount = sum(status == "OK");
gate.FailCount = sum(status == "FAIL");
gate.SkipCount = sum(status == "SKIP");
gate.EvaluatedCount = gate.OkCount + gate.FailCount;
gate.UpdatedCount = sum(double(updateResult.UpdatedCount));

if gate.EvaluatedCount == 0
    gate.Status = 'SKIP';
    st_log(cfg, 'INFO', ...
        ['Expected update gate | phase=%s | Status=SKIP | ' ...
         'no scenario required an update (skip=%d)'], phase, gate.SkipCount);
    return;
end

if gate.FailCount == 0
    gate.Status = 'OK';
    st_log(cfg, 'INFO', ...
        ['Expected update gate | phase=%s | Status=OK | ok=%d | skip=%d | ' ...
         'updated lines=%d'], ...
        phase, gate.OkCount, gate.SkipCount, gate.UpdatedCount);
    return;
end

failedRows = updateResult(status == "FAIL", :);
gate.FailedScenarios = string(failedRows.TestCaseName) + "/" + ...
    string(failedRows.ScenarioName);
details = gate.FailedScenarios + ": " + string(failedRows.Message);
gate.Message = char(strjoin(details, ' | '));

if gate.OkCount > 0
    gate.Status = 'PARTIAL';
    st_log(cfg, 'WARN', ...
        ['Expected update gate | phase=%s | Status=PARTIAL | ok=%d | fail=%d | ' ...
         'skip=%d | updated lines=%d | %s'], ...
        phase, gate.OkCount, gate.FailCount, gate.SkipCount, ...
        gate.UpdatedCount, gate.Message);
    return;
end

gate.Status = 'FAIL';
st_log(cfg, 'ERROR', ...
    ['Expected update gate | phase=%s | Status=FAIL | fail=%d | skip=%d | ' ...
     'no scenario could be updated | %s'], ...
    phase, gate.FailCount, gate.SkipCount, gate.Message);
end
