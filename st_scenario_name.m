function name = st_scenario_name(cutName, index)
%ST_SCENARIO_NAME Return UT_REQ_{CUTName}_{three-digit index}.

if nargin < 2
    index = 1;
end

index = double(index);
if ~isscalar(index) || ~isfinite(index) || index < 1 || ...
        index > 999 || mod(index,1) ~= 0
    error('Scenario index must be an integer in the range 1..999.');
end

cutName = char(strtrim(string(cutName)));
name = sprintf('UT_REQ_%s_%03d', cutName, index);

if ~isvarname(name)
    error('Scenario name is not a valid MATLAB variable name: %s', name);
end
end
