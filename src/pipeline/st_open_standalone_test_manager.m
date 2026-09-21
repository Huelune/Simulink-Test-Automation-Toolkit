function info = st_open_standalone_test_manager(varargin)
%ST_OPEN_STANDALONE_TEST_MANAGER Rebuild Test Manager from a standalone run.
%
%   info = st_open_standalone_test_manager()
%   info = st_open_standalone_test_manager('PipelineId', id)
%
% After st_run_standalone_coverage_pipeline finishes, its execution models
% are closed and nothing is left open in Test Manager. This command puts the
% packaged submission back into Test Manager so it can be inspected:
%
%   1. loads every packaged standalone model (so the Test Case SUT and the
%      CVF viewer names resolve against the model that produced them),
%   2. loads the packaged, rewired Test File,
%   3. re-applies each packaged CVF to its Test Case,
%   4. imports the saved aggregate Result when the pipeline kept one
%      (SaveTestResult=true), and
%   5. opens the Test Manager window.
%
% It is read-only on disk: no model, Test File, CVF or Result is saved or
% changed. It only loads them into the current MATLAB session. It also does
% not touch the original Top Model.
%
% Options:
%   'PipelineId'        - pipeline to open, or 'LATEST' (default).
%   'OutputRoot'        - pipeline root. Default cfg.StandaloneCoverageRootDir.
%   'ImportResults'     - import the saved aggregate Result (default true).
%                         Silently skipped when the pipeline saved none.
%   'ClearTestManager'  - close every Test File and Result already open in
%                         Test Manager first (default false). Use it when a
%                         Test File of the same name is still loaded.
%   'View'              - open the Test Manager window (default true).

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'PipelineId', 'LATEST', @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ImportResults', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'ClearTestManager', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'View', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

outputRoot = strtrim(char(string(p.Results.OutputRoot)));
if isempty(outputRoot)
    cfg = st_require_runtime_target('LoadModel', false);
    outputRoot = cfg.StandaloneCoverageRootDir;
else
    cfg = st_config();
end

timerValue = tic;
st_log(cfg, 'INFO', ...
    'Standalone Test Manager open start | Root=%s | PipelineId=%s', ...
    outputRoot, char(string(p.Results.PipelineId)));

[manifest, manifestPath] = st_load_standalone_pipeline_manifest( ...
    outputRoot, p.Results.PipelineId);
pipelineId = char(string(manifest.PipelineId));
require_packaged(manifest, manifestPath);
targets = manifest.Targets;

if p.Results.ClearTestManager
    st_log(cfg, 'INFO', 'Standalone Test Manager clear start');
    sltest.testmanager.clearResults;
    sltest.testmanager.clear;
    st_log(cfg, 'INFO', 'Standalone Test Manager clear complete');
end

% 1. Standalone models. Load every packaged model before Test Manager
%    resolves the Test Case SUT, exactly as the packaged launcher does.
loadedModels = strings(0,1);
for k = 1:numel(targets)
    item = targets(k);
    modelFile = field_text(item, 'PackagedStandaloneModel');
    if isempty(modelFile)
        st_log(cfg, 'WARN', ...
            'Standalone model is not packaged | Target=%d | TestCase=%s', ...
            k, field_text(item, 'TestCaseName'));
        continue;
    end
    if ~isfile(modelFile)
        error('simtest:StandaloneTestManagerModelMissing', ...
            'Standalone model is missing for target %d: %s', k, modelFile);
    end
    addpath(fileparts(modelFile));
    [~, modelName] = fileparts(modelFile);
    if bdIsLoaded(modelName)
        loadedFile = char(string(get_param(modelName, 'FileName')));
        if ~st_same_path(loadedFile, modelFile)
            error('simtest:StandaloneTestManagerModelIsolationFailed', ...
                ['A different model is already loaded for %s. ' ...
                 'Close it first. Expected=%s | Actual=%s'], ...
                modelName, modelFile, loadedFile);
        end
        st_log(cfg, 'DEBUG', ...
            'Standalone model already loaded | Model=%s', modelName);
    else
        st_log(cfg, 'DEBUG', ...
            'Standalone model load start | Model=%s | File=%s', ...
            modelName, modelFile);
        load_system(modelFile);
    end
    loadedModels(end+1,1) = string(modelName); %#ok<AGROW>
end
st_log(cfg, 'INFO', ...
    'Standalone models ready | Loaded=%d | Targets=%d', ...
    numel(loadedModels), numel(targets));

% 2. Packaged Test File.
testFilePath = field_text(manifest, 'TestManagerFile');
if ~isfile(testFilePath)
    error('simtest:StandaloneTestManagerFileMissing', ...
        'Packaged Test File is missing: %s', testFilePath);
