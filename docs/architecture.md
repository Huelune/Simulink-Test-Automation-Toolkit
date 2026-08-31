# Repository Architecture

## Current structure

The repository now uses a transitional domain-based layout. Existing `st_*` names remain unchanged, and `st_setup.m` registers the source and MATLAB diagnostic folders.

```text
Simulink-Test-Automation-Toolkit/
├── st_setup.m
├── src/
│   ├── workflow/
│   ├── config/
│   ├── targets/
│   ├── harness/
│   ├── sldv/
│   ├── signal_editor/
│   ├── assessment/
│   ├── test_manager/
│   ├── execution/
│   ├── reporting/
│   ├── exporting/
│   ├── verification/
│   ├── maintenance/
│   ├── scenarios/
│   └── shared/
├── diagnostics/
│   ├── matlab/
│   └── python/
├── tests/
│   ├── unit/
│   └── fixtures/
├── examples/
└── docs/
    └── archive/
```

| Area | Responsibility |
| --- | --- |
| `workflow` | Full and existing-Harness orchestration entry points |
| `config`, `targets` | Project settings, workbook parsing, model/CUT discovery and validation |
| `harness`, `sldv`, `signal_editor` | Expensive model preparation and scenario data generation |
| `assessment`, `test_manager` | Verification logic, Test Case, Iteration, and alignment management |
| `execution` | Test execution and expected-value update |
| `exporting` | Immutable template bundle, dependency and input collection |
| `verification` | QUICK/RUNTIME/CERTIFY orchestration, status aggregation, manual evidence and Excel/JSON/JUnit writers |
| `maintenance` | Dry-run-first cleanup of known generated result artifacts |
| `reporting`, `shared`, `scenarios` | Cross-domain result, path, lifecycle, and naming helpers |

## Path and compatibility rules

- `st_setup.m` stays at the repository root and is the only MATLAB bootstrap file there.
- `st_project_root()` resolves the root through `st_setup.m`; source files must not assume their own folder is the project root.
- Existing `st_*` public commands remain callable after `st_setup` and are not renamed during this migration.
- Diagnostics remain public commands but live outside production source code.
- Archived handoff documents preserve historical evidence and are not current implementation instructions.

## Configuration precedence

```text
project default
    -> st_config global option
        -> Targets row override
            -> one-run call option
```

Only documented row-level options override global settings. Invalid values fail before the model or Test File is changed.

## Future package target

After MATLAB regression validation, a small `+simtest` package can be introduced for `setup`, `selectModel`, `validate`, `generate`, and `run`. Existing `st_*` functions should remain compatibility wrappers until a separately announced major release.

## Boundaries

- Excel and configuration parsing must not call Simulink mutation APIs.
- Validation must complete before Harness, model, Test File, or expected values are modified.
- Expected-value generation and approval are separate responsibilities; only explicit `APPLY` behavior mutates values.
- Reports are reproducible outputs and are not inputs for the next run.
- Each test execution owns an immutable directory under `result/runs`.
  Initial and final Test Manager ResultSets remain distinct, while
  `result/latest.json` and the latest workbook are replaceable pointers.
- Coverage aggregation is outcome-weighted only across compatible CUT
  checksums. Coverage thresholds are report-only and do not alter test
  outcomes.
- Report bundles are local artifacts and have no Notion or repository
  publishing side effect.
- Incremental workflow state is an operational cache under `result/state`.
  It is never a source of truth: missing, corrupt, or mismatched state widens
  execution to the earliest safe preparation stage.
- Workflow entry points build a per-target stage plan. Domain functions keep
  their direct no-argument behavior and accept an internal optional row
  selection only when invoked by the workflow coordinator.
- Real models, workbooks, MAT files, and generated results are not repository fixtures.
- Verification fixtures are MATLAB builders. Generated SLX/XLSX/MAT/MLDATX
  files exist only under the run workspace.
- QUICK may write only under `result/verification`; it records and restores
  model/Test File session state and does not run simulations.
- RUNTIME and CERTIFY execute actual project inputs through an isolated export
  snapshot. Source model, Test File, Excel, dependencies, Signal Editor and
  SLDV input checksums must remain unchanged.
