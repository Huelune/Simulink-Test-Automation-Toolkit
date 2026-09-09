function [text, notes, maxTime, status] = ...
        st_specification_input_scenario(value, sldvMode)
%ST_SPECIFICATION_INPUT_SCENARIO Format one linked Signal Editor scenario.
% An empty Dataset is valid for an OFF target whose CUT has no inputs.

mode = upper(strtrim(string(sldvMode)));
if ~isscalar(mode)
    error('simtest:SpecificationInputMode', ...
        'SldvMode must be scalar when reading an input scenario.');
end

if mode == "OFF" && ...
        isa(value, 'Simulink.SimulationData.Dataset') && ...
        numElements(value) == 0
    text = "<입력 신호 없음>";
    notes = "";
    maxTime = NaN;
    status = "OK";
    return;
end

[text, notes, maxTime] = st_specification_input_lines(value);
status = "OK";
if contains(text, "<읽기 실패>")
    status = "FAIL";
end
end
