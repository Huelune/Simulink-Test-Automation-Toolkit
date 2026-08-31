function features = st_verification_feature_status(catalog, checks)
%ST_VERIFICATION_FEATURE_STATUS Add current evidence status to the catalog.

Status = strings(height(catalog),1);
Message = strings(height(catalog),1);
for i = 1:height(catalog)
    rows = checks(upper(string(checks.FeatureId)) == ...
        upper(string(catalog.FeatureId(i))), :);
    if isempty(rows)
        Status(i) = "BLOCKED";
        Message(i) = "No check result was produced";
    else
        Status(i) = st_verification_overall_status(rows);
        Message(i) = sprintf('%d check(s)', height(rows));
    end
end
features = addvars(catalog, Status, Message);
end
