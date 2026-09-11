function [targets, testCases, result, tf] = ...
        st_prepare_standalone_bundle_execution( ...
        manifest, bundleRoot, workRoot)
%ST_PREPARE_STANDALONE_BUNDLE_EXECUTION Rewire a copied Test File to models.

cfg = st_require_runtime_target();
totalTimer = tic;
st_log(cfg, 'INFO', ...
    'Standalone bundle preparation start | Targets=%d', ...
    numel(manifest.Targets));

sourceTargets = st_load_targets(cfg.OnlyEnabled);
tf = sltest.testmanager.TestFile(cfg.TestFile);
suite = getTestSuiteByName(tf, cfg.TestSuiteName);
if numel(suite) ~= 1
    error('simtest:StandaloneTestSuiteMappingFailed', ...
        'Expected exactly one Test Suite named %s.', cfg.TestSuiteName);
end
suiteCases = getTestCases(suite);
suiteNames = strings(numel(suiteCases),1);
for i = 1:numel(suiteCases)
    suiteNames(i) = string(suiteCases(i).Name);
end
configure_standalone_coverage(tf, suite, [], cfg);

n = numel(manifest.Targets);
order = zeros(n,1);
testCases = suiteCases([]);
ExecutionModel = strings(n,1);
StandaloneCUTPath = strings(n,1);
ModelFile = strings(n,1);
AssessmentBlock = strings(n,1);
IterationSignature = strings(n,1);
Status = repmat("FAIL", n, 1);
Message = strings(n,1);

for i = 1:n
    itemTimer = tic;
    item = manifest.Targets(i);
    model = '';
    targetNo = double(item.No);
    testCaseName = string(item.TestCaseName);
    st_log(cfg, 'DEBUG', ...
        ['[StandalonePrepare %d/%d] start | No=%g | ' ...
         'TestCase=%s | Model=%s'], ...
        i, n, targetNo, char(testCaseName), char(item.StandaloneModel));
    try
        targetMatch = find(double(sourceTargets.No) == targetNo & ...
            string(sourceTargets.TestCaseName) == testCaseName);
        if numel(targetMatch) ~= 1
            error('simtest:StandaloneTargetMappingFailed', ...
                ['Manifest target does not map to exactly one enabled ' ...
                 'Targets row. No=%g | TestCase=%s'], ...
                targetNo, char(testCaseName));
        end
        caseMatch = find(suiteNames == testCaseName);
        if numel(caseMatch) ~= 1
            error('simtest:StandaloneTestCaseMappingFailed', ...
                'Expected one Test Case named %s, found %d.', ...
                char(testCaseName), numel(caseMatch));
        end

        model = char(item.StandaloneModel);
        modelFile = execution_path(bundleRoot, workRoot, ...
            char(item.StandaloneModelFile));
        if isempty(model) || ~isfile(modelFile)
            error('simtest:StandaloneModelMissing', ...
                'Standalone model is missing: %s', modelFile);
        end
        load_system(modelFile);
        loadedFile = char(get_param(model, 'FileName'));
        if ~same_path(loadedFile, modelFile)
            error('simtest:StandaloneModelLoadMismatch', ...
                'A different model file was loaded: %s', loadedFile);
        end

        cutPath = char(item.StandaloneCUTPath);
        if getSimulinkBlockHandle(cutPath) == -1
            error('simtest:StandaloneCUTMissing', ...
                'Recorded standalone CUT path is missing: %s', cutPath);
        end
        assessment = st_find_assessment_block(model);
        inputPath = char(item.SignalEditorInput);
        if ~isempty(inputPath)
            signalEditor = st_find_signal_editor_block(model);
            expectedInput = execution_path(bundleRoot, workRoot, inputPath);
            set_param(signalEditor, 'Filename', expectedInput);
            actualInput = st_resolve_data_file( ...
                get_param(signalEditor, 'Filename'), model);
            if ~same_path(actualInput, expectedInput)
                error('simtest:StandaloneSignalEditorReadbackFailed', ...
                    ['Standalone Signal Editor Filename readback failed. ' ...
                     'Expected=%s | Actual=%s'], expectedInput, actualInput);
            end
        end
        save_system(model);

        tc = suiteCases(caseMatch);
        originalIterationSignature = iteration_signature(tc);
        setProperty(tc, ...
            'Model', model, ...
            'HarnessOwner', '', ...
            'HarnessName', '', ...
            'TestSequenceBlock', assessment);
        verify_property(tc, 'Model', model);
        verify_property(tc, 'HarnessOwner', '');
        verify_property(tc, 'HarnessName', '');
        verify_property(tc, 'TestSequenceBlock', assessment);
        configure_standalone_coverage(tf, suite, tc, cfg);
        rewiredIterationSignature = iteration_signature(tc);
        if rewiredIterationSignature ~= originalIterationSignature
            error('simtest:StandaloneIterationChanged', ...
                ['Standalone Test Case rewiring changed Iteration or ' ...
                 'Signal Editor/Test Sequence Scenario settings.']);
        end

        order(i) = targetMatch;
        testCases(i,1) = tc;
        ExecutionModel(i) = string(model);
        StandaloneCUTPath(i) = string(cutPath);
        ModelFile(i) = string(modelFile);
        AssessmentBlock(i) = string(assessment);
        IterationSignature(i) = rewiredIterationSignature;
        Status(i) = "OK";
        Message(i) = "Test Case rewired and API readback verified";
        close_model(model);
        st_log(cfg, 'DEBUG', ...
            ['[StandalonePrepare %d/%d] complete | Model=%s | ' ...
             'CUT=%s | elapsed=%.3f sec'], ...
            i, n, model, cutPath, toc(itemTimer));
    catch ME
        if ~isempty(model), close_model(model); end
        st_log(cfg, 'ERROR', ...
            '[StandalonePrepare %d/%d] failed | %s: %s', ...
            i, n, ME.identifier, ME.message);
        rethrow(ME);
    end
