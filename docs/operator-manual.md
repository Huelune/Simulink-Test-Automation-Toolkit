# 운영자 매뉴얼

각 단계에서 **실제로 무슨 일이 일어나는지**, 무엇이 바뀌고 무엇이 바뀌지 않는지,
문제가 생기면 어떻게 되돌리는지를 설명합니다.

이 문서는 다음과 중복하지 않습니다. 값의 의미를 찾을 때는 해당 문서를 보십시오.

| 찾는 것 | 문서 |
| --- | --- |
| Excel 열의 뜻과 기본값 | [관리 Excel 열 사전](workbook-reference.md) |
| 전역 설정의 뜻과 기본값 | [설정 사전](config-reference.md) |
| 명령과 옵션 목록 | [실행 명령 사전](execution-commands.md) |
| 오류 대처 | [문제 해결](troubleshooting.md) |
| 용어 | [용어집](glossary.md) |

## 1. 무엇이 바뀌는가

명령을 실행하기 전에 그 명령이 원본을 바꾸는지 아는 것이 중요합니다.

| 분류 | 해당 명령 | 원본 변경 |
| --- | --- | --- |
| 읽기 전용 | `st_pre_validate_targets`, `st_validate_targets`, `st_check_readiness`, `st_check_*`, `st_diagnose_*`, QUICK 검증, `st_export_test_specification` | 의도적으로 저장하지 않음 |
| Excel 변경 | `st_export_subsystem_paths`, `st_fill_temp_paths_from_indent`, `st_find_target_paths` | 관리 Excel을 씁니다 |
| 모델·Test File 변경 | Harness 생성, Signal Editor, Assessment, Test Manager 구성 | 모델과 Test File을 저장합니다 |
| 기대값 변경 | 실행 중 `ExpectedUpdateMode=APPLY` | Assessment의 기대값을 고칩니다 |
| 생성물 | `result/` 아래 전부 | 다시 만들 수 있습니다 |
| 삭제 | `st_cleanup_results('Apply',true)` | 선택한 생성물을 지웁니다 |

처음 실행하기 전에 **모델·Excel·Test File을 백업하십시오.**

## 2. 실행 전 확인

### 2.1 저장 상태

다음을 모두 저장하고, 가능하면 닫으십시오.

- 선택한 Top Model과 로드된 dependency 모델
- 대상 Test File(`.mldatx`)
- `TestManagement.xlsx`
- 현재 쓰는 Signal Editor와 SLDV 입력

저장되지 않은 모델이 있으면 내보내기와 runtime 검증은 실행을 중단합니다. 이것은
정상 동작입니다. 저장되지 않은 상태를 기준으로 삼으면 재현할 수 없기 때문입니다.

### 2.2 같은 이름의 모델

MATLAB은 같은 이름의 모델을 두 개 로드할 수 없습니다. standalone 파이프라인만 원본
Top Model을 저장하고 닫은 뒤 시작하며(`CloseSourceModel` 기본 `true`), 그 밖의
명령은 사용자가 연 모델을 강제로 닫지 않습니다. 충돌이 예상되면 미리 닫거나
MATLAB을 새로 시작하십시오.

### 2.3 상대 경로의 기준

`SldvDataFile`의 상대 경로는 MATLAB의 Current Folder가 아니라
**`TestManagement.xlsx`가 있는 폴더**를 기준으로 해석합니다.

## 3. 기본 실행 순서

```matlab
st_setup
st_pre_validate_targets
st_run_from_harness

st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
```

처음이거나 대상 모델을 바꿀 때만 `st_select_target_model`을 사이에 넣습니다.

Harness가 이미 전부 있으면 생성 단계를 건너뜁니다.

```matlab
st_setup
st_validate_targets
st_run_after_harness
```

기존 SLDV MAT로 Test Case까지만 만들고 실행하지 않으려면:

