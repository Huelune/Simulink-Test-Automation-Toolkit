function R = st_update_expected_from_results(resultObj, targetConfig)
%ST_UPDATE_EXPECTED_FROM_RESULTS
% Test execution 결과를 사용하여 실패한 Iteration의 verify expected value를 갱신합니다.
%
% 기준:
%   OFF: cfg.ExpectedValueSampleTime 시점의 실제 Harness Outport 값
%   FILE/GENERATE: 해당 CUT Tmax 시점의 실제 Harness Outport 값
%
% Assessment symbol과 Harness output 이름이 달라도,
% Assessment Port 순서 = Scenario 변수 + Harness output 순서를 이용해
% 실제 logged Harness output으로 다시 매핑합니다.
%
% 대상 Action 형식:
%   verify(A == 0);
%   verify(A(1) == 0);
%   verify(data(1,1).NAME == 0);
%
% 실제값과 RHS가 다를 때만:
%
%   verify(A == 0);
%
% 를 예를 들어:
%
%   verify(A == 15);
%
% 로 변경합니다.
%
% 처리 대상:
%   Test Iteration Outcome == Failed 인 경우만
%
% 지원 expected value:
%   real numeric scalar
%   logical scalar
%
% 지원하지 않는 값은 해당 verify line을 변경하지 않고 결과 Message에 기록합니다.

cfg = st_require_runtime_target();

if nargin < 2 || isempty(targetConfig)
    T = st_load_targets(cfg.OnlyEnabled);
else
    T = targetConfig;
end

T = ...
    T(T.ExpectedUpdateMode == "APPLY", :);

if isempty(T)
    error('Expected value update requires at least one APPLY target.');
end


st_force_model_stopped( ...
    cfg.TopModel);


[taskTargetRow, taskScenarioName, taskSampleTime] = ...
    build_expected_update_tasks(T, cfg);


%% ============================================================
% Test Case Result 수집
%% ============================================================

testCaseResults = ...
    collect_test_case_results( ...
        resultObj);


n = numel(taskTargetRow);

TestCaseName = strings(n,1);
ScenarioName = strings(n,1);
IterationOutcome = strings(n,1);
VerifyLineCount = zeros(n,1);
MismatchCount = zeros(n,1);
UpdatedCount = zeros(n,1);
ElapsedSec = zeros(n,1);
Status = strings(n,1);
Message = strings(n,1);
Timestamp = strings(n,1);


fprintf('\n');
fprintf('============================================\n');
fprintf('Expected Value Auto Update\n');
fprintf('Sample Time : per target/scenario\n');
fprintf('============================================\n');

totalTimer = tic;

st_log(cfg, 'INFO', ...
    'Expected value update start | iteration count=%d', n);


%% ============================================================
% CUT / Test Case 반복
%% ============================================================

