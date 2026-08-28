function st_run_after_harness()
%ST_RUN_AFTER_HARNESS Workflow when Harnesses already exist.
%
% Recommended preparation:
%   st_find_target_paths
%
% Workflow:
%   1. Validate CUT / Harness mapping
%   2. Prepare SLDV data
%   3. Configure Harnesses
%   4. Configure Signal Editor
%   5. Configure Test Assessment
%   6. Create Test Manager
%   7. Validate Scenario Alignment
%   8. Optionally run generated tests
%
% Progress output:
%   Every workflow step prints START / DONE / FAILED timestamps and elapsed
%   time. The complete workflow also prints total elapsed time.

cfg = st_require_runtime_target();

totalTimer = tic;

st_log(cfg, 'INFO', ...
    'VerboseLogging=%d', ...
    logical(cfg.VerboseLogging));

fprintf('\n');
fprintf('============================================\n');
fprintf('Existing-Harness Automation\n');
fprintf('Model : %s\n', cfg.TopModel);
fprintf('Start : %s\n', st_now_text());
fprintf('============================================\n');


R0 = st_execute_timed_step( ...
    1, 8, ...
    'Validate CUT / Harness Mapping', ...
    @() st_validate_targets());

if st_result_has_fail(R0)
    error('Validation failed. Check ValidationResult.');
end


R1 = st_execute_timed_step( ...
    2, 8, ...
    'Prepare SLDV Data', ...
    @() st_prepare_sldv_targets());

if st_result_has_fail(R1)
    error('SLDV preparation failed. Check SldvGenerationResult.');
end


R2 = st_execute_timed_step( ...
    3, 8, ...
    'Configure Harnesses', ...
    @() st_configure_harnesses());

if st_result_has_fail(R2)
    error('Harness configuration failed. Check HarnessConfigResult.');
end


R3 = st_execute_timed_step( ...
    4, 8, ...
    'Configure Signal Editor', ...
    @() st_configure_signal_editors());

if st_result_has_fail(R3)
    error('Signal Editor configuration failed. Check SignalEditorResult.');
end


R4 = st_execute_timed_step( ...
    5, 8, ...
    'Configure Test Assessment', ...
    @() st_configure_assessments());

if st_result_has_fail(R4)
    error('Test Assessment configuration failed. Check AssessmentResult.');
end


R5 = st_execute_timed_step( ...
    6, 8, ...
    'Create Test Manager', ...
    @() st_create_test_manager());

if st_result_has_fail(R5)
    error('Test Manager creation failed. Check TestManagerResult.');
end


R6 = st_execute_timed_step( ...
    7, 8, ...
    'Validate Scenario Alignment', ...
    @() st_validate_scenario_alignment());

if st_result_has_fail(R6)
    error( ...
        ['Scenario alignment validation failed. ' ...
         'Check ScenarioAlignmentResult.']);
end


if cfg.RunGeneratedTests

    st_execute_timed_step( ...
        8, 8, ...
        'Run Generated Tests', ...
        @() st_run_generated_tests());

else

    fprintf('\n');
    fprintf('============================================\n');
    fprintf('[8/8] Run Generated Tests\n');
    fprintf('SKIP  : %s\n', st_now_text());
    fprintf('Reason: cfg.RunGeneratedTests = false\n');
    fprintf('============================================\n');
end


fprintf('\n');
fprintf('============================================\n');
fprintf('Existing-Harness Automation Complete\n');
fprintf('End     : %s\n', st_now_text());
fprintf('Elapsed : %s\n', st_elapsed_text(toc(totalTimer)));
fprintf('============================================\n');

end


function R = ...
    st_execute_timed_step( ...
        stepNo, ...
        stepCount, ...
        label, ...
        fn)

fprintf('\n');
fprintf('============================================\n');
fprintf('[%d/%d] %s\n', ...
    stepNo, ...
    stepCount, ...
    label);
fprintf('START : %s\n', ...
    st_now_text());
fprintf('============================================\n');

timerValue = tic;

try

    R = ...
        fn();

catch ME

    elapsedSec = ...
        toc(timerValue);

    fprintf('\n');
    fprintf('--------------------------------------------\n');
    fprintf('[%d/%d] FAILED %s\n', ...
        stepNo, ...
        stepCount, ...
        label);
    fprintf('TIME    : %s\n', ...
        st_now_text());
    fprintf('ELAPSED : %s\n', ...
        st_elapsed_text(elapsedSec));
    fprintf('--------------------------------------------\n');

    rethrow(ME);
end

elapsedSec = ...
    toc(timerValue);

fprintf('\n');
fprintf('--------------------------------------------\n');
fprintf('[%d/%d] DONE %s\n', ...
    stepNo, ...
    stepCount, ...
    label);
fprintf('TIME    : %s\n', ...
    st_now_text());
fprintf('ELAPSED : %s\n', ...
    st_elapsed_text(elapsedSec));
fprintf('--------------------------------------------\n');

end


function text = st_now_text()

text = ...
    char( ...
        datetime( ...
            'now', ...
            'Format', ...
            'yyyy-MM-dd HH:mm:ss'));

end


function text = st_elapsed_text(secondsValue)

secondsValue = ...
    max( ...
        0, ...
        double(secondsValue));

hoursValue = ...
    floor(secondsValue / 3600);

minutesValue = ...
    floor(mod(secondsValue, 3600) / 60);

secondsPart = ...
    mod(secondsValue, 60);

text = ...
    sprintf( ...
        '%02d:%02d:%06.3f', ...
        hoursValue, ...
        minutesValue, ...
        secondsPart);

end


function tf = st_result_has_fail(R)

if isempty(R) || ...
        ~istable(R) || ...
        ~ismember('Status', R.Properties.VariableNames)

    tf = false;
    return;
end

tf = ...
    any(strcmp(R.Status, 'FAIL'));

end
