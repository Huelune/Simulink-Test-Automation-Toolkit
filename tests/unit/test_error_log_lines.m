function tests = test_error_log_lines
%TEST_ERROR_LOG_LINES Log ERROR lines reach the screen as time, order and identifiers only.
tests = functiontests(localfunctions);
end

function testPerCutExceptionKeepsOrderAndIdentifier(testCase)
log = ["[2026-11-27 17:30:01.120][INFO] Rebuild all start"; ...
    "[2026-11-27 17:39:47.533][ERROR] [PER_CUT 1/3] exception | Simulink:Engine:Secret_Thing: Secret_Model/Secret_Cut failed at D:\Secret\x.slx"; ...
    "[17:40:02] ERROR PER_CUT execution failed | 1 of 3 | Secret_Cut"];
lines = st_error_log_lines(log);
verifyEqual(testCase, lines, {'  [17:39:47] PER_CUT 1/3 | Simulink:Engine:Secret_Thing', ...
    '  [17:40:02] 식별자 없음'});
end

function testOtherIdentifiersAndTextNeverShow(testCase)
log = ["[09:00:00] ERROR something | SecretCompany:Init:Failed: Secret text"; ...
    "[09:00:05] ERROR something | SecretCompany:Init:Failed: Secret text"; ...
    "[09:00:09] ERROR https://secret.example/x D:\Secret_Dir 12:34:56"];
lines = st_error_log_lines(log);
verifyEqual(testCase, lines, {'  [09:00:00] (다른 식별자) (2번)', '  [09:00:09] 식별자 없음'});
verifyFalse(testCase, any(contains(string(lines), "Secret")));
end

function testManyKindsAreCut(testCase)
log = compose("[10:00:%02d] ERROR x | MATLAB:Kind%d:Id: y", (1:5)', (1:5)');
lines = st_error_log_lines(log, 3);
verifyEqual(testCase, numel(lines), 4);
verifyEqual(testCase, lines{4}, '  다른 ERROR 2가지 더 있음');
end

function testNoErrorSaysSo(testCase)
verifyEqual(testCase, st_error_log_lines("[10:00:00] INFO  fine"), {'  ERROR 없음'});
end
