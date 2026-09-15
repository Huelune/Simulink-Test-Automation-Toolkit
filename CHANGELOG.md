# Changelog

## Unreleased

- Documented why Coverage filter rules show `n/a` in the name column: the
  rules address blocks by SID, which the viewer resolves against a loaded
  model. Opening the standalone model that sits beside the CVF fills the
  names in; the original Top Model does not, because standalone models do
  not reuse its SIDs.
- Packaged standalone Coverage artifacts now carry a `UT_REQ_` prefix:
  `{NUM}_UT_REQ_{TestCaseName}` target folders holding
  `UT_REQ_{TestCaseName}.cvf`, `.cvt` and `.html`. The stem comes from the
  new `st_artifact_stem`, which every producer and the checker share so the
  names cannot drift apart; prefixing is idempotent and stays inside the
  80-character cap. Harness, standalone model and input MAT names are
  unchanged. Deliveries packaged before this change no longer satisfy the
  checker and must be produced again.
- `DecisionBlocks` now inventories the block types that create Simulink
  Coverage objectives without looking like a decision: Saturate, Abs,
  DeadZone, RateLimiter, Relay, Lookup_n-D, Interpolation_n-D, PreLookup,
  Integrator, DiscreteIntegrator, ForIterator, WhileIterator and Logic sit
  next to If/Switch/MinMax/MultiPortSwitch/SwitchCase under the same
  D-numbering. A CUT with no If or Switch block could already report Decision
  coverage and the specification never said where it came from. Masked blocks
  such as Saturation Dynamic and Unit Delay Enabled report BlockType SubSystem
  and stay out of a SearchDepth=1 BlockType scan, as do the control ports of a
  child Enabled or Triggered Subsystem.
- The `DecisionBlocks` cell on the TestSpecification sheet now always prints
  `[T/F]`, and the specific branch kind moved to the `Outcome` column of
  DecisionBlockDetails. The main sheet says where the branches are, the detail
  sheet says what kind they are. MinMax and Multiport Switch used to print
  `[SELECT]` and Switch Case `[CASE]` in the main cell; those rows now read
  `[T/F]` and keep `SELECT` and `CASE` in the detail sheet. Outcome tokens are
  no longer rendered inline, so they were renamed for legibility and grouped by
  branch kind rather than by block: LIMIT, BAND, RATE, ON/OFF, SIGN, INTERVAL,
  LOOP and CONDITION.
- Blocks whose branch parameters are inactive are listed rather than filtered.
  An Integrator with `LimitOutput=off; ExternalReset=none` appears with that
  state in its expression. The column is a static inventory of candidates and
  claims no objective count, so filtering on saved parameters alone would be
  wrong whenever the data type or optimization settings decide the outcome.
  Breakpoint parameters are copied as saved text and never resolved in a
  workspace, so a lookup table configured from a variable shows the variable
  name.
- Block type knowledge moved into `st_specification_decision_catalog`. The scan
  list, the outcome token, the failed-read fallback outcome and the display
  alias were four literal copies of the same table, and the fallback copy only
  ran when an expression read had already failed, so drift there was invisible.
  Adding a type is now one catalog row, and only a type whose expression needs
  special assembly still touches `st_specification_decision_descriptor`.
- File hashing now reads on the Java side instead of copying every chunk
  through MATLAB. The cost was never SHA-256 itself but marshalling the
  bytes across the boundary, which dominated delivery verification once a
  project had hundreds of targets. Files above 256 MB still stream through
  the chunked reader, which also remains the fallback.
- Added scoped warning suppression. `cfg.SuppressedWarnings` lists the
  identifiers to silence while the standalone Harness export drives its
  per-target loop; they are logged once and the caller's warning state is
  restored afterwards. Bare words are rejected so a typo cannot widen into
  suppressing everything. `st_collect_warning_ids` gathers the identifiers
  a run actually emits, which `lastwarn` cannot do.
- `st_check_standalone_coverage` now understands `ExecutionStatus=EXCEPT`.
  A target whose Test Case raised an exception keeps only its standalone
  Harness and input, so it is judged against that reduced contract, the
  expected CVF/CVT/HTML counts exclude it, and an Action WARN explained
  entirely by excepted targets no longer zeroes the manifest bit for every
  target. Such a run reports PARTIAL with an EXCEPT row, never PASS.
  Result filtering and coverage metrics are reported as not applicable for
  an excepted target, while cleanup stays enforced so a leaked execution
  model or an unrestored MATLAB path is still a failure.
