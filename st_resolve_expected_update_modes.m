function modes = st_resolve_expected_update_modes(rowModes, defaultMode)
%ST_RESOLVE_EXPECTED_UPDATE_MODES Resolve global and per-row update modes.
%
% Supported row values:
%   DEFAULT or blank -> use defaultMode
%   OFF              -> never update expected values
%   APPLY            -> update failed expected values

% Supported default values:
%   OFF, APPLY

% REVIEW is intentionally not accepted until a review/approval workflow is
% implemented. Rejecting unknown modes prevents accidental model changes.

defaultMode = upper(strtrim(string(defaultMode)));

if ~isscalar(defaultMode) || ...
        ~ismember(defaultMode, ["OFF", "APPLY"])
    error( ...
        'simtest:InvalidExpectedUpdateMode', ...
        'ExpectedUpdateMode default must be OFF or APPLY: %s', ...
        char(strjoin(defaultMode, ', ')));
end

modes = upper(strtrim(string(rowModes)));
modes(ismissing(modes) | strlength(modes) == 0) = "DEFAULT";

invalid = ~ismember(modes, ["DEFAULT", "OFF", "APPLY"]);

if any(invalid)
    values = unique(modes(invalid), 'stable');
    error( ...
        'simtest:InvalidExpectedUpdateMode', ...
        ['ExpectedUpdateMode must be DEFAULT, OFF, or APPLY. ' ...
         'Invalid values: %s'], ...
        char(strjoin(values, ', ')));
end

modes(modes == "DEFAULT") = defaultMode;
end
