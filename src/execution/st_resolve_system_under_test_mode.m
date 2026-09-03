function mode = st_resolve_system_under_test_mode(value)
%ST_RESOLVE_SYSTEM_UNDER_TEST_MODE Normalize the Test Manager SUT policy.

mode = upper(strtrim(string(value)));
if ismissing(mode) || strlength(mode) == 0
    mode = "INTERNAL_HARNESS";
end
if ~isscalar(mode) || ...
        ~ismember(mode, ["INTERNAL_HARNESS","EXPORTED_MODEL"])
    error('simtest:InvalidSystemUnderTestMode', ...
        ['SystemUnderTestMode must be INTERNAL_HARNESS or ' ...
         'EXPORTED_MODEL.']);
end
mode = char(mode);
end
