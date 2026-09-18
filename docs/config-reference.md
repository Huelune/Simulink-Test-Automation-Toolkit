# 설정 사전 (`st_config`)

`src/config/st_config.m`이 이 도구의 전역 기본값을 담고 있습니다. 관리 Excel이
행마다 정하는 값과 달리, 여기 있는 값은 **프로젝트 전체에 적용되는 정책**입니다.

이 문서는 사용자가 실제로 바꿀 만한 설정만 다룹니다. 경로 관련 설정처럼 기본값을
그대로 두는 것이 정상인 항목은 마지막 장에 모았습니다.

## 0. 설정을 바꾸는 방법

### 파일을 고치는 방법 (영구)

```matlab
edit src/config/st_config.m
```

해당 줄의 값을 고치고 저장합니다. 이후 모든 명령에 적용됩니다.

### 변수만 고치면 안 되는 이유

```matlab
cfg = st_config();
cfg.RunGeneratedTests = false;   % 이렇게 해도 반영되지 않습니다
st_run_from_harness                % 이 명령은 st_config()를 새로 호출합니다
```

공개 명령은 실행할 때마다 `st_config()`를 다시 호출합니다. Command Window에서
받아 온 `cfg` 변수를 고쳐도 다음 명령에는 전달되지 않습니다. **영구적으로 바꾸려면
파일을 고쳐야 하고, 한 번만 바꾸려면 명령의 옵션 인자를 쓰십시오.**

### 우선순위

같은 항목을 여러 곳에서 정할 수 있을 때의 순서입니다.

| 정책 | 우선순위 (왼쪽이 이김) |
| --- | --- |
| 실행 모드 | 명령 옵션 `ExecutionMode` > `cfg.ExecutionMode` |
| 준비 모드·시작 단계 | 명령 옵션 > Excel 행 > `cfg` |
| 기대값 갱신 | Excel 행 > `cfg.ExpectedUpdateMode` |
| 커버리지 필터 선택 | Excel 행의 `CoverageFilter*` (전역 설정 없음) |
| 기존 CVF 처리 | `cfg.CoverageFilterExistingPolicy` (행 설정 없음) |
| 경로·결과 위치 | `cfg` |

## 1. 가장 먼저 확인할 설정

처음 도입할 때 이 네 개를 먼저 정하십시오. 나머지는 기본값으로 시작해도 됩니다.

| 설정 | 기본값 | 왜 먼저 봐야 하는가 |
| --- | --- | --- |
| `ExpectedUpdateMode` | `'APPLY'` | 실패한 테스트의 기대값을 자동으로 덮어씁니다 |
| `RunGeneratedTests` | `true` | 준비만 하고 멈출지, 테스트까지 돌릴지 정합니다 |
| `OverwriteTestFile` | `false` | `true`면 기존 Test Case를 전부 새로 만듭니다 |
| `ExecutionMode` | `'BATCH'` | BATCH와 PER_CUT 중 무엇으로 돌릴지 정합니다 |

## 2. 테스트 실행

### `RunGeneratedTests` — 기본 `true`

Test Manager 구성까지 끝낸 다음 실제로 테스트를 실행할지 정합니다.

| 값 | 동작 |
| --- | --- |
| `true` | 준비 후 활성 Test Case를 실행합니다 |
| `false` | Test Case를 만들고 멈춥니다. 실행과 기대값 갱신을 하지 않습니다 |

Harness와 Test Case만 먼저 만들어 두고 실행은 사람이 Test Manager에서 확인하며
하고 싶을 때 `false`로 둡니다.

### `ExecutionMode` — 기본 `'BATCH'`

여러 Test Case를 한꺼번에 돌릴지, 하나씩 따로 돌릴지 정합니다.
**부르는 쪽이 정하며, Excel은 이 선택에 관여하지 않습니다.**

