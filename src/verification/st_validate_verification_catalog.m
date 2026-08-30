function issues = st_validate_verification_catalog(catalog)
%ST_VALIDATE_VERIFICATION_CATALOG Return catalog consistency problems.

issues = strings(0,1);
required = {'FeatureId','FeatureName','AutomatedCheckIds','ManualCheckIds'};
if ~istable(catalog) || ~all(ismember(required, ...
        catalog.Properties.VariableNames))
    issues(end+1,1) = "Catalog schema is invalid";
    return;
end

featureIds = upper(strtrim(string(catalog.FeatureId)));
if any(strlength(featureIds) == 0)
    issues(end+1,1) = "FeatureId must not be empty";
end
if numel(unique(featureIds)) ~= numel(featureIds)
    issues(end+1,1) = "FeatureId values must be unique";
end

allChecks = strings(0,1);
for i = 1:height(catalog)
    automatic = split_ids(catalog.AutomatedCheckIds(i));
    manual = split_ids(catalog.ManualCheckIds(i));
    if isempty(automatic) && isempty(manual)
        issues(end+1,1) = "Feature has no verification check: " + ...
            featureIds(i); %#ok<AGROW>
    end
    allChecks = [allChecks; automatic; manual]; %#ok<AGROW>
end
allChecks = upper(allChecks(strlength(allChecks) > 0));
if numel(unique(allChecks)) ~= numel(allChecks)
    issues(end+1,1) = "Check IDs must be unique across the catalog";
end
end

function values = split_ids(value)
value = strtrim(string(value));
if ismissing(value) || strlength(value) == 0
    values = strings(0,1);
else
    values = strtrim(split(value, ','));
    values = values(strlength(values) > 0);
end
end
