function name = st_result_iteration_name(iterResult, index)
%ST_RESULT_ITERATION_NAME The name a Test Iteration result is keyed by.
% The Iterations sheet and the DecisionOutcomes sheet are both joined to a
% specification row by this name, so both derive it here: the result Name,
% then the Test Sequence scenario, then "Iteration N".
name = string(safe_property(iterResult, 'Name', ''));
if strlength(name) > 0
    return;
end
try
    scenario = iterResult.TestSequenceScenario;
    if isstruct(scenario) && isfield(scenario, 'TestSequenceScenario')
        name = string(scenario.TestSequenceScenario);
    end
catch
end
if strlength(name) == 0
    name = "Iteration " + string(index);
end
end

function value = safe_property(object, property, defaultValue)
try
    value = object.(property);
catch
    value = defaultValue;
end
end
