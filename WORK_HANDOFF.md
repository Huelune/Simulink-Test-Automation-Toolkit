# Simulink Test Automation - Work Handoff

## Repository baseline

Repository:
`https://github.com/Huelune/Simulink-Test-Automation-Toolkit`

v0.9.6 candidate baseline:
`1b96b924b4f8f30bddb77a9da5c1b6c3a27c3145` (`add log`)

`VERSION.txt` identifies the previous documentation candidate as `0.9.6`. Unreleased changes are recorded in `CHANGELOG.md`. Treat current code as the source of truth. Do not restore behavior from older README, release notes, or archived handoff material.

## Current workflow

`st_run_from_harness` performs:

1. CUT path pre-validation
2. Missing Harness creation
3. Per-row SLDV generation/file validation and manifest creation
4. Harness configuration
5. Signal Editor configuration
6. Test Assessment configuration
7. Test Manager creation or incremental extension
8. Optional test execution and expected-value update

`st_run_after_harness` validates existing CUT/Harness mappings and starts from Harness configuration.

Both entry points report stage START/DONE/FAILED timestamps and elapsed time.

## Assessment mapping rule

Confirmed from generated Harness inspection:

```text
Test Assessment Input order
= Signal Editor ActiveScenario variables
+ Harness output signals
```

If the active Scenario has `K` elements:

```text
Assessment Port 1..K      -> Scenario input area
Assessment Port K+1..end  -> Harness output area
```

Implementation rule:

1. Read Assessment Input symbols and their actual Ports.
2. Sort symbols by actual Assessment input `Port`.
3. Read the active Signal Editor Scenario element count.
4. Skip the first `K` Assessment symbols.
5. Match the remaining symbols to Harness outputs in Outport order.
6. Generate `verify(...)` using the actual Assessment symbol name.

Signal names are diagnostics only. Do not delete `/`, call `makeValidName`, or introduce any guessed name normalization.

Example:

```text
Harness signal : A/B
Assessment     : AB
```

The relationship is established by position, not text transformation.

## Expected-value update rule

`st_update_expected_from_results` rebuilds the same positional map used during Assessment generation.

```text
Assessment symbol
-> positional Assessment/Harness mapping
-> Harness SignalName / OutportBlock
-> logged signal
```

A verify expression may contain:

```matlab
verify(AB == 0);
```

while the logged Harness signal is still `A/B`. Do not revert to lookup by the verify LHS root name alone.

Only Failed Iterations are updated. Supported replacement values are real numeric scalar and logical scalar. If at least one RHS changes and `cfg.RerunAfterExpectedUpdate` is true, the Test File is run again.

## Signal Editor direct-Inport rule

`OFF` mode keeps the legacy rule:

```text
direct CUT Inport exists -> configure and rename Signal Editor scenario
no direct CUT Inport     -> SKIP_NO_INPORT
```

For SLDV `FILE`/`GENERATE`, direct CUT Inports are not an execution gate. The nonempty Harness Signal Editor `ActiveScenario` is the input template; SLDV-provided elements replace matching template elements and external Harness-only elements are preserved. Scenario input count for Assessment mapping is read from the active Signal Editor data rather than inferred from direct CUT Inports.

## Test Manager rules

Current default:

```matlab
cfg.OverwriteTestFile = false;
```

Incremental behavior:

```text
open target .mldatx     -> reuse open TestFile
closed existing .mldatx -> open existing file
missing .mldatx         -> create file
existing TestCaseName   -> preserve + SKIP_EXISTING
missing TestCaseName    -> create only missing Test Case
```

With `cfg.OverwriteTestFile = true`, close only the target Test File and recreate it. Do not globally clear Test Manager files.

Coverage recording is enabled at Test File, Test Suite, and Test Case levels.

`OFF` mode, direct Inport exists:

```text
SignalEditorScenario = UT_REQ_{CUTName}_001
TestSequenceScenario = UT_REQ_{CUTName}_001
```

`OFF` mode, no direct Inport:

```text
SignalEditorScenario is not assigned
TestSequenceScenario = UT_REQ_{CUTName}_001
```

