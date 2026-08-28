# Target Architecture

## Decision

The current root-level functions remain in place until the MATLAB workflow can be regression-tested. Moving approximately fifty public functions in the same change as behavior updates would make failures difficult to isolate.

The target structure is a MATLAB package with a small public API, domain-oriented internal modules, separate test levels, anonymized examples, and supporting tools.

```text
Simulink-Test-Automation-Toolkit/
├── src/
│   └── +simtest/
│       ├── setup.m
│       ├── selectModel.m
│       ├── validate.m
│       ├── generate.m
│       ├── run.m
│       └── +internal/
│           ├── +config/
│           ├── +targets/
│           ├── +harness/
│           ├── +sldv/
│           ├── +scenarios/
│           ├── +assessment/
│           ├── +testmanager/
│           ├── +execution/
│           └── +reporting/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── examples/
├── docs/
└── tools/
```

## Public workflow

| API | Responsibility |
| --- | --- |
| `simtest.setup` | Add the package path and verify runtime prerequisites |
| `simtest.selectModel` | Select and persist one runtime Top Model |
| `simtest.validate` | Validate workbook schema, CUT paths, Harness mappings, and configuration without mutation |
| `simtest.generate` | Create or update Harness, scenarios, Assessment, and Test Manager content |
| `simtest.run` | Execute selected tests and apply the configured expected-value policy |

## Configuration precedence

```text
safe built-in default
    -> st_config global project option
        -> Targets row override
```

Only explicitly documented row-level options override global settings. Invalid values fail before the model or Test File is changed.

## Migration stages

1. Stabilize current behavior and add tests around pure functions and configuration parsing.
2. Introduce `src/+simtest` entry points while retaining root `st_*` compatibility wrappers.
3. Move one domain at a time, starting with config/targets/reporting and then the Simulink-dependent modules.
4. Run the full MATLAB fixture regression after each domain move.
5. Remove compatibility wrappers only in a separately announced major release.

## Boundaries

- Excel and configuration parsing must not call Simulink mutation APIs.
- Validation must complete before Harness, model, Test File, or expected values are modified.
- Expected-value generation and approval are separate responsibilities; only the existing explicit `APPLY` mode mutates values today.
- Reports must be reproducible outputs and must not be required as inputs for the next run.
- Real models, workbooks, MAT files, and generated results are not repository fixtures.