| | `'BATCH'` (기본) | `'PER_CUT'` |
| --- | --- | --- |
| 실행 | `run(tf)` 전체 한 번 | Test Case마다 `run(tc)` |
| 기대값 갱신 후 재실행 | Test File **전체** | 그 Test Case만 |
| 결과물 | 통합 보고서 하나 | CUT별 폴더 |

`PER_CUT`은 **혼자 돌려야만 되는 Test Case**가 있을 때 씁니다. 기대값 갱신 후
재실행 범위도 다릅니다 — `BATCH`는 Test File 전체를, `PER_CUT`은 해당 Test
Case만 다시 돌립니다.

커버리지 필터는 이 선택과 무관합니다. 필터는 결과물을 만들 때 적용되므로
활성 CVF가 있는 대상도 `'BATCH'`로 돌 수 있습니다.

한 번만 바꾸려면 명령에서 지정합니다.

```matlab
st_run_after_harness('ExecutionMode', 'PER_CUT')
```

> 예전 `'AUTO'`는 없어졌습니다. Excel의 CVF 설정을 보고 `PER_CUT`을 골랐는데,
> 필터가 결과물 단계로 옮겨가면서 근거가 사라졌습니다. 전달하면
> `simtest:RemovedExecutionMode` 오류로 대체 값을 안내합니다.
CUT별 결과 폴더를 항상 따로 받고 싶을 때만 `PER_CUT`으로 고정하십시오.

### `PerCutContinueOnFailure` — 기본 `true`

`PER_CUT`에서 한 CUT이 실패했을 때 다음 CUT을 계속 처리할지 정합니다.

| 값 | 동작 |
| --- | --- |
| `true` | 필터 복원이 확인되면 다음 CUT을 계속 처리합니다 |
| `false` | 첫 실패에서 전체를 중단합니다 |

> `true`여도 **필터 복원 자체가 실패하면 즉시 전체를 중단합니다.** 복원되지 않은
> 필터가 남으면 다음 CUT의 커버리지 수치가 오염되기 때문입니다. 이것은 설정으로
> 끌 수 없는 안전장치입니다.

### `PerCutFailOnNonPass` — 기본 `false`

Test Case의 판정이 통과가 아닐 때 MATLAB 오류를 낼지 정합니다.

| 값 | 동작 |
| --- | --- |
| `false` | `FAILED`/`UNTESTED`/`INCOMPLETE`는 결과에 기록만 하고 계속 진행합니다 |
| `true` | 모든 CUT을 처리한 뒤, 통과하지 못한 것이 있으면 MATLAB 오류를 냅니다 |

테스트가 실패하는 것은 정상적인 결과이지 도구의 오류가 아닙니다. 그래서 기본값은
`false`입니다. CI처럼 자동으로 성패를 판정해야 할 때만 `true`로 바꾸십시오.

### `PerCutReportMode` — 기본 `'SUMMARY'`

`PER_CUT`에서 만들 보고서의 범위입니다.

| 값 | 만드는 것 |
| --- | --- |
| `'SUMMARY'` | Excel, MLDATX, 경량 Coverage HTML |
| `'FULL'` | 위에 더해 공식 PDF와 전체 Coverage HTML |

`FULL`은 시간이 훨씬 오래 걸립니다. 두 모드 모두 CVT 원본과 적용한 CVF 사본,
독립 Coverage Detail HTML은 저장합니다.

### `OnlyEnabled` — 기본 `true`

Excel의 `Enabled` 열을 볼지 정합니다. `false`로 하면 `Enabled` 값과 무관하게 모든
행을 처리합니다.

## 3. 기대값 갱신

### `ExpectedUpdateMode` — 기본 `'APPLY'`

**이 도구에서 가장 주의해야 하는 설정입니다.**

테스트가 실패하면 실제 출력값을 읽어 `verify(... == 기대값)`의 기대값을 그 값으로
고쳐 씁니다. 아직 정답이 정해지지 않은 초기 단계에서 기준값을 만들어 내기 위한
기능입니다.

