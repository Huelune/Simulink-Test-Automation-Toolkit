% OPEN_STANDALONE_COVERAGE_TEST_MANAGER Open a packaged standalone test file.
%
% This script is packaged beside the MLDATX file. It resolves every
% standalone model and its colocated input before Test Manager refreshes the
% Model SUT properties, then applies each packaged CVF to the in-memory copy.

launcherDirectory = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(launcherDirectory);
manifestPath = fullfile(pipelineRoot, 'pipeline-manifest.json');
if ~isfile(manifestPath)
    error('simtest:PackagedTestManagerManifestMissing', ...
        'Pipeline manifest is missing: %s', manifestPath);
end

manifest = jsondecode(fileread(manifestPath));
if ~isfield(manifest, 'Targets') || isempty(manifest.Targets)
    error('simtest:PackagedTestManagerTargetsMissing', ...
        'Pipeline manifest has no packaged targets: %s', manifestPath);
end
targets = manifest.Targets;

for k = 1:numel(targets)
    modelFile = char(string(targets(k).PackagedStandaloneModel));
    if ~isfile(modelFile)
        error('simtest:PackagedTestManagerModelMissing', ...
            'Standalone model is missing for target %d: %s', k, modelFile);
    end
    addpath(fileparts(modelFile));
    [~, modelName] = fileparts(modelFile);
    if bdIsLoaded(modelName)
        loadedFile = char(string(get_param(modelName, 'FileName')));
        expectedFile = char(java.io.File(modelFile).getCanonicalPath());
        actualFile = char(java.io.File(loadedFile).getCanonicalPath());
        if ispc
            sameModel = strcmpi(expectedFile, actualFile);
        else
            sameModel = strcmp(expectedFile, actualFile);
        end
        if ~sameModel
            error('simtest:PackagedTestManagerModelIsolationFailed', ...
                ['A different model is already loaded for %s. ' ...
                 'Expected=%s | Actual=%s'], ...
                modelName, expectedFile, actualFile);
        end
    else
        load_system(modelFile);
    end
end

testFiles = dir(fullfile(launcherDirectory, '*.mldatx'));
if numel(testFiles) ~= 1
    error('simtest:PackagedTestManagerFileAmbiguous', ...
        'Expected exactly one MLDATX file in %s, found %d.', ...
        launcherDirectory, numel(testFiles));
end
testFilePath = fullfile(testFiles(1).folder, testFiles(1).name);
testFile = sltest.testmanager.load(testFilePath);
testCases = getAllTestCases(testFile);

for k = 1:numel(targets)
    testCaseName = string(targets(k).TestCaseName);
    matches = find(string({testCases.Name}) == testCaseName);
    if numel(matches) ~= 1
        error('simtest:PackagedTestManagerCaseMappingFailed', ...
            'Expected one Test Case named %s, found %d.', ...
            char(testCaseName), numel(matches));
    end
    filterFile = char(string(targets(k).PackagedCVF));
    if ~isfile(filterFile)
        error('simtest:PackagedTestManagerFilterMissing', ...
            'Packaged CVF is missing for %s: %s', ...
            char(testCaseName), filterFile);
    end
    coverage = getCoverageSettings(testCases(matches));
    coverage.CoverageFilterFilename = filterFile;
    actual = string(coverage.CoverageFilterFilename);
    if ~filter_readback_matches(filterFile, actual)
        error('simtest:PackagedTestManagerFilterReadbackFailed', ...
            ['Coverage filter readback failed for %s. ' ...
             'Expected=%s | Actual=%s'], ...
            char(testCaseName), filterFile, char(strjoin(actual, ' | ')));
    end
    fprintf('Coverage filter applied | TestCase=%s | Filter=%s\n', ...
        char(testCaseName), filterFile);
end

sltest.testmanager.view;
fprintf(['Standalone Test Manager loaded | TestFile=%s | ' ...
    'Models=%d | CVFs=%d\n'], testFilePath, numel(targets), numel(targets));

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