for i = 1:n

    targetIndex = taskTargetRow(i);
    profile = st_get_sldv_profile(T(targetIndex,:), cfg);
    sampleTime = taskSampleTime(i);

    testCaseName = ...
        char(T.TestCaseName(targetIndex));

    scenarioName = ...
        char(taskScenarioName(i));

    ownerPath = ...
        st_normalize_cut_path( ...
            T.CUTPath(targetIndex), ...
            cfg.TopModel);

    harnessName = ...
        char(T.HarnessName(targetIndex));


    TestCaseName(i) = ...
        string(testCaseName);

    ScenarioName(i) = ...
        string(scenarioName);

    timerValue = tic;

    st_log(cfg, 'DEBUG', ...
        '[ExpectedUpdate %d/%d] start | TestCase=%s | Harness=%s | Scenario=%s', ...
        i, n, testCaseName, harnessName, scenarioName);


    fprintf('\n[%d/%d] %s\n', ...
        i, ...
        n, ...
        testCaseName);


    try

        %% ----------------------------------------------------
        % Test Case Result 찾기
        %% ----------------------------------------------------

        tcResult = ...
            find_test_case_result( ...
                testCaseResults, ...
                testCaseName);


        if isempty(tcResult)

            error( ...
                'Test Case Result를 찾지 못했습니다: %s', ...
                testCaseName);
        end


        %% ----------------------------------------------------
        % Iteration Result 찾기
        %% ----------------------------------------------------

        iterResult = ...
            find_iteration_result( ...
                tcResult, ...
                scenarioName, ...
                strcmp(profile.Mode, 'OFF'));


        if isempty(iterResult)

            error( ...
                'Test Iteration Result를 찾지 못했습니다: %s', ...
                testCaseName);
        end


        outcomeValue = ...
            double(iterResult.Outcome);


        IterationOutcome(i) = ...
            outcome_to_text( ...
                outcomeValue);


        %% ----------------------------------------------------
        % Failed Iteration만 갱신
        %% ----------------------------------------------------

        if outcomeValue ~= 3

            Status(i) = ...
                'SKIP';

            Message(i) = ...
                'Iteration is not Failed';

            fprintf('  -> SKIP : Iteration is not Failed\n');

            ElapsedSec(i) = ...
                toc(timerValue);

            Timestamp(i) = ...
                current_timestamp();

            st_log(cfg, 'DEBUG', ...
                '[ExpectedUpdate %d/%d] skipped | elapsed=%.3f sec', ...
                i, n, ElapsedSec(i));

            continue;
        end


        %% ----------------------------------------------------
        % Output Run
        %% ----------------------------------------------------

        st_log(cfg, 'DEBUG', ...
            '[ExpectedUpdate %d/%d] getOutputRuns start', ...
            i, n);

        outputRuns = ...
            getOutputRuns( ...
                iterResult);

        st_log(cfg, 'DEBUG', ...
            '[ExpectedUpdate %d/%d] output run count=%d', ...
            i, n, numel(outputRuns));


        if isempty(outputRuns)

            error( ...
                ['Simulation Output Run이 없습니다. ' ...
                 'Harness Outport signal logging 설정을 확인하세요.']);
        end


        %% ----------------------------------------------------
        % Harness / Assessment Load
        %% ----------------------------------------------------

        st_force_model_stopped( ...
            cfg.TopModel);


        st_log(cfg, 'DEBUG', ...
            '[ExpectedUpdate %d/%d] harness.load start', ...
            i, n);

        sltest.harness.load( ...
            ownerPath, ...
            harnessName);

        st_log(cfg, 'DEBUG', ...
            '[ExpectedUpdate %d/%d] harness.load done', ...
            i, n);


        assess = ...
            st_find_assessment_block( ...
                harnessName);


        step2Path = ...
            [scenarioName '.step2'];


        st_log(cfg, 'TRACE', ...
            '[ExpectedUpdate %d/%d] readStep Action start | step=%s', ...
            i, n, step2Path);

        currentAction = ...
            sltest.testsequence.readStep( ...
                assess, ...
                step2Path, ...
                'Action');

        st_log(cfg, 'DEBUG', ...
            '[ExpectedUpdate %d/%d] current verify action length=%d chars', ...
            i, n, length(char(currentAction)));


        %% ----------------------------------------------------
        % RHS 갱신
        %% ----------------------------------------------------

        st_log(cfg, 'DEBUG', ...
            '[ExpectedUpdate %d/%d] collecting Harness outputs', ...
            i, n);

        harnessOutputs = ...
            st_collect_harness_output_signals( ...
                harnessName);

        st_log(cfg, 'DEBUG', ...
            '[ExpectedUpdate %d/%d] Harness output rows=%d | names=[%s]', ...
            i, n, ...
            height(harnessOutputs), ...
            strjoin(cellstr(harnessOutputs.SignalName), ', '));


        %% Assessment Symbol <-> Harness Output mapping
        %
        % Assessment Input order was confirmed as:
        %   1) Signal Editor ActiveScenario variables
        %   2) Harness output signals
        %
        % verify() uses the actual Assessment Symbol name, while logged
        % signals keep the Harness output signal/outport name. Therefore
        % the expected-value updater must rebuild the same positional map
        % used by st_configure_assessments.

        if cfg.VerifyHarnessOutportsOnly

            assessmentSpecs = ...
                st_collect_assessment_input_specs( ...
                    assess);

            scenarioNames = ...
                st_collect_signal_editor_scenario_names( ...
                    harnessName, ...
                    cfg.TopModel);

            scenarioInputCount = ...
                numel(scenarioNames);

            st_log(cfg, 'DEBUG', ...
                '[ExpectedUpdate %d/%d] Assessment=%d | Scenario=%d | ScenarioNames=[%s]', ...
                i, n, ...
                height(assessmentSpecs), ...
                scenarioInputCount, ...
                strjoin(cellstr(scenarioNames), ', '));

            usableHarnessOutputs = ...
                harnessOutputs( ...
                    strlength(harnessOutputs.SignalName) > 0, ...
                    :);

            assessmentOutputMap = ...
                build_assessment_output_map( ...
                    assessmentSpecs, ...
                    usableHarnessOutputs, ...
                    scenarioInputCount);

            st_log(cfg, 'DEBUG', ...
                '[ExpectedUpdate %d/%d] Assessment->Harness output map count=%d', ...
                i, n, height(assessmentOutputMap));

            for logIdx = 1:height(assessmentOutputMap)

                st_log(cfg, 'TRACE', ...
                    ['[ExpectedUpdate %d/%d] map #%d | Assessment=%s | ' ...
                     'HarnessSignal=%s | Outport=%s'], ...
                    i, n, logIdx, ...
                    char(assessmentOutputMap.AssessmentSymbol(logIdx)), ...
                    char(assessmentOutputMap.HarnessSignalName(logIdx)), ...
                    char(assessmentOutputMap.HarnessOutportBlock(logIdx)));
            end

        else

            assessmentOutputMap = ...
                table();
        end


        st_log(cfg, 'DEBUG', ...
            '[ExpectedUpdate %d/%d] update_verify_action start', ...
            i, n);

        [newAction, lineCount, mismatchCount, updatedCount, notes] = ...
            update_verify_action( ...
                char(currentAction), ...
                outputRuns, ...
                sampleTime, ...
                harnessOutputs, ...
                assessmentOutputMap);


        VerifyLineCount(i) = ...
            lineCount;

        MismatchCount(i) = ...
            mismatchCount;

        UpdatedCount(i) = ...
            updatedCount;

        st_log(cfg, 'DEBUG', ...
            ['[ExpectedUpdate %d/%d] update_verify_action done | ' ...
             'verify=%d | mismatch=%d | updated=%d'], ...
            i, n, lineCount, mismatchCount, updatedCount);


        %% ----------------------------------------------------
        % 변경사항 저장
        %% ----------------------------------------------------

        if updatedCount > 0

            st_log(cfg, 'DEBUG', ...
                '[ExpectedUpdate %d/%d] editStep start', ...
                i, n);

            sltest.testsequence.editStep( ...
                assess, ...
                step2Path, ...
                'Action', ...
                newAction);

            st_log(cfg, 'DEBUG', ...
                '[ExpectedUpdate %d/%d] editStep done; save_system start', ...
                i, n);


            save_system( ...
                cfg.TopModel);

            st_log(cfg, 'DEBUG', ...
                '[ExpectedUpdate %d/%d] save_system done', ...
                i, n);
        end


        st_close_harness_quiet( ...
            ownerPath, ...
            harnessName);


        %% ----------------------------------------------------
        % Result
        %% ----------------------------------------------------

        Status(i) = ...
            'OK';


        if isempty(notes)

            Message(i) = ...
                sprintf( ...
                    'verify=%d, mismatch=%d, updated=%d', ...
                    lineCount, ...
                    mismatchCount, ...
                    updatedCount);

        else

            Message(i) = ...
                string( ...
                    sprintf( ...
                        'verify=%d, mismatch=%d, updated=%d | %s', ...
                        lineCount, ...
                        mismatchCount, ...
                        updatedCount, ...
                        notes));
        end


        fprintf( ...
            '  -> OK : verify=%d, mismatch=%d, updated=%d\n', ...
            lineCount, ...
            mismatchCount, ...
            updatedCount);


    catch ME

        st_close_harness_quiet( ...
            ownerPath, ...
            harnessName);


        Status(i) = ...
            'FAIL';

        Message(i) = ...
            string(ME.message);


        fprintf( ...
            '  -> FAIL : %s\n', ...
            ME.message);
    end


    ElapsedSec(i) = ...
        toc(timerValue);

    st_log(cfg, 'DEBUG', ...
        '[ExpectedUpdate %d/%d] finished | status=%s | elapsed=%.3f sec | total=%.3f sec', ...
        i, n, char(Status(i)), ElapsedSec(i), toc(totalTimer));

    Timestamp(i) = ...
        current_timestamp();
