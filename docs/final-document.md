# 최종 문서 추출

고객에게 제출할 문서를 명령 하나로 만듭니다. 지금까지 명세서 Excel, 결과 정리
산출물, `CoverageSummary.xlsx`를 각각 열어 손으로 옮겨 적던 내용을 한 파일에
모읍니다.

테스트를 **실행하지 않습니다.** 시뮬레이션, 테스트 실행, SLDV 생성, 기대값
갱신을 호출하지 않습니다. 모델과 블록을 읽기 위해 로드만 합니다.

**이미 만들어 둔 명세서 Excel을 읽지 않습니다.** `st_export_test_specification`과
똑같은 방식으로 저장된 모델에서 다시 추출합니다. 판정과 커버리지만 기존 결과
파일에서 읽습니다.

**실패한 verify의 내용은 적지 않습니다.** 어느 행을 봐야 하는지와 어느
`.mldatx`를 Test Manager에서 열어야 하는지만 줍니다.

## 1. 선행 조건 — 결과 정리를 먼저 하십시오

이 문서를 가장 먼저 읽으셔야 합니다.

기본 설정이 `cfg.GenerateTestReport = false`이고
`cfg.PerCutResultCollection = 'DEFERRED'`입니다. 즉 **테스트를 실행만 하면
iteration별 판정이 파일에 남지 않습니다.** 그 상태로 이 명령을 부르면 `판정
결과` 열이 전부 빈 칸입니다.

| 실행 방식 | 먼저 부를 명령 |
| --- | --- |
| `PER_CUT` (기본) | `st_collect_per_cut_results` |
| `BATCH` | `st_generate_test_report` |

가장 쉬운 방법은 실행할 때 수집까지 이어서 하는 것입니다.

```matlab
st_run_from_harness('AutoCollect', true)
```

정리를 건너뛰어도 오류로 막지는 않습니다. 판정이 빈 칸이 되고 `TestResults`
시트의 모든 행에 `NOT_COLLECTED` 또는 `NOT_REPORTED`가 적힙니다. 빈 판정을
아예 허용하지 않으려면 `RequireTestResults`를 켜십시오.

> **정리한 뒤에 테스트를 또 돌리면 처음으로 돌아갑니다.**
> `result/per_cut_latest.json`은 *실행*이 쓰고 수집은 쓰지 않습니다. 새로
> 실행하면 포인터가 아직 정리되지 않은 새 실행을 가리키므로 판정이 다시 전부
> 빈 칸이 됩니다. 실행할 때마다 정리도 같이 하시는 편이 안전합니다.

커버리지 시트까지 채우려면 standalone 산출물도 있어야 합니다.

```matlab
st_run_standalone_coverage_pipeline('Action', 'ALL', ...
    'ContinueOnFailure', true, 'FailOnNonPass', false);
```

## 2. 실행

모델·하네스·Test File·입력 MAT을 저장하고, 실행 중인 모델을 멈춘 뒤 실행합니다.

```matlab
st_setup
[T, outputFile] = st_export_final_document();
winopen(outputFile)
```

기본 출력은 `result/final_document_<timestamp>.xlsx`입니다. 별도 Excel 설치나
ActiveX가 필요 없습니다. 기존 `cfg.OnlyEnabled`, 관리 Excel, `cfg.TestSuiteName`을
그대로 씁니다.

전체 흐름은 이렇습니다.

```matlab
st_setup
st_pre_validate_targets
st_run_from_harness('AutoCollect', true)     % 실행 + 결과 정리
st_run_standalone_coverage_pipeline('Action','ALL', ...
    'ContinueOnFailure',true,'FailOnNonPass',false);
[T, outputFile] = st_export_final_document();
```

## 3. 시트 구성

| 시트 | 내용 |
| --- | --- |
| `TestCase` | 고객 양식 14열 |
| `Coverage` | CUT별 Execution / Decision 커버리지 |
| `TestResults` | 행별 판정과 확인이 필요한 곳 |
| `OverflowDetails` | 셀 한도를 넘은 텍스트의 조각 |
| `Metadata` | 언제, 무엇에서, 어느 실행에서 만들었는지 |

