function T = st_resolve_harness_clone_settings(T)
%ST_RESOLVE_HARNESS_CLONE_SETTINGS Preserve ordinary preparation defaults.
fields = {'TestPreparationSource','SourceCUTPath','SourceHarnessName'};
for k = 1:numel(fields)
    name = fields{k};
    if ~ismember(name,T.Properties.VariableNames)
        T.(name) = strings(height(T),1);
    end
    T.(name) = string(T.(name));
    T.(name)(ismissing(T.(name))) = "";
end
T.TestPreparationSource = upper(strtrim(T.TestPreparationSource));
T.TestPreparationSource(T.TestPreparationSource == "") = "EXISTING";
T.SourceHarnessName = strtrim(T.SourceHarnessName);
if any(T.TestPreparationSource == "HARNESS_IMPORT")
    error('simtest:HarnessImportRetired', ...
        'HARNESS_IMPORT is retired. Select HARNESS_CLONE and review SLDV/expected-update settings.');
end
if any(~ismember(T.TestPreparationSource,["EXISTING","HARNESS_CLONE"]))
    error('simtest:InvalidTestPreparationSource', ...
        'TestPreparationSource must be EXISTING or HARNESS_CLONE.');
end
% Missing templates are checked per target so valid batch rows can continue.
end
