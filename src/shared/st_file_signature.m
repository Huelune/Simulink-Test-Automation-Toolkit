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

signature.SHA256 = file_digest(filePath, signature.Bytes);
end

function value = file_digest(filePath, bytes)
%FILE_DIGEST SHA-256 of a file, read on the Java side where possible.
%
% Hashing dominates delivery verification once a project has hundreds of
% targets. The cost is not SHA-256 itself but moving the bytes: reading in
% MATLAB copies every chunk with typecast and marshals it across the Java
% boundary. Letting Java read the file keeps the data on one side.

md = java.security.MessageDigest.getInstance('SHA-256');
% Guard against loading a huge file into the JVM heap in one piece.
inMemoryLimit = 256 * 1024 * 1024;
if bytes <= inMemoryLimit
    try
        md.update(java.nio.file.Files.readAllBytes( ...
            java.io.File(filePath).toPath()));
        value = digest_text(md);
        return;
    catch
        % Out of heap, a locked file, or an unusual path: fall through to
        % the chunked reader rather than reporting no signature.
        md.reset();
    end
end

fileId = fopen(filePath, 'rb');
if fileId < 0
    error('simtest:FileHashFailed', ...
        'Cannot open file for hashing: %s', filePath);
end
cleanupFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
while true
    data = fread(fileId, 8 * 1024 * 1024, '*uint8');
    if isempty(data)
        break;
    end
    md.update(typecast(data(:), 'int8'));
end
value = digest_text(md);
end

function value = digest_text(md)
raw = typecast(int8(md.digest()), 'uint8');
value = lower(reshape(dec2hex(raw, 2).', 1, []));
end
