function tests = test_target_failure_lines
%TEST_TARGET_FAILURE_LINES The Excel check before a run shows kinds and numbers, never cell text.
tests = functiontests(localfunctions);
end

function testEmptyNamesComeFirstAndKindsGroup(testCase)
no = [1; 2; 3; 4];
empty = [false false false; false true false; false true true; false false false];
statuses = ["OK"; "OK"; "FAIL"; "FAIL"];
messages = ["Valid CUT path"; "Valid CUT path"; "CUT block not found: Secret_Top/Secret_Cut"; ...
    "CUT block not found: Secret_Top/Other"];
lines = st_target_failure_lines(no, empty, statuses, messages);
verifyEqual(testCase, lines, {'Excel 검사 | 대상 4 | OK 1 | 실패 3', ...
    '  HarnessName 빈 칸 | 대상 2', '  HarnessName·TestCaseName 빈 칸 | 대상 3', ...
    '  CUT 블록 없음(경로 오타나 빠진 중간 Subsystem) | 대상 4'});
end

function testLongListIsCutAndTextNeverShows(testCase)
no = (1:20)';
empty = [false(20, 1), true(20, 1), false(20, 1)];
statuses = repmat("OK", 20, 1);
messages = repmat("Secret message", 20, 1);
lines = st_target_failure_lines(no, empty, statuses, messages);
verifyEqual(testCase, numel(lines), 2);
verifyTrue(testCase, endsWith(lines{2}, '15 외 5개'));
verifyFalse(testCase, any(contains(string(lines), 'Secret')));
end

function testSubsystemKindNamesTheBlockTypeOnly(testCase)
lines = st_target_failure_lines(7, false(1, 3), "FAIL", ...
    "Target exists but is not a Subsystem. BlockType=ModelReference");
verifyEqual(testCase, lines{2}, '  Subsystem 아님(블록 종류 ModelReference) | 대상 7');
end
