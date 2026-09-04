# 테스트 실행 없이 엑셀 명세서 추출

모델, 하네스, Test Manager 파일과 입력 MAT 파일을 저장한 뒤 MATLAB에서 실행한다.
실행 중인 모델은 먼저 중지한다. 추출은 파일과 블록을 읽기 위해 모델을 로드하지만
시뮬레이션, 테스트 실행, SLDV 생성, 기대값 갱신을 호출하지 않는다.

```matlab
st_setup
[T, outputFile] = st_export_test_specification();

% 모든 스텝의 verify를 오른쪽 열에 스텝별로 분리
[T, outputFile] = st_export_test_specification( ...
    'VerifyMode', 'ALL_STEPS_COLUMNS');

% 다른 이름으로 저장 (기존 파일을 덮어쓰지 않음)
[T, outputFile] = st_export_test_specification( ...
    'OutputFile', fullfile(pwd, 'result', 'test_specification_review.xlsx'));
```

기본 출력은 `result/test_specification_<timestamp>.xlsx`이다. 별도 Excel 설치나
ActiveX는 필요 없다. 기존 `cfg.OnlyEnabled`, 관리 엑셀 및 `cfg.TestSuiteName`을
사용한다. 테스트 워크플로에 자동으로 삽입되지 않는 독립 명령이다.

## 행과 셀의 의미

`TestSpecification`은 테스트 케이스 × Assessment 블록의 실제 시나리오마다
한 행을 기록한다. 시나리오 이름을 생성 규칙으로 추측하지 않는다. 여러 iteration이
같은 Assessment 시나리오를 참조하면 입력 연결별로 행이 늘어난다. 연결되지 않은
Assessment 시나리오도 남기고 `연결 없음`으로 표시한다. 동적 IterationScript는
평가하지 않으며 연결을 확인할 수 없다는 사유를 남긴다.

처음 7개 열은 테스트 케이스명, 대상 모델명(CUTName), 하네스명, 하네스 input 파일명,
Test Sequence scenario 명, input 시나리오 내용, verify 내용이다. 그 뒤에 TopModel,
CUTPath, Iteration명, InputScenario명, MaxTime, 추출상태, 비고가 붙는다. 전체 스텝 모드에서는
`verify 내용 2`, `verify 내용 3` 등의 열이 보조 열 앞에 추가된다. 반환 table도
같은 열 구성을 사용하며, 스텝 수가 적은 행의 남는 셀은 비워 둔다.

`MaxTime`은 연결된 입력 시나리오의 모든 신호에 저장된 시간 중 최댓값을 초 단위의
숫자로 기록한다. Test Manager StopTime이나 verify 실행 시간은 사용하지 않는다.
입력이 없거나 연결/시간을 확인할 수 없으면 Excel에서는 빈 셀, 반환 table에서는
NaN이다. 시간을 가진 입력을 읽었지만 시간 단위를 변환할 수 없는 경우에도 NaN과
비고를 남긴다. 절대 datetime은 임의의 시작 시각을 정해 초로 변환하지 않는다.

입력 내용은 각 신호의 마지막 저장 샘플이다. 신호마다 시간이 달라도 각자의 마지막
샘플을 사용하며, StopTime에 대한 보간이나 외삽은 하지 않는다. 숫자 배열은 기존
verify와 같이 MATLAB 열 우선 선형 인덱스로 펼친다. 버스 벡터는 `(1)`, `(2)`,
버스 행렬은 `(1,1)`, `(2,1)`처럼 실제 저장 차원으로 펼친다. 입력 데이터만으로
선언 당시의 벡터/행렬 구분을 복구할 수 없는 경우 저장된 구조를 기준으로 한다.
입력의 모든 원소를 출력하며 VerifyFirstBusElementOnly 설정으로 생략하지 않는다.

```text
ABC: 1
AAA(1): 2
AAA(2): 3
BBB(1).CC: 4
BBB(2).CC: 5
DDD.EE(1): 6
```

`VerifyMode` 기본값은 `STEP2`이다. 현재 활성 스텝과 관계없이 각 시나리오의 직계
`step2` Action을 먼저 읽는다. step2가 없으면 `step2 없음`, verify가 없으면
`verify 없음`으로 표시하고 WARN과 비고를 남긴다. 다른 스텝으로 대체하지 않는다.

`ALL_STEPS_COLUMNS`는 하위 스텝을 포함하여 verify가 있는 각 스텝을 별도 열에
기록한다. 스텝의 계층·Index 순서를 따르며 첫 줄에 `[step2]`, `[step3.child]` 같은
상대 경로를 붙인다. 빈 스텝은 열을 차지하지 않고 반복된 신호 검증은 유지한다.

verify의 단순 등식은 좌변의 경로·인덱스와 우변의 표현식을 그대로 보존해 표시한다.
우변을 실행하지 않으며 현재 기대값이 0이면 0으로 기록한다. 복합식, 부등식 및
추가 인수가 있는 verify는 원문으로 남긴다. 스텝별 순서와 중복을 보존한다.

```text
AAA(1): 0
BBB(1,2).CC: uint8(2)
```

각 항목은 하나의 Excel 셀 안에서 줄바꿈된다. `AssessmentDetails`에는 원본 Action,
스텝 경로 및 전이 조건을 두 모드 모두 보존하므로 조건부 verify의 실행 맥락을
확인할 수 있다. `ReadStatus`와 `Message`에는 스텝별 상세 읽기 실패를 기록한다.
다른 스텝이나 전이 조건을 읽는 데 실패해도 정상적으로 읽은 step2 verify는 유지한다.
셀의 문자 수 또는 줄바꿈 수가 Excel 한도를 넘으면 `OverflowDetails`에 순번별로
나누어 기록하고 원래 셀에 참조 범위를 표시한다. 반환 table `T`에는 나누기 전의
전체 내용이 들어 있다. Excel의 화면 행 높이 제한 때문에 매우 긴 셀은 수식 입력줄
또는 상세 시트에서 확인해야 할 수 있다.

## 실패 및 검증 경계

미저장 모델·하네스·Test File, 실행 중인 모델, 같은 이름의 다른 모델이 로드된 상태는
추출을 중단한다. 관리 파일, 모델, Test File, 확인된 외부 하네스와 입력 MAT 파일의
SHA-256 변경을 감지한다. 개별 시나리오/입력 읽기 실패는 WARN/FAIL과 비고를 남기고
다른 행을 계속 출력한다. `해당 없음`은 입력이 없는 대상에 사용한다.

모델 로드는 해당 모델의 로드 콜백을 실행할 수 있다. 추출기는 콜백이나 iteration
스크립트를 별도로 실행하지 않으며, 자신이 연 모델은 저장하지 않고 닫는다.

개발용 회귀 검사는 실제 대상 시뮬레이션을 수행하지 않는다.

```matlab
st_setup
results = runtests('tests/unit/test_export_test_specification.m');
assertSuccess(results)
results = runtests('tests/unit/test_specification_verify_modes.m');
assertSuccess(results)
```

R2025b에서 저장된 실제 하네스로 추출한 뒤 시나리오 전체 개수, 미연결 시나리오,
여러 iteration 연결, 입력 마지막 값, 배열·버스 경로 및 원문 verify를 대조한다.
Excel에서 셀 줄바꿈과 상세 시트 참조를 확인한다. 개발 PC에서는 MATLAB이 없어
구문/정적 검증만 수행했으며 MATLAB API와 실제 Excel 렌더링 검증은 미수행이다.
