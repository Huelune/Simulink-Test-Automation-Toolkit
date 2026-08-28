function R = st_create_test_manager(stageSelection)
%ST_CREATE_TEST_MANAGER Create or extend Test Manager test cases.
%
% Test File : {TopModel}.mldatx
% Suite     : cfg.TestSuiteName
% Test Case : Excel TestCaseName
% SUT       : TopModel + existing Harness
%
% cfg.OverwriteTestFile == true
%   - If the target Test File is already open, close only that Test File.
%   - Recreate the .mldatx file.
%   - Remove existing/default Test Cases from the requested suite.
%   - Create Test Cases from Excel.
%
% cfg.OverwriteTestFile == false
%   - If the target Test File is already open, reuse the open object.
%   - If the file exists but is not open, open it.
%   - If the file does not exist, create it.
%   - Preserve existing Test Cases.
%   - OFF mode skips an existing TestCaseName.
%   - FILE/GENERATE mode preserves the Test Case and replaces only its
%     table iterations after all new iterations are prepared successfully.
%
% Test Case Inputs:
%   Signal Editor Scenario : OFF at base Test Case level
%   Test Sequence Block    : Test Assessment block
%   Override with Scenario : not set at base Test Case level
%
% Table Iterations:
%   OFF mode keeps the legacy single 'Iteration 1'.
%   FILE/GENERATE creates one named iteration per SLDV TestCase and assigns
%   the same UT_REQ_{CUTName}_{NNN} value to both scenario parameters.
%   OFF mode without a direct CUT Inport omits SignalEditorScenario.
%   FILE/GENERATE always assign SignalEditorScenario from the prepared
%   Harness scenario, even when the CUT has no direct Inport.
%
% Coverage:
%   RecordCoverage = true at Test File level and Test Case level.

cfg = ...
    st_require_runtime_target();

T = ...
    st_load_targets( ...
        cfg.OnlyEnabled);

if nargin < 1
    stageSelection = [];
end
selection = st_normalize_stage_selection(T, stageSelection);

if ~any(selection.Run)
    PreparationAction = selection.Action;
    PreparationReason = selection.Reason;
    Action = repmat("CACHED", height(T), 1);
    Status = repmat("CACHED", height(T), 1);
    Message = PreparationReason;
    R = table(T.No, T.CUTName, T.TestCaseName, T.HarnessName, ...
        PreparationAction, PreparationReason, Action, Status, Message);
    st_write_result('TestManagerResult', R);
    return;
end

st_force_model_stopped( ...
    cfg.TopModel);


%% ============================================================
% Open / create Test File
%% ============================================================

fileExistedBefore = ...
    isfile( ...
        cfg.TestFile);

st_log(cfg, 'INFO', ...
    ['Test Manager open/create start | File=%s | Exists=%d | ' ...
     'Overwrite=%d'], ...
    cfg.TestFile, ...
    fileExistedBefore, ...
    logical(cfg.OverwriteTestFile));

tf = ...
    st_open_or_create_test_file( ...
        cfg.TestFile, ...
        cfg.OverwriteTestFile);

st_log(cfg, 'DEBUG', ...
    'Test File object ready | FilePath=%s', ...
    tf.FilePath);


% Coverage must be enabled at the Test File level first.
covFile = ...
    getCoverageSettings( ...
        tf);

covFile.RecordCoverage = ...
    true;
covFile.MetricSettings = ...
    cfg.CoverageMetricSettings;
covFile.MdlRefCoverage = ...
    logical(cfg.CoverageIncludeReferencedModels);


%% ============================================================
% Test Suite
%% ============================================================

ts = ...
    getTestSuiteByName( ...
        tf, ...
        cfg.TestSuiteName);

if isempty(ts)

    ts = ...
        createTestSuite( ...
            tf, ...
            cfg.TestSuiteName);
end


% Keep coverage enabled throughout the hierarchy.
covSuite = ...
    getCoverageSettings( ...
        ts);

covSuite.RecordCoverage = ...
    true;


%% ============================================================
% Reset suite only for full recreation / first creation
%% ============================================================

% A newly-created TestFile can contain a default Test Case.
% Remove it on the first creation so the generated hierarchy is clean.
%
% In incremental mode with an already-existing file, preserve all
% existing Test Cases.
if cfg.OverwriteTestFile || ...
        ~fileExistedBefore

    existingCases = ...
        getTestCases( ...
            ts);

    for k = 1:numel(existingCases)

        remove( ...
            existingCases(k));
    end
