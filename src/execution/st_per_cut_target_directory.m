function path = st_per_cut_target_directory(runDirectory, targetRow)
%ST_PER_CUT_TARGET_DIRECTORY Return collision-resistant CUT artifact path.

identity = struct( ...
    'No', double(targetRow.No), ...
    'CUTPath', char(string(targetRow.CUTPath)), ...
    'TestCaseName', char(string(targetRow.TestCaseName)));
digest = st_hash_value(identity);
name = st_export_safe_name(char(string(targetRow.CUTName)));
if isempty(name)
    name = 'CUT';
end
folder = sprintf('%03d_%s_%s', ...
    double(targetRow.No), name, digest(1:10));
path = fullfile(runDirectory, 'targets', folder);
end
