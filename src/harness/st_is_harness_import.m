function mask = st_is_harness_import(T)
%ST_IS_HARNESS_IMPORT Backward-compatible preparation-source predicate.
mask = false(height(T), 1);
if ismember('TestPreparationSource', T.Properties.VariableNames)
    mask = strcmpi(string(T.TestPreparationSource), 'HARNESS_IMPORT');
end
end