end


%% ============================================================
% Result variables
%% ============================================================

n = ...
    height(T);

AssessmentBlock = strings(n,1);
ScenarioName = strings(n,1);
IterationCount = zeros(n,1);
ParameterOverrideCount = zeros(n,1);
HasDirectInport = false(n,1);
HarnessScenarioInputCount = zeros(n,1);
SignalEditorScenarioApplied = false(n,1);
ExistingTestCase = false(n,1);
Action = strings(n,1);
Status = strings(n,1);
Message = strings(n,1);
ElapsedSec = zeros(n,1);
Timestamp = strings(n,1);
PreparationAction = selection.Action;
PreparationReason = selection.Reason;


fprintf('\n');
fprintf('============================================\n');
fprintf('Create Test Manager\n');
fprintf('Test File : %s\n', cfg.TestFile);
fprintf('Overwrite : %d\n', logical(cfg.OverwriteTestFile));

if cfg.OverwriteTestFile
    fprintf('Mode      : RECREATE\n');
else
    fprintf('Mode      : INCREMENTAL\n');
end

fprintf('============================================\n');


%% ============================================================
% Create / skip Test Cases
%% ============================================================

totalTimer = tic;

for i = 1:n

    if ~selection.Run(i)
        Action(i) = 'CACHED';
        Status(i) = 'CACHED';
        Message(i) = selection.Reason(i);
        Timestamp(i) = string(datetime('now', ...
            'Format', 'yyyy-MM-dd HH:mm:ss'));
        continue;
    end

    ownerPath = ...
        st_normalize_cut_path( ...
            T.CUTPath(i), ...
            cfg.TopModel);

    harnessName = ...
        char( ...
            T.HarnessName(i));

    testCaseName = ...
        char( ...
            T.TestCaseName(i));

    profile = st_get_sldv_profile(T(i,:), cfg);
    scenarioNames = profile.ScenarioNames;
    scenarioName = scenarioNames{1};

    ScenarioName(i) = ...
        string(strjoin(scenarioNames, ', '));

    tc = [];
    createdThisRun = false;
    timerValue = tic;

    st_log(cfg, 'DEBUG', ...
        '[TestManager %d/%d] start | TestCase=%s | Harness=%s | Scenario=%s', ...
        i, n, testCaseName, harnessName, scenarioName);


    try

        if isempty(testCaseName)

            error( ...
                'TestCaseName is empty. Row No=%d', ...
                T.No(i));
        end


        %% ====================================================
        % Existing Test Case
        %% ====================================================

        st_log(cfg, 'TRACE', ...
            '[TestManager %d/%d] checking existing Test Case', ...
            i, n);

        existingTc = ...
            getTestCaseByName( ...
                ts, ...
                testCaseName);

        st_log(cfg, 'DEBUG', ...
            '[TestManager %d/%d] existing Test Case count=%d', ...
            i, n, numel(existingTc));

        if ~isempty(existingTc) && strcmp(profile.Mode, 'OFF')

            ExistingTestCase(i) = ...
                true;

            Action(i) = ...
                'SKIP_EXISTING';

            Status(i) = ...
                'SKIP';

            if cfg.OverwriteTestFile

                Message(i) = ...
                    ['Same TestCaseName already exists in this run; ' ...
                     'duplicate Excel row skipped'];

            else

                Message(i) = ...
                    'Existing Test Case preserved; no changes applied';
            end

            fprintf( ...
                '[%d/%d] SKIP %s | already exists\n', ...
                i, ...
                n, ...
                testCaseName);

            ElapsedSec(i) = ...
                toc(timerValue);

            Timestamp(i) = ...
                string( ...
                    datetime( ...
                        'now', ...
                        'Format', ...
                        'yyyy-MM-dd HH:mm:ss'));

            st_log(cfg, 'DEBUG', ...
                '[TestManager %d/%d] skipped existing | elapsed=%.3f sec', ...
                i, n, ElapsedSec(i));

            continue;
        end

        if ~isempty(existingTc)
            if numel(existingTc) ~= 1
                error('Multiple Test Cases have the same name: %s', testCaseName);
            end
            ExistingTestCase(i) = true;
            tc = existingTc(1);
            Action(i) = 'UPDATED_SLDV';
        end


        %% ====================================================
        % Direct CUT Inport
        %% ====================================================

        st_log(cfg, 'TRACE', ...
            '[TestManager %d/%d] searching direct CUT Inports', ...
            i, n);

        directInports = ...
            find_system( ...
                ownerPath, ...
                'SearchDepth', 1, ...
                'Type', 'Block', ...
                'BlockType', 'Inport');

        hasDirectInport = ...
            ~isempty(directInports);

        HasDirectInport(i) = ...
            hasDirectInport;

        if strcmp(profile.Mode, 'OFF')
            applySignalEditorScenario = hasDirectInport;
        else
            HarnessScenarioInputCount(i) = ...
                numel(profile.HarnessInputNames);

            if HarnessScenarioInputCount(i) == 0
                error( ...
                    ['SLDV profile has no Harness ActiveScenario inputs. ' ...
                     'Run st_prepare_sldv_targets again.']);
            end

            applySignalEditorScenario = true;
        end

        st_log(cfg, 'DEBUG', ...
            '[TestManager %d/%d] direct Inport count=%d', ...
            i, n, numel(directInports));


        %% ====================================================
        % Harness / Test Assessment
        %% ====================================================

        st_force_model_stopped( ...
            cfg.TopModel);

        st_log(cfg, 'DEBUG', ...
            '[TestManager %d/%d] harness.load start', ...
            i, n);

        sltest.harness.load( ...
            ownerPath, ...
            harnessName);

        st_log(cfg, 'DEBUG', ...
            '[TestManager %d/%d] harness.load done', ...
            i, n);

        assess = ...
            st_find_assessment_block( ...
                harnessName);

        AssessmentBlock(i) = ...
            string( ...
                assess);

        st_log(cfg, 'DEBUG', ...
            '[TestManager %d/%d] Assessment block=%s', ...
            i, n, assess);


        %% ====================================================
        % Create Test Case
        %% ====================================================

        st_log(cfg, 'DEBUG', ...
            '[TestManager %d/%d] createTestCase start', ...
            i, n);

        if isempty(tc)
            tc = ...
                createTestCase( ...
                    ts, ...
                    'simulation', ...
                    testCaseName);
            createdThisRun = true;
        end

        st_log(cfg, 'DEBUG', ...
            '[TestManager %d/%d] createTestCase done', ...
            i, n);


        % Base Test Case Inputs intentionally do NOT select either scenario.
        % Scenarios are selected only by Table Iteration below.
        st_log(cfg, 'TRACE', ...
            '[TestManager %d/%d] applying Test Case properties', ...
            i, n);

        setProperty( ...
            tc, ...
            'Model', cfg.TopModel, ...
            'HarnessOwner', ownerPath, ...
            'HarnessName', harnessName, ...
            'UseSignalEditorScenarios', false, ...
            'TestSequenceBlock', assess);


        %% ====================================================
        % Iteration
        %% ====================================================

        preparedIterations = cell(numel(scenarioNames), 1);
        preparedIterationNames = cell(numel(scenarioNames), 1);
        for scenarioIndex = 1:numel(scenarioNames)
            currentScenario = scenarioNames{scenarioIndex};
            iter = sltest.testmanager.TestIteration;
            iter.Enabled = true;

            if applySignalEditorScenario
                setTestParam(iter, 'SignalEditorScenario', currentScenario);
                SignalEditorScenarioApplied(i) = true;
            end
            setTestParam(iter, 'TestSequenceScenario', currentScenario);

            if strcmp(profile.Mode, 'OFF')
                iterationName = 'Iteration 1';
            else
                [~, params] = sldvsimdata(profile.EffectiveDataFile, ...
                    profile.SourceIndices(scenarioIndex));
                ParameterOverrideCount(i) = ParameterOverrideCount(i) + ...
                    st_apply_sldv_parameters(iter, params, ...
                    profile.SourceIndices(scenarioIndex));
                iterationName = currentScenario;
            end

            preparedIterations{scenarioIndex} = iter;
            preparedIterationNames{scenarioIndex} = iterationName;
        end

        if strcmp(profile.Mode, 'OFF')
            addIteration(tc, preparedIterations{1}, preparedIterationNames{1});
        else
            replace_test_iterations(tc, preparedIterations, ...
                preparedIterationNames);
        end
        IterationCount(i) = numel(preparedIterations);

        st_log(cfg, 'DEBUG', ...
            '[TestManager %d/%d] iterations added=%d', ...
            i, n, IterationCount(i));


        %% ====================================================
        % Coverage
        %% ====================================================

        covCase = ...
            getCoverageSettings( ...
                tc);

        covCase.RecordCoverage = ...
            true;

        st_log(cfg, 'TRACE', ...
            '[TestManager %d/%d] coverage enabled', ...
            i, n);


        %% ====================================================
        % Finish
        %% ====================================================

        st_close_harness_quiet( ...
            ownerPath, ...
            harnessName);

        if ~ExistingTestCase(i)
            Action(i) = 'CREATED';
        end

        Status(i) = ...
            'OK';


        if ~strcmp(profile.Mode, 'OFF')

            Message(i) = sprintf(['SLDV target initialized; iterations=%d, ' ...
                'parameterOverrides=%d, harnessScenarioInputs=%d'], ...
                IterationCount(i), ...
                ParameterOverrideCount(i), ...
                HarnessScenarioInputCount(i));

        elseif hasDirectInport

            Message(i) = ...
                ['Test Case + Iteration 1 + Signal Editor + ' ...
                 'Assessment + Coverage created'];

        else

            Message(i) = ...
                ['Test Case + Iteration 1 + Assessment + Coverage created; ' ...
                 'Signal Editor scenario omitted because CUT has no direct Inport'];
        end


        fprintf( ...
            ['[%d/%d] OK   %s | ' ...
             'DirectInport=%d | SignalEditorScenario=%d | Iterations=%d\n'], ...
            i, ...
            n, ...
            testCaseName, ...
            hasDirectInport, ...
            SignalEditorScenarioApplied(i), ...
            IterationCount(i));


    catch ME

        st_close_harness_quiet( ...
            ownerPath, ...
            harnessName);


        if ~isempty(tc) && createdThisRun

            try

                remove( ...
                    tc);

            catch
            end
        end


        Action(i) = ...
            'FAILED';

        Status(i) = ...
            'FAIL';

        Message(i) = ...
            string( ...
                ME.message);


        fprintf( ...
            '[%d/%d] FAIL %s: %s\n', ...
            i, ...
            n, ...
            testCaseName, ...
            ME.message);
    end


    ElapsedSec(i) = ...
        toc(timerValue);

    st_log(cfg, 'DEBUG', ...
        '[TestManager %d/%d] finished | action=%s | status=%s | elapsed=%.3f sec | total=%.3f sec', ...
        i, n, char(Action(i)), char(Status(i)), ElapsedSec(i), toc(totalTimer));

    Timestamp(i) = ...
        string( ...
            datetime( ...
                'now', ...
                'Format', ...
                'yyyy-MM-dd HH:mm:ss'));
