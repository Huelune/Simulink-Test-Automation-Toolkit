function [resultObj, updateResult, runContext] = st_run_generated_tests()
%ST_RUN_GENERATED_TESTS
% 생성된 Test File의 Enabled Test Case를 실행합니다.
%
% Resolved ExpectedUpdateMode가 모두 OFF이면 1회 실행 후 종료합니다.
%
% 하나 이상의 선택 Target이 APPLY이면:
%   1. Harness Outport signal logging 준비
%   2. Test File 실행
%   3. 실패한 Iteration에서 0.01초 등의 기준 시점 실제값 추출
%   4. verify(... == RHS)의 RHS 자동 갱신
%   5. cfg.RerunAfterExpectedUpdate == true이고 갱신값이 있으면 재실행
%
% 첫 번째 출력 resultObj는 최종 실행 결과입니다.
% 재실행하지 않으면 최초 실행 결과를 반환합니다.
% 세 번째 출력은 보고서 생성용 최초/최종 ResultSet을 모두 보존합니다.

cfg = st_require_runtime_target();

targetConfig = ...
    st_load_targets( ...
        cfg.OnlyEnabled);

if any(targetConfig.CoverageFilterMode ~= "OFF")
    error('simtest:BatchExecutionWithCoverageFilter', ...
        ['st_run_generated_tests uses the BATCH run(tf) path and cannot ' ...
         'run active CVFs. Use st_run_tests_per_cut or ExecutionMode=AUTO.']);
end

expectedUpdateTargetCount = ...
    sum(targetConfig.ExpectedUpdateMode == "APPLY");

autoUpdateExpected = ...
    expectedUpdateTargetCount > 0;

updateResult = table();
runContext = struct( ...
    'InitialResult', [], ...
    'FinalResult', [], ...
    'RerunPerformed', false, ...
    'ExpectedUpdateResult', table(), ...
    'CoverageFilterResult', table(), ...
    'CoverageFilterApplyResult', table(), ...
    'CoverageFilterRestoreResult', table(), ...
    'CoverageFilterApplicationMode', ...
        cfg.CoverageFilterApplicationMode, ...
    'StartedAt', char(datetime('now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss.SSS')), ...
    'CompletedAt', '');

totalTimer = tic;

st_log(cfg, 'INFO', ...
    ['Run Generated Tests start | ExpectedUpdateTargets=%d | Rerun=%d | ' ...
     'SampleTime=%.17g'], ...
    expectedUpdateTargetCount, ...
    logical(cfg.RerunAfterExpectedUpdate), ...
    cfg.ExpectedValueSampleTime);


%% ============================================================
% Test File 확인
%% ============================================================

if ~isfile(cfg.TestFile)

    error( ...
        'Test File을 찾을 수 없습니다: %s', ...
        cfg.TestFile);
end


tf = ...
    sltest.testmanager.TestFile( ...
        cfg.TestFile);


fprintf('\n');
fprintf('============================================\n');
fprintf('Run Generated Tests\n');
fprintf('Test File : %s\n', cfg.TestFile);
fprintf('============================================\n');


%% ============================================================
% Auto Expected Update를 위한 logging 준비
%% ============================================================

if autoUpdateExpected

    fprintf('\nExpected value APPLY 준비 (%d Target)\n', ...
        expectedUpdateTargetCount);
    fprintf('Sample time : %.17g sec\n', ...
        cfg.ExpectedValueSampleTime);

    st_log(cfg, 'DEBUG', ...
        'Expected value logging preparation start');

    loggingTimer = tic;

    st_prepare_expected_value_logging( ...
        cfg, ...
        tf);

    st_log(cfg, 'DEBUG', ...
        'Expected value logging preparation done | elapsed=%.3f sec', ...
        toc(loggingTimer));
end


%% ============================================================
% 1차 실행
%% ============================================================

% run(tf)는 Test File의 모든 Enabled Test Case를 실행한다. 관리
% 파일에서 Enable=true로 선택한 Target만 이번 실행 범위로 강제하고,
% 함수 종료 시 원래 Enabled 상태를 복원한다.
[runTestCases, runScopeResult] = ...
    st_get_run_test_cases(tf);

runScopeCleanup = ...
    st_apply_run_test_case_scope(tf, runTestCases); %#ok<NASGU>

