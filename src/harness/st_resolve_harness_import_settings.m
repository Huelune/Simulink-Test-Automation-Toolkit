function T = st_resolve_harness_import_settings(T, cfg)
%ST_RESOLVE_HARNESS_IMPORT_SETTINGS Normalize source selection and protect copies.
n = height(T);
defaults = {'TestPreparationSource','EXISTING'; 'SourceCUTPath',''; ...
    'SourceHarnessName',''};
for k = 1:size(defaults,1)
    field = defaults{k,1};
    if ~ismember(field, T.Properties.VariableNames)
        T.(field) = repmat(string(defaults{k,2}), n, 1);
    else
        T.(field) = string(T.(field));
        missing = ismissing(T.(field)) | strlength(T.(field)) == 0;
        T.(field)(missing) = string(defaults{k,2});
    end
end
T.TestPreparationSource = upper(strtrim(T.TestPreparationSource));
T.TestPreparationSource(T.TestPreparationSource == "") = "EXISTING";
T.SourceHarnessName = strtrim(T.SourceHarnessName);
if any(~ismember(T.TestPreparationSource, ["EXISTING","HARNESS_IMPORT"]))
    error('simtest:InvalidTestPreparationSource', ...
        'TestPreparationSource must be EXISTING or HARNESS_IMPORT.');
end
mask = st_is_harness_import(T);
if any(mask & (strlength(T.SourceCUTPath) == 0 | strlength(T.SourceHarnessName) == 0))
    error('simtest:ImportSourceMissing', ...
        'HARNESS_IMPORT requires SourceCUTPath and SourceHarnessName.');
end
% Normalize before the ordinary SLDV/update validators consume these values.
for i = find(mask).'
    if T.SldvMode(i) ~= "OFF" || strlength(T.SldvDataFile(i)) > 0 || ...
            T.ExpectedUpdateMode(i) ~= "OFF"
        st_log(cfg, 'WARN', ...
            'Harness import ignores SLDV/expected-update settings | CUT=%s | Harness=%s', ...
            T.CUTPath(i), T.HarnessName(i));
    end
end
T.SldvMode(mask) = "OFF";
T.SldvDataFile(mask) = "";
T.ExpectedUpdateMode(mask) = "OFF";
end
