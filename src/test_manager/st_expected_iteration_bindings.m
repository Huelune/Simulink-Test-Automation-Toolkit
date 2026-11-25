function [names, bound] = st_expected_iteration_bindings(profile)
%ST_EXPECTED_ITERATION_BINDINGS Expected Iteration names and bound scenarios.
%   names{k} is the Test Manager Iteration name; bound{k} is the scenario
%   that Iteration must bind (Signal Editor and Test Sequence). Every
%   Iteration binds the scenario of its own name. Defect Iterations too:
%   st_get_sldv_profile appends their scenarios, copies of their source,
%   to ScenarioNames.

scenarios = cellstr(string(profile.ScenarioNames(:)));

if strcmp(profile.Mode, 'OFF')
    names = {'Iteration 1'};
    bound = scenarios(1);
    return;
end

names = scenarios;
bound = scenarios;
end
