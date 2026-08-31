function tests = test_integrated_reporting
%TEST_INTEGRATED_REPORTING Pure reporting and coverage aggregation tests.
tests = functiontests(localfunctions);
end

function testCoveragePercentageUsesNAForZeroDenominator(testCase)
[percentage, text] = st_coverage_percentage(0, 0);
verifyTrue(testCase, isnan(percentage));
verifyEqual(testCase, text, "N/A");

[percentage, text] = st_coverage_percentage(3, 4);
verifyEqual(testCase, percentage, 75);
verifyEqual(testCase, text, "75.00%");
end

function testCoverageAggregationExcludesChecksumMismatch(testCase)
CoverageRoot = ["CUT_A"; "CUT_A"; "CUT_B"; "CUT_B"; "CUT_C"];
Checksum = ["same"; "same"; "old"; "new"; "zero"];
Metric = repmat("Decision", 5, 1);
Covered = [3; 2; 1; 2; 0];
Total = [4; 3; 2; 2; 0];
Justified = [1; 0; 0; 0; 0];
rows = table(CoverageRoot, Checksum, Metric, Covered, Total, Justified);

summary = st_aggregate_coverage_rows(rows);
verifyEqual(testCase, summary.Covered, 3);
verifyEqual(testCase, summary.Total, 4);
verifyEqual(testCase, summary.Justified, 1);
verifyEqual(testCase, summary.Percentage, 75);
verifyEqual(testCase, summary.CompatibleCUTCount, 2);
verifyEqual(testCase, summary.IncompatibleCUTCount, 1);
verifyEqual(testCase, summary.Status, "PARTIAL_CHECKSUM_MISMATCH");
end

function testPartialArtifactStatusDoesNotDiscardBundle(testCase)
verifyEqual(testCase, st_report_status(["OK"; "SKIP"]), "OK");
verifyEqual(testCase, st_report_status(["OK"; "FAIL"]), "PARTIAL");
end

function testInitialAndFinalResultsAreLinked(testCase)
context = struct( ...
    'InitialResult', 1, ...
    'FinalResult', 2, ...
    'RerunPerformed', true, ...
    'ExpectedUpdateResult', table(), ...
    'StartedAt', 'start', ...
    'CompletedAt', 'finish');
info = st_report_run_context(context);
verifyEqual(testCase, info.InitialLabel, 'INITIAL');
verifyEqual(testCase, info.FinalLabel, 'FINAL');
verifyTrue(testCase, info.RerunPerformed);
end

function testReportConfigDefaults(testCase)
cfg = st_config();
verifyEqual(testCase, cfg.CoverageStructuralLevel, 'Decision');
verifyEqual(testCase, cfg.CoverageMetricSettings, 'dwe');
verifyFalse(testCase, cfg.CoverageIncludeReferencedModels);
verifyTrue(testCase, cfg.GenerateTestReport);
end