| 값 | 동작 |
| --- | --- |
| `'APPLY'` (기본) | 실패한 결과의 실제값으로 기대값을 갱신합니다 |
| `'OFF'` | 실패해도 기대값을 바꾸지 않습니다 |

Excel의 `ExpectedUpdateMode` 열이 행마다 이 값을 덮어씁니다.

> 이미 승인된 기준값이 있는 프로젝트라면 이 값을 `'OFF'`로 바꾸십시오. 그대로 두면
> 실패한 테스트가 조용히 통과로 바뀝니다.

### `RerunAfterExpectedUpdate` — 기본 `true`

기대값이 하나라도 바뀌면 같은 범위를 다시 실행할지 정합니다. `PER_CUT`에서는 같은
CVF를 유지한 채 그 Test Case만 재실행하고 필터를 복원합니다.

### `ExpectedValueSampleTime` — 기본 `0.01`

기대값을 읽어 올 시뮬레이션 시각[초]입니다. `VerifyAtSampleTimeOnly=true`일 때
step1에서 step2로 넘어가는 시각이기도 합니다.

### Iteration 일부만 실패했을 때

한 Test Case는 Test Sequence Scenario마다 Iteration을 하나씩 가집니다. Iteration
3개 중 2개가 오류로 끝나고 1개만 정상 실행된 경우에도, 정상 Iteration의 기대값은
그대로 갱신합니다. 설정 항목은 없으며 항상 이렇게 동작합니다.

| 상황 | 동작 |
| --- | --- |
| 평가 대상 시나리오 일부만 verify timing 실패 | 경고 후 계속 진행, 판정 `PARTIAL` |
| 평가 대상 시나리오 전부 verify timing 실패 | 기존과 같이 실행 중단 |
| 기대값 갱신이 일부 시나리오에서만 실패 | 성공한 갱신을 유지하고 계속 진행, 판정 `PARTIAL` |
| Iteration Outcome이 `Failed`가 아님 | 갱신하지 않고 `SKIP_OUTCOME_NOT_FAILED`로 기록 |

`PARTIAL`은 통과가 아닙니다. BATCH는 `runContext.Status`, PER_CUT은
`manifest.json`의 `Status`와 `PartialTargetCount`, 그리고 Targets 시트의
`VerifyTimingStatus` / `ExpectedUpdateStatus` 열에서 확인합니다.

## 4. Test Manager와 Harness

### `OverwriteTestFile` — 기본 `false`

| 값 | 동작 |
| --- | --- |
| `false` (기본) | 증분 갱신. 기존 `.mldatx`와 Test Case를 보존하고 없는 것만 추가합니다 |
| `true` | 전체 재생성. 열려 있으면 닫고, 파일을 덮어쓰고, Excel에서 Test Case를 다시 만듭니다 |

`true`는 사람이 Test Manager에서 직접 고쳐 둔 설정을 전부 날립니다. 기본값을
유지하는 것을 권합니다.

### `OverwriteHarness` — 기본 `false`

Template Harness 복제(`TestPreparationSource=HARNESS_CLONE`)에서 대상 Harness가 이미
있을 때의 동작입니다.

| 값 | 동작 |
| --- | --- |
| `false` (기본) | 기존 Harness를 건드리지 않고 건너뜁니다 |
| `true` | 복구용 clone을 먼저 저장한 뒤 교체합니다. 후처리가 실패하면 그 clone에서 복원합니다 |

### `TestSuiteName` — 기본 `'New Test Suite 1'`

Test Case를 담을 Test Suite 이름입니다. 기존 Test File을 쓸 때는 그 파일에 실제로
있는 Suite 이름과 맞춰야 합니다.

### `HarnessStopTime` — 기본 `'0.01'`

Harness의 기본 종료 시각입니다. SLDV나 MAT 입력이 있는 대상은 입력의 Tmax가 이
값을 덮어씁니다. 실제로 이 값이 쓰이는 것은 입력 시간 정보가 없는 `OFF` 대상입니다.