1. Excel의 `SldvMode`를 `FILE`, `SldvDataFile`에 MAT 경로를 적습니다.
2. `st_run_after_harness('ExecuteTests', false)`를 실행합니다.

## 4. Workflow 단계별 동작

전체 순서는 다음과 같습니다.

```text
CUT 사전 검증
→ HARNESS          누락 Harness 생성
→ SLDV             입력 데이터 준비 (OFF/FILE/GENERATE 전부 포함)
→ HARNESS_CONFIG   StopTime 등 Harness 설정
→ SIGNAL_EDITOR    Scenario MAT 생성과 연결
→ ASSESSMENT       verify 문장 구성
→ TEST_MANAGER     Test File, Test Case, Iteration 구성
→ ALIGNMENT        Scenario와 Iteration 정렬 검사 (검사만)
→ EXECUTE          테스트 실행 → 기대값 갱신 → 재실행 → 실행 기록 저장
```

**여기까지가 workflow입니다.** 보고서와 제출물은 그다음 단계이고, 어느 쪽을 만들지는
호출자가 고릅니다.

```text
                    실행 기록 (result/run_records/)
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
  결과 정리 (Harness 미포함)          제출물 (Harness 내보냄)
  st_generate_test_report            st_run_standalone_coverage_pipeline
  st_collect_per_cut_results         st_check_standalone_coverage
```

커버리지 필터(CVF)는 오른쪽 두 갈래에서만 만들어집니다. workflow는 커버리지를
필터 없이 수집만 합니다.

### 4.1 HARNESS — Harness 생성

- **기존 Harness는 지우지 않습니다.** 없는 것만 만듭니다.
- Harness 생성은 모델 컴파일을 포함하므로 CUT 하나에 수 분 이상 걸릴 수 있습니다.
- 라이브러리에 링크된 CUT의 Harness는 `SyncOnOpen`으로 만들거나 보정합니다. Harness를
  닫을 때 CUT 복사본이 원본 모델로 역전파되지 않게 하기 위해서입니다.
- 생성·복제 전후의 `StaticLinkStatus`와 `ReferenceBlock`이 달라지면
  `HarnessChangedLibraryLink`로 즉시 중단합니다. **이때 모델을 저장하지 마십시오.**

### 4.2 SLDV — 입력 데이터 준비

단계 이름은 `SLDV`지만 `OFF`와 `FILE` 대상의 입력 준비도 여기서 합니다.

#### `SldvMode=OFF`

Harness에 이미 있는 입력을 그대로 씁니다. 기존 ActiveScenario의 이름만
`UT_REQ_{CUTName}_001`로 바꾸고 Test Case의 `SignalEditorScenario`에 연결합니다.

CUT에 직계 Inport가 없어도, Harness에 Signal Editor가 있으면 그대로 연결합니다.
Signal Editor 블록 자체가 없을 때만 입력 없이 진행하며 WARN을 남깁니다. 블록은
있는데 MAT이나 ActiveScenario가 손상됐으면 그 대상 준비를 실패로 기록합니다.

#### `SldvMode=FILE` + `DataFileFormat=SLDV`

Design Verifier가 만든 `sldvData` 구조체를 읽고 TestCase parameter override도 함께
적용합니다.

Harness의 기존 Signal Editor MAT에 `TestCase_1`, `TestCase_2`처럼 여러 Scenario가 이미
있으면 SLDV 원본 TestCase 번호와 일대일로 맞춰 각각의 템플릿으로 씁니다. 그래서
SLDV가 구동하지 않는 Harness 외부 입력도 각 Scenario의 기존 값으로 보존됩니다.
번호로 맞출 수 없을 때만 `ActiveScenario` → `InputScenario` → 유일한 Dataset 순으로
단일 템플릿을 고르며, 둘 이상이 모호하게 남으면 임의로 고르지 않고 실패합니다.

#### `SldvMode=FILE` + `DataFileFormat=MAT`

MAT 안의 비어 있지 않은 scalar `Simulink.SimulationData.Dataset` 변수를 입력
Scenario로 씁니다.

