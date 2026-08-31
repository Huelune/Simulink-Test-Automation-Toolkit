function signature = st_file_signature(filePath)
%ST_FILE_SIGNATURE Describe and hash a local file without modifying it.

filePath = char(string(filePath));
signature = struct( ...
    'Path', filePath, ...
    'Exists', false, ...
    'Bytes', 0, ...
    'Modified', '', ...
    'SHA256', '');

if isempty(filePath) || ~isfile(filePath)
    return;
end

info = dir(filePath);
signature.Exists = true;
signature.Bytes = info.bytes;
signature.Modified = char(datetime(info.datenum, ...
    'ConvertFrom', 'datenum', ...
    'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));

fileId = fopen(filePath, 'rb');
if fileId < 0
    error('simtest:FileHashFailed', ...
        'Cannot open file for hashing: %s', filePath);
end
cleanupFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>

md = java.security.MessageDigest.getInstance('SHA-256');
while true
    data = fread(fileId, 1024 * 1024, '*uint8');
    if isempty(data)
        break;
    end
    md.update(typecast(data(:), 'int8'));
end

raw = typecast(int8(md.digest()), 'uint8');
signature.SHA256 = lower(reshape(dec2hex(raw, 2).', 1, []));
end
