# 용어집

이 도구의 문서에는 Simulink Test 제품의 용어가 그대로 나옵니다. MATLAB이나
Simulink Test를 처음 쓴다면 이 문서를 먼저 읽으십시오. 각 용어는 "무엇인가"와
"이 도구에서 어떤 역할인가"를 함께 설명합니다.

## 1. 테스트 대상

### Top Model (최상위 모델)

테스트하려는 전체 Simulink 모델 파일(`.slx`) 하나입니다. 이 도구는 한 번에 하나의
Top Model만 다룹니다. 관리 Excel의 모든 활성 행은 같은 Top Model에 속합니다.

Top Model 이름은 코드에 적지 않습니다. `st_select_target_model`로 고르면
`runtime_target.mat`이라는 로컬 파일에 저장됩니다.

### CUT (Component Under Test, 테스트 대상 블록)

Top Model 안에서 실제로 테스트하려는 Subsystem 하나입니다. "이 서브시스템이
의도한 대로 동작하는가"를 확인하는 단위이며, 이 도구의 작업은 전부 CUT 단위로
움직입니다.

CUT은 두 값으로 지정합니다.

| 값 | 의미 | 예 |
| --- | --- | --- |
| `CUTName` | Subsystem 블록의 이름 | `Controller` |
| `CUTPath` | Top Model부터 시작하는 전체 경로 | `TopModel/Logic/Controller` |

이름만으로는 같은 이름의 Subsystem이 여러 개일 때 구분할 수 없으므로 경로가
필요합니다. 경로를 채우는 보조 명령은 [운영자 매뉴얼](operator-manual.md)에
있습니다.

### Library link (라이브러리 링크)

Simulink Library에 있는 원본 블록을 여러 모델에서 참조해 쓰는 기능입니다. 링크된
블록은 원본을 복사한 것이 아니라 가리키고 있는 것이므로, 링크된 CUT을 잘못 건드리면
그 변경이 원본 라이브러리로 퍼져 다른 모델까지 바뀔 수 있습니다.

이 도구는 링크된 CUT을 자동으로 수정하지 않고, 링크 상태가 바뀐 것이 감지되면
모델을 저장하지 말라는 오류로 즉시 중단합니다.

## 2. 테스트 자산

### Test Harness (테스트 하네스)

CUT 하나를 전체 모델에서 떼어내 따로 실행하기 위해 Simulink Test가 만들어 주는
별도의 작은 모델입니다. 안에는 CUT 복사본과 입력을 넣어 주는 블록, 출력을 검사하는
블록이 들어 있습니다.

비유하면 부품 하나를 시험하기 위한 전용 시험대입니다. 전체 자동차를 돌리지 않고
브레이크만 따로 시험하는 것과 같습니다.

Harness는 보통 Top Model 안에 숨겨진 형태로 저장됩니다(내부 Harness). 이 도구의
`st_export_test_bundle`이나 standalone pipeline은 이것을 독립 `.slx` 파일로
꺼내기도 합니다.

### Signal Editor (신호 편집기)

Harness 안에서 CUT에 넣어 줄 입력 신호를 담고 있는 블록입니다. 실제 신호 데이터는
옆에 있는 MAT 파일에 저장되고, Signal Editor는 그중 어느 것을 쓸지 고릅니다.

### Scenario (시나리오)

Signal Editor MAT 파일 안에 저장된 입력 신호 묶음 하나입니다. "속도 0에서 100까지
올렸을 때"처럼 한 가지 시험 상황에 해당합니다. 한 MAT 파일에 여러 Scenario가 들어
있을 수 있고, 지금 쓰고 있는 것을 ActiveScenario라고 부릅니다.

이 도구는 Scenario 이름을 `UT_REQ_{CUTName}_{번호}` 규칙으로 통일합니다.

### Test Assessment (테스트 평가 블록)

Harness 안에서 "출력이 이 값이어야 한다"를 적어 두는 블록입니다. 내용은 Test
Sequence 언어로 된 단계(Step)와 `verify(...)` 문장으로 구성됩니다.

이 도구가 자동으로 만드는 형태는 다음과 같습니다.

```text
step1: 아무것도 하지 않고 기다림 → step2로 전이
step2: verify(출력신호 == 기대값)
```

기대값(expected value)이란 `verify(... == 기대값)`의 오른쪽 값입니다.

### Test Manager / Test File / Test Case / Iteration

