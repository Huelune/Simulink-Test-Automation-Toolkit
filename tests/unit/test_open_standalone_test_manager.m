function tests = test_open_standalone_test_manager
%TEST_OPEN_STANDALONE_TEST_MANAGER Open-submission command contracts.
tests = functiontests(localfunctions);
end

function testCommandExistsWithSignature(testCase)
rootDir = st_project_root();
verifyTrue(testCase, isfile(fullfile(rootDir, 'src', 'pipeline', ...
    'st_open_standalone_test_manager.m')));
signatures = jsondecode(fileread(fullfile(rootDir, 'src', 'pipeline', ...
    'functionSignatures.json')));
verifyTrue(testCase, isfield(signatures, 'st_open_standalone_test_manager'));
names = string({signatures.st_open_standalone_test_manager.inputs.name});
verifyEqual(testCase, sort(names), sort(["PipelineId", "OutputRoot", ...
    "LoadModels", "ApplyFilters", "ImportResults", "ClearTestManager", ...
    "View"]));
end

function testCommandIsReadOnlyOnDisk(testCase)
% The checker's B6 counts every MLDATX and forbidden artifact under the
% pipeline root, and B9 hashes the original sources. Opening a submission
% must therefore load into the session only and never write a file.
text = source();
for forbidden = ["exportResults", "save_system", "saveToFile", ...
        "writetable", "writecell", "fopen", "copyfile", "movefile", ...
        "st_write_standalone_pipeline_manifest", "append_event"]
    verifyFalse(testCase, contains(text, forbidden), ...
        "Command must not call " + forbidden);
end
verifyTrue(testCase, contains(text, ...
    "st_require_runtime_target('LoadModel', false)"));
verifyFalse(testCase, contains(text, 'load_system(cfg.ModelFile)'));
end

function testDefaultMatchesTheManualSnippet(testCase)
% docs/manual/open-results.md: addpath every target OutputDirectory, open
% the packaged Test File with sltest.testmanager.TestFile, then view.
% Everything beyond that is opt-in.
text = source();
addpathAt = strfind(text, 'addpath(folder)');
openAt = strfind(text, 'testFile = open_test_file(testFilePath, cfg)');
viewAt = strfind(text, 'if p.Results.View');
verifyTrue(testCase, contains(text, 'sltest.testmanager.view;'));
verifyNotEmpty(testCase, addpathAt);
verifyNotEmpty(testCase, openAt);
verifyNotEmpty(testCase, viewAt);
verifyLessThan(testCase, addpathAt(1), openAt(1));
verifyLessThan(testCase, openAt(1), viewAt(1));
verifyTrue(testCase, contains(text, "field_text(targets(k), 'OutputDirectory')"));
verifyTrue(testCase, contains(text, 'sltest.testmanager.TestFile(testFilePath)'));
for extra = ["LoadModels", "ApplyFilters", "ImportResults", "ClearTestManager"]
    verifyTrue(testCase, contains(text, ...
        "addParameter(p, '" + extra + "', false"), ...
        extra + " must default to false");
end
verifyTrue(testCase, contains(text, "addParameter(p, 'View', true"));
% Each extra only runs behind its option.
verifyTrue(testCase, contains(text, 'if p.Results.LoadModels'));
verifyTrue(testCase, contains(text, 'if p.Results.ApplyFilters'));
verifyTrue(testCase, contains(text, 'if p.Results.ClearTestManager'));
end

function testOptionalExtrasMirrorTheLauncher(testCase)
text = source();
launcher = string(fileread(fullfile(st_project_root(), 'resources', ...
    'standalone_coverage', 'open_standalone_coverage_test_manager.m')));
verifyTrue(testCase, contains(text, 'load_system(modelFile)'));
verifyTrue(testCase, contains(text, ...
    'coverage.CoverageFilterFilename = filterFile'));
verifyTrue(testCase, contains(text, ...
    'filter_readback_matches(filterFile, actual)'));
verifyTrue(testCase, contains(launcher, ...
    'filter_readback_matches(filterFile, actual)'));
% The saved Result is imported exactly once and only after its checksum
% still matches the manifest.
resultAt = strfind(text, 'sltest.testmanager.importResults(resultFile)');
verifyEqual(testCase, numel(resultAt), 1);
verifyTrue(testCase, contains(text, "'ResultSHA256'"));
verifyTrue(testCase, contains(text, 'CHECKSUM_MISMATCH'));
verifyTrue(testCase, contains(text, 'NOT_SAVED'));
end

function testCommandRefusesUnpackagedPipelineAndNameConflicts(testCase)
text = source();
verifyTrue(testCase, contains(text, ...
    'simtest:StandaloneTestManagerNotPackaged'));
verifyTrue(testCase, contains(text, ...
    'simtest:StandaloneTestManagerTargetFolderMissing'));
verifyTrue(testCase, contains(text, ...
    'simtest:StandaloneTestManagerFileNameConflict'));
verifyTrue(testCase, contains(text, ...
    'simtest:StandaloneTestManagerModelIsolationFailed'));
verifyTrue(testCase, contains(text, 'sltest.testmanager.getTestFiles'));
clearAt = strfind(text, 'sltest.testmanager.clear;');
verifyNotEmpty(testCase, clearAt);
guardAt = strfind(text, 'if p.Results.ClearTestManager');
verifyLessThan(testCase, guardAt(1), clearAt(1));
end

function testCommandEmitsLifecycleLogs(testCase)
text = source();
verifyTrue(testCase, contains(text, 'Standalone Test Manager open start'));
verifyTrue(testCase, contains(text, ...
    'Standalone Test Manager open complete'));
verifyTrue(testCase, contains(text, "st_log(cfg, 'WARN'"));
end

function text = source()
text = string(fileread(fullfile(st_project_root(), 'src', 'pipeline', ...
    'st_open_standalone_test_manager.m')));
end
