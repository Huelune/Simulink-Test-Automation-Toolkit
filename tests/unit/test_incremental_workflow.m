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
verifyEqual(testCase, cfg.CoverageFilterApplicationMode, 'RUNTIME');
verifyTrue(testCase, endsWith(string(cfg.CoverageFilterDir), ...
    fullfile('result', 'coverage_filters')));
verifyEqual(testCase, cfg.ExecutionMode, 'AUTO');
verifyTrue(testCase, cfg.PerCutContinueOnFailure);
verifyEqual(testCase, cfg.PerCutReportMode, 'SUMMARY');
verifyTrue(testCase, cfg.PerCutFailOnNonPass);
end

function testWorkflowOptionOverrides(testCase)
options = st_parse_workflow_options( ...
    'PreparationMode', 'force', 'FromStage', 'assessment');
verifyEqual(testCase, options.PreparationMode, 'FORCE');
verifyEqual(testCase, options.FromStage, 'ASSESSMENT');
end

function testCoverageFilterStageOverride(testCase)
options = st_parse_workflow_options('FromStage', 'coverage_filter');
verifyEqual(testCase, options.FromStage, 'COVERAGE_FILTER');
end

function testPerCutWorkflowOptionOverrides(testCase)
options = st_parse_workflow_options( ...
    'ExecutionMode', 'per_cut', ...
    'ContinueOnFailure', false, ...
    'ReportMode', 'full', ...
    'FailOnNonPass', false);
verifyEqual(testCase, options.ExecutionMode, 'PER_CUT');
verifyFalse(testCase, options.ContinueOnFailure);
verifyEqual(testCase, options.ReportMode, 'FULL');
verifyFalse(testCase, options.FailOnNonPass);
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
    'ASSESSMENT','COVERAGE_FILTER','TEST_MANAGER','ALIGNMENT'};
for i = 1:numel(stages)
    plan.(['Run' stages{i}]) = false(2,1);
    plan.(['Action' stages{i}]) = repmat("CACHED", 2, 1);
    plan.(['Reason' stages{i}]) = repmat("Checkpoint matches", 2, 1);
end

plan = st_force_plan_downstream( ...
    plan, [false; true], 'ASSESSMENT', 'test force');
verifyFalse(testCase, plan.RunSIGNAL_EDITOR(2));
verifyTrue(testCase, plan.RunASSESSMENT(2));
verifyTrue(testCase, plan.RunCOVERAGE_FILTER(2));
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