`사용법` 시트는 넣지 않습니다. 내부 `st_*` 명령 목록이라 고객 제출물에 맞지
않습니다. 필요하면 `IncludeUsageSheet`를 켜면 맨 뒤에 붙습니다.

## 4. `TestCase` 시트 — 14열

행 단위는 명세서와 같습니다. **테스트 케이스 × Assessment 시나리오 × 입력 연결
마다 한 행**입니다.

| # | 머리글 | 무엇이 들어가나 | 어디서 오나 |
| --- | --- | --- | --- |
| 1 | `Test Case ID` | `UT_REQ_Controller_12345_001` | 시나리오명 + codeBeamer ID |
| 2 | `ID` | `12345` | 테스트 케이스명에서 뽑은 codeBeamer ID |
| 3 | `-` | 빈칸 | 고객 양식의 빈 열 |
| 4 | `Pre Condition` | 숫자 그대로 (`0.2`) | `MaxTime` |
| 5 | `Description` | `D1 [T/F]Switch (c1 > 0)` | 커버리지가 잡은 분기 블록 |
| 6 | `Test Steps.Action` | 입력 신호의 마지막 값 | `input 시나리오 내용` |
| 7 | `Test Steps.Expected result` | verify 문장 | `verify 내용` |
| 8–11 | `-` ×4 | 빈칸 | 고객 양식의 빈 열 |
| 12 | `출력값` | 7열과 같은 내용 | `verify 내용` |
| 13 | `판정 결과` | `PASS` / `FAIL` / 빈 칸 | 결과 정리 산출물 |
| 14 | `테스트 자료` | `TOP_Ctrl_Harness1_HarnessInputs.mat` | 하네스 input 파일명 |

`-` 다섯 개는 머리글에 하이픈을 그대로 적고 데이터 칸은 비웁니다. 고객 양식의
빈 열 자리를 맞추기 위한 것입니다.

### `Test Case ID`와 `ID`

두 열로 나눠 적습니다.

| 열 | 값 | 예 |
| --- | --- | --- |
| 1 `Test Case ID` | `UT_REQ_{CUT}_{ID}_{NUM}` | `UT_REQ_Controller_12345_001` |
| 2 `ID` | codeBeamer ID만 | `12345` |

재료는 두 가지입니다.

- Test Sequence 시나리오명 `UT_REQ_{CUT}_{NUM}` (예: `UT_REQ_Controller_001`)
- 테스트 케이스명 `{CUT}_{ID}` (예: `Controller_12345`)

`{ID}`는 테스트 케이스명에서 **CUT 이름 접두사를 떼어** 얻습니다. 마지막 밑줄
뒤를 자르지 않습니다. CUT 이름 자체에 밑줄이 있으면 (`Motor_Ctrl_Unit`) 틀린
값이 나오기 때문입니다.

1열은 CUT 이름으로 다시 조립하지 않고 **시나리오명의 끝 `_{NUM}` 앞에 `_{ID}`를
끼워 넣어** 만듭니다. `st_scenario_name`은 식별자로 쓸 수 없는 CUT 이름을 고쳐
쓰고 길면 digest를 붙이므로(`UT_REQ_A_B_C_3f9a2c_001`), 조립하면 실제 시나리오와
어긋납니다. 끼워 넣으면 1열은 언제나 실재하는 시나리오명에 ID만 더한 값입니다.

> 1열은 **표시용 이름입니다.** Test File이나 관리 Excel에 그 이름의 식별자는
> 없습니다. 무엇을 찾아 들어갈 때는 2열 `ID`나 `TestResults` 시트의
> `TestCaseName`을 쓰십시오.

#### 규칙과 다른 이름

