function tests = test_file_signature
%TEST_FILE_SIGNATURE Hashing correctness across both read paths.
tests = functiontests(localfunctions);
end

function testKnownVectorMatchesTheStandard(testCase)
% "abc" has a published SHA-256. If the fast path ever disagrees with the
% standard, every stored signature in every manifest becomes meaningless.
path = write_bytes(testCase, uint8('abc'));
verifyEqual(testCase, st_file_signature(path).SHA256, ...
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
end

function testEmptyFileMatchesTheStandard(testCase)
path = write_bytes(testCase, uint8([]));
verifyEqual(testCase, st_file_signature(path).SHA256, ...
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
end

function testChunkedPathAgreesWithTheFastPath(testCase)
% The chunked reader stays as the fallback for very large files, so it has
% to produce the same digest as the Java-side read.
data = uint8(mod(0:(3 * 1024 * 1024 - 1), 256));
path = write_bytes(testCase, data);
expected = st_file_signature(path).SHA256;

md = java.security.MessageDigest.getInstance('SHA-256');
fileId = fopen(path, 'rb');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
while true
    chunk = fread(fileId, 1024 * 1024, '*uint8');
    if isempty(chunk), break; end
    md.update(typecast(chunk(:), 'int8'));
end
raw = typecast(int8(md.digest()), 'uint8');
chunked = lower(reshape(dec2hex(raw, 2).', 1, []));

verifyEqual(testCase, expected, chunked);
end

function testMissingFileHasNoSignature(testCase)
signature = st_file_signature(fullfile(tempdir, 'st_no_such_file.bin'));
verifyFalse(testCase, signature.Exists);
verifyEmpty(testCase, signature.SHA256);
end

function path = write_bytes(testCase, data)
path = [tempname(tempdir) '.bin'];
fileId = fopen(path, 'wb');
fwrite(fileId, data, 'uint8');
fclose(fileId);
testCase.addTeardown(@() delete(path));
end
