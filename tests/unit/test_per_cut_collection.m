function tests = test_per_cut_collection
%TEST_PER_CUT_COLLECTION PER_CUT runs alone; the CVF belongs to the results.
%
% PER_CUT exists because some Test Cases only work when run by themselves.
% A coverage filter shapes the coverage data of the artifacts built from a
% run, so it is the collect step's work, not the run's.
tests = functiontests(localfunctions);
end

function testDefaultDefersCollection(testCase)
cfg = st_config();
verifyEqual(testCase, cfg.PerCutResultCollection, 'DEFERRED');
end

function testInvalidModeIsRejected(testCase)
verifyError(testCase, @() st_run_tests_per_cut( ...
    'ResultCollection', 'LATER'), ...
    'simtest:InvalidPerCutResultCollection');
end

function testDeferredRunNeverFiltersDuringTheRun(testCase)
% Both run-time filter paths must be closed, otherwise the run would shape
% the coverage data the collect step is supposed to shape.
source = fileread(fullfile(st_project_root(), 'src', 'execution', ...
    'st_run_tests_per_cut.m'));
verifyNotEmpty(testCase, regexp(source, ...
    'if deferResults\s*\n\s*%[^\n]*\n\s*%[^\n]*\n\s*applyManagedFiltersDuringRun = false;', ...
    'once'));
verifyEqual(testCase, numel(regexp(source, ...
    '~deferResults && ~applyManagedFiltersDuringRun')), 2);
end

function testStandaloneBundleKeepsItsCoverageWorkInsideTheRun(testCase)
% The bundle's execution models are disposable. Nothing could reopen them
% later to attach a CVF, so that run cannot defer.
runner = fileread(fullfile(st_project_root(), 'resources', ...
    'export_bundle', 'run_exported_tests.m'));
verifyNotEmpty(testCase, regexp(runner, ...
    "'ResultCollection', 'INLINE'", 'once'));
end

function testCollectWithoutARunNamesWhatToDoFirst(testCase)
% The message has to say the tests must run first; a bare missing-file path
% leaves the operator guessing which command they skipped.
source = fileread(fullfile(st_project_root(), 'src', 'execution', ...
    'st_collect_per_cut_results.m'));
verifyNotEmpty(testCase, regexp(source, ...
    'simtest:CollectRunMissing', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'No PER_CUT run to collect. Run the tests first', 'once'));
end

function testDiagnosticAcceptsTheDeferredLifecycle(testCase)
% Apply and restore are about filtering a live model. A deferred run does
% neither, so NOT_REQUIRED must not read as a failure.
source = fileread(fullfile(st_project_root(), 'diagnostics', 'matlab', ...
    'st_check_per_cut_cvf.m'));
verifyNotEmpty(testCase, regexp(source, 'deferredToCollect', 'once'));
verifyNotEmpty(testCase, regexp(source, "'NOT_REQUIRED'", 'once'));
end
function testAutoCollectIsOffByDefault(testCase)
% Collecting reopens every model the saved coverage data points at. The
% caller asks for that; it does not happen because a run finished.
cfg = st_config();
verifyFalse(testCase, cfg.PerCutAutoCollect);
verifyEmpty(testCase, st_parse_workflow_options().AutoCollect);
end

function testAutoCollectIsAWorkflowOverride(testCase)
% One command that ends with the reports in place must be reachable
% without editing st_config.
options = st_parse_workflow_options('AutoCollect', true);
verifyTrue(testCase, options.AutoCollect);
verifyError(testCase, ...
    @() st_parse_workflow_options('AutoCollect', 'YES'), ...
    'MATLAB:InputParser:ArgumentFailedValidation');
end

function testWorkflowCollectsOnlyWhenAsked(testCase)
% Without the option the workflow must still stop after the run and name
% the command, because that is what makes a long run interruptible.
source = fileread(fullfile(st_project_root(), 'src', 'workflow', ...
    'st_run_workflow.m'));
verifyNotEmpty(testCase, regexp(source, ...
    'autoCollect = option_or_default\(\s*\.\.\.\s*options\.AutoCollect, cfg\.PerCutAutoCollect\);', ...
    'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'if autoCollect\s*\n\s*collectInfo = execute_timed_step\(''Collect PER_CUT Results''', ...
    'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'else\s*\n\s*fprintf\(\[''\nPER_CUT saved one ResultSet per CUT', 'once'));
end

function testAutoCollectOnlyAppliesToADeferredRun(testCase)
% An INLINE run built its artifacts already. Collecting it would find no
% saved ResultSet, so the option stays inside the DEFERRED branch.
source = fileread(fullfile(st_project_root(), 'src', 'workflow', ...
    'st_run_workflow.m'));
deferredBranch = regexp(source, ...
    'if strcmpi\(cfg\.PerCutResultCollection, ''DEFERRED''\).*?\n    end', ...
    'match', 'once');
verifyNotEmpty(testCase, deferredBranch);
verifyNotEmpty(testCase, regexp(deferredBranch, ...
    'st_collect_per_cut_results\(\)', 'once'));
verifyEqual(testCase, ...
    numel(regexp(source, 'st_collect_per_cut_results\(\)')), 1);
end

function testOnlyPassedIsOffByDefault(testCase)
% A failure report is evidence when nobody intends to rerun, so collecting
% everything stays the default; skipping is the operator's explicit choice.
source = fileread(fullfile(st_project_root(), 'src', 'execution', ...
    'st_collect_per_cut_results.m'));
verifyNotEmpty(testCase, regexp(source, ...
    "addParameter\(p, 'OnlyPassed', false,", 'once'));
end

function testOnlyPassedDecidesBeforeTheWorkbookLookup(testCase)
% A skipped target produces nothing, so it must not need its workbook row.
% The outcome check therefore sits ahead of the CollectTargetMissing lookup.
source = fileread(fullfile(st_project_root(), 'src', 'execution', ...
    'st_collect_per_cut_results.m'));
skipAt = regexp(source, 'if onlyPassed && outcome ~= "PASSED"', 'once');
lookupAt = regexp(source, 'simtest:CollectTargetMissing', 'once');
verifyNotEmpty(testCase, skipAt);
verifyNotEmpty(testCase, lookupAt);
verifyLessThan(testCase, skipAt, lookupAt);
end
