# 테스트 명세서 추출

테스트를 **실행하지 않고**, 이미 저장된 Assessment 시나리오·입력 마지막 값·verify
문장을 Excel 명세서로 뽑습니다. 시뮬레이션, 테스트 실행, SLDV 생성, 기대값 갱신을
호출하지 않습니다. 모델과 블록을 읽기 위해 로드만 합니다.

## 1. 실행

모델·하네스·Test File·입력 MAT을 저장하고, 실행 중인 모델을 멈춘 뒤 실행합니다.

```matlab
st_setup
[T, outputFile] = st_export_test_specification();

% 모든 스텝의 verify를 오른쪽 열에 스텝별로 분리
[T, outputFile] = st_export_test_specification('VerifyMode','ALL_STEPS_COLUMNS');

% 다른 이름으로 저장 (기존 파일을 덮어쓰지 않습니다)
[T, outputFile] = st_export_test_specification( ...
    'OutputFile', fullfile(pwd,'result','test_specification_review.xlsx'));
```

기본 출력은 `result/test_specification_<timestamp>.xlsx`입니다. 별도 Excel 설치나
ActiveX가 필요 없습니다. 기존 `cfg.OnlyEnabled`, 관리 Excel, `cfg.TestSuiteName`을
그대로 씁니다. 테스트 workflow에 자동으로 끼어들지 않는 독립 명령입니다.

첫 번째 `사용법` 탭에는 주요 실행 파일, 역할, 사용 시점, 대표 명령이 기록됩니다.
일반 사용 명령과 단계별 진단용 고급 명령을 구분하며 내부 helper는 제외합니다.

## 2. 행과 셀의 의미

`TestSpecification` 시트는 **테스트 케이스 × Assessment 블록의 실제 시나리오마다 한
행**을 기록합니다. 시나리오 이름을 생성 규칙으로 추측하지 않습니다.

- 여러 iteration이 같은 Assessment 시나리오를 참조하면 입력 연결별로 행이 늘어납니다.
- 연결되지 않은 Assessment 시나리오도 남기고 `연결 없음`으로 표시합니다.
- 동적 IterationScript는 평가하지 않으며 연결을 확인할 수 없다는 사유를 남깁니다.

### 열 구성

처음 7개 열은 다음과 같습니다.

```text
테스트 케이스명 | 대상 모델명(CUTName) | 하네스명 | 하네스 input 파일명
| Test Sequence scenario 명 | input 시나리오 내용 | verify 내용
```

그 뒤에 `TopModel`, `CUTPath`, `DecisionBlocks`, `Iteration명`, `InputScenario명`,
`MaxTime`, `추출상태`, `비고`가 붙습니다.

`ALL_STEPS_COLUMNS` 모드에서는 `verify 내용 2`, `verify 내용 3` 등이 보조 열 앞에
추가됩니다. 반환 table `T`도 같은 열 구성을 쓰며, 스텝 수가 적은 행의 남는 셀은
비워 둡니다.

## 3. 입력 시나리오

입력 시나리오를 뽑을지 여부는 CUT의 직계 Inport 수가 아니라 **Harness의 Signal
Editor와 실제 Test Manager 연결**로 판단합니다.

| 상황 | 결과 |
| --- | --- |
| `SldvMode=OFF`이고 직계 Inport가 없지만 Signal Editor가 있고 TC에 연결됨 | input 파일명, `InputScenario명`, 저장된 Dataset 내용을 출력합니다 |
| Signal Editor 블록 자체가 없음 | `해당 없음`과 `SKIP_NO_SIGNAL_EDITOR` WARN |
| Dataset이 정상적으로 비어 있음 | 시나리오 연결은 유지하고 내용에 `<입력 신호 없음>` |
| 중복 블록, 잘못된 ActiveScenario, 읽을 수 없는 MAT | 그 대상을 FAIL로 기록하고 다음 대상은 계속 |

`해당 없음`은 Signal Editor가 없는 `OFF` 대상에만 씁니다.

### 입력 내용의 값

각 신호의 **마지막 저장 샘플**입니다. 신호마다 시간이 달라도 각자의 마지막 샘플을
쓰며, StopTime에 대한 보간이나 외삽은 하지 않습니다.

- 숫자 배열은 기존 verify와 같이 MATLAB 열 우선 선형 인덱스로 펼칩니다.
- 버스 벡터는 `(1)`, `(2)`, 버스 행렬은 `(1,1)`, `(2,1)`처럼 실제 저장 차원으로
  펼칩니다.