- 변수명이 정렬 순서를 결정합니다. `MatVariableName`을 지정하면 그 변수만 씁니다.
- 여러 Scenario의 입력 개수·순서·이름·자료형·차원이 모두 같아야 하고, Harness의
  ActiveScenario 인터페이스와도 정확히 일치해야 합니다.
- 종료 시각은 각 Dataset 안 모든 입력 신호의 마지막 시간 중 최댓값입니다.
  **시간 정보가 전혀 없으면 임의 시간을 만들지 않고 실패합니다.**
- parameter payload가 없으므로 `ParameterCount=0`이며 `sldvsimdata`와
  `st_apply_sldv_parameters`를 호출하지 않습니다.

#### `SldvMode=GENERATE`

Top Model의 현재 Design Verifier 설정을 복사해 CUT에 TestGeneration을 실행합니다.
성공한 데이터는 다음에 저장되므로 이후 `FILE`로 재사용할 수 있습니다.

```text
result/sldv/{No}_{CUTName}/latest_sldvdata.mat
```

이 파일은 생성된 TestCase를 전부 담습니다. 그중 일부만 쓰려면 Excel의
`SldvTestCases` 열에 번호를 적습니다(`1,3,5` 또는 `2-4`). 빈 값이면 전부 씁니다.
선택은 파일을 읽을 때 적용되므로, `FILE`로 재사용하면서 선택만 바꿀 수 있습니다.
자세한 규칙은 `docs/workbook-reference.md`의 `SldvTestCases`를 보십시오.

#### Atomic Subsystem 요구

`FILE+SLDV`와 `GENERATE` 대상은 Atomic이어야 합니다. 기본 설정은 라이브러리 링크가
없는 CUT만 자동으로 바꿔 줍니다. 링크된 CUT은 원본 훼손을 막기 위해
`SldvLinkedCUTRequiresAtomic`으로 중단합니다. 일반 `FILE+MAT`에는 이 제약이 없으며
`AtomicAction=NOT_REQUIRED_MAT`로 기록됩니다.

#### Tmax

각 CUT의 가장 늦은 SLDV 종료 시각을 `Tmax`로 씁니다. 기본적으로 0.01초 격자에
올림해서 Harness StopTime, Assessment transition, 기대값 sampling에 동일하게
적용합니다.

### 4.3 ASSESSMENT — verify 문장 구성

- 실제 Input symbol의 Port 순서에서 Signal Editor 입력 수만큼 건너뛴 뒤, Harness
  Outport와 **위치로** 연결합니다.
- 이름에서 `/`를 제거하거나 임의로 정규화해서 signal을 추측하지 않습니다.
- scalar, numeric array, Bus, nested Bus를 지원합니다. Bus 배열은 기본적으로 첫 Bus
  인스턴스만 검증합니다(`cfg.VerifyFirstBusElementOnly`).

`cfg.VerifyHarnessOutportsOnly=true`(기본)일 때 쓸 수 있는 Harness 출력 신호가 하나도
없으면 verify가 빈 Action으로 구성됩니다. 실행 후 verify timing 검사와 기대값 갱신은
`SKIP_NO_VERIFY_OUTPUT`으로 건너뜁니다. **정상 구성입니다.** 반면 출력이 있는데
verify 결과가 없거나 `Untested`이면 계속 실패로 처리합니다.

### 4.4 TEST_MANAGER — Test Case 구성

- 기본 정책은 `cfg.OverwriteTestFile=false`인 증분 갱신입니다.
- 기존 Test File과 Test Case를 보존하고 없는 Test Case만 추가합니다.
- SLDV 행은 대상 Test Case의 Iteration만 Scenario 수에 맞게 다시 구성합니다.
- 다른 열린 Test Manager 파일을 전역으로 제거하지 않습니다.

### 4.5 ALIGNMENT — 정렬 검사

