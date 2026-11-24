# 도달 불가 결정 결과를 결함 TC로 남기는 설계

- 작성일: 2026-11-24
- 상태: 구현 중 (실험 완료, 6절 결과 참고)
- 대상 브랜치: main

## 1. 배경과 의도

SLDV 테스트 생성은 결정 결과마다 목표(objective)를 세우고, 어떤 입력으로도 만들 수 없다고
증명한 목표를 `Unsatisfiable`로 남긴다. 이런 결과는 커버리지 100%를 막는다. 흔한 처리 방법은
Justify(커버리지 필터로 "정당한 미달"이라 적기)이다.

팀 규칙은 다르다. **도달 불가는 설계 결함이므로 덮지 않는다.** 결함마다 Test Manager에 실제 TC를
하나 두고, 그 TC가 FAIL로 나와서 최종 문서에 결함으로 기록되어야 한다.

FAIL은 진짜여야 한다. `verify(false)`처럼 무조건 실패하는 검증은 "검증 자체가 틀린 것"이라 쓰지
않는다. 이 TC가 검사하는 것은 "이 결정 결과가 한 번이라도 실행되는가"이다. 실제로 실행되지 않기
때문에 FAIL이 된다. 결과가 실행되면(모델이 고쳐지면) 같은 TC는 PASS가 된다.

계기가 된 모델에서는 안쪽 Switch의 결과 하나와 Max의 결과 하나가 `Unsatisfiable`였다. 두 블록은
서로 다른 결함이므로 결함 TC는 2건이다.

## 2. 목표

- CUT마다 SLDV가 `Unsatisfiable`로 증명한 결정 결과를 찾고, **블록 하나당 결함 TC 하나**를 그 CUT의
  Test Case에 Iteration으로 추가한다.
- 결함 TC는 그 결과가 실행됐는지를 커버리지로 판정하고, 실행되지 않았으면 FAIL이 된다.
- 결함 TC의 입력은 기존 시나리오 하나를 그대로 쓴다. 어느 시나리오를 쓸지 CUT마다 고를 수 있고,
  고르지 않으면 그 CUT의 마지막 시나리오를 쓴다.
- 결함 TC의 이름은 그 CUT의 마지막 시나리오 번호 다음부터 붙인다(`UT_REQ_{CUT}_{N+1}`, `{N+2}` …).
- 최종 문서에 결함 TC가 한 행으로 나오고, 어느 결정 결과가 도달 불가인지, 그 사유가 무엇인지, 판정
  FAIL이 적힌다.

### 범위 밖

- Justify용 커버리지 필터를 만드는 일.
- `Undecided`(시간 초과 등으로 판정하지 못한 목표). 증명되지 않았으므로 결함으로 만들지 않고, 개수만
  로그에 남긴다.
- Condition·MCDC 목표. 결정(Decision) 목표만 다룬다.
- 최종 문서의 D 번호 범위를 넓히는 일. D 번호는 지금처럼 CUT 바로 아래 블록에만 붙는다. 하위
  Subsystem 안의 블록도 결함 TC는 만들지만, 문서에는 D 번호 대신 경로로 적는다(5.6).
- 도달 불가 사유를 자동으로 분석하는 일. 사유 분석은 `st_explain_block_logic`과 사람이 한다.

### 하면 안 되는 것

- 무조건 실패하는 검증(`verify(false)`, 일부러 틀린 기대값)으로 FAIL을 만드는 것.
- 모델이나 하네스를 고치는 것. 결함 TC를 위해 Signal Editor·Test Sequence 시나리오를 새로 만드는
  것도 하지 않는다.
- 기대값 자동 갱신(APPLY)이 결함 TC를 고쳐 PASS로 만드는 것.
- 커버리지를 읽지 못했을 때 FAIL로 처리하는 것. 판정할 근거가 없으면 FAIL이 아니라 오류로 끝나야
  한다(가짜 FAIL 금지와 같은 이유).

## 3. 제약