테스트 케이스명이 `{CUT}_`로 시작하지 않거나 시나리오명이 세 자리 숫자로
끝나지 않으면 조립하지 않습니다. 1열에 시나리오명을, 2열에 테스트 케이스명을
**원문 그대로** 적고 `TestResults` 시트에 `TESTCASE_ID_PATTERN_UNMATCHED`를
남깁니다. 칸이 비지 않고, 어느 행이 규칙 밖인지 보입니다.

손으로 만든 Test Case가 섞여 있으면 이 경우가 나옵니다.

### `Description` — 실행이 잡은 분기 블록

결과 정리를 하면 `st_collect_per_cut_results`가 Simulink Coverage에 **그 CUT에서
실제로 Decision objective가 잡힌 블록**을 물어 결과 워크북의 `DecisionPoints`
시트에 적어 둡니다. `Description`은 그 목록을 씁니다.

- 저장된 블록 파라미터로 추정하지 않으므로, 카탈로그에 없는 종류를 놓치거나
  커버리지가 세지 않는 블록을 더 적는 일이 없습니다.
- 목록은 **CVF를 거친 뒤의 결과**입니다. 커버리지 필터가 면제한
  objective만 가진 블록은 빠집니다. 필터가 곧 "이 CUT이 무엇을 재는가"를
  정하므로, CUT이 자기 것으로 claim하지 않은 중첩 Subsystem 안쪽이 여기 올라오지
  않게 하는 것이 이 규칙입니다. 필터를 안 쓰면 면제되는 것이 없으므로 아무것도
  빠지지 않습니다.
- **CUT의 직계 블록만 봅니다.** 중첩 Subsystem 안의 분기는 그 Subsystem의
  것이지 이 CUT의 것이 아니고, 넣으면 `Description`을 읽을 수 없게 됩니다.
  정적 스캔과 같은 범위이고, 바뀌는 것은 그중 무엇을 분기로 세느냐뿐입니다.
- **Enabled / Triggered Subsystem도 분기로 셉니다.** enable과 trigger 자체가
  CUT이 가진 분기입니다. 다만 그 분기는 Subsystem 한 겹 안의 port 블록에
  붙어 있어 직계 검색에 걸리지 않으므로, 스캔이 port를 찾아 **Subsystem을**
  보고합니다. port 블록 이름은 어느 모델에서나 `Enable`이라 그것을 적으면
  어느 서브시스템인지 알 수 없기 때문입니다. 평범한 Subsystem은 자기 분기가
  없으므로 그대로 빠집니다.
- **CUT 자신의 것만 셉니다.** CUT 자체가 Enabled Subsystem이면 그 enable을
  적습니다. 그 분기는 Subsystem 한 겹 안의 port 블록에 붙어 있어 위에서 깊이 1로
  찾으면 안 보이고, 다른 어떤 스캔도 대신 잡아 주지 않습니다.
- **자식 서브시스템의 enable은 제외합니다.** 그것은 그 자식의 분기이고, 이 열은
  CUT 하나를 설명합니다. 더 깊은 곳도 물론 제외합니다.
- 이 두 종류만은 **커버리지 목록이 아니라 모델에서 직접** 읽습니다. 서브시스템이
  조건부인지는 구조적 사실이라 커버리지에 물을 이유가 없고, 물으면 결과 정리를
  언제 했는지에 따라 보였다 안 보였다 합니다. 나머지 종류는 그대로 커버리지
  목록이 정합니다.
- 대화상자 조건이 없으므로 셀에는 `D1 [ON/OFF]Enable`처럼 분기 종류만
  찍힙니다. 행이 가리키는 블록은 Subsystem이라 `EnablePort`라고 쓰면 다른
  블록을 이름 붙이게 됩니다. `DecisionBlockDetails` 시트에는 `enable` /
  `trigger`가 남습니다.
- Subsystem과 Model Reference 자체는 빠집니다. 그 블록의 커버리지 수치는 안쪽
  합계라서 남기면 모든 상위 블록이 분기로 보입니다.

**커버리지가 없으면 지금까지대로 정적 스캔 결과를 씁니다.** 결과 정리를 하기
전에도 문서가 나오고, 어느 쪽에서 왔는지는 `Metadata` 시트의
`DecisionSourceWorkbooks`와 `DecisionSourceCUTs`로 확인합니다. 0이면 전부 정적
스캔입니다.

