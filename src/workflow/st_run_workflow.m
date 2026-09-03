function [resultObj, updateResult, workflowResult, reportInfo] = ...
    st_run_workflow(workflowKind, varargin)
%ST_RUN_WORKFLOW Execute the shared incremental preparation pipeline.

cfg = st_require_runtime_target();
options = st_parse_workflow_options(varargin{:});
T = st_load_targets(cfg.OnlyEnabled);
systemUnderTestMode = options.SystemUnderTestMode;
if isempty(systemUnderTestMode)
    systemUnderTestMode = cfg.SystemUnderTestMode;
end
systemUnderTestMode = st_resolve_system_under_test_mode( ...
    systemUnderTestMode);
requestedExecutionMode = options.ExecutionMode;
if isempty(requestedExecutionMode)
    requestedExecutionMode = cfg.ExecutionMode;
end
executionMode = st_resolve_execution_mode( ...
    requestedExecutionMode, T, systemUnderTestMode);
% Pass the resolved policy into fingerprint/artifact planning. AUTO itself
% is not sufficient to decide whether a shared CVF should exist.
cfg.ExecutionMode = executionMode;
cfg.SystemUnderTestMode = systemUnderTestMode;
[plan, state, context] = ...
    st_build_execution_plan(T, cfg, workflowKind, options);

state = st_invalidate_workflow_state(state, plan);
state.Artifacts.Model = context.ModelSignature;
state.Artifacts.TestFile = context.TestFileSignature;
st_save_workflow_state(state, cfg);
st_write_result('WorkflowPlanResult', plan);

resultObj = [];
updateResult = table();
workflowResult = table();
reportInfo = struct();
runContext = struct();
totalTimer = tic;

fprintf('\n============================================\n');
fprintf('Incremental Simulink Test Automation\n');
fprintf('Workflow : %s\n', upper(char(string(workflowKind))));
fprintf('Model    : %s\n', cfg.TopModel);
fprintf('State    : %s\n', context.StateLoadStatus);
fprintf('Execute  : %s\n', executionMode);
fprintf('SUT Mode : %s\n', systemUnderTestMode);
fprintf('Start    : %s\n', timestamp_text());
fprintf('============================================\n');
print_plan(plan);

if strcmpi(workflowKind, 'FULL')
    validationResult = execute_timed_step( ...
        'Pre-Validate CUT Paths', @() st_pre_validate_targets());
    require_success(validationResult, ...
        'Pre-Validation failed. Check PreValidationResult.');

    harnessResult = execute_timed_step( ...
        'Create Harnesses', @() st_create_harnesses( ...
        st_stage_selection(plan, 'HARNESS')));
    state = st_checkpoint_workflow_state( ...
        state, plan, 'HARNESS', harnessResult, cfg);
    require_success(harnessResult, ...
        'Harness creation failed. Check HarnessCreateResult.');

    createdRows = strcmpi(string(harnessResult.Status), 'OK');
    if any(createdRows)
        plan = st_force_plan_downstream(plan, createdRows, 'SLDV', ...
            'Harness was created in this run');
        state = st_invalidate_workflow_state(state, plan);
        st_save_workflow_state(state, cfg);
        st_write_result('WorkflowPlanResult', plan);
    end
else
    validationResult = execute_timed_step( ...
        'Validate CUT / Harness Mapping', @() st_validate_targets());
    require_success(validationResult, ...
        'Validation failed. Check ValidationResult.');
end

stageNames = {'SLDV','HARNESS_CONFIG','SIGNAL_EDITOR', ...
    'ASSESSMENT','COVERAGE_FILTER','TEST_MANAGER','ALIGNMENT'};
stageLabels = {'Prepare SLDV Data','Configure Harnesses', ...
    'Configure Signal Editor','Configure Test Assessment', ...
    'Prepare Coverage Filters','Create Test Manager', ...
    'Validate Scenario Alignment'};
stageFunctions = { ...
    @st_prepare_sldv_targets, @st_configure_harnesses, ...
    @st_configure_signal_editors, @st_configure_assessments, ...
    @st_prepare_coverage_filters, @st_create_test_manager, ...
    @st_validate_scenario_alignment};

stageResults = cell(numel(stageNames),1);
for s = 1:numel(stageNames)
    stage = stageNames{s};
    selection = st_stage_selection(plan, stage);
    fn = stageFunctions{s};
    if strcmp(systemUnderTestMode, 'EXPORTED_MODEL') && ...
            ismember(stage, {'COVERAGE_FILTER','TEST_MANAGER','ALIGNMENT'})
        fn = @(value) st_defer_standalone_execution_stage(value, stage);
    elseif strcmp(executionMode, 'PER_CUT') && ...
            strcmp(stage, 'COVERAGE_FILTER')
        fn = @st_defer_coverage_filters_to_per_cut;
    elseif strcmp(executionMode, 'PER_CUT') && ...
            strcmp(stage, 'TEST_MANAGER')
        fn = @(value) st_create_test_manager( ...
            value, 'DeferCoverageFilters', true);
    end
    stageResults{s} = execute_timed_step( ...
        stageLabels{s}, @() fn(selection));
    state = st_checkpoint_workflow_state( ...
        state, plan, stage, stageResults{s}, cfg);
    require_success(stageResults{s}, sprintf( ...
        '%s failed. Check the stage result report.', stageLabels{s}));