- 이 저장소에서는 MATLAB을 돌릴 수 없다. 실기 확인은 사용자가 `todo.md` 절을 돌려 화면 한 장으로
  돌려준다. 그 출력에는 회사 내부 정보(모델·블록·TC 이름, 경로)가 없어야 한다.
- 새 기능은 `st_log` 수명 로그(시작·끝, 저하·실패 시 WARN·ERROR)를 남긴다.
- standalone 번들은 툴킷이 없는 곳에서도 열리고 돈다. 결함 TC의 판정 코드도 번들 안에서 돌아야 한다.
- Simulink Test의 Custom Criteria는 Test Case 단위로 하나다. 같은 Test Case의 모든 Iteration에서
  돈다.

## 4. 접근

### 판정 방식

| 방식 | 내용 | 결과 |
| --- | --- | --- |
| 커버리지로 판정 | Custom Criteria가 그 Iteration의 커버리지에서 목표 결과의 실행 횟수를 읽고, 0이면 실패 | **채택** |
| 출력값으로 판정 | "그 결과를 탔다면 하네스 출력이 이 값"이라는 기대값을 적음 | 분기마다 사람이 출력 영향을 계산해야 하고, 출력에 드러나지 않는 내부 분기에는 쓸 수 없음 |
| `verify(false)` | 무조건 실패 | 검증 자체가 틀린 것이라 금지 |

커버리지 판정이 이 TC가 묻는 질문("이 결과가 실행되는가")과 정확히 같다.

**확인되지 않은 전제**: Custom Criteria가 도는 시점에 그 Iteration의 커버리지를 읽을 수 있는지 공식
문서에 나와 있지 않다. Custom Criteria에 넘어오는 객체에는 Iteration 결과(`TestIterationResult`)가
있고 여기에 `getCoverageResults`가 있지만, 그 시점에 커버리지가 이미 붙어 있는지는 모른다. 그래서
구현 전에 실험(6절)을 먼저 한다. 실험에서 읽을 수 없다고 나오면 대체 판정으로 바꾼다. 대체 판정은
목표 블록의 입력 신호를 로깅하고, 결과가 실행됐는지를 그 값으로 직접 계산한다(Switch는 제어 입력과
임계값 비교, MinMax는 어느 입력이 뽑혔는지). 이때는 이 문서의 5.4절만 다시 설계한다.

### 결함 TC를 어디에 두는가

| 방식 | 장점 | 단점 | 결과 |
| --- | --- | --- | --- |
| A. 같은 Test Case에 Iteration으로 덧붙이고, 입력은 기존 시나리오 이름을 가리킴 | 시나리오를 새로 만들지 않음. `ScenarioNames`를 도는 기대값 갱신·SLDV 검증이 결함 TC를 건드리지 않음 | Iteration 이름을 시나리오 목록과 정확히 맞춰 보는 검사 두 곳과, 시나리오로 Iteration을 찾는 곳 두 곳을 고쳐야 함 | **채택** (사용자 선택) |
| B. 결함 TC를 정식 시나리오로 추가(Signal Editor MAT·Test Sequence 시나리오 복사) | 모든 단계가 보통 TC처럼 다룸 | `ScenarioNames`를 도는 모든 곳에 제외 처리 필요. 하나라도 빠지면 기대값 갱신이 FAIL을 PASS로 바꿈 | 기각 |
| C. CUT마다 결함 전용 Test Case를 따로 만듦 | Custom Criteria가 그 Test Case에만 걸림 | PER_CUT 실행, standalone 패키징, 결과 수집이 "CUT 하나 = Test Case 하나"를 전제함 | 기각 |

## 5. 설계

### 5.1 결함 단위, 이름, 입력

- **결함 하나 = 블록 하나.** 한 블록에 도달 불가 결과가 여럿이면 한 TC에 같이 적고, Custom Criteria는
  그 결과들을 모두 확인한다. 이 중 하나라도 실행되지 않으면 FAIL이다. *(이 문서의 판단: 사용자가
  "Switch와 Max가 각각 결함"이라고 블록 단위로 말했다.)*
