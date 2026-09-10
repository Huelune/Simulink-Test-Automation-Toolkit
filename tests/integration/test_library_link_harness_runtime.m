function tests = test_library_link_harness_runtime
%TEST_LIBRARY_LINK_HARNESS_RUNTIME R2025b linked-CUT regression fixture.
tests = functiontests(localfunctions);
end


function setup(testCase)
assumeTrue(testCase, ~isempty(which('sltest.harness.create')), ...
    'Simulink Test required.');
root = tempname;
mkdir(root);
testCase.TestData.Root = root;
testCase.TestData.OldFolder = pwd;
configSource = fileread(which('st_config'));
write_text(fullfile(root, 'st_config.m'), configSource);
write_text(fullfile(root, 'st_setup.m'), 'function st_setup; end');
write_text(fullfile(root, 'VERSION.txt'), 'library-link-runtime-fixture');
mkdir(fullfile(root, 'src'));
cd(root);
clear st_config st_setup;

[~, id] = fileparts(root);
library = matlab.lang.makeValidName(['st_link_lib_' id]);
model = matlab.lang.makeValidName(['st_link_model_' id]);
testCase.TestData.Models = {model, library};

new_system(library, 'Library');
set_param(library, 'Lock', 'off');
cut = [library '/CUT'];
add_block('built-in/SubSystem', cut);
add_block('simulink/Sources/In1', [cut '/u']);
add_block('simulink/Math Operations/Gain', [cut '/Gain']);
add_block('simulink/Sinks/Out1', [cut '/y']);
add_line(cut, 'u/1', 'Gain/1');
add_line(cut, 'Gain/1', 'y/1');
libraryFile = fullfile(root, [library '.slx']);
save_system(library, libraryFile);

new_system(model);
owner = [model '/CUT'];
add_block(cut, owner);
save_system(model, fullfile(root, [model '.slx']));

TopModel = model; %#ok<NASGU>
ModelFile = fullfile(root, [model '.slx']); %#ok<NASGU>
save(fullfile(root, 'runtime_target.mat'), 'TopModel', 'ModelFile');
T = table(1, "CUT", string(owner), "LinkedCUTHarness", ...
    "LinkedCUTCase", "OFF", "OFF", "OFF", ...
    'VariableNames', {'No','CUTName','CUTPath','HarnessName', ...
    'TestCaseName','SldvMode','ExpectedUpdateMode','CoverageFilterMode'});
writetable(T, fullfile(root, 'TestManagement.xlsx'), 'Sheet', 'Targets');
testCase.TestData.Owner = owner;
testCase.TestData.Before = st_cut_library_link_state(owner);
testCase.TestData.LibraryFile = libraryFile;
testCase.TestData.LibraryBytes = read_bytes(libraryFile);
end


function teardown(testCase)
if isfield(testCase.TestData, 'Models')
    for item = testCase.TestData.Models
        if bdIsLoaded(item{1})
            close_system(item{1}, 0);
        end
    end
end
if isfield(testCase.TestData, 'OldFolder')
    cd(testCase.TestData.OldFolder);
    clear st_config st_setup;
end
if isfield(testCase.TestData, 'Root') && ...
        isfolder(testCase.TestData.Root)
    rmdir(testCase.TestData.Root, 's');
end
end


function testHarnessCreationPreservesLibraryLink(testCase)
result = st_create_harnesses();
verifyEqual(testCase, string(result.Status), "OK");

owner = testCase.TestData.Owner;
before = testCase.TestData.Before;
after = st_cut_library_link_state(owner);
verifyTrue(testCase, before.IsLinked);
verifyEqual(testCase, after.StaticLinkStatus, before.StaticLinkStatus);
verifyEqual(testCase, after.ReferenceBlock, before.ReferenceBlock);

items = sltest.harness.find( ...
    owner, 'SearchDepth', 0, 'Name', 'LinkedCUTHarness');
verifyEqual(testCase, numel(items), 1);
verifyEqual(testCase, ...
    string(items(1).synchronizationMode), "SyncOnOpen");
verifyEqual(testCase, read_bytes(testCase.TestData.LibraryFile), ...
    testCase.TestData.LibraryBytes);
verifyEqual(testCase, string(get_param(bdroot(owner), 'Dirty')), "off");
verifyEqual(testCase, string(get_param(items(1).ownerFullPath, ...
    'StaticLinkStatus')), string(before.StaticLinkStatus));
end


function testExistingHarnessIsCorrectedWithoutBreakingLink(testCase)
result = st_create_harnesses();
verifyEqual(testCase, string(result.Status), "OK");

owner = testCase.TestData.Owner;
before = st_cut_library_link_state(owner);
sltest.harness.set(owner, 'LinkedCUTHarness', ...
    'SynchronizationMode', 'SyncOnOpenAndClose');
save_system(bdroot(owner));

cfg = st_config();
T = st_load_targets(cfg.OnlyEnabled);
protection = st_protect_linked_cut_harnesses(T, cfg);
verifyEqual(testCase, string(protection.Status), "OK");
verifyTrue(testCase, protection.Changed);

after = st_cut_library_link_state(owner);
verifyEqual(testCase, after.StaticLinkStatus, before.StaticLinkStatus);
verifyEqual(testCase, after.ReferenceBlock, before.ReferenceBlock);
items = sltest.harness.find( ...
    owner, 'SearchDepth', 0, 'Name', 'LinkedCUTHarness');
verifyEqual(testCase, ...
    string(items(1).synchronizationMode), "SyncOnOpen");
verifyEqual(testCase, read_bytes(testCase.TestData.LibraryFile), ...
    testCase.TestData.LibraryBytes);
verifyEqual(testCase, string(get_param(bdroot(owner), 'Dirty')), "off");
end


function write_text(path, value)
fileId = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '%s', value);
end


function value = read_bytes(path)
fileId = fopen(path, 'r');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
value = fread(fileId, Inf, '*uint8');
end
