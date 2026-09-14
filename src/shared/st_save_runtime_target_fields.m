function st_save_runtime_target_fields(targetFile, fields)
%ST_SAVE_RUNTIME_TARGET_FIELDS Merge fields into runtime_target.mat.
%
% save(...) replaces the whole MAT-file, so writing TopModel/ModelFile
% here would silently erase an unrelated saved field (for example a
% StandaloneCoverageRootDir override) written by a different command, and
% vice versa. This reads any existing content first and merges the given
% fields on top before writing the file back.

targetFile = char(targetFile);

merged = struct();
if isfile(targetFile)
    merged = load(targetFile);
end

if isfield(merged, 'ActiveModelProfile') && ~isempty(merged.ActiveModelProfile) && ...
        isfield(fields, 'ModelFile')
    current = st_config();
    if ~st_same_path(current.ModelFile, fields.ModelFile)
        merged.ActiveModelProfile = '';
        st_log(current, 'WARN', 'Different model selected; model profile deactivated');
    end
end
names = fieldnames(fields);
for i = 1:numel(names)
    merged.(names{i}) = fields.(names{i});
end

st_atomic_save(targetFile, merged);
end
