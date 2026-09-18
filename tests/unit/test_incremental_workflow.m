function tests = test_incremental_workflow
%TEST_INCREMENTAL_WORKFLOW Static/unit checks for incremental controls.
tests = functiontests(localfunctions);
end

function testConfigDefaults(testCase)
cfg = st_config();
verifyEqual(testCase, cfg.PreparationMode, 'AUTO');
verifyEqual(testCase, cfg.PreparationFromStage, 'START');
verifyTrue(testCase, endsWith(string(cfg.WorkflowStateFile), ...
    fullfile('result', 'state', 'workflow_state.mat')));
verifyTrue(testCase, endsWith(string(cfg.WorkflowStateSummaryFile), ...
    fullfile('result', 'state', 'workflow_state.json')));
verifyTrue(testCase, endsWith(string(cfg.CoverageFilterDir), ...
    fullfile('result', 'coverage_filters')));
verifyEqual(testCase, cfg.ExecutionMode, 'BATCH');
verifyTrue(testCase, cfg.PerCutContinueOnFailure);
verifyEqual(testCase, cfg.PerCutReportMode, 'SUMMARY');
verifyFalse(testCase, cfg.PerCutFailOnNonPass);
verifyTrue(testCase, endsWith(string(cfg.StandaloneCoverageRootDir), ...
    fullfile('result', 'standalone_coverage')));
end

function testWorkflowOptionOverrides(testCase)
options = st_parse_workflow_options( ...
    'PreparationMode', 'force', 'FromStage', 'assessment');
verifyEqual(testCase, options.PreparationMode, 'FORCE');
verifyEqual(testCase, options.FromStage, 'ASSESSMENT');
end

function testRemovedCoverageFilterStageIsRejected(testCase)
% Coverage filters lost their preparation stage; a restart aimed at it has
% to say where to go instead of silently starting somewhere else.
verifyError(testCase, @() st_parse_workflow_options( ...
    'FromStage', 'coverage_filter'), 'simtest:RemovedPreparationStage');
end

function testExecuteOnlySkipsEveryPreparationStage(testCase)
% FromStage=EXECUTE is the caller saying preparation is done. It must be
% accepted without StrictRestart, and the plan builder must leave no stage
% dirty regardless of the signatures.
options = st_parse_workflow_options('FromStage', 'execute');
verifyEqual(testCase, options.FromStage, 'EXECUTE');
verifyFalse(testCase, options.StrictRestart);

source = fileread(fullfile(st_project_root(), 'src', 'workflow', ...
    'st_build_execution_plan.m'));
verifyNotEmpty(testCase, regexp(source, ...
    'strcmp\(fromStage, ''EXECUTE''\)', 'once'));

% Running nothing and then not executing is a no-op, not a request.
verifyError(testCase, @() st_parse_workflow_options( ...
    'FromStage', 'EXECUTE', 'ExecuteTests', false), ...
    'simtest:ExecuteOnlyWithoutExecution');
end

function testPerCutWorkflowOptionOverrides(testCase)
options = st_parse_workflow_options( ...
    'ExecutionMode', 'per_cut', ...
    'ContinueOnFailure', false, ...
    'ReportMode', 'full', ...
    'FailOnNonPass', false, ...
    'ExecuteTests', false);
verifyEqual(testCase, options.ExecutionMode, 'PER_CUT');
verifyFalse(testCase, options.ContinueOnFailure);
verifyEqual(testCase, options.ReportMode, 'FULL');
verifyFalse(testCase, options.FailOnNonPass);
verifyFalse(testCase, options.ExecuteTests);
end

function testInvalidWorkflowOptionRejected(testCase)
verifyError(testCase, @() st_parse_workflow_options( ...
    'PreparationMode', 'DELETE'), 'simtest:InvalidPreparationMode');
verifyError(testCase, @() st_parse_workflow_options( ...
    'FromStage', 'REPORT'), 'simtest:InvalidPreparationFromStage');