- 입력 데이터만으로 선언 당시의 벡터/행렬 구분을 복구할 수 없으면 저장된 구조를
  기준으로 합니다.
- 입력은 모든 원소를 출력하며 `VerifyFirstBusElementOnly` 설정으로 생략하지 않습니다.

```text
ABC: 1
AAA(1): 2
AAA(2): 3
BBB(1).CC: 4
BBB(2).CC: 5
DDD.EE(1): 6
```

## 4. `MaxTime`

기준이 테스트 데이터 생성 방식에 따라 다릅니다.

| `SldvMode` | `MaxTime`에 기록하는 값 |
| --- | --- |
| `FILE` 또는 `GENERATE` | 연결된 TC 입력 시나리오의 모든 신호에 저장된 시간 중 최댓값(Tmax), 초 단위 |
| `OFF` | 입력 시간을 쓰지 않고 그 Harness의 Solver `StopTime` |

verify 실행 시간은 어느 모드에서도 쓰지 않습니다.

다음 경우에는 Excel에서 빈 셀, 반환 table에서 `NaN`이며 비고를 남깁니다.

- FILE/GENERATE 입력이 없거나 연결·시간을 확인할 수 없을 때
- 시간을 가진 SLDV 입력을 읽었지만 시간 단위를 변환할 수 없을 때
- Harness `StopTime`이 숫자로 해석되지 않거나 유한한 0 이상 값이 아닐 때

절대 datetime은 임의의 시작 시각을 정해 초로 변환하지 않습니다.

## 5. `verify` 내용

### `VerifyMode='STEP2'` (기본)

현재 활성 스텝과 관계없이 각 시나리오의 **직계 Step 2** Action을 읽습니다.

이름은 대소문자와 `_`, 공백, `-`를 무시하고 숫자를 비교하므로 `step2`, `step_2`,
`Step 2`, `STEP-02`를 같은 이름으로 인식합니다. 정확한 `step2`와 변형 이름이 함께
있으면 `step2`를 우선하며 비고와 WARN에 중복을 남깁니다.

직계 Step 2가 없으면 `step2 없음`, verify가 없으면 `verify 없음`으로 표시합니다.
`parent.step_2` 같은 하위 스텝이나 다른 번호의 스텝으로 **대체하지 않습니다.**

### `VerifyMode='ALL_STEPS_COLUMNS'`

하위 스텝을 포함해 verify가 있는 각 스텝을 별도 열에 기록합니다. 스텝의 계층과
Index 순서를 따르며 첫 줄에 `[step2]`, `[step3.child]` 같은 상대 경로를 붙입니다.
빈 스텝은 열을 차지하지 않고, 반복된 신호 검증은 그대로 유지합니다.

### 표시 규칙

단순 등식은 좌변의 경로·인덱스와 우변의 표현식을 **그대로 보존**해 표시합니다.
우변을 실행하지 않으며 현재 기대값이 0이면 0으로 기록합니다. 복합식, 부등식,
추가 인수가 있는 verify는 원문으로 남깁니다. 스텝별 순서와 중복을 보존합니다.

```text
AAA(1): 0
BBB(1,2).CC: uint8(2)
```

`AssessmentDetails` 시트에는 원본 Action, 스텝 경로, 전이 조건을 두 모드 모두
보존하므로 조건부 verify의 실행 맥락을 확인할 수 있습니다. `ReadStatus`와 `Message`에
스텝별 상세 읽기 실패를 기록합니다. 다른 스텝이나 전이 조건을 읽는 데 실패해도
정상적으로 읽은 Step 2 verify는 유지합니다.

## 6. `DecisionBlocks`

CUT 바로 아래(`SearchDepth=1`)에서 **정적으로** 찾은 분기 후보 블록을, 블록 이름 한
줄과 그 아래 `D번호 [T/F]블록유형 (저장된 조건/선택 설정)` 줄로 표시합니다. Path,
BlockType, 분기 순서로 정렬하고 중복을 제거하며 빈 목록은 빈 셀입니다.

### 두 가지 분기 그룹

| 그룹 | 블록 | 설명 |
| --- | --- | --- |
| **명시적 분기** | `If`, `Switch`, `MinMax`, `MultiPortSwitch`, `SwitchCase` | 대화상자에 조건을 직접 적습니다 |
| **암시적 분기** | `Saturate`, `Abs`, `DeadZone`, `RateLimiter`, `Relay`, `Lookup_n-D`, `Interpolation_n-D`, `PreLookup`, `Integrator`, `DiscreteIntegrator`, `ForIterator`, `WhileIterator`, `Logic` | 조건식은 없지만 저장된 파라미터 때문에 Coverage objective가 생깁니다 |