filterPreparationResult = st_prepare_coverage_filters();
if any(filterPreparationResult.Status == "FAIL")
    failed = filterPreparationResult( ...
        filterPreparationResult.Status == "FAIL", :);
    error('simtest:CoverageFilterPreparationFailed', ...
        'Coverage filter preparation failed: %s', ...
        char(strjoin(failed.Message, ' | ')));
end

[coverageFilterCleanup, coverageFilterApplyResult, coverageFilterSession] = ...
    st_apply_test_case_coverage_filters( ...
        tf, runTestCases, targetConfig, cfg); %#ok<NASGU>
runContext.CoverageFilterResult = filterPreparationResult;
runContext.CoverageFilterApplyResult = coverageFilterApplyResult;

try

selectedNames = string(runScopeResult.TestCaseName( ...
    runScopeResult.WillRun));

fprintf('\nSelected Test Case 실행 시작 (%d): %s\n', ...
    numel(runTestCases), char(strjoin(selectedNames, ', ')));

st_log(cfg, 'DEBUG', ...
    ['run(tf) start | selected Test Cases=%d [%s] | ' ...
     'CoverageFilterMode=%s. ' ...
     'Test Manager execution may stay inside this call for a long time.'], ...
    numel(runTestCases), char(strjoin(selectedNames, ', ')), ...
    st_coverage_filter_application_mode( ...
        cfg.CoverageFilterApplicationMode));

runTimer = tic;

resultObj = ...
    run(tf);

runContext.InitialResult = resultObj;
runContext.FinalResult = resultObj;

st_log(cfg, 'DEBUG', ...
    'run(tf) returned | elapsed=%.3f sec', ...
    toc(runTimer));

fprintf('Selected Test Case 실행 완료\n');

verifyTimingResult = st_validate_sldv_verify_results(resultObj);
if ~isempty(verifyTimingResult) && any(verifyTimingResult.Status == 'FAIL')
    failed = verifyTimingResult(verifyTimingResult.Status == 'FAIL', :);
    error('SLDV verify timing validation failed: %s', ...
        char(strjoin(failed.Message, ' | ')));
end


%% ============================================================
% Auto Expected Update OFF
%% ============================================================

