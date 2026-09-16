# 관리 Excel 열 사전

`TestManagement.xlsx`의 `Targets` 시트가 이 도구의 유일한 입력 표입니다. 한 행이
CUT 하나이고, 그 행에 적은 값이 그 CUT을 어떻게 준비하고 실행할지를 전부 결정합니다.

이 문서는 모든 열의 **역할, 기본값, 잘못 적었을 때의 동작**을 설명합니다. 용어는
[용어집](glossary.md)을 참조하십시오.

## 0. 표 전체 규칙

- 파일 위치 기본값은 저장소 루트의 `TestManagement.xlsx`, 시트 이름은 `Targets`입니다.
  (`cfg.ManagementExcel`, `cfg.ManagementSheet`로 바꿉니다.)
- 활성 행은 모두 같은 Top Model에 속합니다. 모델을 구분하는 열은 없습니다.
- 열 순서는 상관없습니다. 이름으로 찾습니다.
- 필수 4개를 제외한 열은 없어도 됩니다. 없으면 기본값이 쓰입니다.
- `CUTName`과 `CUTPath`는 블록 이름의 공백을 그대로 보존합니다. `HarnessName`과
  `TestCaseName`은 식별자이므로 앞뒤 공백을 제거합니다.

### 한글 열 이름도 인식합니다

각 열은 여러 이름을 허용합니다. 기존 관리 파일을 그대로 쓰기 위한 장치입니다.

| 표준 이름 | 함께 인식하는 이름 |
| --- | --- |
| `CUTName` | `ModelName`, `CUT`, `모델명`, `대상모델명` |
| `CUTPath` | `Path`, `path`, `경로`, `모델경로` |
| `HarnessName` | `Harness`, `하네스명` |
| `TestCaseName` | `TestCase`, `TCName`, `테스트케이스명` |
| `No` | `번호`, `Number`, `순번` |
| `Enabled` | `사용`, `사용여부`, `활성`, `활성화` |
| `SldvMode` | `SLDVMode`, `SLDV Mode` |
| `SldvDataFile` | `SLDVDataFile`, `SLDV Data File` |
| `DataFileFormat` | `Data File Format`, `데이터파일형식` |
| `MatVariableName` | `MATVariableName`, `MAT Variable Name`, `MAT변수명` |
| `ExpectedUpdateMode` | `Expected Update Mode`, `기대값갱신모드` |
| `CoverageFilterMode` | `Coverage Filter Mode`, `커버리지필터모드` |
| `CoverageFilterAction` | `Coverage Filter Action`, `커버리지필터동작` |
| `CoverageFilterRationale` | `Coverage Filter Rationale`, `커버리지필터사유` |
| `CoverageBoundaryMode` | `Coverage Boundary Mode`, `커버리지경계모드` |
| `PreparationMode` | `Preparation Mode`, `준비실행모드` |
| `PreparationFromStage` | `Preparation From Stage`, `준비시작단계` |

## 1. 한눈에 보기

