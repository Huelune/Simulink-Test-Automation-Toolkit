function info = st_open_standalone_test_manager(varargin)
%ST_OPEN_STANDALONE_TEST_MANAGER Open a standalone submission in Test Manager.
%
%   st_open_standalone_test_manager()                      % LATEST
%   st_open_standalone_test_manager('PipelineId', id)
%
% One command for the manual steps in docs/manual/open-results.md:
%
%   m = st_load_standalone_pipeline_manifest(root, pipelineId);
%   for k = 1:numel(m.Targets), addpath(m.Targets(k).OutputDirectory); end
%   sltest.testmanager.TestFile(m.TestManagerFile);
%   sltest.testmanager.view;
%
% By default it does exactly that: every packaged CUT folder goes on the
% MATLAB path so Test Manager can resolve each Test Case's standalone model,
% input MAT and CVF by name, then the packaged Test File is opened and the
% Test Manager window shown. Nothing is loaded, saved or changed on disk.
%
% Optional extras, all off by default:
%   'LoadModels'        - load_system every packaged standalone model first,
%                         so the CVF viewer resolves block names.
%   'ApplyFilters'      - re-apply each packaged CVF to its Test Case and
%                         verify the readback (what the packaged launcher does).
%   'ImportResults'     - import the saved aggregate Result when the pipeline
%                         kept one (SaveTestResult=true).
%   'ClearTestManager'  - close every Test File and Result already open in
%                         Test Manager first. Use it when a Test File of the
%                         same name is still loaded from the pipeline run.
%   'View'              - open the Test Manager window (default true).
%   'PipelineId'        - pipeline to open, or 'LATEST' (default).
%   'OutputRoot'        - pipeline root. Default cfg.StandaloneCoverageRootDir.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'PipelineId', 'LATEST', @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'LoadModels', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'ApplyFilters', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'ImportResults', false, @(x) islogical(x) && isscalar(x));
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

% 1. Every packaged CUT folder on the path. Test Manager resolves the
%    standalone model, its input MAT and the CVF beside it by name.
addedFolders = strings(0,1);
for k = 1:numel(targets)
    folder = field_text(targets(k), 'OutputDirectory');
    if isempty(folder) || ~isfolder(folder)
        error('simtest:StandaloneTestManagerTargetFolderMissing', ...
            'Packaged target folder is missing for target %d (%s): %s', ...
            k, field_text(targets(k), 'TestCaseName'), folder);
    end
    addpath(folder);
    addedFolders(end+1,1) = string(folder); %#ok<AGROW>
end
st_log(cfg, 'INFO', ...
    'Packaged target folders added to path | Folders=%d', numel(addedFolders));

% 2. Optional: load the standalone models themselves.
loadedModels = strings(0,1);
if p.Results.LoadModels
    loadedModels = load_standalone_models(targets, cfg);
end

% 3. Packaged Test File.
testFilePath = field_text(manifest, 'TestManagerFile');
if ~isfile(testFilePath)
    error('simtest:StandaloneTestManagerFileMissing', ...
        'Packaged Test File is missing: %s', testFilePath);
end
testFile = open_test_file(testFilePath, cfg);

% 4. Optional: re-apply the packaged CVFs.
appliedFilters = 0;
if p.Results.ApplyFilters
    appliedFilters = apply_packaged_filters(testFile, targets, testFilePath, cfg);
end

% 5. Optional: saved aggregate Result.
[resultStatus, resultRoots, resultFile] = import_saved_result( ...
    manifest, p.Results.ImportResults, cfg);

% 6. Window.
if p.Results.View
    sltest.testmanager.view;
end

info = struct( ...
    'PipelineId', pipelineId, ...
    'Manifest', manifestPath, ...
    'TestManagerFile', testFilePath, ...
    'TestFile', testFile, ...
    'AddedFolders', addedFolders, ...
    'LoadedModels', loadedModels, ...
    'AppliedFilterCount', appliedFilters, ...
    'ResultStatus', resultStatus, ...
    'ResultFile', resultFile, ...
    'ResultRootCount', resultRoots);

