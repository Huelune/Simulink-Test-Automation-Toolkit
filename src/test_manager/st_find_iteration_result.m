function index = st_find_iteration_result(iterations, scenarioName, allowFallback)
%ST_FIND_ITERATION_RESULT Index of the iteration result for a scenario name.
% Matches the iteration name first, so a defect iteration that binds another
% iteration's scenario is never taken for it; then the Test Sequence scenario
% binding, accepted only for default-named "Iteration N" results (OFF mode),
% so a named defect iteration is never taken; then, if allowed, the last such
% default-named iteration. Returns 0 when nothing matches.
index = 0;
target = string(scenarioName);
for i = 1:numel(iterations)
    if st_result_iteration_name(iterations(i), i) == target
        index = i;
        return;
    end
end
for i = 1:numel(iterations)
    if ~is_default_name(iterations(i), i)
        continue;
    end
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
if allowFallback
    for i = numel(iterations):-1:1
        if is_default_name(iterations(i), i)
            index = i;
            return;
        end
    end
end
end


function tf = is_default_name(iterResult, i)
tf = ~isempty(regexp(char(st_result_iteration_name(iterResult, i)), '^Iteration \d+$', 'once'));
end