- **순서와 이름**: 결함 블록을 CUT 기준 상대 경로 순으로 정렬하고, `st_scenario_name(CUT, N+k)`로 이름을
  붙인다. `N`은 `numel(profile.ScenarioNames)`이다. 이 순서는 SLDV 결과와 모델만으로 정해지므로 다시
  실행해도 같은 블록이 같은 이름을 받는다.
- **입력 시나리오**: 대상 워크북 Targets 시트에 선택 열을 하나 추가한다. 기존 `ExpectedUpdateMode` 열과
  같은 방식으로 읽는다(열이 없거나 칸이 비면 기본값).
  - 열 이름 후보: `DefectInputScenario` / `Defect Input Scenario` / `결함입력시나리오`.
  - 값은 시나리오 번호(`3`)나 시나리오 이름(`UT_REQ_{CUT}_003`)이다. 없는 시나리오를 가리키면 그 CUT의
    준비 단계가 이유를 말하며 실패한다.
  - 비어 있으면 그 CUT의 **마지막 시나리오**를 쓴다.
- **입력 복사**: 결함 Iteration은 원본 Iteration의 TestParams를 그대로 가진다. Signal Editor 시나리오,
  Test Sequence 시나리오, SLDV 파라미터 덮어쓰기(`st_apply_sldv_parameters`)가 모두 원본과 같다. 따라서
  Test Sequence의 verify도 원본과 같이 통과하고, FAIL은 Custom Criteria에서만 나온다.

### 5.2 도달 불가 결과 찾기

- SLDV 데이터 파일(`profile.EffectiveDataFile`)의 `sldvData.Objectives`에서 종류가 결정(Decision)인 목표 중
  `status`가 다음인 것을 고른다. 목표가 가리키는 `ModelObjects` 항목에서 블록(SID)과 결과(outcome)를 얻는다.

  | status | 결함 TC | 사유 |
  | --- | --- | --- |
  | `Unsatisfiable` | 만든다 | 증명됨 |
  | `Unsatisfiable under approximation` | 만든다 | 근사 분석에서 도달 불가. 최종 문서 `확인 필요=Y` (사용자 결정) |
  | `Undecided` 계열 | 만들지 않는다 | 개수만 로그 |

- **CUT 안의 모든 블록이 대상이다.** 최종 문서의 D 목록으로 거르지 않는다. D 목록은 CUT 바로 아래
  블록만 담고(`SearchDepth 1`), 실행 후에는 커버리지가 인식한 목록(DecisionPoints 시트)으로 바뀌기도
  한다. 실행 전에 만드는 결함 목록이 그 목록에 기대면 범위와 번호가 어긋날 수 있다.
- 그래서 **profile과 Custom Criteria에는 D 번호를 넣지 않는다.** 블록 종류, CUT 기준 상대 경로, SID,
  결과 문구만 둔다. D 번호는 최종 문서가 자기 D 목록에서 붙인다(5.6).
- **CVF가 커버리지에서 빼는 곳의 결과는 결함으로 만들지 않는다(사용자 결정).** 그 Test Case가 책임지는
  범위가 아니기 때문이다. SLDV는 `cfg.SldvCoverageFilter=false`(기본)일 때 CVF가 뺀 하위 Subsystem 안까지
  분석하므로 이 거름이 필요하다. 규칙은 그 행의 `CoverageFilterMode`로 정한다(CVF를 만드는 규칙과 같다).
  - `OFF`: 거르지 않는다.
  - `SUBSYSTEM`: CUT 바로 아래 Subsystem 블록 자체의 결과(Enable·Trigger 등)를 뺀다.
  - `ALL_CONTENT`: 위에 더해, 그 Subsystem 안의 모든 블록 결과를 뺀다(상대 경로에 `/`가 있는 블록).
  - 뺀 개수는 로그(WARN 아님, INFO)에 남긴다. `CoverageBoundaryMode`는 CUT 바깥만 다루므로 상관없다.