D번호는 두 그룹을 구분하지 않고 정렬 결과에 연속으로 붙습니다. 권위 있는 목록은
`src/exporting/st_specification_decision_catalog.m` 한 곳입니다. 블록 하나가 D를 여럿
차지할 수 있다는 점은 아래 "D번호는 블록이 아니라 분기 단위"를 참고하세요.

### 어디까지 뽑을지 고르기

```matlab
[T, file] = st_export_test_specification('DecisionBlockScope','ALL');
```

기본값은 `cfg.DecisionBlockScope`입니다.

| 값 | 포함 대상 | 쓰는 때 |
| --- | --- | --- |
| `EXPLICIT` (기본) | 명시적 분기 5종 | 평소. 목록이 가장 짧습니다 |
| `ALL` | 명시적 + 암시적 18종 | `If`/`Switch`가 없는데 Decision coverage가 나오는 이유를 찾을 때 |
| `NONE` | 없음 (셀이 빕니다) | 분기 목록이 필요 없고 export를 가볍게 하고 싶을 때 |

`ALL`은 목록이 크게 길어집니다. Lookup 테이블이 많은 CUT은 `DecisionBlocks` 셀이 길이
한도를 넘어 `OverflowDetails` 참조로 대체될 수 있습니다. 그때도 구조화된 값은
`DecisionBlockDetails`에 그대로 남습니다.

`NONE`은 셀이 비어 있는 것과 블록이 없는 것을 Excel에서 구분할 수 없으므로, 어느
범위로 뽑았는지는 실행 로그의 `DecisionBlockScope=` 항목으로 확인합니다.

### 메인 시트는 항상 `[T/F]`

메인 시트의 `DecisionBlocks` 셀은 **분기 종류와 무관하게 항상 `[T/F]`로 적습니다.**
구체적인 분기 종류는 `DecisionBlockDetails` 시트의 `Outcome` 열과 JSON에만
기록합니다. 메인 시트는 분기의 **존재와 위치**를, 세부 시트는 분기의 **종류**를
담당합니다.

```text
Dics Block 이름
D1 [T/F]IF (u1 == 0)
D2 [T/F]IF (elseif u2 > 1)
Dics Block 이름2
D3 [T/F]Switch (u2 >= 5)
MinMax 블록
D4 [T/F]MinMax (max; Inputs=3)
Case 선택
D5 [T/F]SwitchCase
Sat 1
D6 [T/F]Saturate (UpperLimit=1; LowerLimit=-1)
```

위 여섯 줄에 대응하는 `DecisionBlockDetails`의 `Outcome`은 각각 `T/F`, `T/F`, `T/F`,
`SELECT`, `CASE`, `LIMIT`입니다.

### D번호는 블록이 아니라 분기 단위

한 블록이 분기를 여럿 가지면 **이름은 한 번만 적고 그 아래에 D 줄이 분기 수만큼**
붙습니다. `If`가 여기 해당합니다. `IfExpression`과 `ElseIfExpressions`의 조건마다 D를
하나씩 쓰므로, elseif가 둘인 `If` 블록은 D를 셋 차지합니다. Simulink Coverage도 if와
각 elseif를 따로 세기 때문에 이렇게 해야 개수가 맞습니다.

`ElseIfExpressions`는 쉼표로 이어진 목록이지만 `min(u1, u2) > 0`처럼 조건식 안에 있는
쉼표는 자르지 않습니다. 괄호 깊이를 보고 나눕니다.

**암묵적 else는 목록에 넣지 않습니다.** else는 모든 조건이 거짓인 경로이지 그 자체로
조건이 아니므로, `ShowElse` 설정과 관계없이 D를 받지 않습니다. 따라서 `If` 블록의 D
개수는 그 블록에 적힌 조건 개수와 같습니다.

### 조건식을 메인 시트에 쓰지 않는 블록

`SwitchCase`는 메인 셀에 `D5 [T/F]SwitchCase`처럼 **블록 유형만** 적습니다. case 목록은
한 줄에 담기에 길고 얻는 게 적기 때문입니다. `CaseConditions` 값은 그대로 읽어
`DecisionBlockDetails`의 `Expression` 열에 남기므로 정보가 사라지지는 않습니다.

어느 블록이 이렇게 동작하는지는 catalog의 `MainExpression` 열(`SHOW` 또는 `HIDE`)이
정합니다. 현재 `HIDE`는 `SwitchCase` 하나뿐입니다.

### `Outcome` 토큰

