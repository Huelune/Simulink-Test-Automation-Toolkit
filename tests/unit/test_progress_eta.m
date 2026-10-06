function tests = test_progress_eta
tests = functiontests(localfunctions);
end


function testFirstTargetHasNoEstimate(testCase)
% Nothing has finished yet, so there is no pace to extrapolate from.
verifyEqual(testCase, st_progress_eta(0, 0, 298), 'elapsed=0.0s eta=--');
end


function testEstimateFollowsAveragePace(testCase)
% 80 targets took 40 minutes, so the 218 left take 30 seconds each.
verifyEqual(testCase, st_progress_eta(2400, 80, 298), ...
    'elapsed=40m00s eta=1h49m');
end


function testLastTargetStillCounted(testCase)
verifyEqual(testCase, st_progress_eta(100, 4, 5), ...
    'elapsed=1m40s eta=25.0s');
end


function testFinishedLoopHasNothingLeft(testCase)
verifyEqual(testCase, st_progress_eta(100, 5, 5), ...
    'elapsed=1m40s eta=0.0s');
end


function testElapsedTextUnits(testCase)
verifyEqual(testCase, st_log_elapsed_text(30.94), '30.9s');
verifyEqual(testCase, st_log_elapsed_text(758), '12m38s');
verifyEqual(testCase, st_log_elapsed_text(3720), '1h02m');
end


function testLongLoopsPrintTheEstimate(testCase)
% Every long per-target loop of the documented workflow reports it.
files = [ ...
    "src/harness/st_create_harnesses.m"
    "src/sldv/st_prepare_sldv_targets.m"
    "src/harness/st_configure_harnesses.m"
    "src/signal_editor/st_configure_signal_editors.m"
    "src/assessment/st_configure_assessments.m"
    "src/test_manager/st_create_test_manager.m"
    "src/execution/st_run_tests_per_cut.m"
    "src/execution/st_collect_per_cut_results.m"
    "src/exporting/st_export_standalone_harnesses.m"
    "src/execution/st_prepare_standalone_bundle_execution.m"
    "src/pipeline/st_package_standalone_coverage_artifacts.m"];
for k = 1:numel(files)
    text = fileread(fullfile(st_project_root(), files(k)));
    verifyTrue(testCase, contains(text, 'st_progress_eta('), files(k));
end
end