end

st_log(cfg, 'DEBUG', 'Standalone Test File saveToFile start');
saveToFile(tf);
st_log(cfg, 'DEBUG', 'Standalone Test File saveToFile complete');
for i = 1:n
    verify_property(testCases(i), 'Model', char(ExecutionModel(i)));
    verify_property(testCases(i), 'HarnessOwner', '');
    verify_property(testCases(i), 'HarnessName', '');
    verify_property(testCases(i), 'TestSequenceBlock', ...
        char(AssessmentBlock(i)));
    verify_coverage_enabled(testCases(i));
    if iteration_signature(testCases(i)) ~= IterationSignature(i)
        error('simtest:StandaloneTestCaseSavedReadbackFailed', ...
            ['Saved Test File changed Iteration or Signal Editor/Test ' ...
             'Sequence Scenario settings for %s.'], ...
            char(string(testCases(i).Name)));
    end
end
targets = sourceTargets(order,:);
targets.ExecutionModel = ExecutionModel;
targets.StandaloneCUTPath = StandaloneCUTPath;
targets.ExecutionModelFile = ModelFile;
result = table(double(targets.No), string(targets.TestCaseName), ...
    ExecutionModel, StandaloneCUTPath, ModelFile, AssessmentBlock, ...
    IterationSignature, ...
    Status, Message, ...
    'VariableNames', {'No','TestCaseName','ExecutionModel', ...
    'StandaloneCUTPath','ModelFile','AssessmentBlock', ...
    'IterationSignature','Status','Message'});
st_write_result('StandaloneBundlePreparationResult', result);
st_log(cfg, 'INFO', ...
    'Standalone bundle preparation complete | Targets=%d | elapsed=%.3f sec', ...
    n, toc(totalTimer));
end

function configure_standalone_coverage(tf, suite, tc, cfg)
%CONFIGURE_STANDALONE_COVERAGE Reassert coverage after changing the SUT.
% TestCase.setProperty can change effective settings when a Harness SUT is
% converted to a Model SUT. Explicitly enable and verify coverage throughout
% the copied Test File hierarchy before it is saved and executed.
st_log(cfg, 'DEBUG', ...
    'Standalone coverage settings update start | TestCase=%s', ...
    coverage_case_name(tc));
fileCoverage = getCoverageSettings(tf);
fileCoverage.RecordCoverage = true;
fileCoverage.MetricSettings = cfg.CoverageMetricSettings;
fileCoverage.MdlRefCoverage = ...
    logical(cfg.CoverageIncludeReferencedModels);
suiteCoverage = getCoverageSettings(suite);
suiteCoverage.RecordCoverage = true;
if ~isempty(tc)
    caseCoverage = getCoverageSettings(tc);
    caseCoverage.RecordCoverage = true;
    verify_coverage_enabled(tc);
end
if ~logical(fileCoverage.RecordCoverage) || ...
        ~logical(suiteCoverage.RecordCoverage)
    error('simtest:StandaloneCoverageSettingsReadbackFailed', ...
        'Test File or Test Suite coverage enable readback failed.');
end
st_log(cfg, 'DEBUG', ...
    'Standalone coverage settings update complete | TestCase=%s', ...
    coverage_case_name(tc));
end

function verify_coverage_enabled(tc)
coverage = getCoverageSettings(tc);
if ~logical(coverage.RecordCoverage)
    error('simtest:StandaloneCoverageSettingsReadbackFailed', ...
        'Test Case coverage is disabled after standalone SUT rewiring: %s', ...
        char(string(tc.Name)));
end
end

function value = coverage_case_name(tc)
if isempty(tc)
    value = '<file-and-suite>';
else
    value = char(string(tc.Name));
end
end

function value = iteration_signature(tc)
iterations = getIterations(tc);
parts = strings(numel(iterations),1);
for i = 1:numel(iterations)
    params = iterations(i).TestParams;
    try
        paramsText = jsonencode(params);
    catch
        paramsText = evalc('disp(params)');
    end
    parts(i) = string(iterations(i).Name) + "|" + string(paramsText);
end
value = strjoin(parts, newline);
end

function path = execution_path(bundleRoot, workRoot, bundlePath)
native = strrep(char(bundlePath), '/', filesep);
prefix = ['template' filesep];
if startsWith(native, prefix)
    path = fullfile(workRoot, char(extractAfter( ...
        string(native), strlength(prefix))));
else
    path = fullfile(bundleRoot, native);
end
end

function verify_property(tc, name, expected)
actual = char(string(getProperty(tc, name)));
if ~strcmp(actual, expected)
    error('simtest:StandaloneTestCaseReadbackFailed', ...
        'Test Case property readback failed. %s expected=%s actual=%s', ...
        name, expected, actual);
end
end

function close_model(model)
if bdIsLoaded(model), close_system(model, 0); end
end

function tf = same_path(left, right)
left = char(java.io.File(char(left)).getCanonicalPath());
right = char(java.io.File(char(right)).getCanonicalPath());
if ispc
    tf = strcmpi(left, right);
else
    tf = strcmp(left, right);
end
end
