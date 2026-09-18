function name = st_scenario_name(cutName, index)
%ST_SCENARIO_NAME Return UT_REQ_{CUTName}_{three-digit index}.
%
% A scenario name becomes a Test Sequence and Signal Editor identifier, so
% it has to be a valid MATLAB variable name. A CUT name is free text and
% breaks that contract in two independent ways: a character that cannot
% appear in an identifier, such as the '/' inside a block named
% 'Something_AC/DC_Check', and a name long enough to push the result past
% namelengthmax.
%
% A name that already fits is returned byte for byte as before, so existing
% scenarios, Harnesses and Test Files keep their identifiers. Only a name
% that Simulink would reject is rewritten:
%
%   1. Every character outside [A-Za-z0-9_] becomes '_'.
%   2. If that is still too long, the stem is cut to fit and a six-digit
%      digest of the original CUT name is appended, so two CUTs that shorten
%      to the same stem keep distinct scenarios.
%
% The digest is taken from the original name rather than the sanitized one,
% otherwise 'A/B' and 'A_B' would collide after step 1.
%
% Examples:
%   st_scenario_name('Controller', 1)
%       -> UT_REQ_Controller_001
%   st_scenario_name('OBC_Operating_State_..._AC/DC_Check', 1)
%       -> UT_REQ_OBC_Operating_State_..._AC_DC_C_3f9a2c_001

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

if isvarname(name)
    return;
end

name = fit_identifier(cutName, index);

if ~isvarname(name)
    error('Scenario name is not a valid MATLAB variable name: %s', name);
end

end


function name = fit_identifier(cutName, index)

sanitized = regexprep(cutName, '[^A-Za-z0-9_]', '_');
name = sprintf('UT_REQ_%s_%03d', sanitized, index);

if isvarname(name)
    return;
end

digest = st_hash_value(cutName);
digest = digest(1:6);

% 'UT_REQ_' + stem + '_' + digest + '_NNN' must fit the identifier limit.
budget = namelengthmax - numel('UT_REQ_') - 1 - numel(digest) - 4;
stem = sanitized(1:min(numel(sanitized), max(budget, 0)));

% A cut that lands on a separator would read as a stray underscore.
stem = regexprep(stem, '_+$', '');

name = sprintf('UT_REQ_%s_%s_%03d', stem, digest, index);

end
