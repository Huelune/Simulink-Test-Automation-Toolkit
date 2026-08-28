Current full replacement bundle

These are complete files, not diffs.

Includes:
- st_configure_signal_editors.m
  Latest SLDVMatFile import + UT_REQ variable verification + Filename
  save/close/reopen scenario refresh.
- st_prepare_sldv_targets.m
  Harness ActiveScenario input interface validation.
- st_load_targets.m
- st_normalize_cut_path.m
- st_fill_temp_paths_from_indent.m
  Trailing-whitespace path fallback handling.
- st_validate_scenario_alignment.m
- st_run_from_harness.m
- st_run_after_harness.m
  Pre-run one-to-one Signal Editor / Assessment / Test Manager scenario
  validation.

This bundle assumes the repository's current versions of the remaining SLDV
files, including st_configure_assessments.m, st_create_test_manager.m,
st_run_generated_tests.m, st_update_expected_from_results.m, and
st_validate_sldv_verify_results.m.
