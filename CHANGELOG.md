# Changelog

## Unreleased

- Added a step-by-step Korean user manual for verification setup, recommended
  QUICK/RUNTIME/CERTIFY operation, manual evidence, result interpretation,
  troubleshooting, and final R2025b certification.
- Added `st_verify_all` with `QUICK`, `RUNTIME`, and `CERTIFY` profiles,
  normalized PASS/FAIL/BLOCKED/SKIP/WARN results, feature-catalog coverage,
  manual evidence validation, and Excel/JSON/JUnit output.
- Added execution-local fixture generation for scalar, numeric array, nested
  Bus, Bus array, no-Inport, and SLDV branch targets without tracking binary
  fixtures in Git.
- Added isolated current-model verification that reuses the export collector,
  hashes source dependencies and inputs, and runs only fresh workspace copies.
- Added certification checks for expected-value APPLY/OFF, SLDV GENERATE/FILE,
  cache reuse, corrupt-state recovery, preparation failure isolation, integrated
  reports, coverage, bundle checksums, template immutability, and repeat runs.

- Added standalone reproducible test bundle export with saved internal Harness
  models, analyzed dependencies, target inputs, Test File definitions, reference
  reports, SHA-256 inventory, and an optional ZIP archive.
- Added an exported runner that validates the bundle and creates a fresh mutable
  workspace for each rerun while preserving the source project and bundle
  template, plus a beginner-oriented Korean bundle README.

- Added target-level incremental preparation with `AUTO`/`FORCE` policies,
  stage checkpoints, input fingerprints, and atomic MAT/JSON state files.
- Added optional `PreparationMode` and `PreparationFromStage` Excel columns
  with call option, row, and global configuration precedence.
- Added cross-run SLDV manifest profile reuse while preserving direct no-arg
  behavior for each existing `st_*` preparation command.
- Added per-run integrated report bundles with initial/final Test Manager
  results, official PDF, raw MLDATX, coverage HTML, manifest, and Excel summary.
- Added Decision and Block Execution coverage extraction at overall CUT,
  Test Case, and Iteration levels, including justified outcomes, `N/A` for a
  zero denominator, and checksum-safe weighted aggregation.
- Added `result/latest.json` and latest Excel summary updates without external
  publishing or coverage-threshold failure enforcement.

- Connected the project to the `Huelune/Simulink-Test-Automation-Toolkit` repository while preserving its initial MIT license commit.
- Added explicit expected-value policy with `cfg.ExpectedUpdateMode = 'APPLY'` as the project default.
- Added optional per-row `ExpectedUpdateMode` values (`DEFAULT`, `OFF`, `APPLY`) to the `Targets` sheet.
- Limited expected-value logging preparation and mutation to rows resolved to `APPLY`.
- Documented the repository artifact policy, target package structure, and deferred decisions.
- Reorganized MATLAB sources by responsibility under `src/`, moved diagnostics and unit tests to dedicated folders, and preserved historical handoff files under `docs/archive/`.
- Added a root resolver so configuration and diagnostic paths remain stable after source files move.

## v0.9.6 Candidate

- Added optional automatic atomic CUT setup for `SldvMode=GENERATE`. With `cfg.AutoEnableAtomicForSldvGenerate = true`, a non-atomic Subsystem is changed to `TreatAsAtomicUnit=on` only around `sldvrun`, then its original setting and the model Dirty state are restored.
- Updated SLDV input handling to use the Harness Signal Editor `ActiveScenario` as the interface template. SLDV Dataset inputs may be a compatible subset; Harness-only external inputs are retained in every generated scenario, while unexpected SLDV inputs fail before mutation.
- Removed the SLDV direct-CUT-Inport gate from Signal Editor and Test Manager setup. SLDV Iterations now always bind both `SignalEditorScenario` and `TestSequenceScenario` to the matching `UT_REQ_*` name.
- Extended scenario alignment validation to check both Iteration scenario parameters in addition to scenario names and counts.
- Treat the initial Signal Editor `InputScenario`/template Scenario after linking a new MAT file as a normal intermediate state. The linked template is renamed and populated with `UT_REQ_*` scenarios only after the Filename refresh completes.