end

if cfg.RunGeneratedTests
    if strcmp(executionMode, 'PER_CUT')
        continueOnFailure = option_or_default( ...
            options.ContinueOnFailure, cfg.PerCutContinueOnFailure);
        failOnNonPass = option_or_default( ...
            options.FailOnNonPass, cfg.PerCutFailOnNonPass);
        reportMode = options.ReportMode;
        if isempty(reportMode)
            reportMode = cfg.PerCutReportMode;
        end
        [resultObj, updateResult, reportInfo] = execute_timed_step( ...
            'Run Generated Tests Per CUT', ...
            @() st_run_tests_per_cut( ...
                'SystemUnderTestMode', systemUnderTestMode, ...
                'ContinueOnFailure', continueOnFailure, ...
                'ReportMode', reportMode, ...
                'FailOnNonPass', failOnNonPass));
    else
        [resultObj, updateResult, runContext] = execute_timed_step( ...
            'Run Generated Tests', @() st_run_generated_tests());
    end
else
    fprintf('\nRun Generated Tests: SKIP (cfg.RunGeneratedTests=false)\n');
end

state.Artifacts.Model = st_file_signature(cfg.ModelFile);
state.Artifacts.TestFile = st_file_signature(cfg.TestFile);
st_save_workflow_state(state, cfg);

Stage = string(stageLabels(:));
RunCount = zeros(numel(stageNames),1);
CachedCount = zeros(numel(stageNames),1);
FailCount = zeros(numel(stageNames),1);
for s = 1:numel(stageNames)
    RunCount(s) = sum(plan.(sprintf('Run%s', stageNames{s})));
    CachedCount(s) = height(plan) - RunCount(s);
    FailCount(s) = sum(strcmpi(string(stageResults{s}.Status), 'FAIL'));
end
workflowResult = table(Stage, RunCount, CachedCount, FailCount);
st_write_result('WorkflowResult', workflowResult);

if cfg.RunGeneratedTests && strcmp(executionMode, 'PER_CUT')
    % st_run_tests_per_cut writes its report before each filter is restored.
elseif cfg.RunGeneratedTests && cfg.GenerateTestReport
    reportInfo = execute_timed_step( ...
        'Generate Integrated Test Report', ...
        @() st_generate_test_report( ...
            runContext, workflowResult, plan));
elseif cfg.RunGeneratedTests
    fprintf(['\nGenerate Integrated Test Report: SKIP ' ...
        '(cfg.GenerateTestReport=false)\n']);
end

fprintf('\n============================================\n');
fprintf('Automation Complete\n');
fprintf('End     : %s\n', timestamp_text());
fprintf('Elapsed : %s\n', elapsed_text(toc(totalTimer)));
fprintf('============================================\n');
end

function value = option_or_default(value, defaultValue)
if isempty(value)
    value = defaultValue;
end
end

function varargout = execute_timed_step(label, fn)
fprintf('\n============================================\n');
fprintf('%s\nSTART : %s\n', label, timestamp_text());
fprintf('============================================\n');
timerValue = tic;
try
    [varargout{1:nargout}] = fn();
catch ME
    fprintf('FAILED  : %s\nELAPSED : %s\n', ...
        label, elapsed_text(toc(timerValue)));
    rethrow(ME);
end
fprintf('DONE    : %s\nELAPSED : %s\n', ...
    label, elapsed_text(toc(timerValue)));
end

function require_success(result, message)
if istable(result) && ismember('Status', result.Properties.VariableNames) && ...
        any(strcmpi(string(result.Status), 'FAIL'))
    error('simtest:WorkflowStageFailed', '%s', message);
end
end

function print_plan(plan)
stages = {'HARNESS','SLDV','HARNESS_CONFIG','SIGNAL_EDITOR', ...
    'ASSESSMENT','COVERAGE_FILTER','TEST_MANAGER','ALIGNMENT'};
for s = 1:numel(stages)
    runCount = sum(plan.(sprintf('Run%s', stages{s})));
    fprintf('%-16s RUN=%d CACHED=%d\n', stages{s}, ...
        runCount, height(plan) - runCount);
end
end

function text = timestamp_text()
text = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function text = elapsed_text(secondsValue)
hoursValue = floor(secondsValue / 3600);
minutesValue = floor(mod(secondsValue, 3600) / 60);
secondsPart = mod(secondsValue, 60);
text = sprintf('%02d:%02d:%06.3f', ...
    hoursValue, minutesValue, secondsPart);
end
