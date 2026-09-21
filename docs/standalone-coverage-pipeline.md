# Standalone Coverage 파이프라인

CUT별 Harness를 **독립 실행 가능한 모델**로 떼어내 실행하고, 커버리지 결과와 부속
파일을 제출 가능한 형태로 묶는 기능입니다. 받는 쪽에 원본 Top Model이 없어도 열
수 있는 결과물을 만듭니다.

복사해서 바로 쓸 코드는 [Standalone 실행](manual/standalone-run.md)에 있습니다.

## 1. 실행 전 조건

이 파이프라인은 **이미 준비가 끝난 Harness와 Test Case를 입력으로 씁니다.**
Harness 생성, Test Case 재생성, 기대값 갱신이 필요하면 먼저 일반 workflow를
실행하십시오.

```matlab
st_run_from_harness('PreparationMode','FORCE','ExecuteTests', false);
```

실행 직전에 다음을 확인합니다.

- 원본 Top Model과 Test File을 저장했는가
- **Top Model을 닫았는가** — 복사된 작업 공간의 모델과 이름이 충돌합니다
- 각 활성 행이 아래 조합을 갖추었는가

```text
CoverageFilterMode      = ALL_CONTENT
CoverageBoundaryMode    = CUT_ONLY
CoverageFilterAction    = EXCLUDE
CoverageFilterRationale = (비어 있지 않은 사유)
```

## 2. 기본 실행

```matlab
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);

% 결과를 읽기 전용으로 한 화면에서 확인
[code, summary, details] = st_check_standalone_coverage();
```

`Action='ALL'`이 기본값이므로 `st_run_standalone_coverage_pipeline()`만 써도 같지만,
`ContinueOnFailure`와 `FailOnNonPass`를 명시해 두면 한 대상이 실패해도 나머지가
처리되고 MATLAB 오류 대신 결과 표로 판정하게 됩니다.

전체 계약을 통과한 코드만 `1111111111`입니다. 화면 출력은 최대 20줄이며 전체 CUT
결과는 `details` 표에서 확인합니다.

## 3. Action별 실행과 재개

긴 실행을 나눠서 하거나 다른 MATLAB 세션에서 이어서 하고 싶을 때 Action을 나눠
실행합니다.

```matlab
% EXECUTE 단독 실행은 재개용 aggregate Result를 기본 저장합니다.
info = st_run_standalone_coverage_pipeline('Action','EXECUTE');

% 새 세션에서 저장된 Result를 한 번 import해 패키징합니다.
st_run_standalone_coverage_pipeline('Action','PACKAGE', 'PipelineId', info.PipelineId);
st_run_standalone_coverage_pipeline('Action','SUMMARY', 'PipelineId', info.PipelineId);
```

| Action | 하는 일 |
| --- | --- |
| `PREPARE` | standalone export, Test Case를 standalone 모델로 재배선한 Test File 저장. **실행하지 않습니다** |
| `EXECUTE` | standalone export, Test Case 1회 실행, CVF 1회 등록, 모델이 열린 동안 report/metric/CVT 임시 증거 캡처 |
| `PACKAGE` | 임시 증거를 검증해 Model/Input/CVF/CVT/HTML/Test File을 최종 산출물로 승격 |
| `SUMMARY` | manifest 값에서 `CoverageSummary.xlsx` 생성 |
| `ALL` (기본) | `EXECUTE` → `PACKAGE` → `SUMMARY` 연속 실행 |

`PREPARE`는 `EXECUTE`가 실행 직전까지 하는 일만 하고 멈춥니다. 산출물은
`<PipelineRoot>/TestManager/<TopModel>.mldatx` 하나이고 standalone 모델은
`.work` 아래 실행 workspace에 남습니다. 실행 증거가 없으므로 같은 PipelineId에
`PACKAGE`나 `SUMMARY`를 부르면 `StandalonePipelinePrepareOnly`로 멈추고,
`latest.json`을 갱신하지 않아 `LATEST`가 되지 않으며,
`st_check_standalone_coverage`에 넘기면 `FAIL`입니다. 절차는
[Standalone 실행](manual/standalone-run.md)의 "Test File만 만들기"에 있습니다.

### `SaveTestResult`의 기본값이 Action마다 다른 이유

| Action | 기본값 | 이유 |
| --- | --- | --- |
| `ALL` | `false` | live Result를 그대로 PACKAGE에 넘기므로 export/import가 필요 없습니다 |
| `EXECUTE` | `true` | 다른 세션에서 재개하려면 Result를 파일로 남겨야 합니다 |
| `PACKAGE` / `SUMMARY` | 지정 불가 | 이미 만들어진 증거를 읽기만 합니다 |
| `PREPARE` | 지정 불가 | 실행하지 않으므로 저장할 Result가 없습니다 |

