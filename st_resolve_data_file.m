function fullPath = st_resolve_data_file(filename, topModel)
%ST_RESOLVE_DATA_FILE Resolve a Signal Editor MAT-file path.

filename = char(filename);
topModel = char(topModel);

if isfile(filename)
    p = which(filename);
    if isempty(p)
        fullPath = filename;
    else
        fullPath = p;
    end
    return;
end

p = which(filename);
if ~isempty(p)
    fullPath = p;
    return;
end

p = fullfile(pwd, filename);
if isfile(p)
    fullPath = p;
    return;
end

modelFile = which(topModel);
if ~isempty(modelFile)
    p = fullfile(fileparts(modelFile), filename);
    if isfile(p)
        fullPath = p;
        return;
    end
end

error('Signal Editor data file not found: %s', filename);
end
