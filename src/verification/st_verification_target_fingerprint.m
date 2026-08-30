function fingerprint = st_verification_target_fingerprint(cfg)
%ST_VERIFICATION_TARGET_FINGERPRINT Hash current model, Excel, and Test File.

value = struct();
value.TopModel = cfg.TopModel;
value.Model = st_file_signature(cfg.ModelFile);
value.ManagementExcel = st_file_signature(cfg.ManagementExcel);
value.TestFile = st_file_signature(cfg.TestFile);
fingerprint = st_hash_value(value);
end
