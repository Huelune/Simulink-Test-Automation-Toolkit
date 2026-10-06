function changes = st_rename_test_file_models(testFilePath, topModel)
%ST_RENAME_TEST_FILE_MODELS Rename every Test Case Model to <topModel>_Harness<N>.
%
%   changes = st_rename_test_file_models(testFilePath, topModel)
%
% Opens the Test File and, for every Test Case in every Test Suite (nested
% suites included), replaces the part of the Model name before
% "_Harness<N>" with topModel:
%
%   A_B_C_D_E_Harness1  ->  <topModel>_Harness1
%
% Only the Model value stored in the Test File changes. No model file is
% renamed, loaded or checked, and HarnessOwner/HarnessName stay as they are.
% Test Cases of different CUTs that share a harness number end up with the
% same Model name; that is not checked either.
%
% A Model that does not end in _Harness<N> is left alone with a WARN, and
% one that already has the new name is left alone silently. The Test File is
% saved in place when at least one Test Case changed, and stays open in
% Test Manager.
%
% changes has one row per Test Case:
%   TestCase  - "<Suite> > ... > <Test Case>"
%   OldModel, NewModel
%   Status    - RENAMED / UNCHANGED / SKIPPED

testFilePath = char(string(testFilePath));
topModel = strtrim(char(string(topModel)));
if ~isfile(testFilePath)
    error('simtest:RenameTestFileMissing', ...
        'Test File is missing: %s', testFilePath);
end
if isempty(topModel)
    error('simtest:RenameTopModelEmpty', 'Top model name is empty.');
end

cfg = st_config();
timerValue = tic;
st_log(cfg, 'INFO', ...
    'Test File model rename start | File=%s | TopModel=%s', ...
    testFilePath, topModel);

tf = sltest.testmanager.load(testFilePath);
[testCases, labels] = collect_test_cases(getTestSuites(tf), strings(0,1));
if isempty(testCases)
    st_log(cfg, 'WARN', 'Test File has no Test Case | File=%s', testFilePath);
end

n = numel(testCases);
TestCase = labels;
OldModel = strings(n,1);
NewModel = strings(n,1);
Status = strings(n,1);
for i = 1:n
    tc = testCases(i);
    oldName = char(string(getProperty(tc, 'Model')));
    OldModel(i) = string(oldName);
    NewModel(i) = string(oldName);
    tokens = regexp(oldName, '^.+(_Harness\d+)$', 'tokens', 'once');
    if isempty(tokens)
        Status(i) = "SKIPPED";
        st_log(cfg, 'WARN', ...
            'Model is not *_Harness<N>, left as is | TestCase=%s | Model=%s', ...
            TestCase(i), oldName);
        continue;
    end
    newName = [topModel tokens{1}];
    NewModel(i) = string(newName);
    if strcmp(oldName, newName)
        Status(i) = "UNCHANGED";
        continue;
    end
    setProperty(tc, 'Model', newName);
    actual = char(string(getProperty(tc, 'Model')));
    if ~strcmp(actual, newName)
        st_log(cfg, 'ERROR', ...
            ['Model readback failed, Test File not saved | TestCase=%s | ' ...
             'Expected=%s | Actual=%s'], TestCase(i), newName, actual);
        error('simtest:RenameReadbackFailed', ...
            'Model readback failed for %s. Expected=%s | Actual=%s', ...
            TestCase(i), newName, actual);
    end
    Status(i) = "RENAMED";
    st_log(cfg, 'DEBUG', 'Model renamed | TestCase=%s | Old=%s | New=%s', ...
        TestCase(i), oldName, newName);
end

renamed = nnz(Status == "RENAMED");
if renamed > 0
    try
        saveToFile(tf);
    catch ME
        st_log(cfg, 'ERROR', 'Test File save failed | File=%s | Error=%s', ...
            testFilePath, ME.message);
        rethrow(ME);
    end
end

changes = table(TestCase, OldModel, NewModel, Status);
disp(changes);
fprintf('Renamed %d, unchanged %d, skipped %d | %s\n', renamed, ...
    nnz(Status == "UNCHANGED"), nnz(Status == "SKIPPED"), testFilePath);
st_log(cfg, 'INFO', ...
    ['Test File model rename complete | File=%s | Renamed=%d | ' ...
     'Unchanged=%d | Skipped=%d | Saved=%d | elapsed=%.3f sec'], ...
    testFilePath, renamed, nnz(Status == "UNCHANGED"), ...
    nnz(Status == "SKIPPED"), renamed > 0, toc(timerValue));
end

function [testCases, labels] = collect_test_cases(suites, parentPath)
%COLLECT_TEST_CASES Every Test Case under suites, nested suites included.
testCases = [];
labels = strings(0,1);
for s = 1:numel(suites)
    suitePath = [parentPath; string(suites(s).Name)];
    cases = getTestCases(suites(s));
    for k = 1:numel(cases)
        testCases = [testCases; cases(k)]; %#ok<AGROW>
        labels(end+1,1) = strjoin([suitePath; string(cases(k).Name)], ' > '); %#ok<AGROW>
    end
    [nestedCases, nestedLabels] = collect_test_cases( ...
        getTestSuites(suites(s)), suitePath);
    for k = 1:numel(nestedCases)
        testCases = [testCases; nestedCases(k)]; %#ok<AGROW>
    end
    labels = [labels; nestedLabels]; %#ok<AGROW>
end
end