- **상대 경로 규칙(실험으로 확인)**: `ModelObjects.slPath`는 `<분석 루트>/<CUT 이름>/...` 꼴이다. 앞의
  두 요소를 떼면 CUT 기준 상대 경로가 된다. 이름 속 `/`의 `//` 표기와 줄바꿈은 그대로 둔다(콜백이 이
  경로로 블록을 찾기 때문). 최종 문서는 비교할 때만 공백을 접는다(5.6). 요소가 둘뿐인(CUT 자신) 목표는
  결함 대상이 아니다.
- `profile.Mode`가 `OFF`이거나 데이터 형식이 MAT(SLDV 데이터가 아님)이면 이 단계는 아무것도 하지 않는다.

### 5.3 결함 목록은 profile 한 곳에 둔다

- `st_get_sldv_profile`이 5.2의 결과로 `profile.DefectIterations`를 채운다. 항목마다 이름, 원본 시나리오
  이름과 번호, 블록 종류·상대 경로·SID, 목표 결과 목록(결과 번호, 결과 문구, 근사 여부)을 가진다.
  `st_empty_sldv_profile`의 기본값은 빈 목록이다.
- Test Manager 생성, 검사, 최종 문서가 모두 이 목록을 읽는다. 각자 다시 계산하지 않는다.

### 5.4 Test Manager: Iteration과 Custom Criteria

- `st_create_test_manager`가 `preparedIterations`를 만든 뒤, 결함 목록마다 원본 Iteration을 복사한
  Iteration을 덧붙인다. `replace_test_iterations`는 매번 전체를 다시 쓰므로, 재실행해도 결함 Iteration이
  사라지거나 중복되지 않는다.
- 결함 목록이 비어 있지 않으면 Test Case의 Custom Criteria를 켜고 콜백을 쓴다.
  - 콜백은 **자기완결 코드**다. 툴킷 함수를 부르지 않는다(standalone 번들에서도 돌아야 하므로). 결함
    Iteration 이름 → 목표 결과 목록을 콜백 안에 상수로 박는다.
  - 결함 Iteration이 아니면 아무것도 하지 않는다(통과).
  - 결함 Iteration이면 그 Iteration의 커버리지에서 목표 결과마다 실행 횟수를 읽고, `verifyGreaterThan(실행 횟수, 0, 'Switch [false] 실행 횟수')`
    같은 검증을 한다(블록 종류 + 결과 문구, D 번호 없음). 실행되지 않았으니 이 검증이 실패하고
    Iteration이 FAIL이 된다.
  - 커버리지를 읽지 못하면 검증하지 않고 오류를 던진다. FAIL이 아니라 오류로 끝나야 한다.
  - **접근 경로(실험으로 확인)**: 커버리지는 `getCoverageResults(test.TestResult)`로 얻는다. 블록은 하네스
    경로 `[test.sltest_bdroot '/' <CUT 블록 이름> '/' <상대 경로>]`로 찾는다. `test.sltest_sut`는 원래 모델의
    Subsystem 경로를 가리키며, 그 경로로는 `decisioninfo`가 빈 값을 돌려준다. CUT 블록 이름은
    `test.sltest_sut`의 마지막 요소(하네스 안 CUT 블록은 원래 Subsystem과 이름이 같다)이다.
  - 콜백 첫 줄에 툴킷이 만든 콜백이라는 표식 주석을 둔다. 툴킷은 이 표식이 있는 콜백만 바꾸거나 끈다.
    표식 없는 콜백(사람이 쓴 것)이 이미 있으면 덮어쓰지 않고, 이유와 할 일을 말하며 실패한다.
- 결함 목록이 비면 툴킷 표식이 있는 Custom Criteria를 끈다(모델이 고쳐진 경우).

### 5.5 결함 Iteration을 받아들여야 하는 곳

