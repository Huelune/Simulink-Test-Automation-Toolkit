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
│   ├── scenarios/
│   └── shared/
├── diagnostics/
│   ├── matlab/
│   └── python/
├── tests/
│   └── unit/
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
| `reporting`, `shared`, `scenarios` | Cross-domain result, path, lifecycle, and naming helpers |

## Path and compatibility rules

- `st_setup.m` stays at the repository root and is the only MATLAB bootstrap file there.
- `st_project_root()` resolves the root through `st_setup.m`; source files must not assume their own folder is the project root.
- Existing `st_*` public commands remain callable after `st_setup` and are not renamed during this migration.
- Diagnostics remain public commands but live outside production source code.
- Archived handoff documents preserve historical evidence and are not current implementation instructions.

## Configuration precedence

```text
built-in project default
    -> st_config global option
        -> Targets row override
```

Only documented row-level options override global settings. Invalid values fail before the model or Test File is changed.

## Future package target

After MATLAB regression validation, a small `+simtest` package can be introduced for `setup`, `selectModel`, `validate`, `generate`, and `run`. Existing `st_*` functions should remain compatibility wrappers until a separately announced major release.

## Boundaries

- Excel and configuration parsing must not call Simulink mutation APIs.
- Validation must complete before Harness, model, Test File, or expected values are modified.
- Expected-value generation and approval are separate responsibilities; only explicit `APPLY` behavior mutates values.
- Reports are reproducible outputs and are not inputs for the next run.
- Real models, workbooks, MAT files, and generated results are not repository fixtures.