### 한 번만 실행할 수 있는 이유

lifecycle 횟수를 보존하기 위해 **각 PipelineId의 `PACKAGE`와 `SUMMARY`는 한 번만**
실행할 수 있습니다. 다시 만들려면 `st_run_from_stage`가 저장된 증거를 검증하고
**새 PipelineId**를 만듭니다.

증거가 없거나 바뀌었으면 재생성을 막고 `EXECUTE`부터 다시 실행하도록 안내합니다.
`.work` 폴더를 지웠거나 report 캡처 자체가 실패했다면 PACKAGE 재생성으로 복구할 수
없습니다. 절차는 [재시작](manual/restart.md)에 있습니다.

> 예전 `RunMode`와 준비 옵션을 전달하면 새 Action API와 `st_run_from_harness`를
> 안내하는 migration 오류가 납니다.

## 4. 산출물

각 CUT 폴더(`{NUM}_UT_REQ_{TC_NAME}`)에는 다음만 둡니다.

- Harness 이름과 같은 파일 stem의 standalone 모델
- Signal Editor Input MAT (대상에 Input이 있을 때)
- `UT_REQ_{TC_NAME}.cvf`
- `UT_REQ_{TC_NAME}.cvt`
- Test Manager Coverage Results의 REPORT 화살표가 여는 원본 `UT_REQ_{TC_NAME}.html`
- target manifest

실행하지 못한 대상도 폴더는 만들어집니다.

파이프라인 root에는 복사된 Test File, pipeline manifest, JSONL lifecycle event log,
`CoverageSummary.xlsx`가 생성됩니다. `SaveTestResult=true`일 때만 aggregate Result가
추가됩니다.

`TestManager` 폴더에는 재배선된 MLDATX와
`open_standalone_coverage_test_manager.m` launcher가 함께 생성됩니다. launcher는
편의 기능이며 필수가 아닙니다.

이 PC에서 제출물을 Test Manager에서 열려면 `st_open_standalone_test_manager`를
부릅니다. 대상 폴더를 path에 올리고 재배선된 MLDATX를 열어 창을 띄우는 수동 절차를
명령 하나로 묶은 것이며, 파일은 만들거나 바꾸지 않습니다. 자세한 여는 방법은
[결과 열기](manual/open-results.md)에 있습니다.

### 일부러 만들지 않는 것

`FilteredResults.mldatx`, `coverage-metrics.mat`, `TestSummary.xlsx`, PDF와 별도 보조
Coverage HTML은 만들지 않습니다. `UT_REQ_{TC_NAME}.html`은 CUT별 원본 `cvhtml`
Coverage 보고서 하나만 보존하며, 렌더링에 필요한 부속 asset은 같은 폴더에 둡니다.

> 원본 Coverage HTML은 긴 실행 경로에 직접 만들지 않습니다. Windows의 legacy path
> 경계를 피하려고 짧은 writable scratch에서 report tree와 ZIP을 완성한 뒤 ZIP만
> package evidence 경로로 승격합니다. 압축 파일은 캡처 증거용이며 최종 HTML 대신
> 제출하는 파일이 아닙니다.

### 팀 제출 트리로 재배치

팀 내부 제출은 위 폴더를 파일 종류별 세 갈래로 나눈 형태를 씁니다. MATLAB 없이
Python만으로 재배치합니다.

```bash
python tools/python/classify_standalone_results.py result/standalone_coverage/{PipelineId}
```

파이프라인 폴더 옆에 `{TopModel}/` 폴더(이름은 `TestManager/{TopModel}.mldatx`의
stem)를 만들고 파일 이름은 바꾸지 않은 채 복사합니다. 원본 폴더는 그대로 남으므로
`st_open_standalone_test_manager` 같은 툴킷 명령은 계속 원본에 대해 동작합니다.

```text
{TopModel}/
├── 테스트 케이스/{NUM}_UT_REQ_{TC_NAME}/   Input .mat
├── 테스트 보고서/{TopModel}.mldatx
├── 테스트 보고서/{NUM}_UT_REQ_{TC_NAME}/   .cvf .cvt .html + 부속 asset 폴더
└── 프로젝트/{NUM}_UT_REQ_{TC_NAME}/        standalone 모델 .slx
```