입력 Scenario 수와 Iteration 수가 맞는지 확인합니다. 입력 MAT을 바꾼 뒤 Test Manager
단계를 다시 실행하지 않았을 때 여기서 걸립니다.

## 5. 증분 준비와 단계 재실행

### 5.1 어떻게 재사용하는가

기본 준비 모드는 `AUTO`입니다. Excel 행, 설정, 모델, Test File, SLDV 입력, 그리고
이 도구의 코드까지의 fingerprint가 마지막 성공 checkpoint와 같으면 그 단계를
재사용합니다.

상태는 두 파일에 저장됩니다.

```text
result/state/workflow_state.mat
result/state/workflow_state.json
```

성공한 대상은 즉시 checkpoint합니다. 준비 중 한 대상이 실패하면 다른 대상의 준비
결과는 남기지만, **일관되지 않은 Test File로 실행을 시작하지는 않습니다.**

준비 단계가 전부 캐시되어도 `cfg.RunGeneratedTests=true`이면 테스트는 매번
실행합니다.

### 5.2 다시 실행하기

평소에는 이것으로 충분합니다.

```matlab
st_run_from_harness('PreparationMode','FORCE');                      % 전부 다시
st_run_from_harness('PreparationMode','FORCE', 'FromStage','SLDV');  % 그 단계부터
```

| 무엇이 바뀌었나 | `FromStage` |
| --- | --- |
| 입력 MAT 또는 SLDV 설정 | `SLDV` |
| Harness StopTime 등 설정 | `HARNESS_CONFIG` |
| verify 대상 또는 Assessment 구성 | `ASSESSMENT` |
| Coverage 필터 설정 | `TEST_MANAGER` |
| Test Case 이름 또는 Iteration | `TEST_MANAGER` |
| 아무것도 안 바뀜, 테스트만 다시 | `EXECUTE` |

> **`FromStage`는 앞 단계를 "건너뛰라"는 뜻이 아닙니다.** (`'EXECUTE'`는 예외입니다.
> 준비 단계를 하나도 실행하지 않고 바로 테스트로 갑니다.) `st_build_execution_plan`은
> 지정 단계부터 `dirty`로 표시할 뿐이고, 그보다 앞 단계는 여전히 checkpoint와
> fingerprint로 판정합니다. checkpoint가 없거나(단계 명령을 직접 부른 경우 등) 모델이
> 바뀌었으면 앞 단계도 함께 실행됩니다.
>
> 앞 단계 재실행을 **확실히 막는** 것은 선택 기능인 `st_check_readiness` +
> `st_run_from_stage`뿐입니다. 앞 단계를 읽기 전용으로 검증한 뒤 유효하면 그보다 앞을
> `CACHED`로 못 박고, 유효하지 않으면 자동으로 고치지 않고 중단합니다. 절차는
> [재시작](manual/restart.md)에 있습니다.

단계를 하나씩 끊어서 실행하려면
[단계별로 끊어서 실행하기](manual/step-by-step.md)를 보십시오.

### 5.3 checkpoint만 지우기

```matlab
st_cleanup_results('Scope','STATE')              % 계획만
st_cleanup_results('Scope','STATE','Apply',true) % 실제 삭제
```

## 6. 기대값 갱신

기본값은 다음과 같습니다.

```matlab
cfg.ExpectedUpdateMode = 'APPLY';
cfg.ExpectedValueSampleTime = 0.01;
cfg.RerunAfterExpectedUpdate = true;
```

`APPLY`는 실패한 Iteration만 처리하고, 실제값과 현재 기대값이 다를 때만
`verify(... == 기대값)`을 고칩니다. 자동 갱신 대상은 실수 스칼라와 logical
스칼라입니다. 배열과 Bus Assessment를 **생성**할 수 있다는 것이 배열·Bus 기대값의
**자동 갱신**까지 된다는 뜻은 아닙니다.