| 위치 | 지금 | 바꿀 것 |
| --- | --- | --- |
| `st_inspect_preparation_stage` (Iteration 이름 검사) | Iteration 이름 = `ScenarioNames` 정확히 일치 | 기대 목록 = `ScenarioNames` + 결함 이름 |
| `st_validate_scenario_alignment` (Iteration 이름 검사) | 같음 | 같음 |
| `st_update_expected_from_results` `find_iteration_result` | 같은 Test Sequence 시나리오를 고른 첫 Iteration | 이름까지 일치하는 Iteration. 결함 Iteration은 절대 고르지 않음 |
| `st_validate_sldv_verify_results` (Iteration 결과 찾기) | 같은 시나리오를 고른 첫 Iteration | 같음 |

기대값 갱신과 SLDV 검증은 `ScenarioNames`를 돌기 때문에 결함 Iteration을 대상으로 삼지 않는다. 위의
"이름까지 일치"는 결함 Iteration이 원본보다 앞에 오는 경우를 막는다.

### 5.6 최종 문서

결함 Iteration은 원본 시나리오에 묶여 있으므로, `st_collect_specification_target`이 지금 코드 그대로 결함
행을 하나 만든다(입력·MaxTime·테스트 자료는 원본과 같다). 판정도 지금처럼 TestCaseName + Iteration명으로
찾으므로 FAIL이 들어간다. 바꿀 것은 다음이다.

| 칸 | 보통 행 | 결함 행 |
| --- | --- | --- |
| Test Case ID | Test Sequence 시나리오 이름 + ID | **Iteration 이름** + ID (시나리오 이름을 쓰면 원본 행과 겹쳐 `DUPLICATE_TEST_CASE_ID`가 됨) |
| Description | D 목록 전체 | 목표 결과의 줄만 (아래 표기 규칙) |
| Expected result | verify 내용 | `<표기>가 한 번 이상 실행된다` 고정 문구 |
| 출력값 | verify 내용 | 사유 문장 (5.7) |
| 판정 결과 | 실행 결과 | 실행 결과 (FAIL) |
| Action, 테스트 자료 | 시나리오 | 원본 시나리오 그대로 |

표기 규칙:

- 블록이 최종 문서의 D 목록에 있으면 그 D 줄을 쓰고, 결과 표시만 목표 결과로 바꾼다. 결과가 true/false
  둘뿐인 블록(catalog의 `TwoWay=YES`)은 `D3 [F]Switch (u2 >= 1)`처럼 적는다. 그 밖의 블록(MinMax 등)은
  커버리지 결과 문구를 대괄호에 넣는다(예: `D5 [input 1]Max`). *(이 문서의 판단)*
- D 목록에 없으면(하위 Subsystem 안의 블록) D 번호 없이 `Switch [false] (<CUT 기준 상대 경로>)`로 적는다.
- 계기가 된 모델의 두 블록은 CUT 바로 아래에 있으므로 둘 다 D 번호로 적힌다(사용자 확인).

결과 시트의 `확인 사유` 코드:

- 결함 행이 FAIL이고 목표가 모두 `Unsatisfiable`이면 `UNREACHABLE_DEFECT`를 남긴다. 알고 있는 결함이므로
  정보성 코드로 두고 `FAILED`는 붙이지 않는다. 따라서 `확인 필요`는 비어 있다. *(이 문서의 판단)*
- 목표 중 하나라도 `Unsatisfiable under approximation`이면 `UNREACHABLE_DEFECT_APPROXIMATE`를 남기고
  `확인 필요=Y`로 둔다. 근사 판정은 사람이 확인해야 한다(사용자 결정).
- 결함 행이 PASS면 `UNREACHABLE_DEFECT_PASSED`를 남기고 `확인 필요=Y`로 둔다. SLDV 결과가 오래됐거나
  모델이 바뀐 것이다.
- 결함 행이 오류·미완료면 지금 규칙대로 `NOT_PASSED:…`가 붙는다.

### 5.7 사유 문장