end


%% ============================================================
% Save Test File
%% ============================================================

st_log(cfg, 'DEBUG', ...
    'Test Manager saveToFile start');

saveToFile( ...
    tf);

st_log(cfg, 'DEBUG', ...
    'Test Manager saveToFile done');


%% ============================================================
% Result
%% ============================================================

R = ...
    table( ...
        T.No, ...
        T.CUTName, ...
        T.TestCaseName, ...
        T.HarnessName, ...
        AssessmentBlock, ...
        ScenarioName, ...
        IterationCount, ...
        ParameterOverrideCount, ...
        HasDirectInport, ...
        HarnessScenarioInputCount, ...
        SignalEditorScenarioApplied, ...
    ExistingTestCase, ...
    PreparationAction, ...
    PreparationReason, ...
    Action, ...
        Status, ...
        Message, ...
        ElapsedSec, ...
        Timestamp, ...
        'VariableNames', { ...
            'No', ...
            'CUTName', ...
            'TestCaseName', ...
            'HarnessName', ...
            'AssessmentBlock', ...
            'ScenarioName', ...
            'IterationCount', ...
            'ParameterOverrideCount', ...
            'HasDirectInport', ...
            'HarnessScenarioInputCount', ...
            'SignalEditorScenarioApplied', ...
        'ExistingTestCase', ...
        'PreparationAction', ...
        'PreparationReason', ...
        'Action', ...
            'Status', ...
            'Message', ...
            'ElapsedSec', ...
            'Timestamp'});


