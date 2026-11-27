function tests = test_delete_harness_inputs
%TEST_DELETE_HARNESS_INPUTS Only the named Harnesses' input MATs are deleted.
tests = functiontests(localfunctions);
end

function testDeletesInputsAndPreparedSiblingsOnly(testCase)
folder = tempname;
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
other = tempname;
mkdir(other);
testCase.addTeardown(@() rmdir(other, 's'));
make(folder, 'Secret_H1_HarnessInputs.mat');
make(folder, 'Secret_H1_HarnessInputs_prepared.mat');
make(other, 'Secret_H2_HarnessInputs.mat');
make(folder, 'Secret_H3_HarnessInputs.mat');   % a Harness not named
make(folder, 'Secret_H1_data.mat');            % the workbook's own data file
% A folder given twice, and one that does not exist, change nothing.
[deleted, failed] = st_delete_harness_inputs(["Secret_H1"; "Secret_H2"; ""], ...
    {folder, other, folder, fullfile(folder, 'missing')});
verifyEqual(testCase, deleted, 3);
verifyEqual(testCase, failed, 0);
verifyFalse(testCase, isfile(fullfile(folder, 'Secret_H1_HarnessInputs.mat')));
verifyFalse(testCase, isfile(fullfile(folder, 'Secret_H1_HarnessInputs_prepared.mat')));
verifyFalse(testCase, isfile(fullfile(other, 'Secret_H2_HarnessInputs.mat')));
verifyTrue(testCase, isfile(fullfile(folder, 'Secret_H3_HarnessInputs.mat')));
verifyTrue(testCase, isfile(fullfile(folder, 'Secret_H1_data.mat')));
end

function make(folder, name)
value = 1; %#ok<NASGU>
save(fullfile(folder, name), 'value');
end