end


%% ============================================================
% Result Table
%% ============================================================

SampleTime = taskSampleTime;


R = table( ...
    T.No(taskTargetRow), ...
    T.CUTName(taskTargetRow), ...
    TestCaseName, ...
    T.HarnessName(taskTargetRow), ...
    ScenarioName, ...
    SampleTime, ...
    IterationOutcome, ...
    VerifyLineCount, ...
    MismatchCount, ...
    UpdatedCount, ...
    ElapsedSec, ...
    Status, ...
    Message, ...
    Timestamp, ...
    'VariableNames', { ...
        'No', ...
        'CUTName', ...
        'TestCaseName', ...
        'HarnessName', ...
        'ScenarioName', ...
        'SampleTime', ...
        'IterationOutcome', ...
        'VerifyLineCount', ...
        'MismatchCount', ...
        'UpdatedCount', ...
        'ElapsedSec', ...
        'Status', ...
        'Message', ...
        'Timestamp'});


st_write_result( ...
    'ExpectedUpdateResult', ...
    R);


fprintf('\n');
fprintf('============================================\n');
fprintf('Expected Value Update Result\n');
fprintf('============================================\n');
fprintf('Updated lines : %d\n', ...
    sum(UpdatedCount));
fprintf('FAIL         : %d\n', ...
    sum(strcmp(Status, 'FAIL')));