## 5. Assessment(verify) 생성

### `VerifyHarnessOutportsOnly` — 기본 `true`

무엇을 검증 대상으로 삼을지 정합니다.

| 값 | 검증 대상 |
| --- | --- |
| `true` (기본) | Harness 최상위 Outport에 대응하는 Assessment 입력만 |
| `false` | Assessment에 등록된 모든 입력 데이터 심볼 |

`true`이고 쓸 수 있는 Harness 출력이 하나도 없으면 verify가 빈 Action으로
구성되며, 실행 후 기대값 갱신은 `SKIP_NO_VERIFY_OUTPUT`으로 건너뜁니다. 이것은
정상 동작입니다. 다만 출력이 있는데 verify 결과가 없거나 `Untested`이면 오류로
처리합니다.

### `VerifyFirstBusElementOnly` — 기본 `true`

같은 Bus 구조가 배열로 반복될 때 첫 번째 Bus 인스턴스만 검증할지 정합니다.
`false`로 하면 모든 원소를 검증합니다. Bus 안의 숫자 배열은 두 경우 모두 전부
검증합니다.

### `VerifyAtSampleTimeOnly` — 기본 `false`

verify를 언제 수행할지 정합니다.

| 값 | step1 → step2 전이 조건 |
| --- | --- |
| `false` (기본) | `true` (즉시) |
| `true` | `after(ExpectedValueSampleTime, sec)` |

`true`로 할 때는 `HarnessStopTime`이 `ExpectedValueSampleTime`보다 커야 합니다.

## 6. SLDV와 입력 준비

### `AutoConvertSldvTargetsToAtomic` — 기본 `true`

`FILE+SLDV`와 `GENERATE` 대상은 Atomic Subsystem이어야 합니다.

| 값 | 동작 |
| --- | --- |
| `true` (기본) | 라이브러리 링크가 **없는** 비-Atomic CUT만 `TreatAsAtomicUnit=on`으로 바꾸고 그 변경을 저장합니다 |
| `false` | 대상이 이미 Atomic이 아니면 실패로 처리합니다 |

라이브러리 링크된 CUT은 `true`여도 자동 변경하지 않습니다. 원본 라이브러리를
훼손할 수 있기 때문입니다. 이때는 원본 라이브러리 블록을 Atomic으로 만들고 링크를
갱신해야 합니다.

### `IgnoreUnexpectedSldvInputs` — 기본 `false`

SLDV MAT에 Harness의 ActiveScenario에는 없는 입력 신호가 들어 있을 때의 동작입니다.

| 값 | 동작 |
| --- | --- |
| `false` (기본) | 준비 단계를 실패로 처리합니다 |
| `true` | 그 신호를 무시하고, Harness에도 있는 공통 입력만 교체합니다 |

`true`로 바꾸는 것은 그 입력이 이 테스트에 필요 없다는 것을 사람이 확인한 뒤에만
하십시오. 무시한 신호 목록은 `SldvGenerationResult`의 `IgnoredSldvInputs` 열에
남습니다.

### `AllowSldvSubsystemPathMismatch` — 기본 `true`

SLDV MAT에 기록된 `ModelInformation.SubsystemPath`가 지금 대상 CUT과 다를 때의
동작입니다.

| 값 | 동작 |
| --- | --- |
| `true` (기본, 임시 호환 정책) | WARN만 남기고 계속 진행합니다 |
| `false` | 경로가 다르면 거부합니다 |

같은 라이브러리 구현을 서로 다른 모델 계층에서 쓰는 경우를 위한 임시 완화입니다.
Harness 입력 인터페이스 검증은 어느 쪽이든 그대로 수행합니다. 잘못된 MAT을 쓰는
사고를 막고 싶으면 `false`로 바꾸십시오.

### `CheckSharedSignalEditorDataFile` — 기본 `false`

여러 Harness가 같은 Signal Editor MAT 파일을 공유하고 있는지 검사할지 정합니다.

