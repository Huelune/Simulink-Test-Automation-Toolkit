function tests = test_standalone_coverage_pipeline
%TEST_STANDALONE_COVERAGE_PIPELINE Static contracts for staged execution.
tests = functiontests(localfunctions);
end

function testControllerExposesOnlyApprovedModes(testCase)
text = source('pipeline', 'st_run_standalone_coverage_pipeline.m');
verifyTrue(testCase, contains(text, ...
    "{'STEP1','STEP234','STEP5','STEP6','STEP2_TO_6'}"));
verifyTrue(testCase, contains(text, ...
    "'ExecutionModelMode', 'STANDALONE_HARNESS'"));
verifyTrue(testCase, contains(text, ...
    "'IncludeReferenceReport', false"));
verifyTrue(testCase, contains(text, ...
    "'ResultFilterMode', 'POST_RUN_REQUIRED'"));
verifyTrue(testCase, contains(text, ...
    "'ExecuteTests', false"));
verifyTrue(testCase, contains(text, ...
    "st_require_runtime_target('LoadModel', loadSourceModel)"));
verifyTrue(testCase, contains(text, ...
    "loadSourceModel = strcmp(runMode, 'STEP1')"));
verifyTrue(testCase, contains(text, ...
    "'HarnessInventory', {inventory}"));
runner = string(fileread(fullfile(st_project_root(), 'resources', ...
    'export_bundle', 'run_exported_tests.m')));
perCut = source('execution', 'st_run_tests_per_cut.m');
verifyTrue(testCase, contains(runner, 'remove_standalone_model_paths'));
verifyTrue(testCase, contains(runner, 'previousPath = path'));
verifyTrue(testCase, contains(runner, 'path(previousPath)'));
verifyFalse(testCase, contains(runner, 'rmpath(genpath(workRoot))'));
verifyTrue(testCase, contains(perCut, ...
    'register_execution_model_folder(row, cfg)'));
end

function testControllerRejectsMissingOrUnknownModeBeforeRuntime(testCase)
verifyError(testCase, @() st_run_standalone_coverage_pipeline(), ...
    'simtest:StandalonePipelineRunModeInvalid');
verifyError(testCase, @() st_run_standalone_coverage_pipeline( ...
    'RunMode', 'ALL'), 'simtest:StandalonePipelineRunModeInvalid');
end

function testStep234RequiresExactFilterPolicy(testCase)
text = source('pipeline', 'st_run_standalone_coverage_pipeline.m');
verifyTrue(testCase, contains(text, 'CoverageFilterMode'));
verifyTrue(testCase, contains(text, 'ALL_CONTENT'));
verifyTrue(testCase, contains(text, 'CoverageBoundaryMode'));
verifyTrue(testCase, contains(text, 'CUT_ONLY'));
verifyTrue(testCase, contains(text, 'CoverageFilterAction'));
verifyTrue(testCase, contains(text, 'EXCLUDE'));
verifyTrue(testCase, contains(text, 'CoverageFilterRationale'));
verifyTrue(testCase, contains(text, 'assert_source_unchanged'));
verifyTrue(testCase, contains(text, ...
    'StandalonePipelineRequiresFilterReplacement'));
verifyNotEmpty(testCase, regexp(text, ...
    "'CoverageFilterMode', '', 'CoverageBoundaryMode', ''", 'once'));
end

function testPipelineStateIsAtomicAndChecksumProtected(testCase)
writer = source('pipeline', ...
    'st_write_standalone_pipeline_manifest.m');
loader = source('pipeline', ...
    'st_load_standalone_pipeline_manifest.m');
verifyTrue(testCase, contains(writer, 'tempname(folder)'));
verifyTrue(testCase, contains(writer, "movefile(temporary, path, 'f')"));
verifyTrue(testCase, contains(writer, 'ManifestSHA256'));
verifyTrue(testCase, contains(loader, ...
    'StandalonePipelineManifestChecksumMismatch'));
end

function testStep234ExportDestinationSkipsExtraNesting(testCase)
% st_export_test_bundle already builds template/workspace/standalone/
% {CUTName} below its Destination. A project checked out under a deep
% path can push that combination past the Windows 260-character
% MAX_PATH limit, so STEP234 must not add its own extra "exports"
% segment on top of the pipeline's .work scratch folder.
text = source('pipeline', 'st_run_standalone_coverage_pipeline.m');
verifyTrue(testCase, contains(text, 'exportRoot = workRoot'));
verifyFalse(testCase, contains(text, "fullfile(workRoot, 'exports')"));
end


function testStep5PerformsRequiredResultRoundTrip(testCase)
text = source('pipeline', ...
    'st_package_standalone_coverage_artifacts.m');
verifyTrue(testCase, contains(text, ...
    'sltest.testmanager.importResults(rawResult)'));
verifyTrue(testCase, contains(text, ...
    'sltest.testmanager.exportResults(resultObj, filteredResult)'));
verifyTrue(testCase, contains(text, "'ReadOnly', true"));
verifyTrue(testCase, contains(text, 'cvsave(arguments{:})'));
verifyTrue(testCase, contains(text, ...
    'sltest.testmanager.report(roundtripResult, zipPath'));
verifyTrue(testCase, contains(text, 'unzip(zipPath, reportDirectory)'));
verifyTrue(testCase, contains(text, 'cvhtml('));
verifyTrue(testCase, contains(text, "sprintf('%03d_%s'"));
end

function testStep6UsesNAForMissingDenominator(testCase)
text = source('pipeline', ...
    'st_export_standalone_coverage_summary.m');
verifyTrue(testCase, contains(text, 'st_coverage_percentage'));
verifyTrue(testCase, contains(text, "'Decision %'"));
verifyTrue(testCase, contains(text, "'Execution %'"));
verifyTrue(testCase, contains(text, "'CoverageSummary.xlsx'"));
[percentage, percentageText] = st_coverage_percentage(0, 0);
verifyTrue(testCase, isnan(percentage));
verifyEqual(testCase, percentageText, "N/A");
end

function testResultFilterFlattensAllSupportedShapes(testCase)
helper = source('coverage', 'st_flatten_coverage_results.m');
filter = source('coverage', 'st_apply_result_coverage_filters.m');
verifyTrue(testCase, contains(helper, "isa(value, 'cvdata')"));
verifyTrue(testCase, contains(helper, "isa(value, 'cv.cvdatagroup')"));
verifyTrue(testCase, contains(helper, 'iscell(value)'));
verifyTrue(testCase, contains(filter, "'RequireCoverage', false"));
verifyTrue(testCase, contains(filter, "'ReadOnly', false"));
verifyTrue(testCase, contains(filter, "'RequireExactSet', false"));
verifyTrue(testCase, contains(filter, 'decisioninfo(cvd, coveragePath)'));
verifyTrue(testCase, contains(filter, 'executioninfo(cvd, coveragePath)'));
end

function text = source(folder, file)
text = string(fileread(fullfile(st_project_root(), 'src', folder, file)));
end