fprintf('\n');
fprintf('============================================\n');
fprintf('Standalone Test Manager opened\n');
fprintf('PipelineId : %s\n', pipelineId);
fprintf('Test File  : %s\n', testFilePath);
fprintf('Path       : %d target folder(s) added\n', numel(addedFolders));
if p.Results.LoadModels
    fprintf('Models     : %d loaded\n', numel(loadedModels));
end
if p.Results.ApplyFilters
    fprintf('CVF        : %d applied\n', appliedFilters);
end
if p.Results.ImportResults
    fprintf('Results    : %s\n', result_summary_text(resultStatus, resultRoots));
end
fprintf('============================================\n');
st_log(cfg, 'INFO', ...
    ['Standalone Test Manager open complete | PipelineId=%s | Folders=%d | ' ...
     'Models=%d | CVFs=%d | Results=%s | elapsed=%.3f sec'], ...
    pipelineId, numel(addedFolders), numel(loadedModels), appliedFilters, ...
    resultStatus, toc(timerValue));
end

function require_packaged(manifest, manifestPath)
%REQUIRE_PACKAGED The Test File and CUT folders exist only after PACKAGE.
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

function loadedModels = load_standalone_models(targets, cfg)
%LOAD_STANDALONE_MODELS Load every packaged model, refusing a same-named
% model from another path (the packaged launcher's isolation rule).
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
    [~, modelName] = fileparts(modelFile);
    if bdIsLoaded(modelName)
        loadedFile = char(string(get_param(modelName, 'FileName')));
        if ~st_same_path(loadedFile, modelFile)
            error('simtest:StandaloneTestManagerModelIsolationFailed', ...
                ['A different model is already loaded for %s. ' ...
                 'Close it first. Expected=%s | Actual=%s'], ...
                modelName, modelFile, loadedFile);
        end
    else
        st_log(cfg, 'DEBUG', ...
            'Standalone model load start | Model=%s | File=%s', ...
            modelName, modelFile);
        load_system(modelFile);
    end
    loadedModels(end+1,1) = string(modelName); %#ok<AGROW>
end
st_log(cfg, 'INFO', ...
    'Standalone models loaded | Models=%d | Targets=%d', ...
    numel(loadedModels), numel(targets));
end

function testFile = open_test_file(testFilePath, cfg)
%OPEN_TEST_FILE Reuse the packaged Test File if it is already open.
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
    'Packaged Test File open start | File=%s', testFilePath);
testFile = sltest.testmanager.TestFile(testFilePath);
st_log(cfg, 'INFO', ...
    'Packaged Test File open complete | File=%s', testFilePath);
end

function applied = apply_packaged_filters(testFile, targets, testFilePath, cfg)
%APPLY_PACKAGED_FILTERS Point each Test Case at the CVF packaged beside it.
testCases = getAllTestCases(testFile);
caseNames = strings(numel(testCases),1);
for k = 1:numel(testCases)
    caseNames(k) = string(testCases(k).Name);
end
applied = 0;
for k = 1:numel(targets)
    item = targets(k);
    testCaseName = string(field_text(item, 'TestCaseName'));
    filterFile = field_text(item, 'PackagedCVF');
    if isempty(filterFile)
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
    applied = applied + 1;
    st_log(cfg, 'DEBUG', ...
        'Coverage filter applied | TestCase=%s | Filter=%s', ...
        char(testCaseName), filterFile);
end
st_log(cfg, 'INFO', ...
    'Coverage filters applied | Applied=%d | Targets=%d', ...
    applied, numel(targets));
end

function [status, rootCount, resultFile] = import_saved_result( ...
        manifest, wanted, cfg)
%IMPORT_SAVED_RESULT Bring the saved aggregate Result back into Test Manager.
rootCount = 0;
resultFile = field_text(manifest, 'ResultFile');
if ~wanted
    status = 'SKIPPED';
    return;
end
if isempty(resultFile)
    status = 'NOT_SAVED';
    st_log(cfg, 'WARN', ...
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
        text = 'none saved (SaveTestResult=false)';
    case 'MISSING'
        text = 'saved Result file is missing';
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
