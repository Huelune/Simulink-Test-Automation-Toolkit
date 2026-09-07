function [signalCount,sequenceCount] = st_validate_import_iterations(iterations,profile)
%ST_VALIDATE_IMPORT_ITERATIONS Exact bindings; arbitrary imported names may overlap.
expected = string(profile.ScenarioNames(:));
if ~isequal(string({iterations.Name}).',expected)
    error('simtest:ImportIterationOrder','Imported iteration names/order differ.');
end
signalCount = 0; sequenceCount = 0;
for i = 1:numel(iterations)
    if ~iterations(i).Enabled || ~isempty(iterations(i).Variables) || ...
            ~isempty(iterations(i).ModelParams)
        error('simtest:ImportIterationOverride','Imported iterations must be enabled without overrides.');
    end
    [input,note] = st_specification_parameter(iterations(i).TestParams, ...
        {'SignalEditorScenario','SignalBuilderGroup'});
    wanted = "";
    if profile.HasSignalEditor, wanted = string(profile.SignalScenarioNames{i}); end
    if input ~= wanted || strlength(note) > 0
        error('simtest:ImportIterationBinding','Imported Signal Editor binding differs: %s',expected(i));
    end
    [sequence,note] = st_specification_parameter(iterations(i).TestParams,{'TestSequenceScenario'});
    wanted = "";
    if profile.UsesScenarios, wanted = expected(i); end
    if sequence ~= wanted || strlength(note) > 0
        error('simtest:ImportIterationBinding','Imported Assessment binding differs: %s',expected(i));
    end
    signalCount = signalCount + profile.HasSignalEditor;
    sequenceCount = sequenceCount + profile.UsesScenarios;
end
end