**`DecisionBlockScope`의 기본값은 `'ALL'`이고 `cfg.DecisionBlockScope`를
따르지 않습니다.** 고객 문서는 CUT이 가진 분기를 다 적어야 하고, Enabled /
Triggered Subsystem은 `'EXPLICIT'`에서 빠지기 때문입니다. 명세서 설정을
물려받으면 커버리지가 있을 때만 보이는 들쭉날쭉한 결과가 됩니다. 명세서
쪽(`st_export_test_specification`)의 기본값은 그대로 `'EXPLICIT'`입니다.

`'NONE'`을 주면 커버리지가 있어도 열을 비웁니다.

### `Pre Condition`

명세서의 `MaxTime`을 그대로 씁니다. 다시 계산하지 않습니다.

| `SldvMode` | 값 |
| --- | --- |
| `FILE` 또는 `GENERATE` | 연결된 입력 시나리오의 시간 최댓값 |
| `OFF` | 하네스 Solver `StopTime` |

`FILE`/`GENERATE`의 시간 최댓값이 그대로 시뮬레이션 종료 시각이 되므로 `OFF`의
`StopTime`과 같은 의미입니다. 값을 알 수 없으면 셀을 비우고 `TestResults` 시트에
`MAXTIME_UNAVAILABLE`을 적습니다.

### `해당 없음`은 `N/A`로 적습니다

Signal Editor가 없는 `OFF` 대상은 명세서에서 `하네스 input 파일명`과
`input 시나리오 내용`이 한글 `해당 없음`입니다. 고객 시트에서는 이것을 전부
`N/A`로 바꿉니다. `Coverage` 시트가 쓰는 글자와 같습니다.

### `출력값`은 `Test Steps.Expected result`의 복제입니다

두 열의 내용이 같습니다. 고객 양식이 그렇게 되어 있습니다.

### 한 대상의 `Description`이 여러 행에 반복됩니다

분기 블록 목록은 CUT 단위이고 행은 시나리오 단위이므로, 같은 CUT의 행마다 같은
`Description`이 들어갑니다. 정상 동작입니다.

## 5. `판정 결과` — 어느 실행에서 오나

판정은 **결과 정리를 거친 실행 디렉터리 안의 원본 워크북**에서 읽습니다.

| 모드 | 먼저 부를 명령 | 어디를 읽나 |
| --- | --- | --- |
| `PER_CUT` | `st_collect_per_cut_results` | `result/per_cut_latest.json` → manifest → target별 `final/` 또는 `initial/TestSummary.xlsx`의 `Iterations` 시트 |
| `BATCH` | `st_generate_test_report` | `result/latest.json` → 실행 디렉터리 → `TestSummary.xlsx`의 `Iterations` 시트 |

기본값 `ResultRun='AUTO'`는 두 pointer의 `UpdatedAt`을 비교해 **더 최근 실행**을
고릅니다. 어느 쪽을 골랐는지는 `Metadata` 시트에 남습니다.

`'BATCH'`나 `'PER_CUT'`을 직접 지정했는데 그 이력이 없으면 **오류로 중단**합니다.
명시한 선택이 조용히 다른 쪽으로 넘어가면 안 되기 때문입니다.

> **`result/TestSummary.xlsx`는 읽지 않습니다.** 그 복사본은 BATCH에서만
> 갱신됩니다. PER_CUT으로 돌린 뒤 그것을 읽으면 예전 BATCH 결과가 나오는데,
> 아무 표시도 없이 틀린 값이 됩니다. 항상 실행 디렉터리 안의 원본을 읽습니다.

### 판정 값

| 원문 | 적히는 값 |
| --- | --- |
| `Passed` | `PASS` |
| `Failed` | `FAIL` |
| 그 밖(`Incomplete` 등) | 대문자 원문 그대로 + `NOT_PASSED:<토큰>` 사유 |
| 못 찾음 | 빈 칸 + `NO_MATCHING_TEST_RESULT` 사유 |

