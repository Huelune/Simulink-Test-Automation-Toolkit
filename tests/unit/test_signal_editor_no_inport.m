function tests = test_signal_editor_no_inport
%TEST_SIGNAL_EDITOR_NO_INPORT Static contracts for OFF scenario binding.
tests = functiontests(localfunctions);
end

function testSignalEditorConfigurationDoesNotGateOnDirectInport(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'signal_editor', ...
    'st_configure_signal_editors.m'));
verifyFalse(testCase, contains(source, 'SKIP_NO_INPORT'));
verifyTrue(testCase, contains(source, 'SKIP_NO_SIGNAL_EDITOR'));
verifyTrue(testCase, contains(source, ...
    'simtest:SignalEditorBlockMissing'));
end

function testTestManagerBindsBySignalEditorAvailability(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'test_manager', ...
    'st_create_test_manager.m'));
verifyTrue(testCase, contains(source, ...
    'applySignalEditorScenario = SignalEditorAvailable(i)'));
verifyFalse(testCase, contains(source, ...
    'applySignalEditorScenario = hasDirectInport'));
verifyTrue(testCase, contains(source, "Action(i) = 'UPDATED_INPUT'"));
end

function testOffAlignmentIsNoLongerSkipped(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'test_manager', ...
    'st_validate_scenario_alignment.m'));
verifyFalse(testCase, contains(source, ...
    'OFF mode uses the legacy scenario workflow'));
verifyTrue(testCase, contains(source, ...
    "expectedIterationNames = {'Iteration 1'}"));
verifyTrue(testCase, contains(source, 'SignalEditorAvailable(i)'));
end

function testSpecificationUsesSignalEditorAvailabilityNotDirectInport(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'exporting', ...
    'st_collect_specification_target.m'));
verifyFalse(testCase, contains(source, ...
    "'BlockType', 'Inport'"));
verifyFalse(testCase, contains(source, 'if noInput'));
verifyTrue(testCase, contains(source, ...
    'signalEditorAvailable = true'));
verifyTrue(testCase, contains(source, ...
    'simtest:SignalEditorBlockMissing'));
verifyTrue(testCase, contains(source, 'SKIP_NO_SIGNAL_EDITOR'));
verifyTrue(testCase, contains(source, ...
    'linked(6) = "해당 없음"'));
end

function testMissingAndAmbiguousSignalEditorsHaveDistinctErrors(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'signal_editor', ...
    'st_find_signal_editor_block.m'));
verifyTrue(testCase, contains(source, ...
    'simtest:SignalEditorBlockMissing'));
verifyTrue(testCase, contains(source, ...
    'simtest:SignalEditorBlockAmbiguous'));
end
