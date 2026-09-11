function cleanup = st_enter_writable_coverage_directory(cfg, operation)
%ST_ENTER_WRITABLE_COVERAGE_DIRECTORY Satisfy Coverage API pwd checks.
%
% Coverage save/report APIs can reject the current MATLAB directory even
% when their output path is absolute. Enter a short writable scratch folder
% for the API call and restore the caller directory through onCleanup.

if nargin < 2 || strlength(strtrim(string(operation))) == 0
    operation = 'COVERAGE_API';
end
operation = upper(char(string(operation)));
previousDirectory = pwd;
writableDirectory = tempname(tempdir);
[created, createMessage] = mkdir(writableDirectory);
if ~created
    st_log(cfg, 'ERROR', ...
        'Coverage writable directory unavailable | Operation=%s | %s | %s', ...
        operation, writableDirectory, createMessage);
    error('simtest:CoverageWritableDirectoryUnavailable', ...
        'Cannot create Coverage scratch directory %s: %s', ...
        writableDirectory, createMessage);
end
st_log(cfg, 'DEBUG', ...
    ['Coverage writable directory enter | Operation=%s | ' ...
     'From=%s | To=%s'], ...
    operation, previousDirectory, writableDirectory);
cd(writableDirectory);
cleanup = onCleanup(@() restore_directory( ...
    previousDirectory, writableDirectory, operation, cfg));
end

function restore_directory(previousDirectory, writableDirectory, ...
        operation, cfg)
try
    cd(previousDirectory);
    if isfolder(writableDirectory)
        rmdir(writableDirectory, 's');
    end
    st_log(cfg, 'DEBUG', ...
        'Coverage writable directory restored | Operation=%s | To=%s', ...
        operation, previousDirectory);
catch ME
    st_log(cfg, 'ERROR', ...
        ['Coverage writable directory restore failed | Operation=%s | ' ...
         '%s: %s'], operation, ME.identifier, ME.message);
end
end