- `st_check_standalone_coverage` now scans for forbidden artifacts with a
  single recursive listing instead of five patterns per target directory.
  The unzipped Coverage report puts hundreds of companion assets in every
  target root, so the old scan repeated that walk 5*(targets+1) times.
- The standalone coverage pipeline and the verification snapshot no longer
  run the toolbox dependency analysis. Both build an internal bundle that
  is executed in place rather than delivered, so the informational product
  list never repaid loading every dependency model.
- Added `st_export_test_bundle('AnalyzeProducts', false)` to skip the
  toolbox dependency analysis, which loads every dependency model and can
  outlast the rest of the export. `RequiredProducts` is a bundle README
  hint that no code reads back; the manifest policy records whether the
  analysis ran.
- Standalone Harness export now reports progress. Each target prints a
  start line, the elapsed time of its source-copy save, Harness export and
  standalone save, and a completion line; reused targets are named instead
  of silently skipped. ZIP archiving reports the bundle size first.
- Bundle manifest export now reports what it is doing. Toolbox dependency
  analysis, whole-bundle SHA-256 hashing, and the source-unchanged recheck
  each log a start/complete checkpoint with elapsed time, and the hashing
  loop prints progress every five seconds.
- Fixed standalone Harness export failing to re-identify a library-linked CUT.
  `find_system` defaults stop at a link boundary, so a CUT inside a library
  link reported no ports while its exported copy reported the real ones, and
  the interface could never match. Both sides now resolve links and masks, and
  the failure message lists the candidate blocks with their link status.
- Standalone Harness export no longer runs dependency analysis over every
  branch of the source Top Model. It analyses the generated standalone
  models, copies their union of dependencies, and leaves the configuration
  Top Model unloaded during replay. Actual standalone dependency gaps still
  fail the export rather than producing a partial delivery.
- Added local named model profiles, a generated anonymous FILE/MAT example,
  read-only `st_check_readiness`, and strict `st_run_from_stage` execution.
  Valid predecessors are inspected and reused; invalid predecessors block
  instead of being repaired implicitly. Preparation checkpoints now preserve
  independent input/output readbacks and incomplete-stage status.
- Added hash-verified PACKAGE/SUMMARY regeneration into a new v3 PipelineId,
  recording source provenance and zero new test executions. Existing Action
  once-per-PipelineId rules and v2 reads remain supported. Failed/partial
  derivatives do not replace latest; missing saved evidence blocks regeneration.
- Added Korean task runbooks, behavior tests and disposable R2025b restart
  acceptance cases. Local MATLAB is unavailable; runtime validation is pending.

- Packaged standalone Coverage artifacts now use the safe Test Case name:
  `{TestCaseName}.cvf`, `{TestCaseName}.cvt`, and `{TestCaseName}.html` at the
  target root. The original `cvhtml` report binds a matching short filter name
  so the HTML names the CVF that sits beside it, and the validated absolute CVF
  binding is restored before final metric extraction.
- Fixed the per-CUT Coverage report filter helpers being nested inside
  `capture_package_evidence`, which left them unreachable from the report
  subfunctions that bind and restore the CVF.
- CoverageSummary.xlsx now reports the Decision and Execution objective counts
  next to each percentage (`Decision Executed`, `Decision Total`,
  `Execution Executed`, `Execution Total`). `st_check_standalone_coverage`
  verifies the eleven-column set and the Test Case artifact names.
- Fixed standalone Coverage packaging after per-CUT model cleanup. Each
  original Coverage `cvhtml` report, CVT, and final metric snapshot is now
  captured while its execution model is still open; PACKAGE verifies and
  promotes that evidence without serializing detached Coverage objects. PACKAGE also clears
  a cached prior helper and verifies its active-project implementation contract
  before promotion, preventing mixed revisions in long-lived MATLAB sessions.
- Generate the original Coverage HTML entirely in a short writable scratch
  directory before promoting its ZIP. This avoids the Windows legacy path
  boundary that made long per-CUT names fail with a misleading read-only
  current-directory error.
- Package a Test Manager launcher that resolves CUT-specific standalone
  models and applies each packaged CVF before opening the rewired MLDATX.
  Evidence capture now rechecks that every active coverage object still holds
  the CVF used by the original `cvhtml` report.
- Fixed `st_check_standalone_coverage` returning a 1-by-10 struct array. Its
  ten bit values now remain one field of a scalar summary struct.
- PACKAGE target manifests now preserve the exception identifier, message, and
  call stack; checker details surface the first failing source location.