| 용어 | 의미 |
| --- | --- |
| Test Manager | 테스트를 실행하고 결과를 보는 Simulink Test의 화면 |
| Test File | Test Manager가 읽는 파일(`{TopModel}.mldatx`). Test Case 정의가 들어 있습니다 |
| Test Suite | Test File 안에서 Test Case를 담는 묶음. 기본 이름은 `New Test Suite 1` |
| Test Case | 실행 단위 하나. 보통 CUT 하나에 Test Case 하나가 대응합니다 |
| Iteration | 한 Test Case 안에서 입력 Scenario를 바꿔 가며 반복 실행하는 단위 |

Scenario가 3개면 Iteration도 3개가 되고, 서로 일대일로 연결되어야 합니다. 이
일치 여부를 검사하는 단계가 `ALIGNMENT`입니다.

## 3. 입력 데이터 생성

### SLDV (Simulink Design Verifier)

모델의 분기를 자동으로 분석해서 "이 분기를 타려면 입력이 얼마여야 하는가"를
계산하고 테스트 입력을 만들어 주는 MathWorks 제품입니다. 직접 입력값을 손으로
만들지 않아도 되므로 커버리지를 올리기 쉽습니다.

이 도구에서 SLDV는 관리 Excel의 `SldvMode` 열로 제어합니다.

| 값 | 의미 |
| --- | --- |
| `OFF` | SLDV를 쓰지 않고 Harness에 이미 있는 입력을 그대로 씁니다 |
| `FILE` | 이미 있는 MAT 파일을 입력으로 씁니다. SLDV 라이선스가 필요 없습니다 |
| `GENERATE` | 지금 SLDV를 돌려 입력을 새로 만듭니다. SLDV 라이선스가 필요합니다 |

### Dataset MAT

`Simulink.SimulationData.Dataset` 형식으로 신호를 담은 일반 MAT 파일입니다. SLDV
없이 직접 만든 입력을 쓸 때 사용하며, `SldvMode=FILE` + `DataFileFormat=MAT`로
지정합니다. SLDV가 만든 MAT(`sldvData` 구조체)와는 내용이 다르므로 확장자가 같아도
`DataFileFormat`으로 구분해서 알려 주어야 합니다.

### Tmax

한 CUT의 입력 데이터에 기록된 마지막 시각 중 가장 큰 값입니다. Harness를 언제까지
돌릴지(StopTime), 기대값을 언제 샘플링할지가 모두 이 값을 기준으로 정해집니다.
기본적으로 0.01초 격자로 올림합니다.

## 4. Coverage(커버리지)

### Coverage

테스트가 모델의 어느 부분을 실제로 지나갔는지 측정한 값입니다. 이 도구는 두 가지를
수집합니다.

| 지표 | 의미 |
| --- | --- |
| Decision | 분기(if/switch 등)의 참·거짓 갈래를 각각 지나갔는가 |
| Block Execution | 각 블록이 한 번이라도 실행됐는가 |

분모가 0이면 백분율을 계산할 수 없으므로 `N/A`로 기록합니다. 커버리지가 낮다는
이유만으로 테스트를 실패로 바꾸지는 않습니다.

### CVF (Coverage Filter, `.cvf` 파일)

커버리지 계산에서 특정 블록을 빼거나 "이건 안 지나가도 정당하다"고 표시하는 규칙
파일입니다. CUT 바깥의 블록이나 테스트 범위가 아닌 하위 모듈 때문에 커버리지가
낮게 나오는 것을 막는 데 씁니다.

두 가지 동작이 있습니다.

| `CoverageFilterAction` | 의미 |
| --- | --- |
| `EXCLUDE` | 분모에서 아예 제외합니다 |
| `JUSTIFY` | 분모에는 남기되 "정당한 미달"로 따로 집계합니다 |

필터를 쓸 때는 반드시 사유(`CoverageFilterRationale`)를 적어야 합니다. 나중에
검토하는 사람이 왜 뺐는지 알 수 없으면 커버리지 수치를 신뢰할 수 없기 때문입니다.

CVF 규칙은 블록을 경로가 아니라 **SID**(모델 안에서 블록에 붙는 내부 식별자)로
가리킵니다. 그래서 CVF 뷰어에서 모델이 열려 있지 않으면 이름 칸이 `n/a`로 보입니다.
고장이 아닙니다. 자세한 이유는 [결과 열기](manual/open-results.md)에 있습니다.

### CVT (`.cvt` 파일)

커버리지 측정 결과 원본 데이터 파일입니다. HTML 보고서는 여기서 만들어집니다.

## 5. 실행 방식

### BATCH와 PER_CUT

| 모드 | 동작 | 언제 |
| --- | --- | --- |
| `BATCH` (기본) | Test File 전체를 한 번에 실행합니다 | 평소 |
| `PER_CUT` | Test Case를 Excel 순서대로 하나씩 따로 실행합니다 | **혼자 돌려야만 되는 Test Case가 있을 때** |

