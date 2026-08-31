function result = st_verification_catalog_coverage(catalog, checks, options)
%ST_VERIFICATION_CATALOG_COVERAGE Fail when a feature produced no evidence.

result = st_empty_verification_checks();
prerequisiteBlocked = any(checks.Required & checks.Status == "BLOCKED");
for i = 1:height(catalog)
    featureId = string(catalog.FeatureId(i));
    linked = any(upper(string(checks.FeatureId)) == upper(featureId));
    if linked
        status = 'PASS'; message = 'Feature produced verification evidence';
    elseif prerequisiteBlocked
        status = 'BLOCKED';
        message = 'Prerequisite capability blocked this feature check';
    else
        status = 'FAIL'; message = 'Feature has no connected verification result';
    end
    result = [result; st_verification_check( ...
        "CATALOG.COVERAGE." + featureId, featureId, ...
        options.Profile, options.Target, true, status, message)]; %#ok<AGROW>
end
end
