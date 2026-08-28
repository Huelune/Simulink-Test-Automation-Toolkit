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
- [ ] CI, expanded automated testing, and runtime fixture validation are intentionally deferred in the current task.

## Reporting and operations

- [x] Add target-level incremental preparation checkpoints with non-destructive
  `AUTO` and `FORCE` execution policies.
- [x] Add local run bundles with initial/final results, Decision and Execution
  coverage, Excel summary, official PDF, HTML, and MLDATX artifacts.

- [ ] Select the next release version after MATLAB validation; current changes remain under `Unreleased`.
- [ ] Decide whether machine-readable reports use JSON, JUnit XML, or both in addition to current INI reports.
- [ ] Define redaction rules for model paths, CUT names, and diagnostic errors before reports can be shared.
- [ ] Decide whether project registration and development history will be maintained in the configured development portfolio after the repository baseline is verified.