fprintf('============================================\n');

st_log(cfg, 'INFO', ...
    'Expected value update complete | elapsed=%.3f sec', ...
    toc(totalTimer));

end


%% ============================================================
% Target/scenario expansion
%% ============================================================

function [targetRows, scenarioNames, sampleTimes] = ...
        build_expected_update_tasks(T, cfg)

targetRows = zeros(0,1);
scenarioNames = strings(0,1);
sampleTimes = zeros(0,1);

for targetIndex = 1:height(T)
    profile = st_get_sldv_profile(T(targetIndex,:), cfg);
    if strcmp(profile.Mode, 'OFF')
        names = profile.ScenarioNames;
        times = double(cfg.ExpectedValueSampleTime);
    else
        names = profile.ScenarioNames;
        times = repmat(double(profile.Tmax), numel(names), 1);
    end

    if isscalar(times)
        times = repmat(times, numel(names), 1);
    end
    if any(~isfinite(times)) || any(times < 0)
        error('Expected-value sample times must be finite and nonnegative.');
    end

    targetRows = [targetRows; repmat(targetIndex, numel(names), 1)]; %#ok<AGROW>
    scenarioNames = [scenarioNames; string(names(:))]; %#ok<AGROW>
    sampleTimes = [sampleTimes; times(:)]; %#ok<AGROW>
end
end


%% ============================================================
% Action Update
%% ============================================================

function [newAction, lineCount, mismatchCount, updatedCount, notes] = ...
    update_verify_action( ...
        currentAction, ...
        outputRuns, ...
        sampleTime, ...
        harnessOutputs, ...
        assessmentOutputMap)


if isempty(currentAction)

    newAction = currentAction;
    lineCount = 0;
    mismatchCount = 0;
    updatedCount = 0;
    notes = '';

    return;
end


lines = ...
    regexp( ...
        currentAction, ...
        '\r\n|\n|\r', ...
        'split');


sampleCache = ...
    containers.Map( ...
        'KeyType', ...
        'char', ...
        'ValueType', ...
        'any');