- 사람이 분석한 사유는 **대상 워크북의 새 시트**에 적는다(사용자 결정). 한 줄에 결함 TC 이름 하나와 사유
  문장 하나를 적는다. 결함 TC 이름은 사용자가 Test Manager에서 보고 적는다.
  - 시트 이름 후보: `DefectReasons` / `도달불가사유`. 열 이름 후보: `TestName` / `결함TC`, `Reason` / `사유`.
    시트가 없으면 모든 결함 행이 기본 문장을 쓴다.
  - 시트에 있는데 결함 목록에 없는 이름(모델이 고쳐졌거나 오타)은 WARN 로그로 남기고 무시한다.
- 시트에 사유가 없으면 기본 문장을 쓴다.
  - `Unsatisfiable`: `SLDV가 어떤 입력으로도 실행할 수 없음을 증명함`
  - `Unsatisfiable under approximation`: `SLDV 근사 분석에서 실행할 수 없다고 판정함(확인 필요)`
- 이 시트는 최종 문서만 읽는다. Test Manager 생성 단계와 관계가 없으므로 `st_stage_inputs` 지문에 넣지
  않는다. 사유를 고친 뒤에는 최종 문서만 다시 만들면 된다.

### 5.8 켜고 끄기, 재실행 판단

- `cfg.UnreachableDefectTests = true`가 기본이다. 팀 규칙이고, `Unsatisfiable`이 없는 모델에서는 아무것도
  바뀌지 않는다. *(이 문서의 판단)*
- 이 설정값과 5.1의 워크북 열은 `st_stage_inputs` 지문(fingerprint)에 넣는다. 값이 바뀌면 Test Manager
  생성 단계가 다시 돈다.

### 5.9 실행 흐름에 미치는 영향

- PER_CUT: 결함 TC가 FAIL이므로 그 CUT은 지금 규칙대로 WARN이 되고, 실행은 계속된다. 그대로 둔다.
- standalone 파이프라인: Iteration을 있는 그대로 옮기고 서명(signature)으로 바뀌지 않았는지 확인한다.
  결함 Iteration도 같이 옮겨진다. Custom Criteria가 번들에 따라가는지는 6절 실험에서 함께 확인한다.
- 커버리지 합계: 결함 Iteration은 원본과 입력이 같으므로 Test Case 전체 커버리지 숫자는 바뀌지 않는다.

### 5.10 로그

- CUT마다 `[UnreachableDefect] start | CUT=… | Unsatisfiable=… | Undecided=…`와 `end | Defects=…`를 남긴다.
- 근사 판정 개수, 고른 입력 시나리오가 없음, 사람이 쓴 Custom Criteria가 있음, 사유 시트의 모르는 이름은
  WARN 또는 ERROR로 이유와 함께 남긴다.

## 6. 먼저 할 실험

구현 전에 `todo.md` 절 하나로 사용자 PC에서 확인한다. 회사 모델은 쓰지 않는다. 스크립트가 임시 폴더에
작은 모델을 만든다. 이 모델에는 실행될 수 없는 Switch 결과가 하나 있다(예: 제어 입력이 상수라 한쪽
결과가 나올 수 없음). 스크립트는 이 모델로 하네스와 Test File을 만들고, 커버리지를 켜고, 5.4의 콜백을
붙여 실행한다.

화면에 찍을 것(한 줄씩, 이름 없음):

1. Custom Criteria 안에서 Iteration 결과 객체에 닿았는가 (예/아니오)
2. 그 시점에 커버리지가 붙어 있었는가 (예/아니오, 못 읽었으면 오류 종류)
3. 목표 결과의 실행 횟수 (숫자)
4. Iteration 판정 (FAIL이 기대값)
5. 결과를 저장했다가 다시 불러왔을 때(번들과 같은 경로) Custom Criteria 판정이 유지되는가

2가 "아니오"면 4절의 대체 판정으로 5.4를 다시 설계한다.

**결과 (2026-11-24, R2025b)**: 커버리지 판정 방식이 성립한다.