| 값 | 동작 |
| --- | --- |
| `false` (기본) | 검사하지 않습니다. 모든 Harness를 열고 닫지 않으므로 빠릅니다 |
| `true` | 모든 Harness를 열어 MAT 공유를 검사하고, 공유가 있으면 실패로 처리합니다 |

공유된 상태에서 검사를 끈 채 진행하면 한 Harness의 Scenario 기록이 다른 Harness의
것을 덮어쓸 수 있습니다. 인증 전에는 `true`로 한 번 확인하십시오.

### `SldvTmaxResolution` — 기본 `0.01`

각 CUT의 SLDV 종료 시각을 올림할 격자[초]입니다. `1.060000001` 같은 부동소수점
꼬리를 흡수하면서, Harness가 원본 TestCase보다 먼저 끝나지 않게 합니다. `[]`로
두면 원본 종료 시각을 그대로 씁니다.

## 7. 커버리지

### `CoverageStructuralLevel` / `CoverageMetricSettings`

기본값은 `'Decision'`과 `'dwe'`입니다. Decision 커버리지를 설정하면 Block Execution이
함께 수집됩니다. 특별한 이유가 없으면 바꾸지 마십시오.

### `CoverageFilterExistingPolicy` — 기본 `'REPLACE'`

사람이 직접 걸어 둔 기존 필터를 어떻게 다룰지 정합니다.

| 값 | 동작 |
| --- | --- |
| `'REPLACE'` (기본) | 기존 필터를 임시로 해제하고 새 CVF만 적용한 뒤 원래대로 복원합니다 |
| `'MERGE'` | 기존 필터와 새 CVF를 함께 적용합니다 |

### `CoverageIncludeReferencedModels` — 기본 `false`

참조 모델 내부까지 커버리지를 수집할지 정합니다.

## 8. 증분 준비

### `PreparationMode` — 기본 `'AUTO'`

| 값 | 동작 |
| --- | --- |
| `'AUTO'` | 입력 지문이 마지막 checkpoint와 같으면 그 준비 단계를 재사용합니다 |
| `'FORCE'` | `PreparationFromStage`부터 모든 후속 준비 단계를 다시 실행합니다 |

지문에는 Excel 행, 설정, 모델, Test File, SLDV 입력, 그리고 이 도구의 코드가
들어갑니다. 코드를 고치면 자동으로 다시 실행됩니다.

준비 단계가 전부 캐시되어도 `RunGeneratedTests=true`이면 테스트는 매번 실행합니다.

### `PreparationFromStage` — 기본 `'START'`

`FORCE`가 시작할 단계입니다. `'START'`는 전체 workflow에서 `HARNESS`, 기존 Harness
workflow에서 `SLDV`로 해석됩니다.

`'EXECUTE'`는 준비 단계가 아니라 **준비를 전혀 하지 않겠다**는 뜻입니다. 지문을
따지지 않고 모든 준비 단계를 `CACHED`로 두고 테스트만 실행하므로, 이 값일 때는
`RunGeneratedTests=false`여도 테스트가 실행됩니다.

## 9. 테스트 명세서 추출

### `DecisionBlockScope` — 기본 `'EXPLICIT'`

`st_export_test_specification`이 `DecisionBlocks` 열에 어디까지 적을지 정합니다.

| 값 | 포함 대상 | 쓰는 때 |
| --- | --- | --- |
| `'EXPLICIT'` (기본) | 대화상자에 조건을 적는 블록 5종 (If, Switch, MinMax, MultiPortSwitch, SwitchCase) | 평소 |
| `'ALL'` | 위에 더해 조건식 없이 Coverage objective를 만드는 블록 13종 (Saturate, Abs, Lookup 계열, Integrator 계열 등) | If/Switch가 없는데 Decision 커버리지가 나오는 이유를 찾을 때 |
| `'NONE'` | 없음. 열이 비고 스캔도 건너뜁니다 | 목록이 필요 없을 때 |