lineCount = 0;
mismatchCount = 0;
updatedCount = 0;
noteList = {};


pattern = ...
    '^\s*verify\((.*?)\s*==\s*(.*?)\);\s*$';


for i = 1:numel(lines)

    line = ...
        lines{i};


    token = ...
        regexp( ...
            line, ...
            pattern, ...
            'tokens', ...
            'once');


    if isempty(token)

        continue;
    end


    lineCount = ...
        lineCount + 1;


    lhs = ...
        strtrim(token{1});

    rhs = ...
        strtrim(token{2});


    try

        rootToken = ...
            regexp( ...
                lhs, ...
                '^([A-Za-z]\w*)', ...
                'tokens', ...
                'once');


        if isempty(rootToken)

            error( ...
                'LHS root symbol을 찾지 못했습니다: %s', ...
                lhs);
        end


        rootName = ...
            rootToken{1};


        if isKey( ...
                sampleCache, ...
                rootName)

            rootValue = ...
                sampleCache(rootName);

        else

            sig = ...
                find_logged_signal( ...
                    outputRuns, ...
                    rootName, ...
                    harnessOutputs, ...
                    assessmentOutputMap);


            if isempty(sig)

                error( ...
                    'Logged signal을 찾지 못했습니다: %s', ...
                    rootName);
            end


            rootValue = ...
                sample_logged_value( ...
                    sig.Values, ...
                    sampleTime);


            sampleCache(rootName) = ...
                rootValue;
        end


        actualValue = ...
            evaluate_lhs( ...
                lhs, ...
                rootName, ...
                rootValue);


        expectedValue = ...
            parse_expected_literal( ...
                rhs);


        if ~is_supported_scalar(actualValue)

            error( ...
                '지원하지 않는 actual value type입니다: %s', ...
                class(actualValue));
        end


        if ~values_equal( ...
                actualValue, ...
                expectedValue)

            mismatchCount = ...
                mismatchCount + 1;


            newRhs = ...
                format_expected_literal( ...
                    actualValue);


            lines{i} = ...
                sprintf( ...
                    'verify(%s == %s);', ...
                    lhs, ...
                    newRhs);


            updatedCount = ...
                updatedCount + 1;
        end


    catch ME

        noteList{end+1,1} = ...
            sprintf( ...
                '%s: %s', ...
                lhs, ...
                ME.message); %#ok<AGROW>
    end
end


newAction = ...
    strjoin( ...
        lines, ...
        sprintf('\n'));


if isempty(noteList)

    notes = '';

else

    notes = ...
        strjoin( ...
            noteList, ...
            ' | ');
end

end


%% ============================================================
% Assessment Symbol <-> Harness Output mapping
%% ============================================================

function M = ...
    build_assessment_output_map( ...
        assessmentSpecs, ...
        harnessOutputs, ...
        scenarioInputCount)
% Rebuild the same mapping rule used by st_configure_assessments:
%
% Assessment ports:
%   1..K       -> Signal Editor scenario variables
%   K+1..K+N   -> Harness outputs 1..N
%
% The Assessment symbol name may differ from the Harness signal name
% (for example A/B -> AB), so names are never used to establish the map.

if ~ismember( ...
        'Port', ...
        assessmentSpecs.Properties.VariableNames)

    error( ...
        ['Assessment input specs에 Port 열이 없습니다. ' ...
         'st_collect_assessment_input_specs.m을 최신 패치로 교체하세요.']);
end


scenarioInputCount = ...
    double(scenarioInputCount);


if ~isscalar(scenarioInputCount) || ...
        ~isfinite(scenarioInputCount) || ...
        scenarioInputCount < 0 || ...
        mod(scenarioInputCount,1) ~= 0

    error( ...
        'Invalid scenario input count: %g', ...
        scenarioInputCount);
end


nAssessment = ...
    height(assessmentSpecs);

nHarness = ...
    height(harnessOutputs);


expectedPorts = ...
    (1:nAssessment).';

actualPorts = ...
    double(assessmentSpecs.Port);