`Incomplete`를 통과로 보이게 감추지 않습니다.

### 초기 실행과 재실행

기대값을 고친 뒤 재실행이 있었으면 **재실행 결과**를 씁니다.

- BATCH 워크북에는 `INITIAL`과 `FINAL` 행이 **항상 둘 다** 있습니다. 재실행이
  없었으면 `FINAL`은 `INITIAL`의 복제입니다. 따라서 `FINAL` 행이 있다고 해서
  재실행이 있었다는 뜻은 아닙니다.
- PER_CUT은 재실행이 있었을 때만 target 폴더에 `final/`이 생깁니다. 없으면
  `initial/`을 최종 결과로 쓰고 `NO_FINAL_RUN_USED_INITIAL`을 남깁니다. 재실행이
  없었다면 초기 실행이 곧 최종 결과이므로 대체가 아니라 정확한 값입니다.

### 같은 키에 값이 엇갈리면

조인 키는 테스트 케이스명 + Iteration명입니다. 같은 키가 서로 다른 판정을 가지면
하나를 골라 적지 않고 **빈 칸 + `AMBIGUOUS_TEST_RESULT`** 로 둡니다.

Iteration명이 비었거나 `<기본 설정>`이면 테스트 케이스 단위 결과로 대체하고
`ITERATION_MATCHED_BY_TEST_CASE`를 남깁니다.

## 6. `Coverage` 시트

| CUT | Execution Executed | Execution Total | Execution (%) | Decision Executed | Decision Total | Decision (%) |
| --- | --- | --- | --- | --- | --- | --- |
| Controller | `12` | `15` | `80.00%` | `7` | `10` | `70.00%` |
| Limiter | `N/A` | `N/A` | `N/A` | `N/A` | `N/A` | `N/A` |

- 관리 Excel의 CUT마다 한 줄입니다. 커버리지 원본이 없어도 줄은 남고 값만
  `N/A`가 됩니다. 빠진 것이 보여야 하기 때문입니다.
- 분자와 분모를 **각각 한 칸씩 숫자로** 씁니다. `CoverageSummary.xlsx`의 숫자와
  바로 대조할 수 있습니다.
- 머리글은 `CoverageSummary.xlsx`와 **같은 글자**입니다. 순서만 Execution →
  Decision으로 바꿨습니다.
- `%` 열은 숫자가 아니라 **Excel 수식**입니다. 2행이면 `=B2/C2`이고 표시 형식이
  `0.00%`라 `80.00%`로 보입니다. 셀을 클릭하면 수식 입력줄에 수식이 보입니다.
  계산된 값도 함께 저장하므로 열 때 재계산하지 않는 프로그램에서도 바로
  보입니다.
- 분자나 분모가 없거나 **분모가 `0`이면 `N/A`** 이고 수식을 넣지 않습니다.
  분모 0은 필터가 objective를 전부 걷어낸 정상 상태라 실제로 나옵니다.
- 한 CUT에 대상 행이 여럿이면 분모가 같을 때 분자의 최댓값을 씁니다. 분모가
  다르면 `N/A` + `COVERAGE_CONFLICT`입니다. 더하면 같은 objective를 두 번
  세게 됩니다.

### 커버리지는 판정과 다른 실행에서 옵니다

`CoverageSource`의 기본값 `'STANDALONE'`은 standalone pipeline 산출물을 읽습니다.
이것은 **판정을 읽은 실행과 별개의 실행**입니다.

- SUT가 독립 모델로 바뀌고, 기대값 갱신이 강제로 꺼지며, 필터 적용 시점도
  다릅니다.
- 그래서 **standalone의 PASS/FAIL이 일반 실행과 다를 수 있습니다.** 판정을
  standalone에서 가져오지 않는 이유입니다.
- 두 실행의 식별자를 `Metadata` 시트에 **둘 다** 적습니다.