st_write_result( ...
    'TestManagerResult', ...
    R);


fprintf('\n');
fprintf('============================================\n');
fprintf('Test Manager Result\n');
fprintf('============================================\n');
fprintf('CREATED : %d\n', ...
    sum(Action == 'CREATED'));
fprintf('SKIPPED : %d\n', ...
    sum(Action == 'SKIP_EXISTING'));
fprintf('UPDATED : %d\n', ...
    sum(Action == 'UPDATED_SLDV'));
fprintf('FAILED  : %d\n', ...
    sum(Action == 'FAILED'));
fprintf('Total   : %d\n', ...
    n);
fprintf('============================================\n');
fprintf('Test Manager saved: %s\n', ...
    cfg.TestFile);

st_log(cfg, 'INFO', ...
    'Create Test Manager complete | elapsed=%.3f sec', ...
    toc(totalTimer));

end


%% ============================================================
% Targeted iteration replacement with rollback
%% ============================================================

function replace_test_iterations(tc, newIterations, newNames)

oldIterations = getIterations(tc);
oldNames = cell(numel(oldIterations), 1);
for i = 1:numel(oldIterations)
    oldNames{i} = char(oldIterations(i).Name);
end

if ~isempty(oldIterations)
    deleteIterations(tc, oldIterations);