`'ALL'`은 목록이 크게 길어집니다. Lookup 테이블이 많은 CUT은 셀이 길이 한도를 넘어
`OverflowDetails` 시트 참조로 대체될 수 있습니다.

실행마다 덮어쓰려면 `st_export_test_specification('DecisionBlockScope','ALL')`을
쓰십시오. 어느 범위로 뽑았는지는 실행 로그의 `DecisionBlockScope=` 항목에 남습니다.

## 10. 로그와 진단

### `VerboseLogging` — 기본 `true`

| 값 | 동작 |
| --- | --- |
| `true` (기본) | 오래 걸리는 API 호출 앞뒤에 timestamp·단계·대상·경과 시간을 출력합니다 |
| `false` | 상세 로그를 끄고 START/OK/FAIL 요약만 남깁니다 |

MATLAB이 지금 어느 API에서 기다리는지는 blocking 호출 안을 들여다볼 수 없으므로
알 수 없습니다. **마지막 `START` 로그가 현재 대기 중인 위치입니다.**

### `SuppressedWarnings` — 기본 `{}`

긴 API 루프 동안 숨길 Simulink 경고 식별자 목록입니다. 숨긴 경고도 `st_log`에 한
번은 기록되고 끝나면 원래대로 복원되므로 정보가 사라지지 않습니다.

대상 모델에서 어떤 식별자가 나오는지는 다음으로 수집합니다. 실행할 작업을 함수
핸들로 넘기거나, 이미 받아 둔 diary 파일을 지정합니다.

```matlab
ids = st_collect_warning_ids(@() st_run_after_harness());
ids = st_collect_warning_ids('LogFile', 'run.log');
```

`lastwarn`은 마지막 경고 하나만 알려 주므로, 여러 종류가 섞인 실행은 이 명령으로
모아야 전부 확인할 수 있습니다. 출력된 블록을 `cfg.SuppressedWarnings`에 그대로
붙여 넣으면 됩니다.

## 11. CUT 경로 찾기 보조

### `ModelSearchRoot` — 기본: 저장소의 상위 폴더

`st_select_target_model`이 모델을 찾을 시작 폴더입니다. 기본값은 이 저장소가 모델
폴더 바로 아래에 있다고 가정합니다. 모델이 다른 곳에 있으면 바꾸십시오.

관련 설정으로 `ModelSearchRecursive`(기본 `true`, 하위 폴더까지 탐색)와
`ModelSearchExcludeFolders`(기본 `.git`, `slprj`, `result`)가 있습니다.

### `PathFinderHighlightSelection` — 기본 `false`

`st_find_target_paths`에서 후보를 고른 뒤 Simulink에서 그 블록을 열어 강조 표시하고
확인을 받을지 정합니다. `true`로 하면 확실하지만 느립니다.

### `PathFinderAnchorCount` — 기본 `5`

중복된 CUT 후보의 순위를 매길 때 참고할 주변 확정 경로의 개수입니다.

### `PathFinderExcelContextRows` — 기본 `3`

중복 선택 대화상자에서 현재 행 위아래로 보여 줄 Excel 행 수입니다.

### `IndentPathOverwriteExisting` — 기본 `false`

`st_fill_temp_paths_from_indent`가 이미 값이 있는 `CUTPath` 셀도 덮어쓸지 정합니다.
계층의 근거는 `CUTName` 셀의 Excel IndentLevel 속성이며, 셀 값 앞의 공백 문자나
별도 Depth 열이 아닙니다.

## 12. 결과 저장

### `SaveResultFiles` — 기본 `true`

단계별 INI 결과 보고서를 `result/reports/`에 쓸지 정합니다. `false`로 하면 결과
파일을 만들지 않습니다.

### `PerCutResultCollection` — 기본 `'DEFERRED'`

`PER_CUT` 실행이 커버리지 필터와 CUT별 보고서까지 만들지 정합니다.

