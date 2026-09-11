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
    try
        merged = load(targetFile);
    catch
        merged = struct();
    end
end

names = fieldnames(fields);
for i = 1:numel(names)
    merged.(names{i}) = fields.(names{i});
end

save(targetFile, '-struct', 'merged');
end
