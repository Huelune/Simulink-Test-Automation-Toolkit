function mask = st_is_harness_clone(T)
%ST_IS_HARNESS_CLONE Optional row-level template preparation mode.
mask = false(height(T),1);
if ismember('TestPreparationSource', T.Properties.VariableNames)
    mask = strcmpi(string(T.TestPreparationSource), 'HARNESS_CLONE');
end
end