`PER_CUT`은 **혼자 돌려야만 되는 Test Case**를 위해 있습니다. 커버리지 필터는
실행에 필요한 것이 아니라 실행 결과로 만드는 산출물의 커버리지 데이터를 다듬는
것이므로, 기본값 `'DEFERRED'`는 실행을 필터 없이 하고 각 CUT의 ResultSet만
저장합니다. CVF 생성과 부착, 보고서는 다음 명령이 합니다.

```matlab
st_collect_per_cut_results
```

`'INLINE'`은 예전처럼 실행 안에서 전부 처리합니다. standalone 번들은 실행 모델이
일회용이라 나중에 다시 열 수 없으므로 항상 `'INLINE'`으로 동작합니다.

### `GenerateTestReport` — 기본 `false`

테스트 실행 **직후에** 통합 보고서까지 만들지 정합니다. 기본은 만들지 않습니다.

실행과 결과 정리는 별개의 단계이기 때문입니다. 실행이 끝나면 어느 쪽이든
`result/run_records/`에 실행 기록이 남고, 나중에 원할 때 보고서를 만듭니다.

```matlab
st_generate_test_report('RunRecord', 'LATEST')
```

`true`로 두면 예전처럼 실행이 끝나자마자 보고서까지 만듭니다. 실행 기록은
그래도 남습니다.

## 13. 경로 설정 (보통 그대로 둡니다)

다음 설정은 결과가 저장될 위치를 정합니다. 보통 그대로 둡니다.

| 설정 | 기본 위치 | 내용 |
| --- | --- | --- |
| `ResultDir` | `result/` | 모든 생성물의 루트 |
| `ResultReportDir` | `result/reports/` | 단계별 INI 결과 |
| `SldvDir` | `result/sldv/` | SLDV 생성 데이터와 manifest |
| `WorkflowStateFile` | `result/state/workflow_state.mat` | 증분 준비 checkpoint |
| `RunRecordRootDir` | `result/run_records/` | 저장된 실행 기록 (ResultSet 포함) |
| `TestRunRootDir` | `result/runs/` | BATCH 실행 보고서 |
| `PerCutRunRootDir` | `result/per_cut_runs/` | PER_CUT 실행 보고서 |
| `CoverageFilterDir` | `result/coverage_filters/` | 자동 생성 CVF |
| `ExportRootDir` | `result/exports/` | 내보내기 번들 |
| `StandaloneCoverageRootDir` | `result/standalone_coverage/` | standalone 제출물 |
| `VerificationRootDir` | `result/verification/` | 종합 검증 결과 |
| `LatestReportPointer` | `result/latest.json` | 최신 BATCH 실행 위치 |
| `LatestRunRecordPointer` | `result/run_record_latest.json` | 최신 실행 기록 위치 |
| `PerCutLatestPointer` | `result/per_cut_latest.json` | 최신 PER_CUT 실행 위치 |

`CoverageFilterDir` 밖에 있는 `.cvf` 파일은 사람이 만든 수동 필터로 간주하며 이
도구가 지우지 않습니다.

> **Windows 경로 길이 주의:** standalone pipeline은 폴더를 여러 겹 만들기 때문에
> 저장소가 깊은 경로에 있으면 Windows의 260자 제한에 걸릴 수 있습니다. 이때는
> `st_set_standalone_coverage_root`로 짧은 경로(예: 다른 드라이브 루트)를 지정하십시오.
> 이 값은 `runtime_target.mat`에 로컬로 저장되며 Git에 올라가지 않습니다.

## 14. 모델 선택 관련 (코드에 적지 않는 값)

`TopModel`, `ModelFile`, `TestFile`, `ManagementExcel`은 `st_config.m`에 적지
않습니다. 추적되는 파일에 업무 모델 경로를 남기지 않기 위해서입니다.

| 값 | 어디에 저장되는가 |
| --- | --- |
| 현재 선택한 모델 | `runtime_target.mat` (Git 제외) |

선택은 `st_select_target_model`로 합니다.
