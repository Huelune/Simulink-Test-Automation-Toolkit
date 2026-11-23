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
    "RunPerTestCase", "View"]));
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
% docs/reference/standalone-coverage-pipeline.md (section 12): addpath every target OutputDirectory, open
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
for extra = ["LoadModels", "ApplyFilters", "ImportResults", "ClearTestManager", ...
        "RunPerTestCase"]
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

function testRunPerTestCaseSetsEachCvfRightBeforeItsRun(testCase)
% Test Cases share one coverage setting: setting every CVF first left the
% last one on all Test Cases, and results of the others filtered nothing.
% Each Test Case therefore gets its CVF immediately before its own run.
text = source();
verifyTrue(testCase, contains(text, 'if p.Results.RunPerTestCase'));
body = extractAfter(text, 'function summary = run_per_test_case(');
setAt = strfind(body, 'set_case_filter(');
runAt = strfind(body, 'resultSet = run(testCase);');
verifyNumElements(testCase, runAt, 1);
verifyNotEmpty(testCase, setAt);
verifyLessThan(testCase, setAt(1), runAt(1));
loopAt = strfind(body, 'for k = 1:n');
verifyNotEmpty(testCase, loopAt);
verifyLessThan(testCase, loopAt(1), setAt(1));
% ApplyFilters alone now reports the overwrite instead of passing silently.
verifyTrue(testCase, contains(text, 'Coverage filters overwrite each other'));
verifyTrue(testCase, contains(text, "'RunSummary', runSummary"));
end

function testLauncherRunsEachTestCaseRightAfterItsCvf(testCase)
% The packaged launcher had the same shared-setting problem: it set every
% CVF first, so the last one stayed on all Test Cases. It now sets one CVF
% and runs that Test Case inside the same loop iteration.
launcher = string(fileread(fullfile(st_project_root(), 'resources', ...
    'standalone_coverage', 'open_standalone_coverage_test_manager.m')));
loopAt = strfind(launcher, 'for k = 1:numel(targets)');
setAt = strfind(launcher, 'coverage.CoverageFilterFilename = filterFile;');
runAt = strfind(launcher, 'caseResult = run(testCases(matches));');
viewAt = strfind(launcher, 'sltest.testmanager.view;');
verifyNumElements(testCase, setAt, 1);
verifyNumElements(testCase, runAt, 1);
verifyNotEmpty(testCase, loopAt);
verifyLessThan(testCase, loopAt(end), setAt(1));
verifyLessThan(testCase, setAt(1), runAt(1));
verifyLessThan(testCase, runAt(1), viewAt(1));
% The run sits inside the same loop: the loop's own end (at column 0)
% comes after it. Inner if/try blocks end indented and do not count.
loopEndAt = regexp(launcher, '^end\s*$', 'lineanchors');
loopEndAt = loopEndAt(loopEndAt > setAt(1));
verifyNotEmpty(testCase, loopEndAt);
verifyLessThan(testCase, runAt(1), loopEndAt(1));
end

function testEachRunReadsItsOwnPackagedInput(testCase)
% Inputs are named by file name only. With every target folder and the
% project's inputs on the path, another same-named MAT came first and the
% re-run covered fewer decisions than the pipeline. Each run now puts its
% own folder first and refuses to run when the packaged input is shadowed.
text = source();
body = extractAfter(text, 'function summary = run_per_test_case(');
checkAt = strfind(body, 'require_own_input(targets(k), cfg);');
runAt = strfind(body, 'resultSet = run(testCase);');
verifyNumElements(testCase, checkAt, 1);
verifyLessThan(testCase, checkAt(1), runAt(1));
verifyTrue(testCase, contains(text, "addpath(folder, '-begin');"));
verifyTrue(testCase, contains(text, 'simtest:StandaloneTestManagerInputShadowed'));
% The current folder is searched before the path, so runs happen from an
% empty scratch folder and the previous folder comes back afterwards.
runFolderAt = strfind(body, 'previousFolder = cd(runFolder);');
verifyNotEmpty(testCase, runFolderAt);
verifyLessThan(testCase, runFolderAt(1), runAt(1));
verifyTrue(testCase, contains(body, 'onCleanup(@() cd(previousFolder))'));
launcher = string(fileread(fullfile(st_project_root(), 'resources', ...
    'standalone_coverage', 'open_standalone_coverage_test_manager.m')));
shadowAt = strfind(launcher, 'simtest:PackagedTestManagerInputShadowed');
launcherRunAt = strfind(launcher, 'caseResult = run(testCases(matches));');
verifyNumElements(testCase, shadowAt, 1);
verifyLessThan(testCase, shadowAt(1), launcherRunAt(1));
launcherFolderAt = strfind(launcher, 'previousFolder = cd(runFolder);');
verifyNumElements(testCase, launcherFolderAt, 1);
verifyLessThan(testCase, launcherFolderAt(1), launcherRunAt(1));
verifyEqual(testCase, numel(strfind(launcher, 'cd(previousFolder);')), 2);
end

function text = source()
text = string(fileread(fullfile(st_project_root(), 'src', 'pipeline', ...
    'st_open_standalone_test_manager.m')));
end
