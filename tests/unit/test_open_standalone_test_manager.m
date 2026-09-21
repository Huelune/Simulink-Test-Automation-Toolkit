function tests = test_open_standalone_test_manager
%TEST_OPEN_STANDALONE_TEST_MANAGER Rebuild-and-open command contracts.
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
    "ImportResults", "ClearTestManager", "View"]));
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

function testCommandRebuildsEverythingTheLauncherDoesAndImportsResults(testCase)
text = source();
launcher = string(fileread(fullfile(st_project_root(), 'resources', ...
    'standalone_coverage', 'open_standalone_coverage_test_manager.m')));
% Same rebuild steps as the packaged launcher, in the same order: models
% first so the Test Case SUT and CVF names resolve, then the Test File,
% then the filters, then the window.
modelAt = strfind(text, 'load_system(modelFile)');
testFileAt = strfind(text, 'testFile = load_test_file(testFilePath, cfg)');
filterAt = strfind(text, 'coverage.CoverageFilterFilename = filterFile');
resultAt = strfind(text, 'sltest.testmanager.importResults(resultFile)');
viewAt = strfind(text, 'sltest.testmanager.view');
verifyNotEmpty(testCase, modelAt);
verifyNotEmpty(testCase, testFileAt);
verifyNotEmpty(testCase, filterAt);
verifyNotEmpty(testCase, resultAt);
verifyNotEmpty(testCase, viewAt);
verifyTrue(testCase, contains(text, 'sltest.testmanager.load(testFilePath)'));
verifyLessThan(testCase, modelAt(1), testFileAt(1));
verifyLessThan(testCase, testFileAt(1), filterAt(1));
verifyLessThan(testCase, filterAt(1), viewAt(1));
verifyTrue(testCase, contains(text, ...
    'filter_readback_matches(filterFile, actual)'));
verifyTrue(testCase, contains(launcher, ...
    'filter_readback_matches(filterFile, actual)'));
% The saved Result is imported exactly once and only after its checksum
% still matches the manifest.
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
    'simtest:StandaloneTestManagerFileNameConflict'));
verifyTrue(testCase, contains(text, ...
    'simtest:StandaloneTestManagerModelIsolationFailed'));
verifyTrue(testCase, contains(text, 'sltest.testmanager.getTestFiles'));
% Clearing Test Manager is opt-in; the default must not discard whatever
% the user still has open.
verifyTrue(testCase, contains(text, ...
    "addParameter(p, 'ClearTestManager', false"));
clearAt = strfind(text, 'sltest.testmanager.clear;');
verifyNotEmpty(testCase, clearAt);
guardAt = strfind(text, 'if p.Results.ClearTestManager');
verifyNotEmpty(testCase, guardAt);
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
