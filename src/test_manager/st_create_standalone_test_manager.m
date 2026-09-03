function [tf, testCases, R] = st_create_standalone_test_manager( ...
        targetConfig, modelInfos, testFilePath, cfg)
%ST_CREATE_STANDALONE_TEST_MANAGER Build a run-local model-SUT Test File.

if numel(modelInfos) ~= height(targetConfig)
    error('simtest:StandaloneTestManagerModelCountMismatch', ...
        'One standalone model is required per target row.');
end
parent = fileparts(testFilePath);
if ~isfolder(parent), mkdir(parent); end
st_log(cfg, 'INFO', ...
    'Standalone Test Manager creation start | targets=%d | File=%s', ...
    height(targetConfig), testFilePath);
timerValue = tic;
sourceFilters = collect_source_manual_filters(targetConfig, cfg);

tf = sltest.testmanager.TestFile(testFilePath, true);
fileCoverage = getCoverageSettings(tf);
fileCoverage.RecordCoverage = true;
fileCoverage.MetricSettings = cfg.CoverageMetricSettings;
fileCoverage.MdlRefCoverage = logical(cfg.CoverageIncludeReferencedModels);
fileCoverage.CoverageFilterFilename = ...
    filter_property_value(sourceFilters.File);
suite = getTestSuiteByName(tf, cfg.TestSuiteName);
if isempty(suite), suite = createTestSuite(tf, cfg.TestSuiteName); end
suiteCoverage = getCoverageSettings(suite);
suiteCoverage.RecordCoverage = true;
suiteCoverage.CoverageFilterFilename = ...
    filter_property_value(sourceFilters.Suite);
defaults = getTestCases(suite);
for i = 1:numel(defaults), remove(defaults(i)); end

n = height(targetConfig);
testCases = cell(n,1);
TestCaseName = string(targetConfig.TestCaseName);
ModelName = strings(n,1);
ModelPath = strings(n,1);
AssessmentBlock = strings(n,1);
IterationCount = zeros(n,1);
ParameterOverrideCount = zeros(n,1);
ManualFilterCount = zeros(n,1);
SignalEditorScenarioApplied = false(n,1);
Status = repmat("FAIL", n, 1);
Message = strings(n,1);

caseCells = cell(n,1);
for i = 1:n
    row = targetConfig(i,:);
    modelInfo = modelInfos(i);
    ModelName(i) = string(modelInfo.ModelName);
    ModelPath(i) = string(modelInfo.ModelPath);
    modelDirectory = fileparts(modelInfo.ModelPath);
    pathCleanup = register_model_path(modelDirectory); %#ok<NASGU>
    tc = [];
    try
        load_system(modelInfo.ModelPath);
        modelCleanup = onCleanup(@() close_model(modelInfo.ModelName)); %#ok<NASGU>
        assert_loaded_file(modelInfo.ModelName, modelInfo.ModelPath);
        assessment = st_find_assessment_block(modelInfo.ModelName);
        AssessmentBlock(i) = string(assessment);

        tc = createTestCase(suite, 'simulation', ...
            char(row.TestCaseName));
        setProperty(tc, ...
            'Model', modelInfo.ModelName, ...
            'HarnessOwner', '', ...
            'HarnessName', '', ...
            'UseSignalEditorScenarios', false, ...
            'TestSequenceBlock', assessment);

        profile = st_get_sldv_profile(row, cfg);
        scenarios = profile.ScenarioNames;
        useSignalEditor = modelInfo.InputCount > 0 || ...
            ~strcmp(profile.Mode, 'OFF');
        for scenarioIndex = 1:numel(scenarios)
            scenario = scenarios{scenarioIndex};
            iteration = sltest.testmanager.TestIteration;
            iteration.Enabled = true;
            if useSignalEditor
                setTestParam(iteration, ...
                    'SignalEditorScenario', scenario);
                SignalEditorScenarioApplied(i) = true;
            end
            setTestParam(iteration, 'TestSequenceScenario', scenario);
            if strcmp(profile.Mode, 'OFF')
                iterationName = 'Iteration 1';
            else
                dataFile = profile.EffectiveDataFile;
                if isfield(modelInfo, 'Inputs') && ...
                        isfield(modelInfo.Inputs, 'EffectiveSldv') && ...
                        ~isempty(modelInfo.Inputs.EffectiveSldv)
                    dataFile = modelInfo.Inputs.EffectiveSldv;
                end
                [~, params] = sldvsimdata( ...
                    dataFile, profile.SourceIndices(scenarioIndex));
                ParameterOverrideCount(i) = ...
                    ParameterOverrideCount(i) + st_apply_sldv_parameters( ...
                    iteration, params, profile.SourceIndices(scenarioIndex));
                iterationName = scenario;
            end
            addIteration(tc, iteration, iterationName);
        end
        IterationCount(i) = numel(scenarios);
        caseCoverage = getCoverageSettings(tc);
        caseCoverage.RecordCoverage = true;
        caseCoverage.CoverageFilterFilename = ...
            filter_property_value(sourceFilters.Case{i});
        ManualFilterCount(i) = numel(unique([sourceFilters.File; ...
            sourceFilters.Suite; sourceFilters.Case{i}], 'stable'));
        caseCells{i} = tc;
        Status(i) = "OK";
        Message(i) = "Standalone model SUT Test Case created";
        st_log(cfg, 'DEBUG', ...
            ['Standalone Test Case configured | TestCase=%s | Model=%s | ' ...
             'Assessment=%s | Iterations=%d'], ...
            char(row.TestCaseName), modelInfo.ModelName, assessment, ...
            IterationCount(i));
    catch ME
        if ~isempty(tc)
            try, remove(tc); catch, end
        end
        st_log(cfg, 'ERROR', ...
            'Standalone Test Case creation failed | %s: %s', ...
            ME.identifier, ME.message);
        Status(i) = "FAIL";
        Message(i) = string(ME.message);
    end
    clear modelCleanup;
    clear pathCleanup;
