# Standalone Coverage Pipeline

Standalone Coverage는 이미 준비가 끝난 Harness와 Test Case를 입력으로 사용한다.
Harness 생성, Test Case 재생성, Expected 갱신이 필요하면 먼저
`st_run_from_harness`를 실행한다. 실행 전 원본 Top Model과 Test File을 저장하고
Top Model을 닫아 copied workspace와 같은 모델명이 충돌하지 않게 한다.

## 기본 실행

```matlab
% EXECUTE -> PACKAGE -> SUMMARY
info = st_run_standalone_coverage_pipeline();

% 생성된 결과를 읽기 전용으로 한 화면에서 확인
[code, summary, details] = st_check_standalone_coverage();
```

전체 계약을 통과한 코드만 `1111111111`이다. 화면 출력은 최대 20줄이며,
전체 CUT 결과는 `details` table에서 확인한다.

## Action별 실행과 재개

```matlab
% EXECUTE 단독 실행은 재개용 aggregate Result를 기본 저장한다.
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'EXECUTE');

% 새 MATLAB 세션에서 저장 Result를 한 번 import해 패키징한다.
st_run_standalone_coverage_pipeline( ...
    'Action', 'PACKAGE', ...
    'PipelineId', info.PipelineId);

st_run_standalone_coverage_pipeline( ...
    'Action', 'SUMMARY', ...
    'PipelineId', info.PipelineId);
```

| Action | 역할 |
|---|---|
| `EXECUTE` | standalone export, Test Case 1회 실행, CVF 1회 등록, 열린 모델에서 report/metric/CVT 임시 증거 캡처 |
| `PACKAGE` | 임시 증거를 검증해 Model/Input/CVF/CVT/HTML/Test File 패키징 |
| `SUMMARY` | manifest scalar에서 `CoverageSummary.xlsx` 생성 |
| `ALL` | 세 Action 연속 실행, 기본값 |

`SaveTestResult` 기본값은 `ALL=false`, `EXECUTE=true`이다. `ALL`은 live Result를
PACKAGE로 전달하므로 export/import를 수행하지 않는다. `PACKAGE`와 `SUMMARY`에는
`SaveTestResult`를 지정할 수 없다. lifecycle 횟수를 보존하기 위해 각 PipelineId의
`PACKAGE`와 `SUMMARY`는 한 번만 실행할 수 있다. 다시 생성할 때는
`st_run_from_stage`가 저장 증거를 검증하고 **새 PipelineId**를 만든다.
증거가 없거나 변했으면 재생성을 차단하고 `EXECUTE`부터 다시 실행하도록 안내한다.
업데이트 전 `EXECUTE`가 만든 PipelineId에는 report/metric 임시 증거가 없으므로
현재 `PACKAGE`에 재사용하지 않고 새 `EXECUTE`를 실행한다.

이전 `RunMode`와 준비 옵션을 전달하면 새 Action API와 `st_run_from_harness`를
안내하는 migration 오류가 발생한다.

## 산출물

각 CUT 폴더에는 다음 필수 산출물만 둔다.

- Harness명과 같은 파일 stem의 standalone model
- Signal Editor Input MAT(대상에 Input이 있을 때)
- `UT_REQ_{TC_NAME}.cvf`
- `UT_REQ_{TC_NAME}.cvt`
- Test Manager Coverage Results의 REPORT 화살표가 여는 원본 `UT_REQ_{TC_NAME}.html`
- target manifest

파이프라인 root에는 copied Test File, pipeline manifest, JSONL lifecycle event log,
`CoverageSummary.xlsx`가 생성된다. `SaveTestResult=true`일 때만 aggregate Result가
추가된다.

`FilteredResults.mldatx`, `coverage-metrics.mat`, `TestSummary.xlsx`, PDF와 별도
보조 Coverage HTML은 만들지 않는다. `UT_REQ_{TC_NAME}.html`은 CUT별 원본 `cvhtml` Coverage
보고서 하나만 보존하며, 렌더링에 필요한 부속 asset은 같은 대상 폴더에 둔다.

## CoverageSummary.xlsx

`CoverageSummary` sheet의 열은 다음 순서로 고정한다.

```text
NUM
CUT_NAME
CUT_PATH
Test Case Name
Harness Name
Decision Executed
Decision Total
Decision (%)
Execution Executed
Execution Total
Execution (%)
```

Decision/Execution 분모가 0이거나 값이 없으면 `N/A`이다. metric source는 Result
coverage API와 standalone CUT path의 단일 일치를 요구한다. 둘 이상의 후보가
일치하면 `AMBIGUOUS`로 실패한다. 실제 R2025b HTML Details와 대조하기 전 source
상태는 `PROVISIONAL`이다. CVF로 모든 objective가 제외됐거나 objective가 없는
CUT은 `decisioninfo`/`executioninfo`의 빈 결과를 유효한 `0/0`, `N/A` metric으로
기록한다.

원본 Coverage HTML은 긴 execution target 경로에 직접 생성하지 않는다. Windows의
legacy path 경계를 피하도록 짧은 writable scratch에서 report tree와 ZIP을 완성한 뒤
ZIP만 package evidence 경로로 승격한다.

패키지의 `TestManager` 폴더에는 rewired MLDATX와
`open_standalone_coverage_test_manager.m` launcher가 함께 생성된다. standalone model은
CUT별 target 폴더에 보존된다. launcher는 편의 기능이며 필수가 아니다.
대상 폴더를 MATLAB path에 추가하고 MLDATX를 열어 각 Test Case의 Model 폴더 버튼으로
같은 폴더의 standalone `.slx`를 선택해도 된다. 이 파일은 Top Model 아래의 Harness가
아니라 독립 Model이므로 Test Harness 항목은 비워 둔다.
다른 PC에서는 path와 CVF 경로를 다시 확인한다. 자세한 절차는
[결과 열기](manual/open-results.md)를 따른다.

## 한 화면 검사 비트

| 비트 | 검사 |
|---|---|
| B1 | manifest v2/v3, Action, Result 저장/재개 정책 또는 재생성 provenance, 주요 함수 중복 경로 |
| B2 | Harness명 = standalone model명 = `.slx` stem |
| B3 | SUT/iteration/input/assessment readback |
| B4 | `RunCount=1`, rerun 없음, lifecycle event 일치 |
| B5 | CVF 생성, rule/file/hash, Result 등록 1회 |
| B6 | 필수 패키지와 금지 artifact 부재 |
| B7 | Decision/Execution scalar 및 metric source |
| B8 | Summary 파일, 11개 열, CUT row 수 |
| B9 | 원본 model/Test File/Harness/Input/Excel 불변 |
| B10 | filter restore, model/path cleanup, CUT 폴더 격리 |

`EXECUTE`까지만 끝난 상태처럼 아직 적용할 수 없는 PACKAGE/SUMMARY 비트는 `-`로
표시하고 전체 상태는 `PARTIAL`을 반환한다. checker는 Result import, model load/save,
Test Manager clear 또는 파일 생성을 수행하지 않는다.

## 완료 기준

정적 테스트만으로 runtime 완료를 주장하지 않는다. 실제 MATLAB R2025b에서
`tests/integration/test_standalone_coverage_pipeline_runtime.m`과 multi-CUT acceptance를
실행하고, 최종 checker 결과 `1111111111 PASS`를 확보해야 완료로 본다.

실제 수동 실행과 실패 호출 위치 확인 명령은
[`manual/standalone-coverage-runtime.md`](manual/standalone-coverage-runtime.md)에
정리한다.
