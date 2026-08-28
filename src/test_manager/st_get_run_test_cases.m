function [testCases, R] = st_get_run_test_cases(tf)
%ST_GET_RUN_TEST_CASES Resolve the Test Cases selected for this automation run.
%
% [testCases, R] = st_get_run_test_cases()
% [testCases, R] = st_get_run_test_cases(tf)
%
% 실행 대상의 기준은 TestManagement.xlsx의 현재 선택 대상입니다.
% cfg.OnlyEnabled == true이면 Enabled=true인 Target만 대상으로 합니다.
%
% 기존 Test Manager에 다른 Test Case가 남아 있거나 Enabled=true여도
% 이 함수가 반환한 Test Case만 st_run_generated_tests에서 실행합니다.
%
% 실행 전에 개별 확인용으로도 사용할 수 있습니다.
%
%   st_get_run_test_cases
%
% 또는:
%
%   [testCases, R] = st_get_run_test_cases;
%   disp(R);
%
% R은 result/RunTargetResult.* 로도 저장됩니다.

cfg = ...
    st_require_runtime_target();

T = ...
    st_load_targets( ...
        cfg.OnlyEnabled);


%% ============================================================
% Test File
%% ============================================================

if nargin < 1 || ...
        isempty(tf)

    if ~isfile(cfg.TestFile)

        error( ...
            'Test File을 찾을 수 없습니다: %s', ...
            cfg.TestFile);
    end

    tf = ...
        sltest.testmanager.TestFile( ...
            cfg.TestFile);
end


if isempty(T)

    error( ...
        '현재 실행 대상으로 선택된 CUT/Test Case가 없습니다.');
end


%% ============================================================
% 선택된 TestCaseName 검증
%% ============================================================

selectedNames = ...
    strtrim( ...
        string(T.TestCaseName));

if any(strlength(selectedNames) == 0)

    badRows = ...
        find(strlength(selectedNames) == 0);

    error( ...
        '선택된 Target에 빈 TestCaseName이 있습니다. Target row: %s', ...
        char(strjoin(string(badRows), ', ')));
end


[uniqueNames, ~, groupIndex] = ...
    unique( ...
        selectedNames, ...
        'stable');

counts = ...
    accumarray( ...
        groupIndex, ...
        1);

duplicateNames = ...
    uniqueNames(counts > 1);

if ~isempty(duplicateNames)

    error( ...
        '선택된 Target에 중복 TestCaseName이 있습니다: %s', ...
        char(strjoin(duplicateNames, ', ')));
end


%% ============================================================
% Configured Test Suite
%% ============================================================

ts = ...
    getTestSuiteByName( ...
        tf, ...
        cfg.TestSuiteName);

if isempty(ts)

    error( ...
        'Test Suite를 찾을 수 없습니다: %s', ...
        cfg.TestSuiteName);
end

if numel(ts) ~= 1

    error( ...
        '동일한 이름의 Test Suite가 여러 개 있습니다: %s', ...
        cfg.TestSuiteName);
end


suiteCases = ...
    getTestCases( ...
        ts);

suiteNames = ...
    strings(numel(suiteCases), 1);

suiteEnabled = ...
    false(numel(suiteCases), 1);

for i = 1:numel(suiteCases)

    suiteNames(i) = ...
        string(suiteCases(i).Name);

    suiteEnabled(i) = ...
        logical(suiteCases(i).Enabled);
end


%% ============================================================
% 선택 대상 -> 실제 Test Case 매핑
%% ============================================================

n = ...
    height(T);

No = ...
    T.No;

CUTName = ...
    string(T.CUTName);

HarnessName = ...
    string(T.HarnessName);

TestCaseName = ...
    selectedNames;

ExpectedUpdateMode = ...
    string(T.ExpectedUpdateMode);

CurrentEnabled = ...
    false(n,1);

WillRun = ...
    false(n,1);

Status = ...
    strings(n,1);

Message = ...
    strings(n,1);

selectedIndex = ...
    zeros(n,1);


for i = 1:n

    matches = ...
        find(suiteNames == selectedNames(i));

    if isempty(matches)

        Status(i) = ...
            'FAIL';

        Message(i) = ...
            'Test Case not found in configured Test Suite';

        continue;
    end

    if numel(matches) > 1

        Status(i) = ...
            'FAIL';

        Message(i) = ...
            'Duplicate Test Case names exist in configured Test Suite';

        continue;
    end

    selectedIndex(i) = ...
        matches;

    CurrentEnabled(i) = ...
        suiteEnabled(matches);

    % 실제 실행 시에는 현재 Enabled 상태와 관계없이
    % 선택 대상 Test Case만 임시로 Enabled=true로 설정합니다.
    WillRun(i) = ...
        true;

    Status(i) = ...
        'OK';

    Message(i) = ...
        'Selected by TestManagement.xlsx';
end


%% ============================================================
% Result
%% ============================================================

R = ...
    table( ...
        No, ...
        CUTName, ...
        HarnessName, ...
        TestCaseName, ...
        ExpectedUpdateMode, ...
        CurrentEnabled, ...
        WillRun, ...
        Status, ...
        Message);


st_write_result( ...
    'RunTargetResult', ...
    R);


fprintf('\n');
fprintf('============================================\n');
fprintf('Selected Test Cases For Execution\n');
fprintf('Test File  : %s\n', cfg.TestFile);
fprintf('Test Suite : %s\n', cfg.TestSuiteName);
fprintf('============================================\n');

for i = 1:height(R)

    fprintf( ...
        ['[%d/%d] %s | CUT=%s | ExpectedUpdate=%s | ' ...
         'CurrentEnabled=%d | %s\n'], ...
        i, ...
        height(R), ...
        char(R.TestCaseName(i)), ...
        char(R.CUTName(i)), ...
        char(R.ExpectedUpdateMode(i)), ...
        R.CurrentEnabled(i), ...
        char(R.Status(i)));
end

fprintf('--------------------------------------------\n');
fprintf('Will run : %d\n', sum(R.WillRun));
fprintf('FAIL     : %d\n', sum(R.Status == 'FAIL'));
fprintf('============================================\n');


if any(R.Status == 'FAIL')

    failed = ...
        R(R.Status == 'FAIL', :);

    details = ...
        strings(height(failed),1);

    for i = 1:height(failed)

        details(i) = ...
            failed.TestCaseName(i) + ...
            ": " + ...
            failed.Message(i);
    end

    error( ...
        '실행 대상 Test Case 확인 실패: %s', ...
        char(strjoin(details, ' | ')));
end


% Excel에서 선택된 순서를 그대로 유지합니다.
testCases = ...
    suiteCases(selectedIndex);

end
