function [mode, action, rationale] = ...
    st_resolve_coverage_filter_settings(mode, action, rationale)
%ST_RESOLVE_COVERAGE_FILTER_SETTINGS Normalize Targets coverage options.

mode = upper(strtrim(string(mode(:))));
action = upper(strtrim(string(action(:))));
rationale = strtrim(string(rationale(:)));

if numel(action) ~= numel(mode) || numel(rationale) ~= numel(mode)
    error('simtest:InvalidCoverageFilterSettings', ...
        'Coverage filter option columns must have the same row count.');
end

mode(ismissing(mode) | strlength(mode) == 0) = "OFF";
action(ismissing(action)) = "";
rationale(ismissing(rationale)) = "";

validModes = ["OFF", "SUBSYSTEM", "ALL_CONTENT"];
invalidModes = ~ismember(mode, validModes);
if any(invalidModes)
    error('simtest:InvalidCoverageFilterMode', ...
        'CoverageFilterMode must be OFF, SUBSYSTEM, or ALL_CONTENT: %s', ...
        char(strjoin(unique(mode(invalidModes)), ', ')));
end

active = mode ~= "OFF";
validActions = ["EXCLUDE", "JUSTIFY"];
invalidActions = active & ~ismember(action, validActions);
if any(invalidActions)
    error('simtest:InvalidCoverageFilterAction', ...
        ['CoverageFilterAction must be EXCLUDE or JUSTIFY when ' ...
         'CoverageFilterMode is active. Invalid: %s'], ...
        char(strjoin(unique(action(invalidActions)), ', ')));
end

missingRationale = active & strlength(rationale) == 0;
if any(missingRationale)
    error('simtest:MissingCoverageFilterRationale', ...
        ['CoverageFilterRationale is required when ' ...
         'CoverageFilterMode is active. Row indices: %s'], ...
        char(strjoin(string(find(missingRationale)), ', ')));
end

action(~active) = "";
rationale(~active) = "";
end