**어느 쪽으로 돌릴지는 부르는 쪽이 정합니다.** Excel은 관여하지 않습니다.

```matlab
st_run_after_harness('ExecutionMode','PER_CUT')
```

커버리지 필터는 이 선택과 무관합니다. 필터는 결과물을 만들 때 적용되므로 CVF를
쓰는 대상도 `BATCH`로 돌 수 있습니다.

두 모드의 실질적인 차이는 **재실행 범위**입니다. 기대값을 고친 뒤 `BATCH`는 Test
File 전체를 다시 돌리고, `PER_CUT`은 해당 Test Case만 다시 돌립니다.

> 예전 `AUTO` 모드는 없어졌습니다. Excel의 CVF 설정을 보고 `PER_CUT`을 골랐는데,
> 필터가 결과물 단계로 옮겨가면서 근거가 사라졌습니다.

### 실행 기록 (run record)

Test Manager의 결과(ResultSet)는 그 결과를 만든 MATLAB 세션 안에서만 살아 있습니다.
그래서 실행이 끝나면 결과와 표를 `result/run_records/`에 저장해 둡니다. 보고서는
이 기록에서 나중에, 다른 세션에서도 만들 수 있습니다.

| 실행 방식 | 결과 정리 명령 |
| --- | --- |
| `BATCH` | `st_generate_test_report` |
| `PER_CUT` | `st_collect_per_cut_results` |

### transient CVF (임시 필터 적용)

생성된 CVF는 Test File에 영구 저장하지 않습니다. 결과 데이터에 붙이는 동안에만
쓰고, 모델 설정을 건드린 경우 끝나면 원래대로 되돌립니다. 되돌리기에 실패하면
다른 테스트의 설정이 오염될 수 있으므로 즉시 중단합니다.

### Standalone (독립 실행)

Harness를 Top Model에서 완전히 떼어내 혼자 열리는 `.slx` 모델로 만든 것입니다.
모델을 받는 쪽에 Top Model이 없어도 열 수 있으므로 제출물이나 다른 PC 전달에
씁니다. 원본의 SID를 물려받지 않는 별개 모델이라는 점이 중요합니다.

## 6. 실행 제어

### Stage (단계)

준비 작업을 쪼갠 단위입니다. 순서는 다음과 같습니다.

```text
HARNESS → SLDV → HARNESS_CONFIG → SIGNAL_EDITOR → ASSESSMENT
→ TEST_MANAGER → ALIGNMENT → EXECUTE
```

`SLDV`라는 이름의 단계에는 `OFF`와 `FILE` 대상의 입력 준비도 포함됩니다.

### Checkpoint와 증분 실행

각 단계가 성공하면 그 시점의 입력 지문(fingerprint)을 `result/state/`에
저장합니다. 다음 실행에서 입력이 그대로면 그 단계를 건너뛰고 재사용합니다.
Harness 생성처럼 몇 분씩 걸리는 단계를 매번 다시 하지 않기 위한 장치입니다.

## 7. 결과 판정 용어

| 상태 | 의미 |
| --- | --- |
| `PASS` | 통과 |
| `FAIL` | 기능 또는 무결성 오류 |
| `WARN` | 통과를 막지는 않는 관찰 사항(예: 커버리지 미달) |
| `BLOCKED` | 제품·라이선스·입력이 없어서 검사 자체를 수행하지 못함 |
| `SKIP` | 이 대상에는 해당되지 않음 |
| `EXCEPT` | 시뮬레이션 중 예외가 나서 끝까지 실행되지 못함 |
| `PARTIAL` | 일부만 성공. 산출물이 일부 누락 |

전체 상태는 `FAIL > BLOCKED > PASS_WITH_WARNINGS > PASS` 순서로 집계합니다. 즉
하나라도 `FAIL`이면 전체가 `FAIL`입니다.

## 8. 자주 보이는 파일

| 파일 | 내용 | Git 추적 |
| --- | --- | --- |
| `TestManagement.xlsx` | 무엇을 테스트할지 적는 관리 파일 | 실제 업무 파일은 제외 |
| `runtime_target.mat` | 이 PC에서 고른 모델 정보 | 제외 |
| `{TopModel}.mldatx` | Test Manager가 읽는 Test File | 제외 |
| `result/` | 실행 결과 전부 | 제외 |
| `result/state/workflow_state.mat` | 단계별 checkpoint | 제외 |

`runtime_target.mat`은 PC마다 다른 로컬 설정입니다. 저장소를 받아도 다른 사람의
모델 선택이 딸려 오지 않습니다.