verifyError(testCase, @() st_parse_workflow_options( ...
    'ExecutionMode', 'PARALLEL'), 'simtest:InvalidExecutionMode');
verifyError(testCase, @() st_parse_workflow_options( ...
    'ReportMode', 'PDF_ONLY'), 'simtest:InvalidPerCutReportMode');
end

function testDefaultStageSelectionRunsEveryRow(testCase)
T = table((1:3).', 'VariableNames', {'No'});
selection = st_normalize_stage_selection(T, []);
verifyEqual(testCase, selection.Run, true(3,1));
verifyEqual(testCase, selection.Action, repmat("RUN", 3, 1));
end

function testForcePlanPropagatesDownstream(testCase)
plan = table((1:2).', 'VariableNames', {'No'});
stages = {'HARNESS','SLDV','HARNESS_CONFIG','SIGNAL_EDITOR', ...
    'ASSESSMENT','TEST_MANAGER','ALIGNMENT'};
for i = 1:numel(stages)
    plan.(['Run' stages{i}]) = false(2,1);
    plan.(['Action' stages{i}]) = repmat("CACHED", 2, 1);
    plan.(['Reason' stages{i}]) = repmat("Checkpoint matches", 2, 1);
end

plan = st_force_plan_downstream( ...
    plan, [false; true], 'ASSESSMENT', 'test force');
verifyFalse(testCase, plan.RunSIGNAL_EDITOR(2));
verifyTrue(testCase, plan.RunASSESSMENT(2));
verifyTrue(testCase, plan.RunTEST_MANAGER(2));
verifyTrue(testCase, plan.RunALIGNMENT(2));
verifyEqual(testCase, plan.ReasonASSESSMENT(2), "test force");
end

function testWorkflowStateMissingAndCorruptFallback(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
cfg = struct( ...
    'WorkflowStateFile', fullfile(folder, 'state.mat'), ...
    'WorkflowStateSummaryFile', fullfile(folder, 'state.json'));

[state, status] = st_load_workflow_state(cfg);
verifyEqual(testCase, status, 'MISSING');
verifyEqual(testCase, state.Version, 1);

fileId = fopen(cfg.WorkflowStateFile, 'w');
fprintf(fileId, 'not a MAT file');
fclose(fileId);
[~, status] = st_load_workflow_state(cfg);
verifyEqual(testCase, status, 'CORRUPT');
end

function testStableHash(testCase)
one = st_hash_value(struct('A', 1, 'B', 'value'));
two = st_hash_value(struct('A', 1, 'B', 'value'));
three = st_hash_value(struct('A', 2, 'B', 'value'));
verifyEqual(testCase, one, two);
verifyNotEqual(testCase, one, three);
verifyEqual(testCase, strlength(string(one)), 64);
end

function testStageIndicesFollowTheStageList(testCase)
% The plan builder used to mark stages by position. Those literals were
% written for an eight-stage list and pointed at the wrong stages as soon as
% COVERAGE_FILTER was removed: a changed Test File stopped invalidating
% TEST_MANAGER and started writing past the end of the dirty vector.
source = fileread(fullfile(st_project_root(), 'src', 'workflow', ...
    'st_build_execution_plan.m'));

% dirty(1) is HARNESS and dirty(2:end) is "everything after it"; both hold
% whatever the list contains. A numeric range like dirty(7:8) does not.
verifyEmpty(testCase, regexp(source, 'dirty\(\d+:\d+\)', 'once'));
verifyEmpty(testCase, regexp(source, 'reasons\(\d+:\d+\)', 'once'));

% The same literals survived in the per-row matrices, which this check used
% to ignore: OverwriteTestFile watched column 7 and wrote 7:8, so it looked
% at ALIGNMENT and grew a phantom eighth column instead of forcing
% TEST_MANAGER. Stage columns are selected by name, never by number.
verifyEmpty(testCase, regexp(source, ...
    '(run|action|reason|signature)Values\(:,\s*\d', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'stages == "TEST_MANAGER" \| stages == "ALIGNMENT"', 'once'));
end