For SLDV `FILE`/`GENERATE`, every iteration always assigns both parameters to the same `UT_REQ_{CUTName}_{NNN}` scenario.

## Harness creation

Harness creation remains compile-based:

```matlab
'CreateWithoutCompile', false
```

Key settings are Signal Editor source, Outport sink, Test Sequence scheduler, separate Assessment, Normal verification mode, internal Harness storage, and `SyncOnOpenAndClose` synchronization.

A SynchronizationMode warning alone is not a Harness creation failure when the Harness is actually created.

## Assessment generation options

Current defaults:

```matlab
cfg.VerifyHarnessOutportsOnly = true;
cfg.VerifyFirstBusElementOnly = true;
cfg.VerifyAtSampleTimeOnly = false;
```

The verify builder supports scalar, numeric array, Bus, and nested Bus expressions. When first-Bus-element mode is enabled, repeated Bus instances are reduced to the first instance while numeric arrays inside Bus leaves are still fully verified.

## Execution and logging defaults

```matlab
cfg.RunGeneratedTests = true;
cfg.ExpectedUpdateMode = 'APPLY';
cfg.ExpectedValueSampleTime = 0.01;
cfg.RerunAfterExpectedUpdate = true;
cfg.VerboseLogging = true;
```

The optional `Targets.ExpectedUpdateMode` column overrides the global mode per row. `DEFAULT` uses the global setting, `OFF` prevents mutation, and `APPLY` enables the existing failed-value update workflow. `REVIEW` remains unimplemented and must not be documented as supported.

`st_log.m` supplies timestamped `INFO`, `DEBUG`, `TRACE`, `WARN`, and `ERROR` messages. With `VerboseLogging = false`, extra INFO/DEBUG/TRACE logs are suppressed while normal START/OK/FAIL/summary output remains.

Long blocking calls such as `sltest.harness.create`, `sltest.harness.load`, and `run(tf)` log immediately before and after the call. The code does not claim percentage progress from inside those APIs.

## Excel and model rules

Sheet: `Targets`

Required columns:

- `CUTName`
- `CUTPath`
- `HarnessName`
- `TestCaseName`

Optional columns:

- `No`
- `Enabled`
- `SldvMode` (`OFF`, `FILE`, `GENERATE`; missing/blank means `OFF`)
- `SldvDataFile` (`FILE` mode only)
- `ExpectedUpdateMode` (`DEFAULT`, `OFF`, `APPLY`; missing/blank means `DEFAULT`)

Do not add a `ModelName` column. One selected runtime model is shared by all target rows.

`st_export_subsystem_paths` is a broad discovery inventory. It can include masks, library links, Subsystem References, recursively referenced models, inactive variants, and commented blocks. `SourceModel` identifies the owning block diagram. Human selection plus `st_pre_validate_targets` remains the validity gate.

## Documentation and style rules

- Use `TEST_TARGET_MODEL_NAME` in all generic examples.
- Never expose a historical real target model name.
- Prefer single-quote char syntax in MATLAB examples and generated MATLAB code.
- Code takes precedence if documentation becomes stale again.

## Environment and validation status

- MATLAB / Simulink R2025b
- Source model may originate from R2024a
- Harness create/update calls can take several minutes

The ordering `Scenario variables -> Harness outputs` was manually confirmed from generated Harnesses. Do not claim complete runtime validation until the following have run successfully on the real MATLAB machine:

- end-to-end Assessment generation
- failed-test expected-value update
- incremental Test Manager behavior
- verbose logging output
- rerun after expected-value update

## High-priority files

```text
st_config.m
st_log.m
st_run_from_harness.m
st_run_after_harness.m
st_create_harnesses.m
st_configure_harnesses.m
st_configure_signal_editors.m
st_collect_assessment_input_specs.m
st_collect_signal_editor_scenario_names.m
st_collect_harness_output_signals.m
st_configure_assessments.m
st_build_verify_action.m
st_prepare_assessment_scenario.m
st_prepare_sldv_targets.m
st_get_sldv_profile.m
st_normalize_sldv_parameters.m
st_apply_sldv_parameters.m
st_create_test_manager.m
st_run_generated_tests.m
st_update_expected_from_results.m
st_validate_sldv_verify_results.m
```