블록별이 아니라 **분기 종류별**로 묶여 있으므로 같은 행의 `BlockType` 열과 함께
읽습니다.

| Outcome | 대상 BlockType | 의미 |
| --- | --- | --- |
| `T/F` | If, Switch | 참/거짓 2분기 |
| `SELECT` | MinMax, MultiPortSwitch | N개 입력 중 선택 |
| `CASE` | SwitchCase | case 값 분배 |
| `LIMIT` | Saturate, Integrator, DiscreteIntegrator | 상/하한 포화, 외부 reset |
| `BAND` | DeadZone | 구간 아래/안/위 |
| `RATE` | RateLimiter | 상승/하강/제한 내 |
| `ON/OFF` | Relay | 히스테리시스 on/off |
| `SIGN` | Abs | 음수/비음수 |
| `INTERVAL` | Lookup_n-D, Interpolation_n-D, PreLookup | breakpoint 구간 선택과 외삽 |
| `LOOP` | ForIterator, WhileIterator | 루프 진입/지속/종료 |
| `CONDITION` | Logic | Condition/MCDC |

### 괄호 안 내용

| 블록 | 읽는 값 |
| --- | --- |
| `If` | `IfExpression`과 선택적 `ElseIfExpressions` |
| `Switch` | `Criteria`와 `Threshold` |
| `MinMax`, `MultiPortSwitch`, `SwitchCase` | 저장된 입력 선택 또는 case 설정 |
| `Saturate` | `UpperLimit` / `LowerLimit` |
| `Relay` | `OnSwitchValue` / `OffSwitchValue` |
| `Logic` | `Operator` / `Inputs` |
| `Integrator` 계열 | `LimitOutput` / `ExternalReset` |
| `Abs` | 파라미터를 읽지 않고 `u < 0`으로 표시 |

암시적 분기 블록은 catalog가 지정한 파라미터를 `이름=값; 이름=값` 형태로 이어
붙입니다. Lookup 계열의 breakpoint 값은 workspace에서 평가하지 않고 저장된 문자열을
그대로 옮기므로, 변수로 지정한 테이블은 변수 이름이 보입니다.

파라미터가 비활성이어도 목록에서 빼지 않습니다. 예를 들어 `LimitOutput=off;
ExternalReset=none`인 `Integrator`도 그대로 남기고 상태를 표시합니다.

### 이 값으로 할 수 없는 것

- **objective 개수를 세지 않습니다.** 실제 objective 생성 여부는 대화상자
  파라미터뿐 아니라 데이터 타입과 최적화 설정도 관여하므로, 저장된 파라미터만으로
  거르면 틀릴 수 있습니다.
- 메인 시트의 `[T/F]`는 실행 Coverage 결과가 아니라 저장된 블록에 분기가 있다는
  **정적 표기**이며, Decision objective를 뜻하지도 않습니다.
- `Lookup_n-D`/`PreLookup`/`Interpolation_n-D`(`INTERVAL`)는 Lookup Table 지표로,
  `Logic`(`CONDITION`)은 Condition/MCDC 지표로 집계되므로 이 행들은 Decision objective
  수와 일치하지 않습니다. **커버리지 숫자와 대조할 때는 반드시 세부 시트의 `Outcome`
  열을 보십시오.**

모델에 `If`나 `Switch`가 하나도 없는데 Simulink Coverage가 Decision을 보고하는 이유가
바로 암시적 분기 블록입니다.

### `DecisionBlockDetails` 시트

메인 시트 행, 테스트 케이스명, CUTPath, D번호, `Outcome`, `BlockType`, 원본 `Name`,
`Expression`, 전체 Simulink `Path`, 개별 JSON 객체, 조건식 읽기 상태를 행 단위로
기록합니다. 따라서 표시용 셀을 다시 파싱하지 않고 구조화된 열이나 `JSON` 열을 쓸 수
있습니다. 블록이 없는 테스트 케이스도 `JSON=[]`인 행으로 남깁니다.

```json
{"BlockType":"If","Name":"If","Path":"Top/CUT/Logic/If","Outcome":"T/F","Expression":"u1 > 0","ExpressionStatus":"OK","Message":""}
```

### Enabled / Triggered Subsystem

`'ALL'`에는 Enabled Subsystem과 Triggered Subsystem도 들어갑니다. enable과
trigger 자체가 분기이기 때문입니다. 조건을 대화상자에 적는 블록이 아니므로
`'EXPLICIT'`(기본)에는 나오지 않습니다.

