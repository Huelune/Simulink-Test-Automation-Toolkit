function st_prepare_expected_value_logging_for_targets(cfg, tf, targetConfig)
%ST_PREPARE_EXPECTED_VALUE_LOGGING_FOR_TARGETS Enable logging for APPLY rows.

T = targetConfig(targetConfig.ExpectedUpdateMode == "APPLY", :);
if isempty(T)
    return;
end

st_prepare_expected_value_harness_logging(cfg, T);
st_prepare_expected_value_test_file_logging(cfg, tf, T);
end
