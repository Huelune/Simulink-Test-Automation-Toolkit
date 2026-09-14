function st_require_file_hash(file, hash)
%ST_REQUIRE_FILE_HASH Reject unavailable or changed stored evidence.
if isempty(file) || isempty(hash) || ~isfile(file) || ...
        ~strcmpi(st_file_signature(file).SHA256,char(string(hash)))
    error('simtest:RestartEvidenceInvalid','Required evidence missing or changed: %s',char(string(file)));
end
end