- Added row-level `SldvMode` (`OFF`, `FILE`, `GENERATE`) and `SldvDataFile` management columns with backward-compatible `OFF` defaults.
- Added SLDV generation using a deep copy of the Top Model Design Verifier settings, target-specific latest-result storage, and success-only replacement of generated data files.
- Added preflight validation for subsystem ownership, effective test cases, time vectors, Dataset interfaces, direct CUT Inports, iteration parameter metadata/application, and shared Signal Editor MAT files.
- Added one-to-one SLDV TestCase expansion into Signal Editor scenarios, Assessment scenarios, and Test Manager table iterations named `UT_REQ_{CUTName}_{NNN}`.
- Applied CUT-level `Tmax` to Harness StopTime, every Assessment transition, and expected-value sampling, while holding shorter Signal Editor inputs at their final values.
- Added per-iteration SLDV parameter overrides and targeted iteration reset for existing SLDV Test Cases.
- Added verify-run timing validation that reports missing or `Untested` active-scenario results without extending StopTime.
- Replaced Assessment output name matching with the confirmed positional rule: Assessment Input order is Signal Editor ActiveScenario variables followed by Harness output signals.
- Assessment Input symbols are sorted by their actual `Port`; the ActiveScenario element count is skipped and the remaining symbols are paired with Harness Outports in output order.
- Removed exact-name matching and limited port-fallback behavior from the current Assessment workflow. Harness names remain diagnostic metadata and are never normalized or guessed.
- Updated expected-value replacement to rebuild the same Assessment-symbol-to-Harness-output positional map before looking up logged signals.
- Changed the default Test Manager mode to incremental with `cfg.OverwriteTestFile = false`.
- Incremental Test Manager creation reuses an open target Test File, opens a closed existing file, creates a missing file, preserves existing Test Cases, and adds only missing `TestCaseName` values.
- Full recreation closes only the target Test File instead of clearing every open Test Manager file.
- Preserved the no-direct-Inport rule: Signal Editor configuration is skipped and `SignalEditorScenario` is omitted from the Test Manager iteration, while `TestSequenceScenario` remains assigned.
- Added timestamped verbose checkpoints through `st_log.m`, including logs immediately before and after long-running MATLAB/Simulink calls.
- Added workflow and per-target elapsed-time reporting.
- Kept compile-based Harness creation with `CreateWithoutCompile = false`.
- Documentation now treats the current code as the v0.9.6 candidate source of truth and records the remaining MATLAB R2025b runtime validation work.

## v0.9.5

- Assessment output matching no longer performs or proposes slash deletion/name normalization.
- `st_configure_assessments` now matches Harness output names to Assessment Input symbols using exact raw names first.
- If raw names differ, a port-order fallback is allowed only when Harness Outport count and Assessment Input symbol count are identical.
- Fallback keeps the original Harness signal/outport names unchanged and uses the actual Assessment symbol name for verify generation.
- If a safe one-to-one match cannot be established, the automation fails with the unmatched raw Harness names and actual Assessment symbol names instead of guessing.
- Added `PortOrderFallbackCount` to `AssessmentResult`.

## v0.9.4

- Fixed Test Manager iteration setup for CUTs with no direct Inport.
- `st_create_test_manager` now uses the same direct-Inport condition as `st_configure_signal_editors`.
- When a CUT has no direct Inport, `SignalEditorScenario` is no longer assigned to `Iteration 1`.
- `TestSequenceScenario` is still assigned because the Test Assessment scenario is independent of CUT input existence.
- Added `HasDirectInport` and `SignalEditorScenarioApplied` columns to `TestManagerResult` for traceability.

## v0.9.3

- Changed `st_export_subsystem_paths` to exhaustive inventory mode for human path selection.
- Searches under masks and inside library links, Subsystem References, and Model References.
- Includes inactive variant choices with `Simulink.match.allVariants`.
- Includes commented blocks.
- Added `SourceModel` so paths returned from referenced models can be distinguished from the selected top model.
- Depth and relative path are now calculated from each returned subsystem's actual block-diagram root.
- Duplicate identical returned definition paths are removed while preserving order.


## v0.9.2

- Added `excel_open_diagnostic.py` to compare multiple xlwings workbook-opening paths against the same management workbook.
- Added `st_diagnose_excel_access.m` so the diagnostic can be launched directly from MATLAB.
- Safe default tests are read-only and never modify the original workbook.
- Optional `writeProbe=true` additionally checks whether Excel can open the workbook read-write without saving and whether a disposable workbook can be saved in the same directory.
- Diagnostic methods include:
  - `app.books.open(..., read_only=True)`
  - `app.api.Workbooks.Open(..., ReadOnly=True)`
  - `xw.Book(path, read_only=True)`
  - `xw.Book(path, mode='r')`
- JSON results are written to `result/ExcelAccessDiagnostic.json` when launched from MATLAB.
- Existing v0.9.1 indentation-path workflow and test execution defaults are unchanged.

## v0.9.1

- Corrected the temporary path feature to read Excel native cell indentation rather than a numeric Depth column.
- Added `st_fill_temp_paths_from_indent`.
- Kept `st_fill_temp_paths_from_depth` as a compatibility wrapper.