`CoverageSource='TEST_RUN'`으로 하면 판정을 읽은 그 실행의 `Coverage` 시트에서
읽습니다. `'NONE'`이면 값이 전부 `N/A`입니다.

manifest에 적힌 체크섬과 실제 `CoverageSummary.xlsx`가 다르면 **중단합니다**
(`simtest:FinalDocumentCoverageChanged`). 그 pipeline 실행의 커버리지라고 말할 수
없기 때문입니다.

## 7. `TestResults` 시트 읽는 법

`TestCase` 시트의 행과 1:1로 맞습니다. 고객 양식 두 시트에는 비고 열이 없으므로
사람이 확인할 내용을 여기에 모았습니다.

| 열 | 내용 |
| --- | --- |
| `Row` | `TestCase` 시트의 Excel 행 번호 |
| `Test Case ID` | `TestCase` 시트와 같은 값 |
| `TestCaseName` | 조인 키 |
| `Iteration명` | 조인 키 |
| `판정 결과` | `TestCase` 시트와 같은 값 |
| `확인 필요` | `Y` 또는 빈 칸 |
| `확인 사유` | 아래 표 |
| `확인 위치` | Test Manager에서 열 `.mldatx` 경로 |
| `추출상태` | `OK` / `WARN` / `FAIL` |

**`확인 필요`가 `Y`인 행만 보시면 됩니다.**

| 사유 | 뜻과 할 일 |
| --- | --- |
| `FAILED` | 이 iteration이 실패했습니다. `확인 위치`의 `.mldatx`를 Test Manager에서 여십시오 |
| `NOT_PASSED:<토큰>` | 통과도 실패도 아닙니다. 대개 실행이 중간에 끝난 경우입니다 |
| `NO_MATCHING_TEST_RESULT` | 그 iteration의 결과를 찾지 못했습니다 |
| `AMBIGUOUS_TEST_RESULT` | 같은 키에 판정이 엇갈립니다 |
| `ITERATION_MATCHED_BY_TEST_CASE` | Iteration명이 없어 테스트 케이스 단위로 대체했습니다 |
| `NO_FINAL_RUN_USED_INITIAL` | 재실행이 없어 초기 실행을 최종 결과로 썼습니다 |
| `NOT_COLLECTED` | `st_collect_per_cut_results`를 먼저 부르십시오 |
| `NOT_REPORTED` | `st_generate_test_report`를 먼저 부르십시오 |
| `NO_RESULT_RUN` | 실행 이력이 하나도 없습니다 |
| `RESULT_WORKBOOK_SHAPE_UNEXPECTED` | 결과 워크북의 시트나 열이 예상과 다릅니다 |
| `MAXTIME_UNAVAILABLE` | `Pre Condition`이 빈 칸인 이유입니다 |
| `DUPLICATE_TEST_CASE_ID` | 같은 `Test Case ID`가 여러 행에 있습니다. 값은 바꾸지 않습니다 |
| `TESTCASE_ID_PATTERN_UNMATCHED` | 이름이 `{CUT}_{ID}` / `UT_REQ_{CUT}_{NUM}` 규칙과 달라 ID를 나누지 못했습니다. 1·2열은 원문입니다 |
| `COVERAGE_ROW_MISSING` | 그 CUT의 커버리지 행이 없습니다 |
| `COVERAGE_CONFLICT` | 같은 CUT의 커버리지 분모가 서로 다릅니다 |
| `COVERAGE_ROW_UNKNOWN_CUT` | 관리 Excel에 없는 CUT이 커버리지에만 있습니다 |
| `NO_COVERAGE_SOURCE` | standalone 산출물이 없습니다 |
| `[OverflowDetails!E12:E14]` | 셀 한도를 넘어 잘린 텍스트의 나머지 위치입니다 |

커버리지 쪽 사유는 `Row`가 비어 있고 `TestCaseName` 자리에 CUT 이름이 들어가
시트 아래쪽에 덧붙습니다.

### 왜 실패 내용을 여기에 적지 않습니까

