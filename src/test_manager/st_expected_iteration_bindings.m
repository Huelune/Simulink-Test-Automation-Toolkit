function [names, bound] = st_expected_iteration_bindings(profile)
%ST_EXPECTED_ITERATION_BINDINGS Expected Iteration names and bound scenarios.
%   names{k} is the Test Manager Iteration name; bound{k} is the scenario
%   that Iteration must bind (Signal Editor and Test Sequence). Defect
%   Iterations have their own name but bind to their source scenario.

scenarios = cellstr(string(profile.ScenarioNames(:)));

if strcmp(profile.Mode, 'OFF')
    names = {'Iteration 1'};
    bound = scenarios(1);
    return;
end

names = scenarios;
bound = scenarios;
if isfield(profile, 'DefectIterations') && ~isempty(profile.DefectIterations)
    defects = profile.DefectIterations(:);
    for k = 1:numel(defects)
        names{end + 1, 1} = char(string(defects(k).Name)); %#ok<AGROW>
        bound{end + 1, 1} = char(string(defects(k).SourceScenario)); %#ok<AGROW>
    end
end
end