end

saveToFile(tf);
testCases = caseCells;
R = table(targetConfig.No, targetConfig.CUTName, TestCaseName, ...
    ModelName, ModelPath, AssessmentBlock, IterationCount, ...
    ParameterOverrideCount, ManualFilterCount, ...
    SignalEditorScenarioApplied, Status, Message, ...
    'VariableNames', {'No','CUTName','TestCaseName','ModelName', ...
    'ModelPath','AssessmentBlock','IterationCount', ...
    'ParameterOverrideCount','ManualFilterCount', ...
    'SignalEditorScenarioApplied','Status', ...
    'Message'});
st_write_result('StandaloneTestManagerResult', R);
st_log(cfg, 'INFO', ...
    'Standalone Test Manager creation complete | targets=%d | elapsed=%.3f sec', ...
    n, toc(timerValue));
end

function result = collect_source_manual_filters(targetConfig, cfg)
result = struct('File', strings(0,1), 'Suite', strings(0,1), ...
    'Case', []);
result.Case = repmat({strings(0,1)}, height(targetConfig), 1);
if ~isfile(cfg.TestFile)
    error('simtest:StandaloneSourceTestFileMissing', ...
        'Source Test File is missing: %s', cfg.TestFile);
end
source = sltest.testmanager.TestFile(cfg.TestFile);
sourceCoverage = getCoverageSettings(source);
result.File = manual_filters(sourceCoverage.CoverageFilterFilename, cfg);
suites = getTestSuites(source);
suiteMatches = suites(string({suites.Name}) == string(cfg.TestSuiteName));
if numel(suiteMatches) ~= 1
    error('simtest:StandaloneSourceTestSuiteMappingFailed', ...
        'Expected one source Test Suite named %s, found %d.', ...
        cfg.TestSuiteName, numel(suiteMatches));
end
sourceSuite = suiteMatches(1);
sourceSuiteCoverage = getCoverageSettings(sourceSuite);
result.Suite = manual_filters( ...
    sourceSuiteCoverage.CoverageFilterFilename, cfg);
sourceCases = getTestCases(sourceSuite);
sourceNames = string({sourceCases.Name});
for i = 1:height(targetConfig)
    matches = find(sourceNames == string(targetConfig.TestCaseName(i)));
    if numel(matches) ~= 1
        error('simtest:StandaloneSourceTestCaseMappingFailed', ...
            'Expected one source Test Case named %s, found %d.', ...
            char(targetConfig.TestCaseName(i)), numel(matches));
    end
    sourceCaseCoverage = getCoverageSettings(sourceCases(matches));
    result.Case{i} = manual_filters( ...
        sourceCaseCoverage.CoverageFilterFilename, cfg);
end
st_log(cfg, 'DEBUG', ...
    ['Standalone manual coverage filters copied from source Test File | ' ...
     'file=%d | suite=%d | cases=%d'], ...
    numel(result.File), numel(result.Suite), ...
    sum(cellfun(@numel, result.Case)));
end

function values = manual_filters(raw, cfg)
values = string(raw(:));
values(ismissing(values)) = "";
values = unique(values(strlength(values) > 0), 'stable');
keep = true(numel(values),1);
for i = 1:numel(values)
    keep(i) = ~is_managed_filter(values(i), cfg.CoverageFilterDir);
end
values = values(keep);
end

function tf = is_managed_filter(value, managedRoot)
try
    target = char(java.io.File(char(value)).getCanonicalPath());
    root = char(java.io.File(char(managedRoot)).getCanonicalPath());
    prefix = [root filesep];
    if ispc
        tf = startsWith(lower(target), lower(prefix));
    else
        tf = startsWith(target, prefix);
    end
catch
    tf = false;
end
end

function value = filter_property_value(filters)
if isempty(filters), value = ""; else, value = filters; end
end

function cleanup = register_model_path(directory)
addpath(directory, '-begin');
cleanup = onCleanup(@() remove_path(directory));
end

function remove_path(directory)
try, rmpath(directory); catch, end
end

function assert_loaded_file(modelName, expected)
actual = get_param(modelName, 'FileName');
left = char(java.io.File(actual).getCanonicalPath());
right = char(java.io.File(expected).getCanonicalPath());
if ispc, equal = strcmpi(left, right); else, equal = strcmp(left, right); end
if ~equal
    error('simtest:StandaloneModelLoadMismatch', ...
        'MATLAB loaded a different standalone model: %s', actual);
end
end

function close_model(modelName)
if bdIsLoaded(modelName), close_system(modelName, 0); end
end