지금 저장소의 어떤 파일에도 **어느 verify가 왜 틀렸는지가 남아 있지 않습니다.**
결과 표는 판정 값만 갖고, 실행 메시지는 `"final Test Case outcome is FAILED"`
같은 문장이며, 기대값 갱신 기록도 개수만 남깁니다.

내용을 알려면 `.mldatx`를 다시 열어야 하는데, 그러면 Test Manager 세션이 필요하고
추출이 느려집니다. 그래서 **어디를 열면 되는지만** 줍니다. 파일을 열지 않으므로
추가 비용이 없고 실패할 여지도 적습니다.

## 8. `OverflowDetails`와 `Metadata`

`OverflowDetails`는 셀 한 칸에 담기지 않는 텍스트(32767자 또는 253줄 초과)를
조각으로 나눠 담습니다. 고객 시트에는 **첫 조각이 그대로 남고** 참조 문자열은
`TestResults`로 갑니다. 고객 시트에서 `[OverflowDetails!...]` 같은 글자가 보이지
않습니다.

`Metadata`는 `Key`/`Value` 두 열입니다.

| 묶음 | 키 |
| --- | --- |
| 만든 때와 환경 | `CreatedAt`, `TopModel`, `MATLABRelease`, `MATLABVersion`, `SpecificationRows` |
| 원본 | `ModelFile`, `TestFile`, `ManagementExcel`과 각각의 `...SHA256` |
| 판정 출처 | `ResultRunRequested`, `ResultRunMode`, `ResultRunId`, `ResultRunDirectory`, `ResultRunUpdatedAt`, `ResultWorkbooks`, `ResultSets` |
| 커버리지 출처 | `CoverageSource`, `CoveragePipelineId`, `CoverageSummary`, `CoverageSummarySHA256` |
| 설정 | `DecisionBlockScope` |

**판정과 커버리지가 서로 다른 실행에서 왔다는 사실이 여기서 드러납니다.**
제출 전에 `ResultRunId`가 방금 돌린 실행과 맞는지 확인하십시오.

## 9. 옵션

```matlab
[T, file] = st_export_final_document( ...
    'OutputFile',         '', ...      % 기본 result/final_document_<ts>.xlsx
    'DecisionBlockScope', '', ...      % '' → 'ALL' | 'EXPLICIT' | 'NONE'
    'CoverageSource',     '', ...      % '' → cfg | 'STANDALONE' | 'TEST_RUN' | 'NONE'
    'CoveragePipelineId', 'LATEST', ...
    'ResultRun',          '', ...      % '' → cfg | 'AUTO' | 'BATCH' | 'PER_CUT' | 경로
    'RequireTestResults', false, ...
    'RequireCoverage',    false, ...
    'IncludeUsageSheet',  []);
```

빈 값을 주면 `cfg`의 값을 씁니다. 기본값은
[설정 사전](config-reference.md)의 `FinalDocument*` 항목에 있습니다.

## 10. 오류와 경계 동작

### 중단하는 조건

| 상황 | 식별자 |
| --- | --- |
| 모델·하네스·Test File이 저장되지 않음 | `simtest:SpecificationUnsaved` |
| 모델이 실행 중 | `simtest:SpecificationRunning` |
| 추출 도중 원본이 바뀜 | `simtest:SpecificationSourceChanged` |
| 출력 파일이 이미 있음 | `simtest:FinalDocumentOutputExists` |
| `ResultRun`을 지정했는데 그 이력이 없음 | `simtest:FinalDocumentResultRunMissing` |
| 커버리지 요약이 manifest 체크섬과 다름 | `simtest:FinalDocumentCoverageChanged` |
| `RequireTestResults`인데 판정이 없음 | `simtest:FinalDocumentTestResultsRequired` |
| `RequireCoverage`인데 커버리지가 없음 | `simtest:FinalDocumentCoverageRequired` |

중단하면 **출력 파일을 만들지 않습니다.** 원자적으로 발행하므로 반쯤 쓰인 파일이
남지 않습니다.

### 계속 진행하는 조건