- Treat a matched CUT with no remaining Coverage objectives as the valid
  zero-denominator metric (`0/0`, `N/A`) instead of an incomplete package.
- Replaced the standalone coverage `STEP*` interface with the default
  `ALL` workflow and explicit `EXECUTE`, `PACKAGE`, and `SUMMARY` actions.
  Each copied Test Case now runs once before one Result CVF registration;
  live results avoid serialization in `ALL`, staged execution optionally
  persists one aggregate Result, packaging emits one CVT and HTML report per
  CUT, and `st_check_standalone_coverage` provides a read-only 10-bit summary.
- Protected library-linked CUTs during Harness creation and reuse. Linked CUT
  Harnesses now use one-way `SyncOnOpen` synchronization, link status and
  reference identity are checked around create/clone operations, and automatic
  Atomic conversion fails safely instead of modifying a linked block. Ordinary
  `FILE+MAT` input no longer requests an SLDV-only Atomic conversion.
- Temporarily allow `FILE+SLDV` MAT files whose recorded subsystem path differs
  from the configured CUT when `cfg.AllowSldvSubsystemPathMismatch=true` (the
  default), while logging a warning and retaining Harness input-interface checks.
- Targets with no usable Harness output now configure an empty verify action and
  report `SKIP_NO_VERIFY_OUTPUT` during verify-timing validation and expected-value
  update. Missing or untested verify results still fail when an output exists.
- Extended `SldvMode=FILE` with explicit `DataFileFormat=SLDV|MAT` and optional
  `MatVariableName`. Ordinary MAT Dataset scenarios are selected deterministically,
  checked for exact interface and time consistency, copied to Signal Editor input,
  and skip SLDV-only parameter processing. Existing workbooks default to `SLDV`.
- Fixed nested-cell `dataNoEffect` handling and centralized Dataset interface
  inspection on the documented `getElementNames` API.
- Fixed specification workbook writing when MaxTime is NaN or text is missing.
  Overflow checks now preserve numeric cells and normalize missing strings to
  empty cells before character conversion.
- Specification export now defaults to the direct Assessment `step2` verify.
  `VerifyMode=ALL_STEPS_COLUMNS` puts each verify-bearing step in a separate
  column. Partial step/transition failures preserve readable verify content,
  and both modes retain full step details and per-step diagnostics.
- Added a numeric `MaxTime` specification column with the input scenario's
  maximum stored signal time in seconds; unavailable times remain blank in Excel.
- Fixed specification-export cleanup after an early error: cleanup callbacks
  now capture their arguments instead of reading cleared nested-workspace
  variables. Unsaved-model rejection still preserves the user's changes.
- Added `st_export_test_specification` to export every saved Assessment scenario
  without test execution. Input last samples are expanded into scalar array/bus
  paths; simple verify equalities become path/value lines. Wrapped Excel cells,
  original step/transition details, lossless overflow, and source guards are included.
- Added the read-only `st_check_actual_system` field diagnostic. It combines
  six environment checks, six PER_CUT run checks, and the existing six CVF
  checks into one transferable 18-bit result code with detailed tables.
- Fixed `st_check_per_cut_cvf` so a diagnostic no longer relies on the
  runtime-target helper that could load a model before its original open
  state was recorded.
- Changed automatic CVF generation to exclude the CUT root and create rules
  only for its direct-child Subsystems. `SUBSYSTEM` uses `BlockInstance`, while
  descendant filtering remains exclusive to `ALL_CONTENT`.
- Added the read-only `st_check_per_cut_cvf` R2025b diagnostic, which reports
  per-target and aggregate six-bit codes for artifact integrity, lifecycle,
  rule count, CUT exclusion, direct-child matching, and mode/action matching.
- Moved PER_CUT result serialization until after transient filter restore
  and added before/after ResultSet coverage integrity checks around MLDATX,
  CVT, CVF-copy, and HTML creation.
- Removed the editable target-model placeholder from tracked configuration.
  Local model name and file path now come only from the Git-ignored
  `runtime_target.mat` created by `st_select_target_model`.
- Fixed a PER_CUT regression where post-run mutation of `cvdata.filter`
  could make Test Manager Coverage Details fail to open. Generated filters
  are now registered through Test Manager for the run, while report export
  copies the CVF without relinking the live result object.