if ~isequal( ...
        actualPorts, ...
        expectedPorts)

    error( ...
        ['Assessment Input Port가 연속된 1..N 순서가 아닙니다. ' ...
         'Actual=%s'], ...
        mat2str(actualPorts.'));
end


expectedAssessmentCount = ...
    scenarioInputCount + nHarness;


if nAssessment ~= expectedAssessmentCount

    error( ...
        ['Expected update mapping count mismatch. ' ...
         'Assessment=%d, Scenario=%d, HarnessOutput=%d, Expected=%d'], ...
        nAssessment, ...
        scenarioInputCount, ...
        nHarness, ...
        expectedAssessmentCount);
end


if nHarness == 0

    M = ...
        table();

    return;
end


rows = ...
    scenarioInputCount + (1:nHarness).';


AssessmentPort = ...
    assessmentSpecs.Port(rows);

AssessmentSymbol = ...
    assessmentSpecs.Name(rows);

HarnessOutportPort = ...
    harnessOutputs.Port;

HarnessSignalName = ...
    harnessOutputs.SignalName;

HarnessOutportBlock = ...
    harnessOutputs.OutportBlock;


M = ...
    table( ...
        AssessmentPort, ...
        AssessmentSymbol, ...
        HarnessOutportPort, ...
        HarnessSignalName, ...
        HarnessOutportBlock);

end


%% ============================================================
% Logged Signal 검색
%% ============================================================

function sig = ...
    find_logged_signal( ...
        outputRuns, ...
        assessmentSymbol, ...
        harnessOutputs, ...
        assessmentOutputMap)

sig = [];


%% ============================================================
% 1. Assessment Symbol -> actual Harness output aliases
%% ============================================================

searchNames = ...
    {assessmentSymbol};


if ~isempty(assessmentOutputMap)

    rows = ...
        find( ...
            strcmp( ...
                assessmentOutputMap.AssessmentSymbol, ...
                assessmentSymbol));


    if numel(rows) > 1

        error( ...
            'Assessment output mapping is ambiguous: %s', ...
            assessmentSymbol);
    end


    if numel(rows) == 1

        aliases = [ ...
            assessmentOutputMap.HarnessSignalName(rows); ...
            assessmentOutputMap.HarnessOutportBlock(rows)];

        aliases = ...
            aliases( ...
                strlength(aliases) > 0);

        aliases = ...
            unique( ...
                aliases, ...
                'stable');

        searchNames = [ ...
            searchNames; ...
            cellstr(aliases)];
    end
end


%% ============================================================
% 2. Backward-compatible raw-name alias lookup
%% ============================================================

if ~isempty(harnessOutputs)

    mask = ...
        strcmp(harnessOutputs.SignalName, assessmentSymbol) | ...
        strcmp(harnessOutputs.OutportBlock, assessmentSymbol);


    if any(mask)

        aliases = [ ...
            harnessOutputs.SignalName(mask); ...
            harnessOutputs.OutportBlock(mask)];

        aliases = ...
            aliases( ...
                strlength(aliases) > 0);

        aliases = ...
            unique( ...
                aliases, ...
                'stable');

        searchNames = [ ...
            searchNames; ...
            cellstr(aliases)];
    end
end


searchNames = ...
    unique( ...
        searchNames, ...
        'stable');


%% ============================================================
% 3. Search the logged output runs
%% ============================================================

for n = 1:numel(searchNames)

    currentName = ...
        searchNames{n};


    for r = 1:numel(outputRuns)

        found = ...
            getSignalsByName( ...
                outputRuns(r), ...
                currentName);


        if isempty(found)

            continue;
        end


        if numel(found) == 1

            sig = ...
                found;

            return;
        end


        %% 동일 이름이 여러 개면 Signals domain 우선

        for k = 1:numel(found)

            try

                if strcmp( ...
                        char(found(k).Domain), ...
                        'Signals')

                    sig = ...
                        found(k);

                    return;
                end

            catch
            end
        end


        sig = ...
            found(1);

        return;
    end
end

end


%% ============================================================
% Logged Value Sampling
%% ============================================================

function out = ...
    sample_logged_value( ...
        value, ...
        sampleTime)


if isa(value, 'timeseries')

    out = ...
        sample_timeseries( ...
            value, ...
            sampleTime);

    return;
end


if istimetable(value)

    out = ...
        sample_timetable( ...
            value, ...
            sampleTime);

    return;
end


if isstruct(value)

    out = value;

    fieldNames = ...
        fieldnames(value);


    for idx = 1:numel(value)

        for f = 1:numel(fieldNames)

            fieldName = ...
                fieldNames{f};

            out(idx).(fieldName) = ...
                sample_logged_value( ...
                    value(idx).(fieldName), ...
                    sampleTime);
        end
    end

    return;
end


if iscell(value)

    out = cell(size(value));

    for i = 1:numel(value)

        out{i} = ...
            sample_logged_value( ...
                value{i}, ...
                sampleTime);
    end

    return;
end


%% 이미 sample 값 형태인 경우

out = value;

end


function out = ...
    sample_timeseries( ...
        ts, ...
        sampleTime)


if isempty(ts.Time)

    error( ...
        'timeseries에 time data가 없습니다.');
end


timeValues = ...
    double(ts.Time(:));


tol = ...
    max( ...
        1e-12, ...
        abs(sampleTime) * 1e-9);


if sampleTime < min(timeValues) - tol || ...
        sampleTime > max(timeValues) + tol

    error( ...
        'SampleTime %.17g가 logged time range [%.17g, %.17g] 밖입니다.', ...
        sampleTime, ...
        min(timeValues), ...
        max(timeValues));
end


%% 동일 시점 sample이 여러 개면 마지막 sample 사용
%% 정확한 시점이 없으면 이전 sample을 사용(ZOH 기준)

idx = ...
    find( ...
        timeValues <= sampleTime + tol, ...
        1, ...
        'last');


if isempty(idx)

    error( ...
        'SampleTime 이전의 sample을 찾지 못했습니다.');
end


sampleObj = ...
    getsamples( ...
        ts, ...
        idx);

out = ...
    sampleObj.Data;

end


function out = ...
    sample_timetable( ...
        tt, ...
        sampleTime)


if height(tt) == 0

    error( ...
        'timetable에 data가 없습니다.');
end


rowTimes = ...
    tt.Properties.RowTimes;


if isduration(rowTimes)

    timeValues = ...
        seconds(rowTimes);

elseif isnumeric(rowTimes)

    timeValues = ...
        double(rowTimes);

else

    error( ...
        '지원하지 않는 timetable RowTimes type입니다: %s', ...
        class(rowTimes));
end


timeValues = ...
    double(timeValues(:));


tol = ...
    max( ...
        1e-12, ...
        abs(sampleTime) * 1e-9);


if sampleTime < min(timeValues) - tol || ...
        sampleTime > max(timeValues) + tol

    error( ...
        'SampleTime %.17g가 timetable time range 밖입니다.', ...
        sampleTime);
end


idx = ...
    find( ...
        timeValues <= sampleTime + tol, ...
        1, ...
        'last');


row = ...
    tt(idx,:);

out = ...
    row.Variables;


if iscell(out) && ...
        numel(out) == 1

    out = ...
        out{1};
end

end


%% ============================================================
% LHS 평가
%% ============================================================

function value = ...
    evaluate_lhs( ...
        lhs, ...
        rootName, ...
        rootValue)


if length(lhs) < length(rootName) || ...
        ~strncmp( ...
            lhs, ...
            rootName, ...
            length(rootName))

    error( ...
        'LHS root symbol mismatch: %s', ...
        lhs);
end


tail = ...
    lhs(length(rootName)+1:end);


expression = ...
    ['rootValue' tail];


value = ...
    eval(expression);

end


%% ============================================================
% Expected Value Parse / Compare / Format
%% ============================================================

function value = ...
    parse_expected_literal( ...
        text)

text = ...
    strtrim(text);


if strcmpi(text, 'true')

    value = true;
    return;
end


if strcmpi(text, 'false')

    value = false;
    return;
end


if strcmpi(text, 'NaN')

    value = NaN;
    return;
end


if strcmpi(text, 'Inf') || ...
        strcmpi(text, '+Inf')

    value = Inf;
    return;
end


if strcmpi(text, '-Inf')

    value = -Inf;
    return;
end


value = ...
    str2double(text);


if isnan(value) && ...
        ~strcmpi(text, 'NaN')

    error( ...
        '지원하지 않는 expected literal입니다: %s', ...
        text);
end

end


function tf = ...
    values_equal( ...
        actualValue, ...
        expectedValue)


if islogical(actualValue)

    tf = ...
        isequal( ...
            logical(actualValue), ...
            logical(expectedValue));

    return;
end


actualDouble = ...
    double(actualValue);

expectedDouble = ...
    double(expectedValue);


if isnan(actualDouble) && ...
        isnan(expectedDouble)

    tf = true;

else

    tf = ...
        actualDouble == expectedDouble;
end

end


function text = ...
    format_expected_literal( ...
        value)


if islogical(value)

    if value

        text = 'true';

    else

        text = 'false';
    end

    return;
end


value = ...
    double(value);


if isnan(value)

    text = 'NaN';

elseif isinf(value) && ...
        value > 0

    text = 'Inf';

elseif isinf(value) && ...
        value < 0

    text = '-Inf';

else

    text = ...
        sprintf( ...
            '%.17g', ...
            value);
end

end


function tf = ...
    is_supported_scalar(value)


if isa(value, 'embedded.fi')

    tf = ...
        isscalar(value) && ...
        isreal(value);

    return;
end


tf = ...
    (isnumeric(value) || islogical(value)) && ...
    isscalar(value) && ...
    isreal(value);

end


%% ============================================================
% Test Result Hierarchy
%% ============================================================

function resultCells = ...
    collect_test_case_results( ...
        resultObj)


resultCells = {};


testFileResults = ...
    getTestFileResults( ...
        resultObj);


for f = 1:numel(testFileResults)

    suiteResults = ...
        getTestSuiteResults( ...
            testFileResults(f));


    for s = 1:numel(suiteResults)

        caseResults = ...
            getTestCaseResults( ...
                suiteResults(s));


        for c = 1:numel(caseResults)

            resultCells{end+1,1} = ...
                caseResults(c); %#ok<AGROW>
        end
    end
end

end


function tcResult = ...
    find_test_case_result( ...
        resultCells, ...
        testCaseName)


tcResult = [];


for i = 1:numel(resultCells)

    candidate = ...
        resultCells{i};


    if strcmp( ...
            char(candidate.Name), ...
            testCaseName)

        tcResult = ...
            candidate;

        return;
    end
end

end


function iterResult = ...
    find_iteration_result( ...
        tcResult, ...
        scenarioName, ...
        allowFallback)


iterResult = [];


iterations = ...
    getIterationResults( ...
        tcResult);


if isempty(iterations)

    return;
end


%% Scenario가 일치하는 Iteration 우선

for i = 1:numel(iterations)

    try

        tsScenario = ...
            iterations(i).TestSequenceScenario;


        if isstruct(tsScenario) && ...
                isfield(tsScenario, 'TestSequenceScenario') && ...
                strcmp( ...
                    char(tsScenario.TestSequenceScenario), ...
                    scenarioName)

            iterResult = ...
                iterations(i);

            return;
        end

    catch
    end
end


if allowFallback
    %% Legacy OFF mode has one iteration and retains the historical fallback.
    iterResult = iterations(end);
end

end


function text = ...
    outcome_to_text(value)

switch value

    case 0
        text = 'Disabled';

    case 1
        text = 'Incomplete';

    case 2
        text = 'Passed';

    case 3
        text = 'Failed';

    otherwise
        text = 'Unknown';
end

end


%% ============================================================
% Common
%% ============================================================

function text = current_timestamp()

text = ...
    string( ...
        datetime( ...
            'now', ...
            'Format', ...
            'yyyy-MM-dd HH:mm:ss'));

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
