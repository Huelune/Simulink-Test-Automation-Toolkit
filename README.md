# Simulink Test Automation Toolkit

MATLAB/Simulink Test 자동화 도구입니다. Excel에서 CUT, Harness, Test Case 정보를 읽어 Harness 구성, Signal Editor 및 Test Assessment 설정, Test Manager 생성, 테스트 실행과 expected-value 갱신까지 수행합니다.

저장소: [Huelune/Simulink-Test-Automation-Toolkit](https://github.com/Huelune/Simulink-Test-Automation-Toolkit)

| 항목 | 현재 기준 |
| --- | --- |
| 버전 | v0.9.6 candidate 기반 `Unreleased` |
| 기본 브랜치 | `main` |
| 개발 상태 | 기능 후보, 실제 MATLAB end-to-end 재검증 필요 |
| 확인된 근거 | 코드 정적 검토, 생성된 Harness의 Assessment 입력 순서 수동 확인 |
| 미확인 범위 | MATLAB R2025b 전체 workflow와 SLDV FILE/GENERATE 실행 |

현재 `main`의 코드를 기준으로 설명합니다. 검증하지 않은 workflow를 완료된 기능으로 간주하지 않습니다.

## Requirements

| 구성 요소 | 필요 범위 | 비고 |
| --- | --- | --- |
| MATLAB R2025b | 필수 | 현재 문서 기준 버전 |
| Simulink | 필수 | 원본 모델은 R2024a에서 작성되었을 수 있음 |
| Simulink Test | 필수 | Harness, Test Sequence, Test Manager 사용 |
| Simulink Design Verifier | `SldvMode=GENERATE`에서 필수 | `OFF`와 기존 파일을 쓰는 `FILE`에는 생성 기능 불필요 |
| `TestManagement.xlsx` | 필수 | `Targets` Sheet 사용 |

### Targets Sheet

| 열 | 필수 | 기본값 | 설명 |
| --- | --- | --- | --- |
| `CUTName` | 예 | 없음 | 대상 Subsystem 이름 |
| `CUTPath` | 예 | 없음 | 선택한 Top Model 아래 CUT 경로 |
| `HarnessName` | 예 | 없음 | 생성하거나 재사용할 Harness 이름 |
| `TestCaseName` | 예 | 없음 | Test Manager Test Case 이름 |
| `No` | 아니요 | Excel 행 순서 | 결과 및 SLDV 폴더 식별 번호 |
| `Enabled` | 아니요 | `true` | `cfg.OnlyEnabled=true`일 때 실행 대상 선택 |
| `SldvMode` | 아니요 | `OFF` | `OFF`, `FILE`, `GENERATE` |
| `SldvDataFile` | 조건부 | 빈 값 | `FILE`일 때 필수. 절대 경로 또는 workbook 기준 상대 경로 |
| `ExpectedUpdateMode` | 아니요 | `DEFAULT` | `DEFAULT`, `OFF`, `APPLY`. 행별 기대값 갱신 정책 |
| `PreparationMode` | 아니요 | `DEFAULT` | `DEFAULT`, `AUTO`, `FORCE`. 행별 준비 단계 재사용 정책 |
| `PreparationFromStage` | 아니요 | `DEFAULT` | `FORCE` 실행을 시작할 준비 단계 |

모든 CUT는 한 번의 실행에서 선택한 동일한 Top Model을 사용합니다. `ModelName` 열은 추가하지 않습니다.

## Repository layout

| 경로 | 역할 |
| --- | --- |
| `st_setup.m` | 프로젝트 루트 bootstrap과 MATLAB 경로 등록 |
| `src/` | workflow, config, Harness, SLDV, Assessment, Test Manager 등 실행 코드 |
| `diagnostics/matlab/` | 사용자가 직접 호출할 수 있는 읽기·진단 명령 |
| `diagnostics/python/` | Excel 접근 진단 보조 스크립트 |
| `tests/unit/` | Simulink 실행 없이 확인 가능한 단위 테스트 중심 |
| `docs/` | 현재 아키텍처와 TODO |
| `docs/archive/` | 이전 전달 자료와 패치 기록 보존 |
| `examples/` | 향후 익명화된 workbook과 모델 예제 |

기존 `st_*` 함수명과 호출 방식은 유지됩니다. `st_setup`이 `src` 전체와 MATLAB 진단 폴더를 경로에 추가하므로 MATLAB을 새로 시작한 뒤에는 먼저 `st_setup`을 실행해야 합니다.

## Recommended workflow

MATLAB에서 이 폴더를 Current Folder로 연 뒤 실행합니다.

```matlab
st_setup
st_select_target_model
```

Excel의 native indentation으로 임시 CUTPath를 만들려면:

```matlab
st_fill_temp_paths_from_indent
```

실제 모델 계층을 내보내 수동으로 경로를 보정하려면:

```matlab
st_export_subsystem_paths
```

`ModelSubsystems.FullPath`에서 필요한 경로만 `Targets.CUTPath`로 복사한 뒤 검증합니다.

```matlab
st_pre_validate_targets
```

Harness 생성부터 전체 workflow를 실행하려면:

```matlab
st_run_from_harness
```

Harness가 이미 존재하면:

```matlab
st_run_after_harness
```

`st_find_target_paths`는 모델을 선택하고 같은 이름의 Subsystem 후보를 주변의 확정된 경로와 Excel 행 문맥으로 순위화하여 `CUTPath`를 채우는 대체 workflow입니다.

## Full workflow

`st_run_from_harness`는 다음 순서로 실행합니다.

1. CUTPath 사전 검증
2. 누락된 Harness 생성
3. 행별 SLDV 데이터 생성 또는 입력 파일 사전 검증
4. Harness StopTime 설정
5. Signal Editor 설정
6. Test Assessment 설정
7. Test Manager 생성 또는 증분 갱신
8. 설정에 따른 Test 실행 및 expected-value 갱신

`st_run_after_harness`는 기존 Harness 존재 여부를 검증한 뒤 SLDV 준비 단계부터 실행합니다.

### Incremental preparation

두 workflow는 기본적으로 대상별 준비 상태를 `result/state`에 저장합니다.
같은 Excel 행, 모델, Test File, SLDV 입력과 관련 설정이 유지되면
SLDV부터 Scenario 정렬 검증까지 완료된 단계를 재사용합니다. Harness
존재 여부와 CUT 매핑은 항상 다시 확인하고, 기존 Harness는 자동으로
삭제하거나 재생성하지 않습니다.

```matlab
cfg.PreparationMode = 'AUTO';
cfg.PreparationFromStage = 'START';
```

일회성 강제 실행은 호출 옵션으로 지정할 수 있습니다.

```matlab
st_run_from_harness( ...
    'PreparationMode', 'FORCE', ...
    'FromStage', 'SLDV')
```

`Targets`에는 선택적으로 `PreparationMode`(`DEFAULT`, `AUTO`, `FORCE`)와
`PreparationFromStage`(`DEFAULT`, `START`, `HARNESS`, `SLDV`,
`HARNESS_CONFIG`, `SIGNAL_EDITOR`, `ASSESSMENT`, `TEST_MANAGER`,
`ALIGNMENT`) 열을 둘 수 있습니다. 우선순위는 호출 옵션, Excel 행,
전역 설정 순입니다. 준비 단계가 모두 캐시되어도 `RunGeneratedTests=true`이면
선택된 테스트는 다시 실행합니다.

일반 workflow는 `TestManagement.xlsx`를 결과로 수정하지 않습니다. 결과 저장은 `cfg.SaveResultFiles`로 선택하며, 기본값 `true`에서는 `result/reports`에 단계별 INI 파일로 기록합니다. `false`이면 결과 파일을 생성하지 않습니다.

## Harness creation

기존 Harness는 보존하고 없는 Harness만 생성합니다. 주요 생성 설정은 다음과 같습니다.

```text
Source               = Signal Editor
Sink                 = Outport
SchedulerBlock       = Test Sequence
SeparateAssessment   = true
CreateWithoutCompile = false
VerificationMode     = Normal
SaveExternally       = false
SynchronizationMode  = SyncOnOpenAndClose
```

Harness 생성은 compile을 포함하므로 수 분이 걸릴 수 있습니다. `SynchronizationMode` warning만 발생했더라도 Harness가 실제로 생성되었다면 생성 실패로 간주하지 않습니다.

## Signal Editor rule

`OFF` 모드에서 direct CUT Inport가 있으면 Signal Editor의 SampleTime을 설정하고 첫 Scenario를 다음 이름으로 변경하여 활성화합니다.

```text
UT_REQ_{CUTName}_001
```

입력값과 waveform은 변경하지 않습니다.

`OFF` 모드에서 direct CUT Inport가 없으면 Signal Editor 설정을 `SKIP_NO_INPORT`로 건너뜁니다. `FILE`/`GENERATE` SLDV 모드는 direct CUT Inport가 없어도 nonempty Harness `ActiveScenario`가 있으면 진행합니다. 이 규칙은 Assessment 입력 매핑 규칙과 별개입니다.

## SLDV scenario workflow

`SldvMode=FILE`은 지정된 SLDV MAT 파일을 읽고, `GENERATE`는 Top Model의 현재 Design Verifier 설정을 복사해 해당 CUT에 `TestGeneration`을 실행합니다. 기본 `cfg.AutoEnableAtomicForSldvGenerate = true`이므로 CUT의 `TreatAsAtomicUnit`이 `off`이면 `sldvrun` 동안만 임시로 `on`으로 설정하고, 성공 또는 오류 뒤 원래 설정과 모델 Dirty 상태를 복원합니다. 이 옵션을 `false`로 두면 기존처럼 atomic CUT만 허용합니다. 생성 모드에서는 Harness/Report 생성을 끄고 성공한 데이터만 다음 위치의 latest 파일로 교체합니다.

```text
result/sldv/{No}_{CUTName}/latest_sldvdata.mat
```

SLDV 데이터의 subsystem 경로, 유효한 TestCase, 시간값, Dataset 인터페이스 및 Iteration에 적용할 파라미터 metadata를 실제 Harness 변경 전에 검증합니다. SLDV 입력은 Harness `ActiveScenario` 입력의 부분집합이어야 하며, 공통 신호의 자료형·차원이 일치해야 합니다. Harness에만 있는 외부 입력은 원래 시나리오 값으로 유지하고, Harness에 없는 SLDV 신호는 실패 처리합니다. 파라미터 source가 반환되면 그대로 사용하고, 생략된 경우에는 Test Manager의 기본 source 해석을 사용합니다. 모든 입력의 `dataNoEffect`가 true인 TestCase는 제외합니다. SLDV Signal Editor MAT 파일을 다른 Harness가 공유하면 변경하지 않고 실패합니다.

`SldvGenerationResult`에는 mode, source/effective 파일, `sldvrun` status·실행 시간, `Tmax`와 실패 사유를 기록하고, `SldvScenarioResult`에는 원본 TestCase 번호·이름, 생성 Scenario, 원래 종료 시간, `Tmax`, parameter override 수를 기록합니다.

유효한 TestCase는 다음과 같이 연속된 Scenario로 변환됩니다.

```text
UT_REQ_{CUTName}_001
UT_REQ_{CUTName}_002
...
```

SLDV Scenario MAT는 Harness에 연결하기 전에 별도 임시 파일로 완성한다. 각 `UT_REQ_*`는 scalar `Simulink.SimulationData.Dataset` MAT 변수로 일반 저장되며, 저장 직후 다시 불러와 Dataset 클래스·요소 수·요소 값 형식(timeseries 또는 MATLAB struct)을 검증한다. 검증에 실패하면 Harness의 `Filename`과 기존 SLDV MAT는 변경하지 않는다. 검증 성공 후에만 대상 MAT를 교체하고 Harness를 재개방해 `options@ActiveScenario`와 `NumberOfScenarios`를 기록·검증한다. 이전에 실패한 실행이 `_sldv.mat`를 남겼더라도 원본 MAT의 실제 Dataset(우선 `InputScenario`)을 템플릿으로 자동 선택해 복구한다.

해당 CUT의 최장 TestCase 종료 시각을 `Tmax`로 사용합니다. 기본 `cfg.SldvTmaxResolution = 0.01`은 원본 최장 시간보다 작아지지 않도록 0.01초 단위로 올림합니다. 따라서 `1.06`은 그대로 `1.06`이고 `1.060000001`은 `1.07`이 됩니다. 결과에는 원본 `RawTmax`와 적용된 `Tmax`를 함께 기록합니다. `[]`로 설정하면 올림을 끌 수 있습니다.

시간값이 화면 표시와 다르다고 의심되면 `st_diagnose_sldv_timing`을 실행한다. 이 읽기 전용 진단은 원본 `sldvData.TestCases.timeValues`와 `sldvsimdata`가 변환한 각 Dataset element의 시간축을 17자리 및 binary 표현으로 비교하고 `result/reports/SldvTiming*.ini`에 기록한다.

- Harness `StopTime = Tmax`
- 모든 Assessment 전이 `after(Tmax, sec)`
- Signal Editor `OutputAfterFinalValue = Holding final value`
- TestCase마다 같은 이름의 Signal Editor Scenario, Assessment Scenario 및 Table Iteration 생성
- SLDV parameter value를 해당 Iteration의 variable override로 적용
- SLDV에 없는 Harness 외부 입력은 원래 `ActiveScenario` 요소·시계열을 각 Scenario에 유지

따라서 종료 시간이 각각 `10.1`, `1.0`초인 경우 StopTime과 전이는 `10.1`초이며, 짧은 입력은 `1.0~10.1`초 구간에서 마지막 값을 유지합니다. `OFF`는 기존 단일 `_001` workflow를 그대로 사용합니다.

## Assessment output mapping

Harness에서 확인된 Test Assessment Input 순서는 다음과 같습니다.

```text
Signal Editor ActiveScenario variables
+ Harness output signals
```

Active Scenario 요소 수가 `K`이면:

```text
Assessment Port 1..K      -> Scenario input area
Assessment Port K+1..end  -> Harness output area
```

자동화는 다음 순서로 verify 대상을 결정합니다.

1. 실제 Assessment Input symbol과 Port를 읽습니다.
2. 실제 Assessment Port 순서로 정렬합니다.
3. Signal Editor ActiveScenario 요소 수를 읽습니다.
4. 처음 `K`개 Assessment symbol을 건너뜁니다.
5. 나머지 symbol을 Harness Outport 순서와 위치로 연결합니다.
6. 실제 Assessment symbol 이름으로 `verify(...)`를 생성합니다.

Harness signal 이름과 Assessment symbol 이름은 매핑 기준이 아닙니다. `/` 삭제, `makeValidName` 또는 그 밖의 추측 기반 정규화를 사용하지 않습니다.

예를 들어 Harness signal이 `A/B`, 실제 Assessment symbol이 `AB`여도 순서로 관계를 확정하고 다음 형태를 생성할 수 있습니다.

```matlab
verify(AB == 0);
```

기본 설정은 Harness의 최상위 Outport에 대응하는 Assessment Input만 검증합니다. 스칼라, numeric array, Bus, nested Bus를 지원하며 Bus 배열은 기본적으로 첫 Bus instance만 검증합니다. Bus leaf의 numeric array는 전체 요소를 검증합니다.

`OFF`에서는 Assessment를 하나의 Scenario와 두 Step으로 정리합니다.

```text
step1 --true--> step2
step2 action: generated verify(...)
```

`cfg.VerifyAtSampleTimeOnly = true`이면 transition은 `after(ExpectedValueSampleTime, sec)` 형태가 됩니다.

SLDV 모드에서는 TestCase 수만큼 동일 구조의 Assessment Scenario를 다시 만들고, `VerifyAtSampleTimeOnly` 설정과 관계없이 모든 transition을 `after(Tmax, sec)`로 구성합니다.

## Test Manager incremental behavior

기본값은 다음과 같습니다.

```matlab
cfg.OverwriteTestFile = false;
```

증분 모드에서는:

- 이미 열린 대상 Test File을 재사용합니다.
- 닫혀 있는 기존 `.mldatx`를 엽니다.
- 파일이 없으면 새로 만듭니다.
- 기존 Test Case를 보존합니다.
- 같은 `TestCaseName`이 있으면 `SKIP_EXISTING`으로 기록합니다.
- 없는 Test Case만 추가합니다.

`cfg.OverwriteTestFile = true`이면 대상 Test File만 닫고 다시 생성합니다. 다른 열린 Test Manager 파일을 전역으로 제거하지 않습니다.

Test File, Test Suite, Test Case에 coverage recording을 활성화합니다.

`OFF` 모드에서 direct Inport가 있는 CUT의 `Iteration 1`:

```text
SignalEditorScenario = UT_REQ_{CUTName}_001
TestSequenceScenario = UT_REQ_{CUTName}_001
```

`OFF` 모드에서 direct Inport가 없는 CUT의 `Iteration 1`:

```text
SignalEditorScenario is not assigned
TestSequenceScenario = UT_REQ_{CUTName}_001
```

SLDV 모드에서는 기존 Test Case가 있어도 해당 Test Case의 Table Iteration만 완전 초기화한 뒤 Scenario 수만큼 다시 생성합니다. 다른 Test Case는 보존합니다. direct CUT Inport 유무와 관계없이 각 Iteration 이름, `SignalEditorScenario`, `TestSequenceScenario`는 같은 `UT_REQ_{CUTName}_{NNN}` 값을 사용합니다.

MATLAB R2025b의 `Iteration.TestParams` 표시에서는 `SignalEditorScenario`가 `SignalBuilderGroup`으로 나타날 수 있다. 두 이름은 같은 Signal Editor Scenario 연결을 의미하며, 정렬 검증은 둘 중 어느 표기든 허용한다.

## Test execution and expected-value update

기본 실행 설정:

```matlab
cfg.RunGeneratedTests = true;
cfg.ExpectedUpdateMode = 'APPLY';
cfg.ExpectedValueSampleTime = 0.01;
cfg.RerunAfterExpectedUpdate = true;
```

기대값 갱신 정책은 기본적으로 `APPLY`입니다. Excel에서 빈 값 또는 `DEFAULT`를 사용하면 이 전역 설정을 따르며, 갱신하지 않을 행은 `OFF`로 명시합니다.

| Excel `ExpectedUpdateMode` | 실제 동작 |
| --- | --- |
| 빈 값 또는 `DEFAULT` | `cfg.ExpectedUpdateMode` 사용 |
| `OFF` | 실패해도 expected value를 변경하지 않음 |
| `APPLY` | Failed Iteration의 지원 가능한 값을 실제 출력으로 갱신 |

Excel 행별 설정이 전역 설정보다 우선합니다. `REVIEW`는 변경 후보 저장 및 승인 방식이 확정되지 않아 아직 허용하지 않으며 [TODO](docs/TODO.md)로 관리합니다.

expected-value updater는 Failed Iteration만 처리합니다. Assessment의 `verify(...)` 왼쪽 symbol을 Assessment Port와 Scenario offset을 사용해 원래 Harness SignalName/OutportBlock에 연결하고, 지정 시점의 logged 실제값으로 RHS를 갱신합니다.

SLDV Iteration은 각 Scenario의 결과를 개별 처리하고 `Tmax` 시점의 실제값을 사용합니다. 실행 직후 `getVerifyRuns` 결과에서 활성 Scenario의 `step2` verify가 없거나 `Untested`이면 tail time을 추가하지 않고 timing 실패로 기록합니다.

`cfg.OnlyEnabled = true`일 때 실행 대상은 관리 파일에서 `Enabled=true`인 행의 `TestCaseName`으로 제한됩니다. 실행 중에는 해당 Test Case만 임시로 Enabled로 두고 기존에 남아 있는 다른 Test Case는 모두 Disabled 처리하며, 종료·오류 뒤에는 원래 Enabled 상태를 복원합니다.

```text
Assessment symbol
-> positional Assessment/Harness mapping
-> Harness SignalName / OutportBlock
-> logged signal
```

실제값과 RHS가 다를 때만 수정하며 지원 값은 real numeric scalar와 logical scalar입니다. 하나 이상의 값이 갱신되고 `RerunAfterExpectedUpdate`가 true이면 Test File을 다시 실행합니다.

## Repository artifact policy

| 종류 | Git 정책 | 이유 |
| --- | --- | --- |
| MATLAB 소스와 테스트 | 추적 | 제품 소스 |
| 익명화된 예제 모델/workbook | 향후 `examples/`에서 추적 | 재현 가능한 시작점 제공 |
| 실제 `TestManagement.xlsx`, MAT 데이터 | 제외 | 프로젝트 및 업무 데이터 보호 |
| `result/`, `slprj/`, 코드 생성물 | 제외 | 실행마다 재생성되는 산출물 |
| `.mldatx` | 기본 제외 | 모델 경로와 생성된 테스트 데이터 포함 가능 |
| 승인된 baseline/test artifact | 정책 확정 전 제외 | 저장 위치와 검토 절차가 미결정 |

목표 디렉터리 구조와 단계별 이전 원칙은 [Architecture](docs/architecture.md), 미결정 항목은 [TODO](docs/TODO.md)를 참조합니다.

## Progress logging

```matlab
cfg.VerboseLogging = true;
```

`st_log.m`은 장시간 호출 전후에 timestamp가 포함된 `INFO`, `DEBUG`, `TRACE`, `WARN`, `ERROR` 로그를 남깁니다. `VerboseLogging = false`이면 추가 INFO/DEBUG/TRACE 로그만 숨기고 기존 START/OK/FAIL/summary 출력은 유지합니다.

`sltest.harness.create`, `sltest.harness.load`, `run(tf)` 같은 blocking API 내부의 실제 percentage는 표시하지 않습니다. 마지막으로 출력된 호출 직전 로그를 통해 현재 대기 중인 위치를 확인합니다.

## Excel access diagnostic

회사 관리 환경에서 Excel 열기가 실패하면 원본 workbook을 수정하지 않는 read-only 진단을 실행할 수 있습니다.

```matlab
st_diagnose_excel_access
```

read-write open과 disposable workbook 저장까지 확인하려면:

```matlab
st_diagnose_excel_access(true)
```

결과는 `result/ExcelAccessDiagnostic.json`에 기록됩니다. 진단 결과 없이 프로젝트의 Excel I/O 방식을 임의로 교체하지 않습니다.

## Validation status

`Scenario variables -> Harness outputs` 순서는 생성된 Harness에서 수동 확인되었습니다. 다음 항목은 실제 MATLAB R2025b 장비에서 end-to-end로 다시 검증해야 합니다.

- Assessment 생성 및 실행
- Failed Test expected-value 갱신
- 증분 Test Manager 동작
- verbose logging 출력
- expected-value 갱신 후 재실행
- SLDV FILE/GENERATE end-to-end 생성과 다중 Iteration 실행
- 정확히 `Tmax`인 StopTime에서 Assessment verify가 tested 상태가 되는지 확인

단위 테스트를 실행할 수 있는 MATLAB 환경에서는 다음 순서를 사용합니다.

```matlab
st_setup
results = runtests(fullfile(st_project_root(), 'tests', 'unit'));
```