- Custom Criteria의 `test`에 `TestResult`(TestIterationResult)가 있고, `getCoverageResults`로 그 시점의
  커버리지를 얻었다. 도달 불가 결과의 실행 횟수는 0이었고, Iteration 판정은 Failed였다.
- 실행 뒤 같은 Iteration의 커버리지에서도 실행 횟수 0이었다(대조군 일치).
- 블록은 `sltest_bdroot` 기준 하네스 경로로만 찾아졌다. `sltest_sut`와 원래 모델 경로는 빈 값을 돌려줬다.
- Test File을 저장·닫기·다시 열기 해도 콜백이 남았고, 다시 실행해도 Failed였다.
- 실제 SLDV 데이터: 대상마다 결정 목표 30개 중 Unsatisfiable 3개, 근사 0, Undecided 0. 커버리지 결정
  수(22)보다 많은 것은 CVF가 뺀 하위 Subsystem까지 분석했기 때문으로 보며, 5.2의 CVF 거름을 넣었다.
- `slPath` 경로 구조와 `designSid` 필드가 있다는 것을 확인했다(5.2 상대 경로 규칙).

## 7. 검증

- 단위 테스트(이름에 `Secret`을 넣어 출력에 이름이 새지 않는지 함께 확인):
  - 가짜 `sldvData`로 `DefectIterations`가 맞게 만들어지는가. `Unsatisfiable`과 근사 판정을 고르고
    `Undecided`는 고르지 않는가. 하위 Subsystem 안의 블록도 고르는가. 블록 단위로 묶이는가. 이름 번호가
    `N+1`부터인가. 입력 시나리오가 비었을 때 마지막 시나리오를 고르는가.
  - Iteration 이름 검사 두 곳이 결함 이름을 받아들이는가.
  - `find_iteration_result`가 결함 Iteration을 고르지 않는가(결함 Iteration을 원본보다 앞에 둔 경우 포함).
  - 최종 문서에서 결함 행의 Test Case ID가 원본과 겹치지 않는가. 결함 행의 칸, 표기(D 번호 / 경로),
    사유 코드가 5.6과 같은가. 사유 시트의 문장이 들어가고, 없으면 기본 문장이 들어가는가.
- 실기 확인(`todo.md`): 계기가 된 모델에서 결함 TC가 2건 생기고 둘 다 FAIL인가. 기존 TC 판정과 커버리지
  숫자는 그대로인가. 기대값 갱신(APPLY)을 켜고 돌려도 결함 TC가 FAIL로 남는가.

## 8. 빌더에게 맡기는 것

- `ModelObjects`에서 블록 SID와 결과 번호를 얻는 정확한 필드, 하네스 안에서 그 블록을 찾는 방법.
- 커버리지에서 결과별 실행 횟수를 읽는 방법. 기존 `st_collect_decision_outcomes`가 하는 방식을 참고하되,
  콜백은 자기완결이어야 한다.
- 최종 문서가 결함 행을 알아보는 방법(예: profile 목록을 다시 읽기, Iteration 이름 목록 대조).
- SLDV status 문자열의 정확한 철자와 버전별 차이 처리.
- 함수와 파일 나누기, 로그 문구.

## 9. 사용자가 정한 것

- 판정은 커버리지로 한다(`verify(false)` 금지).
- 결함 TC는 같은 Test Case의 Iteration으로 붙인다(방식 A).
- 입력 시나리오는 CUT마다 고를 수 있고, 고르지 않으면 마지막 시나리오를 쓴다.
- 이름은 그 CUT의 마지막 번호 다음부터 붙인다.
- 근사 판정(`Unsatisfiable under approximation`)도 결함 TC로 만들고 확인 필요로 표시한다.
- 분석한 사유는 대상 워크북의 새 시트에 적는다.
- 계기가 된 모델의 두 블록은 CUT 바로 아래에 있다. 하위 Subsystem 안의 블록은 경로로 적는다.
- CVF가 커버리지에서 빼는 곳의 도달 불가 결과는 결함 TC로 만들지 않는다.
