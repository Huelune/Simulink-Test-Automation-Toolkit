function formats = st_resolve_data_file_formats(sldvModes, formats)
%ST_RESOLVE_DATA_FILE_FORMATS Normalize FILE-mode source format settings.
% The option is intentionally inert outside SldvMode=FILE.
modes = upper(strtrim(string(sldvModes)));
formats = upper(strtrim(string(formats)));
formats(ismissing(formats) | strlength(formats) == 0) = "SLDV";

if ~isequal(size(modes), size(formats))
    error('simtest:DataFileFormatSize', ...
        'SldvMode and DataFileFormat must have the same size.');
end

fileRows = modes == "FILE";
invalid = fileRows & ~ismember(formats, ["SLDV","MAT"]);
if any(invalid(:))
    unsupported = unique(formats(invalid), 'stable');
    error('simtest:UnsupportedDataFileFormat', ...
        ['Unsupported DataFileFormat: %s. ' ...
         'Supported values: SLDV, MAT'], ...
        char(strjoin(unsupported, ', ')));
end

formats(~fileRows) = "SLDV";
end