`CoverageSummary.xlsx`, manifest, 로그, `target-manifest.json`, launcher와 CUT 폴더
안의 `scv_images` 폴더는 복사하지 않고 건너뛴 목록으로만 출력합니다. `--dry-run`은 계획만 보여 주고, `--out`으로 출력
위치를 바꾸며, 출력 폴더가 이미 있으면 `--overwrite` 없이는 멈춥니다.

## 5. `CoverageSummary.xlsx`

`CoverageSummary` 시트의 열은 다음 순서로 고정합니다.

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

| 상황 | 표시 |
| --- | --- |
| 분모가 0이거나 값이 없음 | `N/A` |
| CVF로 모든 objective가 제외됨 | 유효한 `0/0`, `N/A` |
| CUT path 후보가 둘 이상 일치 | `AMBIGUOUS`로 실패 |

metric source는 Result coverage API와 standalone CUT path가 **정확히 하나** 일치할
것을 요구합니다. 실제 R2025b HTML Details와 대조하기 전 source 상태는
`PROVISIONAL`입니다.

## 6. 한 화면 검사 비트

```matlab
[code, summary, details] = st_check_standalone_coverage('PipelineId', info.PipelineId);
```

| 비트 | 검사 |
| --- | --- |
| B1 | manifest v2/v3, Action, Result 저장·재개 정책 또는 재생성 provenance, 주요 함수 중복 경로 |
| B2 | Harness명 = standalone 모델명 = `.slx` stem |
| B3 | SUT / iteration / input / assessment readback |
| B4 | `RunCount=1`, rerun 없음, lifecycle event 일치 |
| B5 | CVF 생성, rule/file/hash, Result 등록 1회 |
| B6 | 필수 패키지 존재와 금지 artifact 부재 |
| B7 | Decision/Execution scalar와 metric source |
| B8 | Summary 파일, 11개 열, CUT row 수 |
| B9 | 원본 model/Test File/Harness/Input/Excel 불변 |
| B10 | filter restore, model/path cleanup, CUT 폴더 격리 |

아직 적용할 수 없는 비트(예: `EXECUTE`까지만 끝난 상태의 PACKAGE/SUMMARY 비트)는
`-`로 표시하고 전체 상태는 `PARTIAL`을 반환합니다.

checker는 Result import, model load/save, Test Manager clear, 파일 생성을 하지
않습니다.

> B9는 **현재** 원본이 그대로인지 봅니다. 원본 모델이 나중에 바뀐 뒤 과거 결과를
> 재생성하면, 재생성 자체가 성공해도 B9는 실패할 수 있습니다.

## 7. 예외가 난 대상

시뮬레이션 예외는 `ExecutionStatus=EXCEPT`로 남습니다.

- 만들 수 있었던 Harness와 Input은 패키징합니다.
- 없는 CVT/HTML/metric을 만들어 PASS로 위장하지 않습니다.
- 따라서 그런 결과의 PACKAGE/SUMMARY 또는 checker 판정은 `FAIL`/`PARTIAL`일 수
  있습니다.
- Harness와 Input이 만들어지기 **전에** 실패한 경우에는 보존을 보장하지 않습니다.
- 모든 비트가 1이어도 `EXCEPT` 대상이 있으면 `PASS`가 아니라 `PARTIAL`입니다.
  커버리지 누락을 녹색 코드 뒤에 숨기지 않기 위한 의도적 정책입니다.

필터가 적용돼 objective가 없어진 유효한 `0/0`, `N/A`와 Coverage 객체 자체의 누락은
서로 다른 상황입니다.

## 8. dependency 수집 범위

standalone export는 Top Model 전체가 아니라 **생성된 standalone Harness 모델의
dependency만** 수집합니다.

- 대상과 무관한 Top Model branch의 미해결 dependency는 export를 막지 않습니다.
- 반대로 standalone `.slx` 자체가 필요한 파일을 찾지 못하면, 받는 PC에서 열리지
  않는 제출물을 만들지 않도록 export를 중단합니다.

## 9. 완료 기준

정적 테스트만으로 runtime 완료를 주장하지 않습니다. 실제 MATLAB R2025b에서
`tests/integration/test_standalone_coverage_pipeline_runtime.m`과 multi-CUT
acceptance를 실행하고 최종 checker 결과 `1111111111 PASS`를 확보해야 완료로 봅니다.

실패 원인 확인 방법은 [Standalone 실행](manual/standalone-run.md)과
[문제 해결 6장](troubleshooting.md#6-standalone-제출물-오류)에 있습니다.
