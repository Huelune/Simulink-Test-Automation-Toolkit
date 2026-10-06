function tests = test_rename_test_file_models
%TEST_RENAME_TEST_FILE_MODELS Batch rename of Test Case Model names.
tests = functiontests(localfunctions);
end

function testRenamesHarnessModelsAndSavesInPlace(testCase)
assumeTrue(testCase, ~isempty(which('sltest.testmanager.TestFile')), ...
    'Simulink Test required.');
folder = tempname;
mkdir(folder);
addpath(folder);
testCase.addTeardown(@() remove_folder(folder));

% Real model files for every name, so the test does not depend on whether
% setProperty checks that the Model exists.
for name = ["StRenameA_B_C_D_E_Harness1", "StRenameX_Y_Harness12", ...
        "StRenamePlain", "StRenameTop_Harness1", "StRenameTop_Harness12", ...
        "StRenameTop_Harness2"]
    new_system(char(name));
    save_system(char(name), fullfile(folder, [char(name) '.slx']));
    close_system(char(name), 0);
end

fileName = fullfile(folder, 'st_rename_models.mldatx');
testCase.addTeardown(@() close_test_file(fileName));
tf = sltest.testmanager.TestFile(fileName);
outer = createTestSuite(tf, 'Outer');
inner = createTestSuite(outer, 'Inner');
setProperty(createTestCase(outer, 'simulation', 'CaseA'), ...
    'Model', 'StRenameA_B_C_D_E_Harness1');
setProperty(createTestCase(inner, 'simulation', 'CaseNested'), ...
    'Model', 'StRenameX_Y_Harness12');
setProperty(createTestCase(outer, 'simulation', 'CasePlain'), ...
    'Model', 'StRenamePlain');
setProperty(createTestCase(outer, 'simulation', 'CaseDone'), ...
    'Model', 'StRenameTop_Harness2');
saveToFile(tf);
close(tf);

changes = st_rename_test_file_models(fileName, 'StRenameTop');

verifyEqual(testCase, status_of(changes, 'CaseA'), "RENAMED");
verifyEqual(testCase, status_of(changes, 'CaseNested'), "RENAMED");
verifyEqual(testCase, status_of(changes, 'CasePlain'), "SKIPPED");
verifyEqual(testCase, status_of(changes, 'CaseDone'), "UNCHANGED");
verifyEqual(testCase, new_model_of(changes, 'CaseA'), "StRenameTop_Harness1");

% Read back from disk, not from the object the tool still holds.
close_test_file(fileName);
models = disk_models(fileName);
verifyEqual(testCase, models("CaseA"), "StRenameTop_Harness1");
verifyEqual(testCase, models("CaseNested"), "StRenameTop_Harness12");
verifyEqual(testCase, models("CasePlain"), "StRenamePlain");
verifyEqual(testCase, models("CaseDone"), "StRenameTop_Harness2");
end

function testRejectsMissingFileAndEmptyTopModel(testCase)
verifyError(testCase, @() st_rename_test_file_models( ...
    fullfile(tempdir, 'st_rename_missing.mldatx'), 'Top'), ...
    'simtest:RenameTestFileMissing');
existing = [mfilename('fullpath') '.m'];
verifyError(testCase, @() st_rename_test_file_models(existing, '  '), ...
    'simtest:RenameTopModelEmpty');
end

function value = status_of(changes, caseName)
value = changes.Status(endsWith(changes.TestCase, "> " + caseName));
end

function value = new_model_of(changes, caseName)
value = changes.NewModel(endsWith(changes.TestCase, "> " + caseName));
end

function models = disk_models(fileName)
tf = sltest.testmanager.load(fileName);
cleanup = onCleanup(@() close(tf));
models = containers.Map('KeyType', 'char', 'ValueType', 'any');
add_suites(models, getTestSuites(tf));
end

function add_suites(models, suites)
for s = 1:numel(suites)
    cases = getTestCases(suites(s));
    for k = 1:numel(cases)
        models(char(string(cases(k).Name))) = ...
            string(getProperty(cases(k), 'Model'));
    end
    add_suites(models, getTestSuites(suites(s)));
end
end

function close_test_file(fileName)
open = sltest.testmanager.getTestFiles;
for k = 1:numel(open)
    if strcmpi(char(string(open(k).FilePath)), fileName)
        close(open(k));
    end
end
end

function remove_folder(folder)
rmpath(folder);
if isfolder(folder)
    rmdir(folder, 's');
end
end
