function tests = test_sldv_config
tests = functiontests(localfunctions);
end


function testGenerateAutoAtomicIsEnabledByDefault(testCase)
cfg = st_config();

verifyTrue(testCase, cfg.AutoEnableAtomicForSldvGenerate);
end