end
testFile = load_test_file(testFilePath, cfg);
testCases = getAllTestCases(testFile);
caseNames = strings(numel(testCases),1);
for k = 1:numel(testCases)
    caseNames(k) = string(testCases(k).Name);
end

% 3. CVF per Test Case. Targets that never produced a CVF (EXCEPT) keep
%    their Test Case without a filter.
appliedFilters = 0;
skippedFilters = strings(0,1);
for k = 1:numel(targets)
    item = targets(k);
    testCaseName = string(field_text(item, 'TestCaseName'));
    filterFile = field_text(item, 'PackagedCVF');
    if isempty(filterFile)
        skippedFilters(end+1,1) = testCaseName; %#ok<AGROW>
        st_log(cfg, 'WARN', ...
            'No packaged CVF for Test Case | TestCase=%s | Status=%s', ...
            char(testCaseName), field_text(item, 'ExecutionStatus'));
        continue;
    end
    if ~isfile(filterFile)
        error('simtest:StandaloneTestManagerFilterMissing', ...
            'Packaged CVF is missing for %s: %s', ...
            char(testCaseName), filterFile);
    end
    matches = find(caseNames == testCaseName);
    if numel(matches) ~= 1
        error('simtest:StandaloneTestManagerCaseMappingFailed', ...
            'Expected one Test Case named %s in %s, found %d.', ...
            char(testCaseName), testFilePath, numel(matches));
    end
    coverage = getCoverageSettings(testCases(matches));
    coverage.CoverageFilterFilename = filterFile;
    actual = string(coverage.CoverageFilterFilename);
    if ~filter_readback_matches(filterFile, actual)
        error('simtest:StandaloneTestManagerFilterReadbackFailed', ...
            ['Coverage filter readback failed for %s. ' ...
             'Expected=%s | Actual=%s'], ...
            char(testCaseName), filterFile, char(strjoin(actual, ' | ')));
    end
    appliedFilters = appliedFilters + 1;
    st_log(cfg, 'DEBUG', ...
        'Coverage filter applied | TestCase=%s | Filter=%s', ...
        char(testCaseName), filterFile);
end
st_log(cfg, 'INFO', ...
    'Coverage filters applied | Applied=%d | Skipped=%d', ...
    appliedFilters, numel(skippedFilters));

% 4. Saved aggregate Result.
[resultStatus, resultRoots, resultFile] = import_saved_result( ...
    manifest, p.Results.ImportResults, cfg);

% 5. Window.
if p.Results.View
    sltest.testmanager.view;
end

info = struct( ...
    'PipelineId', pipelineId, ...
    'Manifest', manifestPath, ...
    'TestManagerFile', testFilePath, ...
    'TestFile', testFile, ...
    'LoadedModels', loadedModels, ...
    'AppliedFilterCount', appliedFilters, ...
    'SkippedFilterTestCases', skippedFilters, ...
    'ResultStatus', resultStatus, ...
    'ResultFile', resultFile, ...
    'ResultRootCount', resultRoots);

fprintf('\n');
fprintf('============================================\n');
fprintf('Standalone Test Manager rebuilt\n');
fprintf('PipelineId : %s\n', pipelineId);
fprintf('Test File  : %s\n', testFilePath);
fprintf('Models     : %d loaded\n', numel(loadedModels));
fprintf('CVF        : %d applied', appliedFilters);
if ~isempty(skippedFilters)
    fprintf(', %d without CVF (%s)', numel(skippedFilters), ...
        char(strjoin(skippedFilters, ', ')));
end
fprintf('\n');
fprintf('Results    : %s\n', result_summary_text(resultStatus, resultRoots));
fprintf('============================================\n');
st_log(cfg, 'INFO', ...
    ['Standalone Test Manager open complete | PipelineId=%s | Models=%d | ' ...
     'CVFs=%d | Results=%s | elapsed=%.3f sec'], ...
    pipelineId, numel(loadedModels), appliedFilters, resultStatus, ...
    toc(timerValue));
end

function require_packaged(manifest, manifestPath)
%REQUIRE_PACKAGED The Test File and CVFs exist only after PACKAGE.
packaged = isfield(manifest, 'Actions') && ...
    isfield(manifest.Actions, 'PACKAGE') && ...
    ismember(upper(string(field_text(manifest.Actions.PACKAGE, 'Status'))), ...
        ["OK","WARN"]);
