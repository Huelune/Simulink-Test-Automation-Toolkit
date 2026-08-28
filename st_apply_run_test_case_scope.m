function cleanupObj = st_apply_run_test_case_scope(tf, runTestCases)
%ST_APPLY_RUN_TEST_CASE_SCOPE Temporarily enable only selected Test Cases.
%
% cleanupObj = st_apply_run_test_case_scope(tf, runTestCases)
%
% run(tf)는 Test File 내부의 Enabled Test Case 전체를 실행하므로,
% 현재 자동화에서 선택하지 않은 기존 Test Case까지 실행될 수 있습니다.
%
% 이 함수는:
%   1. Test File 전체 Test Case의 Enabled 상태를 백업
%   2. 전체 Test Case를 Disabled
%   3. runTestCases만 Enabled
%   4. 함수 종료/오류 시 onCleanup으로 원래 상태 복원
%
% 임시 실행 범위는 saveToFile 하지 않습니다.
% 복원 시에는 원래 Enabled 상태를 saveToFile 하여 확실히 보존합니다.

cfg = ...
    st_require_runtime_target();

if nargin < 2 || ...
        isempty(runTestCases)

    error( ...
        '실행할 Test Case가 없습니다.');
end


selectedNames = ...
    strings(numel(runTestCases), 1);

for i = 1:numel(runTestCases)

    selectedNames(i) = ...
        string(runTestCases(i).Name);
end


%% ============================================================
% 전체 Test Case 수집 / Enabled 상태 백업
%% ============================================================

suites = ...
    getTestSuites(tf);

caseObjects = ...
    cell(0,1);

originalEnabled = ...
    false(0,1);

caseSuiteNames = ...
    strings(0,1);

caseNames = ...
    strings(0,1);


for s = 1:numel(suites)

    suiteName = ...
        string(suites(s).Name);

    testCases = ...
        getTestCases( ...
            suites(s));

    for c = 1:numel(testCases)

        row = ...
            numel(caseObjects) + 1;

        caseObjects{row,1} = ...
            testCases(c);

        originalEnabled(row,1) = ...
            logical(testCases(c).Enabled);

        caseSuiteNames(row,1) = ...
            suiteName;

        caseNames(row,1) = ...
            string(testCases(c).Name);
    end
end


if isempty(caseObjects)

    error( ...
        'Test File에 Test Case가 없습니다.');
end


%% ============================================================
% 이번 실행 대상만 Enabled
%% ============================================================

selectedCount = 0;

for i = 1:numel(caseObjects)

    shouldRun = ...
        strcmp( ...
            char(caseSuiteNames(i)), ...
            cfg.TestSuiteName) && ...
        any(caseNames(i) == selectedNames);

    caseObjects{i}.Enabled = ...
        logical(shouldRun);

    if shouldRun

        selectedCount = ...
            selectedCount + 1;
    end
end


if selectedCount ~= numel(runTestCases)

    % 복원 후 실패
    st_restore_run_test_case_scope( ...
        tf, ...
        caseObjects, ...
        originalEnabled);

    error( ...
        ['실행 범위 설정 결과가 선택 Test Case 수와 다릅니다. ' ...
         'selected=%d, enabled=%d'], ...
        numel(runTestCases), ...
        selectedCount);
end


fprintf('\n');
fprintf('============================================\n');
fprintf('Temporary Test Execution Scope Applied\n');
fprintf('Selected Test Cases : %d\n', selectedCount);
fprintf('Other Test Cases    : disabled for this run\n');
fprintf('============================================\n');


cleanupObj = ...
    onCleanup( ...
        @() st_restore_run_test_case_scope( ...
            tf, ...
            caseObjects, ...
            originalEnabled));

end


function st_restore_run_test_case_scope( ...
        tf, ...
        caseObjects, ...
        originalEnabled)

for i = 1:numel(caseObjects)

    try

        caseObjects{i}.Enabled = ...
            logical(originalEnabled(i));

    catch ME

        warning( ...
            'Test Case Enabled 상태 복원 실패 [%d]: %s', ...
            i, ...
            ME.message);
    end
end


try

    saveToFile(tf);

catch ME

    warning( ...
        'Test File Enabled 상태 저장 중 오류: %s', ...
        ME.message);
end


fprintf('\n');
fprintf('Test Case Enabled 상태를 실행 전 값으로 복원했습니다.\n');

end