end

addedCount = 0;
try
    for i = 1:numel(newIterations)
        addIteration(tc, newIterations{i}, newNames{i});
        addedCount = addedCount + 1;
    end
catch originalError
    for i = 1:addedCount
        try
            deleteIterations(tc, newIterations{i});
        catch
        end
    end

    try
        for i = 1:numel(oldIterations)
            addIteration(tc, oldIterations(i), oldNames{i});
        end
    catch rollbackError
        error('Iteration replacement failed: %s | rollback failed: %s', ...
            originalError.message, rollbackError.message);
    end
    rethrow(originalError);
end
end


%% ============================================================
% Open / create Test File safely
%% ============================================================

function tf = ...
    st_open_or_create_test_file( ...
        testFilePath, ...
        overwrite)

testFilePath = ...
    char( ...
        testFilePath);

overwrite = ...
    logical( ...
        overwrite);

targetPath = ...
    st_canonical_test_file_path( ...
        testFilePath);

openFiles = ...
    sltest.testmanager.getTestFiles;

matching = [];

for i = 1:numel(openFiles)

    try

        openPath = ...
            st_canonical_test_file_path( ...
                openFiles(i).FilePath);

        if ispc
            sameFile = strcmpi(openPath, targetPath);
        else
            sameFile = strcmp(openPath, targetPath);
        end

        if sameFile

            matching = ...
                [matching i]; %#ok<AGROW>
        end

    catch
    end
end


%% Overwrite: close only this Test File, then recreate.

if overwrite

    for k = 1:numel(matching)

        obj = ...
            openFiles( ...
                matching(k));

        if obj.Dirty

            fprintf( ...
                ['Closing already-open Test File without saving because ' ...
                 'OverwriteTestFile=true: %s\n'], ...
                obj.FilePath);

        else

            fprintf( ...
                'Closing already-open Test File: %s\n', ...
                obj.FilePath);
        end

        close( ...
            obj);
    end


    tf = ...
        sltest.testmanager.TestFile( ...
            testFilePath, ...
            true);

    return;
end


%% Incremental: reuse already-open Test File.

if ~isempty(matching)

    tf = ...
        openFiles( ...
            matching(1));

    fprintf( ...
        'Reusing already-open Test File: %s\n', ...
        tf.FilePath);

    return;
end


%% Incremental: TestFile(..., false) opens an existing file or creates it
% when it does not exist.

tf = ...
    sltest.testmanager.TestFile( ...
        testFilePath, ...
        false);

if isfile(testFilePath)

    fprintf( ...
        'Opened Test File for incremental update: %s\n', ...
        tf.FilePath);

else

    fprintf( ...
        'Created Test File: %s\n', ...
        tf.FilePath);
end

end


%% ============================================================
% Canonical path
%% ============================================================

function path = ...
    st_canonical_test_file_path( ...
        path)

path = ...
    char( ...
        java.io.File( ...
            char(path)).getCanonicalPath());

end


%% ============================================================
% Harness Close
%% ============================================================

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