if ~packaged
    error('simtest:StandaloneTestManagerNotPackaged', ...
        ['Pipeline %s has not completed PACKAGE, so there is no packaged ' ...
         'Test File to open. Run st_run_standalone_coverage_pipeline(' ...
         '''Action'',''PACKAGE'',''PipelineId'',''%s'') first. Manifest=%s'], ...
        char(string(manifest.PipelineId)), ...
        char(string(manifest.PipelineId)), manifestPath);
end
if ~isfield(manifest, 'Targets') || isempty(manifest.Targets)
    error('simtest:StandaloneTestManagerTargetsMissing', ...
        'Pipeline manifest has no packaged targets: %s', manifestPath);
end
end

function testFile = load_test_file(testFilePath, cfg)
%LOAD_TEST_FILE Reuse the packaged Test File if it is already open.
%
% Test Manager identifies Test Files by name, and the packaged file shares
% its name with the working copy the pipeline ran. A same-named file from a
% different path cannot be opened beside it, so fail with a clear action.
[~, wantedName, wantedExtension] = fileparts(testFilePath);
open = sltest.testmanager.getTestFiles;
for k = 1:numel(open)
    openPath = char(string(open(k).FilePath));
    if st_same_path(openPath, testFilePath)
        st_log(cfg, 'INFO', ...
            'Packaged Test File already open | File=%s', testFilePath);
        testFile = open(k);
        return;
    end
    [~, openName, openExtension] = fileparts(openPath);
    if strcmpi([openName openExtension], [wantedName wantedExtension])
        error('simtest:StandaloneTestManagerFileNameConflict', ...
            ['A Test File named %s is already open from another path. ' ...
             'Close it, or call st_open_standalone_test_manager(' ...
             '''ClearTestManager'', true). Open=%s | Packaged=%s'], ...
            [wantedName wantedExtension], openPath, testFilePath);
    end
end
st_log(cfg, 'INFO', ...
    'Packaged Test File load start | File=%s', testFilePath);
testFile = sltest.testmanager.load(testFilePath);
st_log(cfg, 'INFO', ...
    'Packaged Test File load complete | File=%s', testFilePath);
end

function [status, rootCount, resultFile] = import_saved_result( ...
        manifest, wanted, cfg)
%IMPORT_SAVED_RESULT Bring the saved aggregate Result back into Test Manager.
rootCount = 0;
resultFile = field_text(manifest, 'ResultFile');
if ~wanted
    status = 'SKIPPED';
    st_log(cfg, 'INFO', 'Saved Result import skipped by option');
    return;
end
if isempty(resultFile)
    status = 'NOT_SAVED';
    st_log(cfg, 'INFO', ...
        ['Saved Result import skipped | The pipeline kept no aggregate ' ...
         'Result (SaveTestResult=false)']);
    return;
end
if ~isfile(resultFile)
    status = 'MISSING';
    st_log(cfg, 'WARN', ...
        'Saved Result file is missing | File=%s', resultFile);
    return;
end
expectedHash = field_text(manifest, 'ResultSHA256');
if ~isempty(expectedHash)
    actualHash = st_file_signature(resultFile).SHA256;
    if ~strcmpi(actualHash, expectedHash)
        status = 'CHECKSUM_MISMATCH';
        st_log(cfg, 'WARN', ...
            ['Saved Result import skipped | Checksum differs from the ' ...
             'manifest | File=%s | Expected=%s | Actual=%s'], ...
            resultFile, expectedHash, actualHash);
        return;
    end
end
st_log(cfg, 'INFO', 'Saved Result import start | File=%s', resultFile);
imported = sltest.testmanager.importResults(resultFile);
rootCount = numel(imported);
status = 'IMPORTED';
st_log(cfg, 'INFO', ...
    'Saved Result import complete | Roots=%d', rootCount);
end

function text = result_summary_text(status, rootCount)
switch status
    case 'IMPORTED'
        text = sprintf('%d result set(s) imported', rootCount);
    case 'NOT_SAVED'
        text = 'none saved (SaveTestResult=false); Test File only';
    case 'SKIPPED'
        text = 'import skipped (ImportResults=false)';
    case 'MISSING'
        text = 'saved Result file is missing; Test File only';
    case 'CHECKSUM_MISMATCH'
        text = 'saved Result changed since packaging; not imported';
    otherwise
        text = status;
end
end

function tf = filter_readback_matches(expected, actual)
% CoverageSettings may return a canonical full path or just the CVF name.
actual = string(actual(:));
actual(ismissing(actual)) = "";
actual = actual(strlength(actual) > 0);
if isempty(actual)
    tf = false;
    return;
end
if any(strcmpi(actual, string(expected)))
    tf = true;
    return;
end
[~, expectedName, expectedExtension] = fileparts(expected);
expectedKey = string([expectedName lower(expectedExtension)]);
actualKeys = strings(size(actual));
for i = 1:numel(actual)
    [~, actualName, actualExtension] = fileparts(char(actual(i)));
    actualKeys(i) = string([actualName lower(actualExtension)]);
end
tf = any(strcmpi(actualKeys, expectedKey));
end

function value = field_text(data, name)
value = '';
if isstruct(data) && isfield(data, name)
    raw = data.(name);
    if ~isempty(raw)
        value = strtrim(char(string(raw)));
    end
end
end
