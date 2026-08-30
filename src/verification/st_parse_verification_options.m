function options = st_parse_verification_options(varargin)
%ST_PARSE_VERIFICATION_OPTIONS Parse st_verify_all public options.

p = inputParser;
p.FunctionName = 'st_verify_all';
addParameter(p, 'Profile', 'QUICK', @(x) ischar(x) || isstring(x));
addParameter(p, 'Target', 'CURRENT', @(x) ischar(x) || isstring(x));
addParameter(p, 'ManualEvidence', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'KeepWorkspace', 'ON_FAILURE', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'FailOnNonPass', true, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

options = struct();
options.Profile = upper(strtrim(char(string(p.Results.Profile))));
options.Target = upper(strtrim(char(string(p.Results.Target))));
options.ManualEvidence = strtrim(char(string(p.Results.ManualEvidence)));
options.KeepWorkspace = ...
    upper(strtrim(char(string(p.Results.KeepWorkspace))));
options.FailOnNonPass = logical(p.Results.FailOnNonPass);

validate_value(options.Profile, {'QUICK','RUNTIME','CERTIFY'}, ...
    'simtest:InvalidVerificationProfile', 'Profile');
validate_value(options.Target, {'CURRENT','FIXTURE','BOTH'}, ...
    'simtest:InvalidVerificationTarget', 'Target');
validate_value(options.KeepWorkspace, {'ALWAYS','ON_FAILURE','NEVER'}, ...
    'simtest:InvalidVerificationWorkspacePolicy', 'KeepWorkspace');
end

function validate_value(value, allowed, identifier, label)
if ~ismember(value, allowed)
    error(identifier, '%s must be one of: %s.', ...
        label, strjoin(allowed, ', '));
end
end