if ~autoUpdateExpected

    st_log(cfg, 'INFO', ...
        'Run Generated Tests complete | elapsed=%.3f sec', ...
        toc(totalTimer));

    runContext.CompletedAt = char(datetime('now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
    runContext.CoverageFilterRestoreResult = ...
        coverageFilterSession.Restore();
    return;
end


%% ============================================================
% Expected value 갱신
%% ============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('Update Expected Values From Test Results\n');
fprintf('============================================\n');


st_log(cfg, 'DEBUG', ...
    'Expected-value result analysis/update start');

updateTimer = tic;

updateResult = ...
    st_update_expected_from_results( ...
        resultObj);

runContext.ExpectedUpdateResult = updateResult;

st_log(cfg, 'DEBUG', ...
    'Expected-value result analysis/update done | elapsed=%.3f sec', ...
    toc(updateTimer));


if isempty(updateResult)

    updatedTotal = 0;

else

    updatedTotal = ...
        sum(updateResult.UpdatedCount);
end


fprintf('\nExpected value updated lines : %d\n', ...
    updatedTotal);


if ~isempty(updateResult) && ...
        any(strcmp(updateResult.Status, 'FAIL'))

    warning( ...
        ['Expected value 자동 갱신에 실패한 Test Case가 있습니다. ' ...
         'ExpectedUpdateResult를 확인하세요.']);
end


%% ============================================================
% 재실행
%% ============================================================

if updatedTotal > 0 && ...
        cfg.RerunAfterExpectedUpdate

    fprintf('\n');
    fprintf('============================================\n');
    fprintf('Rerun After Expected Value Update\n');
    fprintf('============================================\n');

    st_log(cfg, 'DEBUG', ...
        'rerun run(tf) start');

    rerunTimer = tic;

    resultObj = ...
        run(tf);

    runContext.FinalResult = resultObj;
    runContext.RerunPerformed = true;

    st_log(cfg, 'DEBUG', ...
        'rerun run(tf) returned | elapsed=%.3f sec', ...
        toc(rerunTimer));

    verifyTimingResult = st_validate_sldv_verify_results(resultObj);
    if ~isempty(verifyTimingResult) && any(verifyTimingResult.Status == 'FAIL')
        failed = verifyTimingResult(verifyTimingResult.Status == 'FAIL', :);
        error('SLDV verify timing validation failed after rerun: %s', ...
            char(strjoin(failed.Message, ' | ')));
    end

    fprintf('재실행 완료\n');

elseif updatedTotal == 0

    fprintf('변경할 Expected value가 없어 재실행하지 않습니다.\n');

else

    fprintf('cfg.RerunAfterExpectedUpdate = false\n');
    fprintf('Expected value 갱신 후 재실행을 건너뜁니다.\n');
end

st_log(cfg, 'INFO', ...
    'Run Generated Tests complete | elapsed=%.3f sec', ...
    toc(totalTimer));

runContext.FinalResult = resultObj;
runContext.CompletedAt = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
runContext.CoverageFilterRestoreResult = coverageFilterSession.Restore();

catch runME
    try
        runContext.CoverageFilterRestoreResult = ...
            coverageFilterSession.Restore();
    catch restoreME
        restoreME = addCause(restoreME, runME);
        throw(restoreME);
    end
    rethrow(runME);
end

end


%% ============================================================
% Expected Value Logging 준비
%% ============================================================

function st_prepare_expected_value_logging( ...
        cfg, ...
        tf)

T = ...
    st_load_targets( ...
        cfg.OnlyEnabled);

T = ...
    T(T.ExpectedUpdateMode == "APPLY", :);

expectedTestCaseNames = ...
    string(T.TestCaseName);


if ~bdIsLoaded(cfg.TopModel)

    load_system( ...
        cfg.TopModel);
end


st_force_model_stopped( ...
    cfg.TopModel);


for i = 1:height(T)

    itemTimer = tic;

    ownerPath = ...
        st_normalize_cut_path( ...
            T.CUTPath(i), ...
            cfg.TopModel);

    harnessName = ...
        char(T.HarnessName(i));

    try

        st_log(cfg, 'DEBUG', ...
            '[LoggingPrep %d/%d] start | Harness=%s', ...
            i, height(T), harnessName);

        st_log(cfg, 'TRACE', ...
            '[LoggingPrep %d/%d] harness.load start', ...
            i, height(T));

        sltest.harness.load( ...
            ownerPath, ...
            harnessName);

        st_log(cfg, 'TRACE', ...
            '[LoggingPrep %d/%d] harness.load done', ...
            i, height(T));


        st_log(cfg, 'DEBUG', ...
            '[LoggingPrep %d/%d] enable Harness output logging start', ...
            i, height(T));

        logResult = ...
            st_enable_harness_output_logging( ...
                harnessName);

        st_log(cfg, 'DEBUG', ...
            '[LoggingPrep %d/%d] output logging result rows=%d', ...
            i, height(T), height(logResult));


        if any(strcmp(logResult.Status, 'FAIL'))

            failed = ...
                logResult( ...
                    strcmp(logResult.Status, 'FAIL'), ...
                    :);

            error( ...
                'Harness Outport logging 설정 실패: %s', ...
                char(strjoin(failed.Message, ' | ')));
        end


        st_log(cfg, 'TRACE', ...
            '[LoggingPrep %d/%d] save_system start', ...
            i, height(T));

        save_system( ...
            cfg.TopModel);

        st_log(cfg, 'TRACE', ...
            '[LoggingPrep %d/%d] save_system done; closing Harness', ...
            i, height(T));


        st_close_harness_quiet( ...
            ownerPath, ...
            harnessName);

        st_log(cfg, 'DEBUG', ...
            '[LoggingPrep %d/%d] finished | elapsed=%.3f sec', ...
            i, height(T), toc(itemTimer));


    catch ME

        st_close_harness_quiet( ...
            ownerPath, ...
            harnessName);

        error( ...
            'Expected value logging 준비 실패 [%s]: %s', ...
            harnessName, ...
            ME.message);
    end
end


%% Test Case에서 signal logging 강제 활성화

suites = ...
    getTestSuites(tf);

for s = 1:numel(suites)

    if ~strcmp(char(string(suites(s).Name)), cfg.TestSuiteName)
        continue;
    end

    testCases = ...
        getTestCases( ...
            suites(s));

    for c = 1:numel(testCases)

        if ~any(string(testCases(c).Name) == expectedTestCaseNames)
            continue;
        end

        setProperty( ...
            testCases(c), ...
            'OverrideModelOutputSettings', ...
            true, ...
            'SignalLogging', ...
            true);
    end
end


saveToFile(tf);

end


function st_close_harness_quiet( ...
        ownerPath, ...
        harnessName)

try

    sltest.harness.close( ...
        ownerPath, ...
        harnessName);

catch
end

end
