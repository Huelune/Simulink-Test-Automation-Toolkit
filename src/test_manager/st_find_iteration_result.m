function index = st_find_iteration_result(iterations, scenarioName, allowFallback)
%ST_FIND_ITERATION_RESULT Index of the iteration result for a scenario name.
% Matches the iteration name first, so a defect iteration that binds another
% iteration's scenario is never taken for it; then the Test Sequence scenario
% binding (OFF mode names iterations "Iteration N"); then, if allowed, the
% last iteration. Returns 0 when nothing matches.
index = 0;
target = string(scenarioName);
for i = 1:numel(iterations)
    if st_result_iteration_name(iterations(i), i) == target
        index = i;
        return;
    end
end
for i = 1:numel(iterations)
    try
        scenario = iterations(i).TestSequenceScenario;
        if isstruct(scenario) && isfield(scenario, 'TestSequenceScenario') && ...
                string(scenario.TestSequenceScenario) == target
            index = i;
            return;
        end
    catch
    end
end
if allowFallback && ~isempty(iterations)
    index = numel(iterations);
end
end
