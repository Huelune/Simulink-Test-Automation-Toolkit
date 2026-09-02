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

function testCoverageDescriptorMatchesExactHarnessOwner(testCase)
descriptors = coverage_descriptors( ...
    ["Top"; "HarnessRoot"; "Other"], ...
    ["Top"; "Top"; "Top"], ...
    [""; "Top/CUT_A"; "Top/CUT_B"], ...
    ["Top"; "HarnessA"; "HarnessB"]);

indices = st_match_coverage_descriptors(descriptors, 'Top/CUT_A');
verifyEqual(testCase, indices, 2);
end

function testCoverageDescriptorDoesNotCrossScanOwnerModel(testCase)
descriptors = coverage_descriptors( ...
    ["HarnessA"; "HarnessB"], ["Top"; "Top"], ...
    ["Top/CUT_A"; "Top/CUT_B"], ["HarnessA"; "HarnessB"]);

indices = st_match_coverage_descriptors(descriptors, 'Top/CUT_C');
verifyEmpty(testCase, indices);
end

function testCoverageDescriptorUsesRootThenTopModelFallback(testCase)
rootMatch = coverage_descriptors( ...
    "Top/CUT_A", "Top", "", "HarnessA");
verifyEqual(testCase, ...
    st_match_coverage_descriptors(rootMatch, 'Top/CUT_A'), 1);

modelMatch = coverage_descriptors("", "Top", "", "");
verifyEqual(testCase, ...
    st_match_coverage_descriptors(modelMatch, 'Top'), 1);
end

function testCoverageDescriptorPrefersAggregatedResult(testCase)
descriptors = coverage_descriptors( ...
    ["HarnessA"; "HarnessA"], ["Top"; "Top"], ...
    ["Top/CUT_A"; "Top/CUT_A"], ["HarnessA"; "HarnessA"]);
descriptors.DataType = ["TEST_DATA"; "DERIVED_DATA"];

verifyEqual(testCase, ...
    st_match_coverage_descriptors(descriptors, 'Top/CUT_A'), 2);
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
verifyEqual(testCase, cfg.CoverageFilterApplicationMode, 'RUNTIME');
verifyTrue(testCase, cfg.GenerateTestReport);
end

function descriptors = coverage_descriptors( ...
        Root, OwnerModel, OwnerBlock, AnalyzedModel)
descriptors = table(string(Root(:)), string(OwnerModel(:)), ...
    string(OwnerBlock(:)), string(AnalyzedModel(:)), ...
    'VariableNames', ...
    {'Root','OwnerModel','OwnerBlock','AnalyzedModel'});
end
