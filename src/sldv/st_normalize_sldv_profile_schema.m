function normalized = st_normalize_sldv_profile_schema(profiles)
%ST_NORMALIZE_SLDV_PROFILE_SCHEMA Add defaults for older manifest profiles.
template = st_empty_sldv_profile();
normalized = repmat(template, size(profiles));
fields = fieldnames(template);
for profileIndex = 1:numel(profiles)
    for fieldIndex = 1:numel(fields)
        field = fields{fieldIndex};
        if isfield(profiles, field)
            normalized(profileIndex).(field) = profiles(profileIndex).(field);
        end
    end
end
end
