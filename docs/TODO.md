# TODO and Deferred Decisions

This file records decisions that are intentionally not presented as implemented features.

## Safety and expected values

- [ ] Define `REVIEW` output format, candidate storage, diff presentation, approval command, and rejection behavior.
- [ ] Decide whether approved baselines live in Git, an artifact store, or a project-specific external directory.
- [ ] Add tolerance-aware Baseline Criteria without automatically recapturing approved baselines.
- [ ] Add a mutation plan/dry-run that lists Harness, Assessment, Test Manager, and expected-value changes before applying them.

## Examples and onboarding

- [ ] Create an anonymized `examples/TestManagement.example.xlsx` matching the README schema.
- [ ] Create a minimal redistributable Simulink model and expected workflow output.
- [ ] Decide whether the example requires SLDV or keeps SLDV as a separate advanced example.
- [ ] Rename the local working directory from the historical misspelling when workspace migration is safe.

## Package migration

- [ ] Introduce the `src/+simtest` public API described in `docs/architecture.md`.
- [ ] Define the compatibility period for the current root `st_*` entry points.
- [ ] Split the large Signal Editor, SLDV preparation, path finder, and expected-value updater files by responsibility.
- [x] Keep diagnostic utilities as public `st_*` commands under `diagnostics/matlab`.
- [x] Preserve `WORK_HANDOFF.md`, `PATCH_NOTES.txt`, and `README_REPLACEMENT_FILES.txt` under `docs/archive`.
- [ ] Consolidate useful archive content into current documentation before removing any archived file.

## Compatibility and validation

- [ ] Decide the supported MATLAB release range, including whether R2024a is supported or only accepted as a model source version.
- [ ] Run the documented MATLAB R2025b end-to-end validation on an approved machine.
- [x] Add QUICK/RUNTIME/CERTIFY verification code, generated fixture builders,
  source-isolated runtime checks, and Excel/JSON/JUnit result writers.
- [ ] Run and preserve the first MATLAB R2025b `CERTIFY + BOTH` result. The
  current non-MATLAB development environment cannot provide runtime evidence.
- [ ] Connect the normalized JUnit output to CI after the first R2025b result
  establishes runtime duration and license behavior.

## Reporting and operations

- [x] Add target-level incremental preparation checkpoints with non-destructive
  `AUTO` and `FORCE` execution policies.
- [x] Add local run bundles with initial/final results, Decision and Execution
  coverage, Excel summary, official PDF, HTML, and MLDATX artifacts.
- [x] Add a standalone, non-destructive export command that packages the saved
  internal Harness model, inputs, Test File, dependencies, and reference report
  and creates a fresh workspace for every recipient rerun.
- [ ] Validate the exported bundle end-to-end on MATLAB R2025b: internal Harness
  preservation, dependency completeness, Signal Editor/SLDV path rewriting,
  repeated runs, and reference-result comparison.
- [ ] Define policy for external resources that dependency analysis cannot copy,
  such as environment variables, private services, and licensed custom code.
- [ ] Decide whether export requires a MATLAB Project so user-added Test File
  baseline, callback, requirement, and custom-criteria dependencies can be
  discovered and packaged in addition to toolkit-managed inputs.

- [ ] Select the next release version after MATLAB validation; current changes remain under `Unreleased`.
- [x] Use both JSON and JUnit XML, with Excel as the human-readable verification summary.
- [ ] Define redaction rules for model paths, CUT names, and diagnostic errors before reports can be shared.
- [ ] Decide whether project registration and development history will be maintained in the configured development portfolio after the repository baseline is verified.