- Fixed PER_CUT ResultSet traversal for direct `run(testCase)` results,
  attached absolute CVF paths to result coverage data, changed each CVF name
  to `{TestCaseName}.cvf`, validates the generated rules after saving,
  and removed Java path canonicalization from result-filter verification.
- Added portable PER_CUT coverage artifacts: standalone detail HTML,
  reloadable CVT data, and copied CVF files while preserving their sources.
- Made result coverage filter verification compatible with MATLAB releases
  that return only the CVF basename or omit the `.cvf` extension on readback.
- Changed `SUBSYSTEM` coverage filtering to use each direct-child Subsystem's
  `BlockInstance`, so the CUT root and descendant primitive blocks remain
  included.
- Added the default PER_CUT `REPLACE` existing-filter policy, which temporarily
  suppresses inherited Test File, Suite, and Test Case CVFs and restores them
  after applying the newly generated Test Case CVF in isolation.
- Applies each PER_CUT CVF through Test Manager during its isolated run. The
  direct-child `BlockInstance` rules keep descendant coverage for `SUBSYSTEM`,
  and portable output copies the CVF without mutating the live Test Manager
  result.
- Fixed incremental SLDV preparation so `OFF` and legacy cached profiles
  use the same canonical structure schema as newly generated profiles.
- Added `AUTO`, `BATCH`, and `PER_CUT` execution policies. Active coverage
  filters now select sequential per-CUT execution for every enabled row while
  all-OFF workbooks retain the legacy `run(tf)` path.
- Added transient CVF sessions with exact Test File, Test Suite, and Test Case
  filter restoration checks, PERSIST rollback, and immediate abort when a
  filter cannot be restored safely.
- Added separate `result/per_cut_runs` bundles and `per_cut_latest.json`, with
  per-target CVF hashes, manifests, initial/final ResultSets, Excel summaries,
  lightweight or full coverage HTML, and optional official PDF reports.

- Added Excel-driven per-Test-Case coverage filters with `OFF`, `SUBSYSTEM`,
  and `ALL_CONTENT` selection, `EXCLUDE`/`JUSTIFY` actions, required
  rationale, API-only `RUNTIME` or `PERSIST` application, managed CVF
  cleanup, incremental workflow checkpoints, and integrated report metadata.
- Changed CUT path discovery to enforce one-to-one subsystem assignment,
  remove already claimed paths from later recommendations, reject duplicate
  existing ownership, and update the management workbook only after every
  selected path passes final validation. Excel row context no longer
  hard-filters candidates.
- Added one-to-one Signal Editor template mapping for existing multi-scenario
  MAT files such as `TestCase_1`, `TestCase_2`, preserving each scenario's
  Harness-only inputs while importing matching SLDV test cases.
- Fixed incremental SLDV cache reuse so `CACHED` remains a report-only
  status, successful manifest profiles stay `OK`, and manifests written by
  the previous behavior are recovered automatically.
- Fixed SLDV verify-result validation to export each complete Verify Run as
  a Dataset and to keep result-table columns aligned when a scenario fails
  before verify counts are available.
- Changed SLDV target preparation so both `FILE` and `GENERATE` modes convert
  non-atomic CUTs to persistent Atomic Subsystems by default, controlled by
  `cfg.AutoConvertSldvTargetsToAtomic`, with the action recorded in results.
- Added the dry-run-first `st_cleanup_results` operator command for scoped
  cleanup of known generated artifacts below `result/`.
- Added a start-to-cleanup operator manual covering public commands,
  prerequisites, side effects, outputs, recovery, and result retention.
- Added `cfg.CheckSharedSignalEditorDataFile = false` as the default so SLDV
  preparation skips the potentially slow all-Harness Signal Editor MAT
  ownership scan, while retaining an explicit opt-in safety check.
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

- Added optional filtering for SLDV Dataset inputs that are absent from the Harness ActiveScenario. `cfg.IgnoreUnexpectedSldvInputs=true` drops those inputs while assembling Signal Editor scenarios and records the ignored names and count; strict failure remains the default.
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

## 2026-09-09 Template Harness clone

- 완전 복사/Import 구현을 backup/harness-full-copy(b6d30a8)에 보존하고 전용 경로만 제거.
- HARNESS_CLONE 행을 sltest.harness.clone + DestinationOwner로 생성하고 기존 입력·Assessment 구성 재사용.
- OverwriteHarness=false 기본값, 교체 recovery clone, 입력 MAT 독립 보존 및 대상 실패 격리 추가.
- 명세서 출력·CVF·일반 생성 동작 유지. MATLAB 런타임 검증은 미수행.