값이 하나라도 바뀌고 `RerunAfterExpectedUpdate=true`이면 같은 범위를 다시
실행합니다. `PER_CUT`에서는 같은 CVF를 유지한 채 그 Test Case만 재실행한 뒤 필터를
복원합니다.

후보를 사람이 검토한 뒤 승인하는 `REVIEW` 모드는 아직 없습니다.

> 기대값을 바꿀 의도가 없다면 Excel 행과 전역 기본값을 모두 `OFF`로 두십시오.

## 7. CUT별 CVF 격리와 Coverage

Test File Coverage는 Decision으로 설정하며, 여기에 포함되는 Block Execution을 함께
수집합니다.

### 7.1 필터 규칙이 만들어지는 방식

필터 규칙은 CUT 자체가 아니라 **직속 하위 Subsystem마다** 만듭니다.

| 설정 | 대상 |
| --- | --- |
| `CoverageFilterMode=SUBSYSTEM` | 직속 하위 Subsystem 블록 인스턴스만 |
| `CoverageFilterMode=ALL_CONTENT` | 직속 하위 Subsystem과 그 내부 전체 |
| `CoverageBoundaryMode=CUT_ONLY` | 실행 루트에서 CUT 밖의 최상위 블록 |

`CoverageBoundaryMode`는 `CoverageFilterMode`와 **독립적으로** 조합합니다. 실행
Harness나 standalone 모델에서 CUT과 이름·인터페이스가 일치하는 블록을 찾고, CUT
외부 최상위 Subsystem에는 `SubsystemAllContent`, 나머지 최상위 블록에는
`BlockInstance` EXCLUDE 규칙을 표준 사유로 추가합니다.

따라서 `CoverageFilterMode=OFF` + `CoverageBoundaryMode=CUT_ONLY`도 CVF를 만듭니다.
둘 다 `OFF`이고 직속 하위 Subsystem이 없으면 규칙 0개짜리 CVF가 만들어집니다.
**오류가 아닙니다.** CVF는 실행 방식을 바꾸지 않습니다.

CVF는 저장 직후 다시 열어 규칙 수와 action을 검증합니다. 제대로 열리지 않으면 그
CUT을 `FAIL`로 기록합니다.

### 7.2 PER_CUT의 안전 순서

```text
CVF 생성
→ Test File·Suite·Test Case의 기존 필터 목록 백업
→ 기존 필터를 임시 해제
→ 새 CVF를 Test Manager 실행 설정에 임시 등록
→ run(testCase)로 해당 CUT의 필터된 Coverage 수집
→ APPLY 변경이 있으면 같은 CVF로 재실행하고 최종 결과 저장
→ 원래 필터 복원
→ 실제 설정을 다시 조회해 일치 확인
→ ResultSet 무결성을 확인하며 MLDATX·CVT·CVF 사본·HTML 저장
→ 다음 CUT
```

- 다른 Test Case의 `Enabled` 상태는 바꾸지 않습니다.
- 기존 수동 필터는 실행 후 복원하며, `CoverageFilterExistingPolicy='MERGE'`일 때만
  새 CVF와 함께 적용합니다.
- 결과 산출물은 임시 필터를 원복한 뒤 만듭니다. 보존 전후로 `cvdata`의
  ID·루트·CVF 참조가 달라지면 그 CUT을 실패로 기록합니다.

> **필터 복원 또는 복원 검증에 실패하면 설정 누출 위험이 있으므로
> `ContinueOnFailure=true`여도 전체 실행을 즉시 중단합니다.** 이것은 설정으로 끌 수
> 없습니다.

### 7.3 커버리지 수치 읽기

- 분모가 0이면 `N/A`, justified outcome은 별도 수치로 기록합니다.
- 다른 checksum의 Coverage를 하나의 합계로 섞지 않습니다.
- 커버리지 미달 자체는 테스트 실패로 바꾸지 않습니다.

### 7.4 실행 후 점검