그 분기는 Subsystem 한 겹 안의 port 블록에 붙어 있지만, 목록에는 **Subsystem이**
적힙니다. port 블록 이름은 어느 모델에서나 `Enable`이라 그것을 적으면 어느
서브시스템인지 알 수 없습니다.

**CUT 자신이 Enabled/Triggered Subsystem인 경우도 포함합니다.** CUT 자체가
조건부인 경우가 흔하고, 그 enable은 자식에 있는 것이 아니라서 자식만 보면
어디에서도 보고되지 않습니다.

### 탐색 범위

CUT의 **직계 자식만** 포함합니다. `CUT/Subsystem/Switch`처럼 하위 Subsystem 안에
있는 블록은 포함하지 않습니다. Variant와 참조 모델 내부로도 내려가지 않습니다.

마스크와 라이브러리 링크 경계는 **넘습니다**(`LookUnderMasks='all'`,
`FollowLinks='on'`). 이것이 없으면 마스크된 CUT이나 라이브러리 링크 안의 CUT은
직계 자식이 하나도 없다고 보고됩니다. 같은 누락으로 링크된 CUT의 포트가 0개로
보이던 사례가 있었습니다.

Enabled/Triggered Subsystem은 **포함합니다.** 자세한 것은 위
[Enabled / Triggered Subsystem](#enabled--triggered-subsystem) 절에 있습니다.
목록에 오르는 것은 port가 아니라 Subsystem이므로 `DecisionBlockDetails`의
`Path`는 그 행이 설명하는 블록을 그대로 가리킵니다.

다음은 **여전히 제외**합니다.

1. `Saturation Dynamic`, `Dead Zone Dynamic`, `Unit Delay Enabled`,
   `Unit Delay Resettable`처럼 마스크 Subsystem으로 구현된 블록. `BlockType`이
   `SubSystem`이라 BlockType 필터로 일반 Subsystem과 구분할 수 없습니다.
   (`LookUnderMasks`는 경계를 넘게 할 뿐이고, 그 안쪽 블록은 깊이 2라 직계
   범위 밖입니다.)
2. Stateflow와 MATLAB Function 블록 내부 분기.

## 7. `OverflowDetails` 시트

overflow 유무와 관계없이 항상 생성합니다. 셀의 문자 수 또는 줄바꿈 수가 Excel
한도를 넘으면 전체 내용을 이 시트에 순번별로 나누어 기록합니다.

| 열 | 원래 셀에 남는 것 |
| --- | --- |
| `input 시나리오 내용`, 모든 `verify 내용*` | **첫 번째 분할 조각의 내용**. 같은 행 `비고`에 열 이름과 `[OverflowDetails!E시작:E끝]` 참조 |
| `DecisionBlocks`를 포함한 나머지 | OverflowDetails 참조 문자열 |

반환 table `T`도 Excel과 같은 첫 조각과 비고를 씁니다.

## 8. 실패와 검증 경계

### 추출을 중단하는 조건

- 저장되지 않은 모델·하네스·Test File
- 실행 중인 모델
- 같은 이름의 다른 모델이 로드된 상태
- 관리 파일, 모델, Test File, 확인된 외부 하네스, 입력 MAT의 SHA-256 변경

### 계속 진행하는 조건

개별 시나리오나 입력 읽기 실패는 WARN/FAIL과 비고를 남기고 다른 행을 계속
출력합니다.

### 부작용 경계

모델 로드는 그 모델의 로드 콜백을 실행할 수 있습니다. 추출기는 콜백이나 iteration
스크립트를 별도로 실행하지 않으며, 자신이 연 모델은 저장하지 않고 닫습니다.

## 9. 회귀 검사

개발용 회귀 검사는 실제 대상 시뮬레이션을 수행하지 않습니다.

```matlab
st_setup
assertSuccess(runtests('tests/unit/test_export_test_specification.m'));
assertSuccess(runtests('tests/unit/test_specification_verify_modes.m'));
assertSuccess(runtests('tests/unit/test_specification_max_time.m'));
assertSuccess(runtests('tests/unit/test_specification_decision_blocks.m'));
```

R2025b에서는 저장된 실제 하네스로 추출한 뒤 시나리오 전체 개수, 미연결 시나리오,
여러 iteration 연결, 입력 마지막 값, 배열·버스 경로, 원문 verify를 대조하고, Excel에서
셀 줄바꿈과 상세 시트 참조를 확인해야 합니다. 개발 PC에서는 MATLAB이 없어 구문·정적
검증만 수행했으며 MATLAB API와 실제 Excel 렌더링 검증은 미수행입니다.