| 상황 | 어떻게 되나 |
| --- | --- |
| 실행 이력이 없음 | 판정 전부 빈 칸 + `NO_RESULT_RUN` |
| 결과 정리를 안 함 | 판정 빈 칸 + `NOT_COLLECTED` / `NOT_REPORTED` |
| 수집이 중간에 끊긴 폴더 | 워크북이 있는 대상만 채우고 나머지는 `NOT_COLLECTED` |
| 대상 하나의 추출 실패 | 그 행만 `추출상태=FAIL` + 예외 메시지, 나머지는 계속 |
| 커버리지 원본이 없음 | 줄은 남고 값만 `N/A` |
| 수집 행이 0개 | 머리글만 있는 파일. 오류가 아닙니다 |

### 저장하라는데 방금 저장했다고 나올 때

결과 정리 명령(`st_collect_per_cut_results`, `st_generate_test_report`)은
커버리지를 읽기 전에 모델을 엽니다. 자기가 연 모델은 닫지만 **원래 열려 있던
모델은 건드리지 않습니다.** 그 과정에서 모델이 미저장 상태가 될 수 있고 아무도
저장하지 않습니다.

그래서 "결과 정리를 방금 돌렸는데 최종 문서가 미저장이라고 거절한다"가 실제로
일어납니다. 오류 메시지에 어느 모델인지 적혀 있으니 그 모델을 저장하고 다시
부르십시오.

## 11. 회귀 검사

```matlab
st_setup
assertSuccess(runtests('tests/unit/test_export_final_document.m'));
assertSuccess(runtests('tests/unit/test_export_test_specification.m'));
assertSuccess(runtests('tests/unit/test_project_layout.m'));
```

이 검사는 Simulink 없이 돕니다. 결과 워크북과 실행 manifest를 임시 폴더에
합성해 실제 코드 경로를 지납니다.

### R2025b 실물 확인이 남아 있습니다

개발 PC에 MATLAB이 없어 **구문·정적 검증만 수행했습니다.** 실제 모델로 다음을
확인해야 합니다. 기본 실행 방식이 `PER_CUT`이므로 그쪽부터 보십시오.

- 머리글 14개가 고객 양식과 글자까지 같고 `-` 다섯 칸이 비어 있는지
- 1열이 `UT_REQ_{CUT}_{ID}_{NUM}`, 2열이 `{ID}`로 나뉘어 있는지. 손으로 만든
  Test Case가 있으면 `TESTCASE_ID_PATTERN_UNMATCHED` 행도 확인하십시오
- `판정 결과`가 Test Manager의 최종 결과와 같은지. 기대값 갱신 재실행이
  있었다면 **재실행 후** 값인지
- `출력값`이 `Test Steps.Expected result`와 같은지
- 시트 2의 CUT 수가 관리 Excel의 활성 행 수와 같고 분자·분모가
  `CoverageSummary.xlsx`와 일치하는지
- 시트 2의 `%` 셀을 클릭했을 때 수식 입력줄에 `=B2/C2`가 보이고 `80.00%`로
  표시되는지. **LibreOffice에서도 열어** 같은지
- 파일을 열 때 복구 대화상자가 뜨지 않는지
- 일부러 하나를 실패시켜 `확인 필요=Y`와 `확인 위치`가 채워지는지, 그 `.mldatx`를
  Test Manager에서 열면 그 실패가 보이는지
- `Metadata`의 `ResultRunId`가 방금 돌린 실행과 같은지
- `Pre Condition`의 `0.2`가 문자열이 아니라 숫자로 들어가는지

BATCH 경로도 따로 확인하십시오. 결과 정리 명령이 다르고 판정이 한 워크북에 모여
있어 코드 경로가 완전히 분리되어 있습니다.

```matlab
st_run_from_harness('ExecutionMode','BATCH');
st_generate_test_report                   % 빼면 판정이 전부 빈 칸입니다
[T, file] = st_export_final_document();
```

정리를 건너뛰고 바로 부르는 경우도 확인하십시오. 기본 설정이 그 상태라 실제로
자주 일어납니다.