```matlab
[code, details] = st_check_per_cut_cvf();     % CVF만 6비트
summary = st_check_actual_system();            % 환경+실행+CVF 18비트
```

두 명령 모두 모델·Test File·CVF를 저장하거나 변경하지 않습니다. 비트의 의미는
[실행 명령 사전 10장](execution-commands.md#10-상태-점검)에 있습니다.

## 8. 결과 구조

### 8.0 실행 기록과 결과 정리

실행과 결과 정리는 별개의 단계입니다. 실행이 끝나면 아래가 남습니다.

```text
result/run_records/{record-id}/
├── initial.mldatx     # INITIAL ResultSet
├── final.mldatx       # 재실행이 있었을 때만 별도 파일
└── run_record.mat     # 기대값 갱신·커버리지 필터·workflow 표
result/run_record_latest.json
```

Test Manager의 ResultSet은 그 실행을 한 MATLAB 세션 안에서만 살아 있습니다.
이 기록이 있어야 나중에, 또는 다른 세션에서 보고서를 만들 수 있습니다.

```matlab
st_generate_test_report('RunRecord', 'LATEST')
```

이 명령이 아래 8.1의 통합 보고서를 만듭니다. `cfg.GenerateTestReport = true`로
두면 실행 직후 자동으로 만들어집니다 (기본은 `false`).

### 8.1 BATCH 통합 보고서

```text
result/runs/{timestamp}_{run-id}/
├── TestSummary.xlsx
├── manifest.json
├── official/
│   ├── InitialTestResults.pdf
│   └── FinalTestResults.pdf
├── coverage/
│   └── {coverage-root}.html
└── raw/
    ├── InitialResults.mldatx
    └── FinalResults.mldatx
```

`TestSummary.xlsx`에는 `Overview`, `Targets`, `Iterations`, `Coverage`,
`CoverageFilters`, `ExpectedUpdates`, `Workflow`, `Metadata` 시트가 있습니다.
`result/latest.json`과 `result/TestSummary.xlsx`가 최신 통합 실행을 가리킵니다.

### 8.2 PER_CUT 개별 보고서

```text
result/per_cut_runs/{run-id}/
├── TestSummary.xlsx          # 모든 CUT의 최종 상태 인덱스
├── manifest.json
├── targets/
│   └── {No}_{CUTName}_{hash}/
│       ├── target-manifest.json   # CVF SHA-256, action, rationale, 적용·복원 상태
│       ├── filter/{TestCaseName}.cvf
│       ├── initial/
│       │   ├── TestSummary.xlsx
│       │   ├── raw/InitialResults.mldatx
│       │   ├── coverage/
│       │   │   ├── CoverageSummary.html
│       │   │   ├── data/*.cvt
│       │   │   ├── filters/{TestCaseName}.cvf
│       │   │   └── detail/...
│       │   └── official/InitialTestResults.pdf
│       └── final/                 # 기대값 변경 후 실제 재실행한 경우에만
└── logs/execution.log
```

- `SUMMARY`: Excel, MLDATX, 경량 Coverage HTML.
- `FULL`: 위에 공식 PDF와 전체 Coverage HTML 추가.
- 두 모드 모두 `coverage/data/`에 CVT 원본, `coverage/filters/`에 적용한 CVF 사본,
  `coverage/detail/`에 독립 Coverage Detail HTML과 동반 리소스를 만듭니다.

> **결과를 전달할 때는 HTML 파일 하나가 아니라 `initial/` 또는 `final/` 폴더 전체를
> 복사해야 합니다.** HTML은 옆에 있는 리소스 파일 없이는 제대로 렌더링되지 않습니다.

`filter/{TestCaseName}.cvf`는 PER_CUT 실행 중간물이며 standalone 제출물의 `UT_REQ_`
이름 규칙과 다릅니다. CVF 활성 CUT에만 만들어지고, Test Case 실행 전에 그 폴더를
MATLAB path에 등록하고 ResultSet coverage에도 절대 경로로 연결합니다.

`result/per_cut_latest.json`이 최신 CUT별 실행을 가리킵니다. 이 경로는
`result/latest.json`과 `result/runs/`를 건드리지 않습니다.

## 9. 진행 로그

```matlab
cfg.VerboseLogging = true;   % 기본값
```

오래 걸리는 MATLAB API 호출 앞뒤에 timestamp, 단계, 대상, 경과 시간을 출력합니다.
blocking API 내부의 실제 진행률은 알 수 없으므로 **마지막 `START` 로그가 현재 대기
위치입니다.**

`PER_CUT`의 상세 순서는 각 실행의 `logs/execution.log`에서 확인합니다.

경고가 너무 많이 나오면 `cfg.SuppressedWarnings`에 식별자를 등록할 수 있습니다.
숨긴 경고도 한 번은 기록되고 끝나면 복원됩니다.

## 10. 자주 쓰는 조합

### 기존 Harness + 기존 SLDV MAT + Test Case까지만

```text
Targets.SldvMode       = FILE
Targets.SldvDataFile   = <Excel 기준 MAT 상대경로>
Targets.DataFileFormat = SLDV
```

```matlab
st_setup
st_run_after_harness('ExecuteTests', false);
```

### 준비 상태를 무시하고 SLDV부터 다시

```matlab
st_run_after_harness('PreparationMode','FORCE', 'FromStage','SLDV');
```

### checkpoint만 지우고 다시 판단

```matlab
st_cleanup_results('Scope','STATE','Apply',true)
st_run_after_harness
```

### 제출물만 다시 만들기

준비와 테스트 실행은 그대로 두고 standalone 제출물만 새로 만듭니다.

```matlab
st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', 'ContinueOnFailure', true, 'FailOnNonPass', false);
[code, summary, details] = st_check_standalone_coverage();
```

원본 Top Model과 열린 Harness는 파이프라인이 저장하고 닫습니다
(`CloseSourceModel` 기본 `true`).

### 실행 후 빠른 점검

```matlab
summary = st_check_actual_system();
```

### 앞 단계를 보존한 채 중간부터 (선택 기능)

```matlab
[ready, checks] = st_check_readiness('Workflow','AFTER_HARNESS','FromStage','ASSESSMENT');
disp(checks)
st_run_from_stage('Workflow','AFTER_HARNESS','FromStage','ASSESSMENT');
```

## 11. 안전 경계 요약

이 도구가 **의도적으로 하지 않는** 일입니다.

- 기존 Harness를 지우고 다시 만들지 않습니다.
- 기존 Test Case를 기본 설정에서 덮어쓰지 않습니다.
- 라이브러리 링크된 CUT을 자동으로 수정하지 않습니다.
- 사용자가 연 모델을 강제로 닫지 않습니다. 예외는 standalone 파이프라인의 원본
  Top Model이며, 저장한 뒤에만 닫고 변경을 폐기하지 않습니다.
- 다른 열린 Test Manager 파일을 전역으로 제거하지 않습니다.
- 사람이 건 수동 Coverage Filter를 지우지 않습니다.
- `result/` 밖의 사용자 파일을 정리 대상으로 선택하지 않습니다.
- 보고서를 외부 시스템으로 자동 전송하지 않습니다.
- 병렬 CUT 실행을 하지 않습니다.
- 커버리지 미달을 테스트 실패로 바꾸지 않습니다.
- 없는 산출물을 만들어 PASS로 위장하지 않습니다.

## 12. 실패했을 때

확인 순서와 오류별 대처는 [문제 해결](troubleshooting.md)에 정리했습니다.

`Ctrl+C`로 중단했다면 열린 Harness와 모델의 Dirty 상태를 먼저 확인하고, 저장 여부를
판단한 뒤 다시 실행하십시오. 증분 checkpoint는 성공한 단계만 재사용하므로 중단된
단계는 다시 실행됩니다.