| 열 | 필수 | 기본값 | 무엇을 정하는가 |
| --- | --- | --- | --- |
| [`CUTName`](#cutname) | 예 | — | 테스트할 Subsystem 이름 |
| [`CUTPath`](#cutpath) | 예 | — | 그 Subsystem이 모델 어디에 있는지 |
| [`HarnessName`](#harnessname) | 예 | — | 만들거나 재사용할 Harness 이름 |
| [`TestCaseName`](#testcasename) | 예 | — | Test Manager에 만들 Test Case 이름 |
| [`No`](#no) | 아니요 | Excel 순서 | 결과 폴더 번호 |
| [`Enabled`](#enabled) | 아니요 | `true` | 이 행을 이번에 처리할지 |
| [`SldvMode`](#sldvmode) | 아니요 | `OFF` | 입력 데이터를 어디서 가져올지 |
| [`SldvDataFile`](#sldvdatafile) | 조건부 | 빈 값 | 입력 파일 경로 |
| [`DataFileFormat`](#datafileformat) | 아니요 | `SLDV` | 그 입력 파일의 형식 |
| [`MatVariableName`](#matvariablename) | 아니요 | 빈 값 | MAT 안에서 쓸 변수 하나 |
| [`ExpectedUpdateMode`](#expectedupdatemode) | 아니요 | `DEFAULT` | 실패 시 기대값을 고칠지 |
| [`CoverageFilterMode`](#coveragefiltermode) | 아니요 | `OFF` | CUT 내부를 커버리지에서 뺄지 |
| [`CoverageBoundaryMode`](#coverageboundarymode) | 아니요 | `OFF` | CUT 바깥을 커버리지에서 뺄지 |
| [`CoverageFilterAction`](#coveragefilteraction) | 조건부 | 빈 값 | 뺄지, 정당화할지 |
| [`CoverageFilterRationale`](#coveragefilterrationale) | 조건부 | 빈 값 | 왜 뺐는지 |
| [`PreparationMode`](#preparationmode) | 아니요 | `DEFAULT` | 이전 결과를 재사용할지 |
| [`PreparationFromStage`](#preparationfromstage) | 아니요 | `DEFAULT` | 어느 단계부터 다시 할지 |
| [`TestPreparationSource`](#testpreparationsource) | 아니요 | `EXISTING` | Harness를 새로 만들지, 복제할지 |
| [`SourceCUTPath`](#sourcecutpath) | 조건부 | 빈 값 | 복제할 원본 CUT 경로 |
| [`SourceHarnessName`](#sourceharnessname) | 조건부 | 빈 값 | 복제할 원본 Harness 이름 |

## 2. 대상 지정 (필수 4개)

### `CUTName`

테스트할 Subsystem 블록의 **이름**입니다. 결과 폴더 이름, SLDV 데이터 폴더 이름,
자동 생성되는 Scenario 이름(`UT_REQ_{CUTName}_001`)에 쓰입니다.

블록 이름에 공백이 있으면 공백까지 그대로 적습니다. 이름만으로는 같은 이름을 가진
Subsystem을 구분할 수 없으므로 `CUTPath`가 함께 필요합니다.

### `CUTPath`

Top Model 이름부터 시작하는 블록의 전체 경로입니다.

```text
TopModel/Logic/Controller
```

이 도구가 하는 거의 모든 일의 기준점입니다. 이 값이 틀리면 Harness를 엉뚱한 블록에
만들게 되므로, 실행 전에 `st_pre_validate_targets`가 다음을 확인합니다.

- 값이 비어 있지 않은가
- 현재 선택한 Top Model 기준으로 경로를 정규화할 수 있는가
- 그 경로에 블록이 실제로 있는가
- 그 블록이 Subsystem인가

경로를 손으로 적기 어려우면 `st_export_subsystem_paths`,
`st_fill_temp_paths_from_indent`, `st_find_target_paths`를 쓰십시오.

> 같은 `CUTPath`를 두 활성 행에 적지 마십시오. 한 Subsystem을 두 Test Case가 각자
> 준비하면 서로의 Harness 설정을 덮어씁니다. 경로를 자동으로 채우는
> `st_find_target_paths`는 이 중복을 감지하면 Excel을 고치지 않고 중단하지만,
> 손으로 적은 중복을 일반 workflow가 자동으로 잡아 주지는 않습니다.

### `HarnessName`

이 CUT에 붙일 Test Harness의 이름입니다.

- 같은 이름의 Harness가 이미 있으면 **그것을 재사용합니다.** 지우고 다시 만들지
  않습니다.
- 없으면 새로 만듭니다. Harness 생성은 모델 컴파일을 포함하므로 CUT 하나에 수 분이
  걸릴 수 있습니다.

standalone 제출물에서는 이 이름이 그대로 독립 모델 파일 이름(`.slx`)이 됩니다.

### `TestCaseName`

Test Manager에 만들 Test Case의 이름입니다. 결과 파일 이름의 기준이기도 합니다.
standalone 제출물의 산출물은 이 이름에 접두사를 붙여
`UT_REQ_{TestCaseName}.cvf` / `.cvt` / `.html`로 저장됩니다.

기본 설정(`cfg.OverwriteTestFile=false`)에서는 같은 이름의 Test Case가 이미 있으면
건드리지 않고, 없는 것만 추가합니다.

## 3. 실행 범위

### `No`

결과 폴더와 manifest에 쓰이는 식별 번호입니다. 비워 두면 Excel의 행 순서를
그대로 씁니다. 결과 폴더가 `{No}_{CUTName}_{해시}` 형태로 만들어지므로, 번호를
고정해 두면 실행할 때마다 폴더 이름이 흔들리지 않습니다.

### `Enabled`

이번 실행에서 이 행을 처리할지 여부입니다(`TRUE` / `FALSE`).

`cfg.OnlyEnabled=true`(기본값)일 때만 의미가 있습니다. `false`로 바꾸면 `Enabled`
값과 무관하게 모든 행을 처리합니다.

특정 CUT만 다시 돌리고 싶을 때 나머지를 `FALSE`로 내리는 것이 가장 간단한
방법입니다. `PER_CUT` 실행에서 다른 Test Case의 Enabled 상태는 이 도구가 임의로
바꾸지 않습니다.

## 4. 입력 데이터

### `SldvMode`

CUT에 넣을 입력 신호를 **어디서 가져올지** 정합니다. 이 도구에서 가장 영향이 큰
선택입니다.

| 값 | 동작 | 필요한 라이선스 |
| --- | --- | --- |
| `OFF` (기본) | Harness에 이미 있는 입력을 그대로 씁니다. Scenario 하나를 `UT_REQ_{CUTName}_001`로 이름만 맞춥니다 | 없음 |
| `FILE` | 이미 있는 MAT 파일을 읽어 Scenario로 변환합니다 | 없음 |
| `GENERATE` | 지금 SLDV 분석을 돌려 입력을 새로 만듭니다 | Simulink Design Verifier |

`GENERATE`는 분기를 자동 탐색하므로 CUT이 복잡하면 오래 걸립니다. 한 번
`GENERATE`로 만든 결과는 `result/sldv/{No}_{CUTName}/latest_sldvdata.mat`에
저장되므로, 이후에는 그 파일을 `FILE`로 지정해 재사용할 수 있습니다.

> **Atomic Subsystem 요구:** `FILE`+`SLDV`와 `GENERATE` 대상은 Atomic Subsystem이어야
> 합니다. 기본 설정(`cfg.AutoConvertSldvTargetsToAtomic=true`)은 라이브러리 링크가
> 없는 CUT만 자동으로 `TreatAsAtomicUnit=on`으로 바꿔 줍니다. 링크된 CUT은 원본
> 라이브러리 훼손을 막기 위해 자동 변경하지 않고 오류로 중단합니다. 이때는 원본
> 라이브러리 블록을 Atomic으로 만들고 링크를 갱신해야 합니다.
> 일반 `FILE`+`MAT`에는 이 제약이 없습니다.

### `SldvDataFile`

`SldvMode=FILE`일 때 읽을 MAT 파일의 경로입니다. `FILE`에서는 **필수**이고, 다른
모드에서는 무시됩니다.

절대 경로 또는 상대 경로를 쓸 수 있습니다.

> **상대 경로의 기준은 MATLAB의 Current Folder가 아니라 `TestManagement.xlsx`가 있는
> 폴더입니다.** 가장 흔한 실수이므로 주의하십시오.

```text
sldv_data/Controller_sldvdata.mat
```

### `DataFileFormat`

`SldvDataFile`이 가리키는 MAT의 **형식**입니다. SLDV 결과 MAT와 직접 만든 Dataset
MAT는 확장자가 둘 다 `.mat`이라 내용으로 구분할 수 없으므로, 여기서 명시해 주어야
합니다. **확장자로 자동 판별하지 않습니다.**

| 값 | 내용 | 비고 |
| --- | --- | --- |
| `SLDV` (기본) | Design Verifier가 만든 `sldvData` 구조체 | TestCase parameter override도 함께 적용 |
| `MAT` | `Simulink.SimulationData.Dataset` 변수를 담은 일반 MAT | SLDV 분석을 돌리지 않음 |

이 열이 아예 없는 기존 Excel은 전부 `SLDV`로 처리되므로 기존 동작이 바뀌지
않습니다.

### `MatVariableName`

`DataFileFormat=MAT`일 때, MAT 안의 여러 변수 중 **어느 하나만** 쓸지 지정합니다.

| 값 | 동작 |
| --- | --- |
| 빈 값 (기본) | 파일 안의 비어 있지 않은 Dataset 변수를 **전부** 쓰며, 변수 이름 순서대로 Scenario를 만듭니다 |
| 변수 이름 | 정확히 그 이름의 변수 하나만 씁니다 |

Dataset이 아닌 변수가 같이 들어 있어도 무시합니다. 다만 Dataset 후보가 하나도
없거나, 지정한 이름이 없거나, 그 변수가 Dataset이 아니면 실패합니다.

여러 Scenario를 쓸 때는 **입력 개수·순서·이름·자료형·차원이 모두 같아야 하고**,
Harness의 Signal Editor ActiveScenario와도 정확히 일치해야 합니다.

최종 Scenario 이름은 항상 `UT_REQ_{CUTName}_{번호}`가 되고, 원래 MAT 변수 이름은
manifest의 `OriginalNames`에 남습니다.

## 5. 기대값 갱신

### `ExpectedUpdateMode`

테스트가 **실패했을 때** Assessment의 기대값(`verify(... == 기대값)`의 오른쪽)을
실제 출력값으로 고쳐 쓸지 정합니다.

| 값 | 동작 |
| --- | --- |
| `DEFAULT` (기본) | 전역 설정 `cfg.ExpectedUpdateMode`를 따릅니다. 그 기본값은 `APPLY`입니다 |
| `OFF` | 실패해도 기대값을 바꾸지 않습니다 |
| `APPLY` | 실패한 Iteration의 실제 출력값을 기대값에 반영하고, 값이 바뀌었으면 다시 실행합니다 |

> **중요:** 아무것도 적지 않으면 `APPLY`가 됩니다. 승인된 기준값이 이미 있는
> 대상에는 반드시 `OFF`를 적으십시오.

`APPLY`의 실제 동작 범위는 다음과 같습니다.

- 실패한 Iteration만 처리합니다.
- 실제값과 현재 기대값이 다를 때만 고칩니다.
- 자동 갱신 대상은 실수 스칼라와 logical 스칼라입니다. 배열이나 Bus 기대값은
  Assessment 생성은 되지만 자동 갱신 대상이 아닙니다.
- 하나라도 바뀌면 `cfg.RerunAfterExpectedUpdate=true`(기본값)에 따라 같은 범위를
  다시 실행합니다. `PER_CUT`에서는 같은 CVF를 유지한 채 그 Test Case만 재실행한 뒤
  필터를 복원합니다.

후보를 사람이 검토한 뒤 승인하는 `REVIEW` 모드는 아직 없습니다.

## 6. 커버리지 필터

두 열은 **독립적**입니다. 하나는 CUT 안쪽을, 다른 하나는 CUT 바깥쪽을 다룹니다.
둘 다 꺼 두면 CVF를 만들지 않고, 하나라도 켜면 `ExecutionMode=AUTO`가 `PER_CUT`을
선택합니다.

### `CoverageFilterMode`

CUT **내부**의 하위 Subsystem을 커버리지 계산에서 뺄지 정합니다. 테스트 범위가
아닌 하위 모듈 때문에 커버리지가 낮게 나오는 것을 막는 용도입니다.

| 값 | 필터 대상 |
| --- | --- |
| `OFF` (기본) | 내부 규칙을 만들지 않습니다 |
| `SUBSYSTEM` | `CUTPath` **바로 아래** 하위 Subsystem 블록 자체만 |
| `ALL_CONTENT` | `CUTPath` 바로 아래 하위 Subsystem과 **그 안의 전체 내용**까지 |

두 모드 모두 CUT 자기 자신은 선택하지 않습니다. 바로 아래 하위 Subsystem이 하나도
없고 경계 모드도 `OFF`라면 규칙이 0개인 CVF가 만들어집니다. 이것은 오류가 아닙니다.

### `CoverageBoundaryMode`

CUT **바깥**을 커버리지에서 뺄지 정합니다. Harness나 standalone 모델에는 CUT 외에
입력 생성 블록 같은 것이 함께 들어 있는데, 이것들이 커버리지 분모에 잡히는 것을
막습니다.

| 값 | 동작 |
| --- | --- |
| `OFF` (기본) | 아무것도 하지 않습니다 |
| `CUT_ONLY` | 실행 루트에서 CUT 밖의 최상위 블록을 제외합니다 |

`CoverageFilterMode=OFF` + `CoverageBoundaryMode=CUT_ONLY` 조합도 유효하며 이때도
CVF가 만들어집니다.

### `CoverageFilterAction`

위 두 모드 중 하나라도 켜면 **필수**입니다. 고른 대상을 어떻게 처리할지 정합니다.

| 값 | 의미 | 커버리지 수치에 미치는 영향 |
| --- | --- | --- |
| `EXCLUDE` | 커버리지에서 제외 | 분모에서 빠집니다 |
| `JUSTIFY` | 정당한 미달로 기록 | 분모에 남고 justified로 따로 집계됩니다 |

### `CoverageFilterRationale`

필터를 쓸 때 **필수**인 사유 문구입니다. 비워 두면 실행하지 않습니다.

나중에 보고서를 검토하는 사람이 "왜 이 블록을 뺐는가"를 알 수 없으면 커버리지
수치를 신뢰할 수 없기 때문에 강제합니다. 검토 가능한 문장으로 적으십시오.

> 만들어진 CVF는 저장 직후 다시 열어 규칙 개수와 action을 검증합니다. 제대로 열리지
> 않으면 해당 CUT을 `FAIL`로 기록합니다.

## 7. 준비 단계 재실행

### `PreparationMode`

이전에 성공한 준비 결과를 재사용할지 정합니다.

| 값 | 동작 |
| --- | --- |
| `DEFAULT` (기본) | 전역 설정 `cfg.PreparationMode`를 따릅니다. 그 기본값은 `AUTO`입니다 |
| `AUTO` | 입력 지문이 이전 checkpoint와 같으면 그 단계를 건너뜁니다 |
| `FORCE` | `PreparationFromStage`부터 끝까지 다시 실행합니다 |

`AUTO`가 지문을 비교하는 대상은 Excel 행, 설정, 모델, Test File, SLDV 입력,
그리고 이 도구의 코드 자체입니다. 하나라도 달라지면 그 단계부터 다시 합니다.

### `PreparationFromStage`

`FORCE`가 **어느 단계부터** 다시 시작할지 정합니다.

```text
START → HARNESS → SLDV → HARNESS_CONFIG → SIGNAL_EDITOR
→ ASSESSMENT → COVERAGE_FILTER → TEST_MANAGER → ALIGNMENT
```

`START`는 전체 workflow에서는 `HARNESS`, 기존 Harness workflow에서는 `SLDV`로
해석됩니다. `SLDV` 단계에는 `OFF`와 `FILE` 대상의 입력 준비도 포함됩니다.

선택한 단계보다 뒤에 있는 단계는 전부 다시 실행됩니다. 앞 단계는 건드리지
않습니다.

> 이 열은 "지금부터 다시 해라"라는 뜻이고, 앞 단계의 유효성을 검사하지는 않습니다.
> 앞 단계가 멀쩡한지 확인한 뒤 실행하고 싶으면 `st_check_readiness`와
> `st_run_from_stage`를 쓰십시오. [재시작](manual/restart.md)에 설명이 있습니다.

## 8. Template Harness 복제

이미 잘 만들어 둔 Harness를 본떠 다른 CUT의 Harness를 만드는 기능입니다. 자세한
절차와 복구 방법은 [Template Harness clone](harness-template-clone.md)에 있습니다.

### `TestPreparationSource`

| 값 | 동작 |
| --- | --- |
| `EXISTING` (기본, 빈 값 포함) | 일반 방식으로 Harness를 만들거나 재사용합니다 |
| `HARNESS_CLONE` | 아래 두 열이 가리키는 Template Harness를 복제합니다 |

`HARNESS_IMPORT`는 폐지되었습니다. 그 값이 남아 있으면 오류로 중단합니다.

### `SourceCUTPath`

복제할 원본 Harness가 붙어 있는 CUT의 전체 경로입니다. **원본 모델 이름을 포함한
전체 경로**여야 하며, 대상 행의 `CUTPath`와 다른 모델이어도 됩니다.

```text
TEMPLATE_MODEL/TemplateCUT
```

원본 모델은 MATLAB 경로에서 로드할 수 있어야 합니다.

### `SourceHarnessName`

복제할 Template Harness의 이름입니다. 대상 Harness의 이름은 이 열이 아니라 그 행의
`HarnessName`을 그대로 씁니다.

복제 전에 컴파일된 포트 순서·이름·타입·차원·버스 정의·샘플 시간을 비교합니다.
호환되지 않으면 그 CUT만 실패로 기록하고 다른 CUT은 계속 처리합니다.

## 9. 값이 잘못됐을 때

| 증상 | 확인할 열 |
| --- | --- |
| 블록을 찾을 수 없다 | `CUTPath` — 모델 이름부터 시작하는 전체 경로인가 |
| Harness 설정이 서로 덮어써진다 | `CUTPath` — 두 활성 행이 같은 경로를 쓰고 있는가 |
| MAT 파일을 찾을 수 없다 | `SldvDataFile` — 상대 경로 기준은 Excel 파일 위치입니다 |
| MAT은 있는데 형식 오류 | `DataFileFormat` — `SLDV`와 `MAT`을 바꿔 적지 않았는가 |
| 기대값이 마음대로 바뀌었다 | `ExpectedUpdateMode` — 빈 값은 `APPLY`입니다 |
| 필터 사유가 없다고 중단 | `CoverageFilterRationale` — 필터를 켜면 필수입니다 |
| SLDV가 Atomic이 아니라고 중단 | `SldvMode` — `FILE+SLDV`/`GENERATE`는 Atomic이 필요합니다 |

더 자세한 대처는 [문제 해결](troubleshooting.md)을 보십시오.
