# 종합 검증 사용자 매뉴얼

이 문서는 Simulink Test Automation Toolkit의 전체 기능 검증을 처음 실행하는
사용자를 위한 단계별 안내서입니다. API와 내부 판정 기준은
[전체 기능 검증 기술 문서](verification.md)에서 별도로 설명합니다.

> 현재 저장소에는 검증 코드와 자동 테스트가 구현되어 있지만, 실제 MATLAB
> R2025b 환경의 최초 `CERTIFY + BOTH` 결과는 아직 확보되지 않았습니다.
> 최초 실행은 이 매뉴얼의 인증 절차에 따라 결과를 보존하십시오.

## 1. 무엇을 검사하는가

`st_verify_all`은 다음 기능을 한 번에 점검합니다.

- MATLAB 제품, 주요 API와 라이선스 존재 여부
- `runtime_target.mat`, 관리 Excel, 모델과 Test File
- CUT, Harness, Signal Editor, Test Assessment, Test Case와 Iteration
- SLDV `OFF`, `FILE`, `GENERATE` 준비
- 기대값 `APPLY` 갱신과 명시적 `OFF` 보존
- 대상별 증분 캐시, 손상 상태 복구와 부분 실패 처리
- Decision 및 Block Execution coverage
- 내부 Harness 실행과 독립 Harness SLX Model SUT 실행
- Harness 인프라 CVF와 CUT 정책 CVF의 분리 적용·복원
- Excel, PDF, HTML, MLDATX 통합 보고서
- 재실행 가능한 내보내기 bundle과 template 불변성
- 대화상자, CUT highlight와 보고서 화면의 수동 확인 증거

정상 workflow와 검증 workflow는 서로 다른 명령입니다.

| 목적 | 명령 |
| --- | --- |
| Harness 준비와 테스트 실행 | `st_run_from_harness` 또는 `st_run_after_harness` |
| 준비된 Test File의 CUT별 직접 실행 | `st_run_tests_per_cut` |
| 구현·환경·산출물 검증 | `st_verify_all` |

## 2. 세 가지 Profile 이해하기

| Profile | 언제 사용하는가 | 원본 변경 | 예상 소요시간 |
| --- | --- | --- | --- |
| `QUICK` | 매일 작업 시작, 설정 변경 후, 실행 전 상태 확인 | 저장하지 않음 | 수십 초~수 분 |
| `RUNTIME` | 실제 업무 Test File이 격리 사본에서 정상 실행되는지 확인 | 원본 대신 snapshot 실행 | 수 분~수 시간 |
| `CERTIFY` | 릴리스 또는 최초 환경 인증 | fixture와 snapshot만 변경 | 수십 분~수 시간 |

검사 대상은 다음과 같이 선택합니다.

| Target | 의미 |
| --- | --- |
| `CURRENT` | 현재 `runtime_target.mat`이 선택한 실제 업무 모델 |
| `FIXTURE` | 검증 실행이 임시 workspace에 만드는 자동 모델 |
| `BOTH` | 실제 업무 모델과 자동 fixture 모두 |

권장 조합은 다음 네 가지입니다.

| 상황 | 권장 조합 |
| --- | --- |
| 평상시 상태 점검 | `QUICK + CURRENT` |
| 실제 테스트 실행 확인 | `RUNTIME + CURRENT` |
| 업무 데이터 없이 프레임워크 전체 확인 | `CERTIFY + FIXTURE` |
| 릴리스 또는 최초 공식 인증 | `CERTIFY + BOTH` |

## 3. 실행 전 체크리스트

### 3.1 필수 소프트웨어

- MATLAB R2025b
- Simulink
- Simulink Test
- Simulink Coverage
- `CERTIFY + FIXTURE`의 경우 Simulink Design Verifier

제품이 설치되어 있어도 실제 실행 시 라이선스 checkout에 실패할 수 있습니다.
이 경우 기능 실패가 아니라 `BLOCKED`로 기록됩니다.

### 3.2 필수 파일

저장소 루트에서 다음 항목을 확인합니다.

```text
st_setup.m
runtime_target.mat
TestManagement.xlsx
{선택한 모델}.slx 또는 .mdl
{TopModel}.mldatx
```

`CERTIFY + FIXTURE`는 업무용 SLX/XLSX/MAT fixture를 요구하지 않습니다.
필요한 바이너리를 실행 workspace에 자동 생성합니다.

### 3.3 저장 상태

`RUNTIME`과 `CERTIFY` 전에 다음 파일을 저장하십시오.

- 선택한 Top Model과 로드된 dependency model
- 대상 Test File
- `TestManagement.xlsx`
- 현재 사용하는 Signal Editor와 SLDV 입력

검증은 원본을 수정하지 않지만, 저장되지 않은 상태를 snapshot의 기준으로 삼지
않습니다. 저장하지 않은 모델이 있으면 실행을 중단하는 것이 정상입니다.

## 4. 최초 설정

MATLAB에서 저장소 루트를 Current Folder로 연 뒤 다음을 실행합니다.

```matlab
st_setup
st_select_target_model
```

선택 상태를 확인합니다.

```matlab
cfg = st_require_runtime_target();
disp(cfg.TopModel)
disp(cfg.ModelFile)
disp(cfg.TestFile)
disp(cfg.ManagementExcel)
```

`TestManagement.xlsx`의 `Targets` 시트에는 최소한 다음 값이 있어야 합니다.

| 필수 열 | 설명 |
| --- | --- |
| `CUTName` | 대상 Subsystem 이름 |
| `CUTPath` | Top Model 아래 실제 경로 |
| `HarnessName` | 생성하거나 재사용할 Harness 이름 |
| `TestCaseName` | Test Manager Test Case 이름 |

실행 범위와 갱신 정책을 제어하려면 `Enabled`, `SldvMode`, `SldvDataFile`,
`ExpectedUpdateMode`, `CoverageFilterMode`, `CoverageFilterAction`,
`CoverageFilterRationale`, `PreparationMode`, `PreparationFromStage`를 사용합니다.

Coverage 자동 필터를 사용하려면 `CoverageFilterMode`를 `SUBSYSTEM` 또는
`ALL_CONTENT`로 정하고, `CoverageFilterAction`과
`CoverageFilterRationale`을 함께 입력합니다. `SUBSYSTEM`은 CUT의 직속 하위
Subsystem 블록만, `ALL_CONTENT`는 그 직속 하위 Subsystem과 각 내부 전체를
필터 대상으로 합니다. CUT 자기 자신과 일반 블록은 직접 필터링하지 않으며,
기본 설정은 실행 중 Test Case별 임시 적용입니다.

실제 실행이 끝난 뒤 `[code, details] = st_check_per_cut_cvf()`를 실행하면 CUT별
6비트 점검 코드가 출력됩니다. `111111`만 전체 통과입니다. 문제가 있으면
`CVF-CHECK-v1`로 시작하는 줄 전체와 `details` 표를 전달하십시오.

환경과 실행 결과까지 함께 확인하려면 `summary = st_check_actual_system()`을
실행하십시오. `SYSTEM-CHECK-v1`의 `ENV`, `RUN`, `CVF`가 모두 `111111`이면
18개 자동 검사를 통과한 것입니다. 0이 있으면 `summary.Environment`,
`summary.Run`, `summary.CVF`에서 같은 번호의 메시지를 확인하고 세 코드 줄과 표를
함께 전달하십시오. 명령은 모델과 Test File을 저장하지 않습니다. PDF/HTML의
시각적 내용과 Test Manager 화면 동작은 사용자가 별도로 확인해야 합니다.

## 5. 권장 실행 순서

### 5.1 1단계: QUICK 결과부터 확인

처음에는 오류를 바로 발생시키지 않고 결과를 모두 확인하는 방식을 권장합니다.

```matlab
summary = st_verify_all( ...
    'Profile', 'QUICK', ...
    'Target', 'CURRENT', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);

disp(summary.Status)
disp(summary.RunDirectory)
```

실행 후 다음 파일을 먼저 엽니다.

```matlab
open(summary.Summary)
```

`Overview`에서 전체 상태를 확인하고 `Checks`에서 `FAIL` 또는 `BLOCKED` 행을
필터링합니다. 원인을 정리한 뒤 같은 명령을 다시 실행하십시오.

모든 차단 원인이 정리되면 이후 실행에서는 엄격한 모드를 사용할 수 있습니다.

```matlab
summary = st_verify_all('FailOnNonPass', true);
```

### 5.2 2단계: 자동 fixture 전체 인증

업무 모델과 무관하게 framework 자체를 먼저 인증합니다.

```matlab
summary = st_verify_all( ...
    'Profile', 'CERTIFY', ...
    'Target', 'FIXTURE', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

이 실행은 다음 항목을 실제로 수행하므로 오래 걸릴 수 있습니다.

1. scalar, numeric array, nested Bus, Bus array, no-Inport 모델 생성
2. 분기와 파라미터를 가진 SLDV 대상 생성
3. 전체 `FORCE` workflow와 테스트 실행
4. 최초 실패, `APPLY` 갱신과 최종 PASS 확인
5. 명시적 `OFF` 대상이 변경되지 않았는지 확인
6. SLDV `GENERATE` 결과를 `FILE` 모드에서 재사용
7. 두 번째 `AUTO`에서 준비 캐시 재사용과 테스트 재실행 확인
8. 손상된 상태 복구와 준비 실패 시 테스트 미실행 확인
9. 보고서, coverage, 내보내기와 두 번의 재실행 확인

fixture에서 분모가 있는 Decision과 Execution coverage는 100%여야 합니다.

### 5.3 3단계: 실제 업무 Test File 실행

QUICK과 fixture 인증이 통과한 뒤 실제 업무 모델을 격리 실행합니다.

```matlab
summary = st_verify_all( ...
    'Profile', 'RUNTIME', ...
    'Target', 'CURRENT', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

검증기는 내보내기 수집기를 이용해 모델, dependency, Test File, Excel,
Signal Editor와 SLDV 입력을 snapshot에 복사합니다. 테스트와 기대값 갱신은
snapshot의 새 workspace에서만 수행합니다. 원본 파일은 실행 전후 SHA-256을
비교합니다.

실제 업무 모델의 coverage는 보고 전용입니다. 100% 미만은 `WARN`일 수 있지만
coverage 미달만으로 테스트 실패가 되지는 않습니다.

### 5.4 4단계: 실제 모델과 fixture 통합 인증

이 단계에는 수동 증거가 필요합니다. 6개의 screenshot 또는 대응 log를 먼저
준비한 뒤 JSON에 6개 수동 검사 항목을 작성합니다.

```matlab
summary = st_verify_all( ...
    'Profile', 'CERTIFY', ...
    'Target', 'BOTH', ...
    'ManualEvidence', 'manual-evidence.json', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

결과가 `PASS`이면 같은 입력으로 `FailOnNonPass=true`를 사용해 최종 인증
명령을 한 번 더 실행할 필요는 없습니다. `false`는 오류 throw 여부만 바꾸며
검사 판정과 결과 내용은 바꾸지 않습니다.

### 5.5 독립 Harness 모델로 실제 테스트 실행

기본 workflow는 Top Model의 내부 Harness를 Test Manager SUT로 사용합니다.
내부 Harness를 독립 SLX로 내보내 Model SUT로 실행하려면 호출 전체에
`SystemUnderTestMode='EXPORTED_MODEL'`을 지정합니다.

```matlab
[results, updates, workflow, report] = st_run_from_harness( ...
    'SystemUnderTestMode', 'EXPORTED_MODEL', ...
    'ExecutionMode', 'AUTO', ...
    'ReportMode', 'SUMMARY', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
```

Harness 준비가 이미 끝났다면 `st_run_after_harness`에 같은 옵션을 사용합니다.
Test File과 Harness가 모두 준비돼 있다면 다음처럼 실행 단계만 직접 호출할 수
있습니다.

```matlab
[results, updates, report] = st_run_tests_per_cut( ...
    'SystemUnderTestMode', 'EXPORTED_MODEL', ...
    'ReportMode', 'FULL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
```

실행 전에는 다음 조건을 확인합니다.

- 원본 모델, 열린 Harness, Test File, Excel과 입력 파일을 저장합니다.
- `cfg.CoverageFilterApplicationMode`은 `RUNTIME`이어야 합니다.
- 현재 지원 CUT은 Subsystem입니다. Model Reference CUT은 아직 지원하지 않습니다.
- `EXPORTED_MODEL`은 항상 CUT별 순차 실행입니다. `ExecutionMode='BATCH'`는
  실행 전에 거부됩니다.
- `SystemUnderTestMode`는 실행 전체 옵션이며 Excel 행별 혼합은 지원하지 않습니다.

각 CUT은 다음 순서로 처리됩니다.

```text
내부 Harness 준비
→ Initial 독립 SLX 내보내기
→ 실행 전용 Test Case의 Model SUT 연결
→ Harness 범위 CVF와 선택적 CUT 정책 CVF 적용
→ Initial 실행·보고서·CVF 복원
→ APPLY 기대값 갱신
→ Final SLX·CVF 재생성 및 재실행
→ 모델·Harness·MATLAB path 복원
```

`harness-scope.cvf`는 CUT을 제외한 독립 모델의 최상위 Harness 구성요소를
제외합니다. `target-policy.cvf`는 Excel의 `CoverageFilterMode`가 `OFF`가 아닐
때만 생성하며, CUT 자체가 아니라 CUT의 직계 자식 Subsystem에 정책을 적용합니다.
원본 Test File의 수동 CVF는 실행용 Test File에 복사하지만, 툴킷이 과거에 만든
자동 CVF는 승계하지 않습니다.

`SUMMARY`는 기본 보고서이며 `FULL`은 공식 PDF와 상세 Coverage HTML을 추가합니다.
실패한 CUT이 있어도 CVF 복원이 확인되면 다음 CUT을 계속 처리합니다. 복원 실패,
모델 unload 실패 또는 MATLAB path 복원 실패는 설정 누출 위험 때문에 즉시 전체
실행을 중단합니다.

실행 결과는 기존 BATCH/PER_CUT 결과와 분리됩니다.

```text
result/standalone_runs/{run-id}/
├── TestSummary.xlsx
├── manifest.json
├── test_manager/StandaloneHarnessTests.mldatx
├── logs/execution.log
└── targets/{No}_{CUTName}_{hash}/
    ├── target-manifest.json
    ├── inputs/
    ├── initial/
    │   ├── model/{standalone-model}.slx
    │   ├── filters/
    │   ├── raw/InitialResults.mldatx
    │   └── coverage/
    └── final/                  # 기대값 갱신 후 재실행한 경우
```

최신 실행은 `result/standalone_latest.json`이 가리킵니다. 실행이 끝나면 다음
자가 점검을 수행합니다.

```matlab
[code, details] = st_check_standalone_run();
disp(code)
disp(details)
```

| 비트 | 확인 항목 |
| --- | --- |
| S1 | latest pointer, manifest, Excel과 실행용 Test File 일치 |
| S2 | CUT별 Initial/Final 모델과 SHA-256 일치 |
| S3 | Harness CVF가 CUT을 제외한 최상위 요소와 selector 정책까지 일치 |
| S4 | CUT 정책 CVF가 `OFF`이거나 직계 자식 Subsystem 정책과 일치 |
| S5 | 기대값 갱신, Final 재내보내기와 재실행 연결 일치 |
| S6 | 실행 PASS, CVF 복원, 원본 상태와 산출물 무결성 통과 |

`STANDALONE-CHECK-v1 CODE=111111`만 여섯 항목 전체 통과입니다. 0이 있으면
출력 한 줄, `details` 표, 해당 실행의 `manifest.json`, 실패 CUT의
`target-manifest.json`과 `logs/execution.log`를 함께 전달하십시오.

## 6. 수동 증거 만들기

### 6.1 작업 폴더 준비

저장소 밖 또는 커밋하지 않을 로컬 폴더에 다음처럼 준비합니다.

```text
verification-evidence/
├── manual-evidence.json
└── evidence/
    ├── subsystem-indent.png
    ├── duplicate-cut.png
    ├── report.png
    ├── excel-application.png
    ├── model-selection.png
    └── cut-highlight.png
```

예시 파일을 복사합니다.

```matlab
copyfile( ...
    fullfile(st_project_root(), 'examples', ...
    'manual-evidence.example.json'), ...
    'manual-evidence.json');
```

### 6.2 현재 fingerprint 생성

모델, Test File 또는 Excel이 변경될 때마다 fingerprint를 다시 생성해야 합니다.

```matlab
cfg = st_require_runtime_target();
fingerprint = st_verification_target_fingerprint(cfg)
```

출력된 문자열을 JSON의 모든 `TargetFingerprint`에 입력합니다.

### 6.3 필수 수동 CheckId

| CheckId | 확인할 내용 | 권장 증거 |
| --- | --- | --- |
| `MANUAL.SUBSYSTEM_EXCEL_INDENT` | Subsystem 계층이 Excel native indentation으로 표시됨 | Excel screenshot |
| `MANUAL.DUPLICATE_CUT_SELECTION` | 중복 CUT 후보 순위와 선택 결과가 올바름 | 선택 대화상자 screenshot |
| `MANUAL.REPORT_VISUAL` | PDF, HTML, Excel이 읽을 수 있는 형태로 생성됨 | 대표 보고서 screenshot |
| `MANUAL.EXCEL_APPLICATION` | 실제 Excel application에서 workbook과 시트를 열 수 있음 | Excel screenshot 또는 진단 log |
| `MANUAL.MODEL_SELECTION` | 모델 선택 대화상자와 선택 결과가 올바름 | 선택 전후 screenshot |
| `MANUAL.CUT_HIGHLIGHT` | 선택한 CUT가 실제 모델에서 highlight됨 | Simulink screenshot |

각 JSON 항목에는 다음 필드가 모두 필요합니다.

```json
{
  "CheckId": "MANUAL.REPORT_VISUAL",
  "Status": "PASS",
  "VerifiedBy": "reviewer-id",
  "VerifiedAt": "2026-08-30T15:00:00+09:00",
  "TargetFingerprint": "현재 fingerprint",
  "Notes": "PDF, HTML, Excel 화면 확인",
  "EvidencePaths": ["evidence/report.png"]
}
```

`EvidencePaths`의 상대 경로는 JSON 파일이 있는 폴더를 기준으로 해석합니다.
검증에 사용된 JSON과 증거 파일은 해당 실행의 `evidence/`로 복사됩니다.

다음 경우에는 증거가 `BLOCKED`입니다.

- 항목 또는 필수 필드가 없음
- `VerifiedBy` 또는 `VerifiedAt`이 유효하지 않음
- screenshot/log 파일이 없음
- fingerprint가 현재 모델·Test File·Excel과 다름

## 7. 실행 옵션 선택법

```matlab
summary = st_verify_all( ...
    'Profile', 'QUICK', ...
    'Target', 'CURRENT', ...
    'ManualEvidence', '', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', true);
```

| 옵션 | 기본값 | 선택 기준 |
| --- | --- | --- |
| `Profile` | `QUICK` | 실행 깊이 선택 |
| `Target` | `CURRENT` | 실제 모델, fixture 또는 둘 다 선택 |
| `ManualEvidence` | 빈 값 | `CERTIFY + CURRENT/BOTH`에서 JSON 전달 |
| `KeepWorkspace` | `ON_FAILURE` | 일반적으로 기본값 유지 |
| `FailOnNonPass` | `true` | 탐색 중에는 `false`, 자동화와 최종 판정에는 `true` |

`KeepWorkspace` 값의 의미는 다음과 같습니다.

| 값 | 동작 |
| --- | --- |
| `ALWAYS` | 성공 여부와 관계없이 격리 workspace 보존 |
| `ON_FAILURE` | `FAIL` 또는 `BLOCKED`일 때만 보존 |
| `NEVER` | 결과 writer가 끝나면 workspace 삭제 |

문제 분석 중에는 `ON_FAILURE` 또는 `ALWAYS`를 사용하십시오. `NEVER`를 사용하면
실패한 snapshot과 fixture를 사후 검사할 수 없습니다.

## 8. 결과 읽는 순서

모든 결과는 실행별로 보관됩니다.

```text
result/verification/
├── latest.json
└── runs/{timestamp}_{run-id}/
    ├── VerificationSummary.xlsx
    ├── verification.json
    ├── junit.xml
    ├── environment.json
    ├── manifest.json
    ├── logs/
    ├── evidence/
    └── workspace/
```

### 8.1 Excel

| 시트 | 먼저 확인할 내용 |
| --- | --- |
| `Overview` | 전체 상태와 PASS/FAIL/BLOCKED/WARN 개수 |
| `Features` | 기능 단위 상태와 연결된 검사 수 |
| `Checks` | 실제 원인, 증거 경로와 실행 시간 |
| `Environment` | 제품 설치, 버전과 라이선스 존재 여부 |
| `ManualEvidence` | reviewer, fingerprint와 증거 파일 |
| `Artifacts` | 생성된 결과 경로와 checksum |

권장 판독 순서는 다음과 같습니다.

1. `Overview.Status` 확인
2. `Checks.Required=true`이면서 `FAIL` 또는 `BLOCKED`인 행 확인
3. `Message`와 `EvidencePath` 확인
4. `Environment`와 `Artifacts`에서 선행 원인 확인
5. `workspace` 또는 `logs`로 상세 원인 추적

### 8.2 JSON과 JUnit

- `verification.json`: 자동 처리와 상세 분석용 전체 검사 결과
- `environment.json`: MATLAB 릴리스와 제품 상태
- `manifest.json`: 실행 ID, 전체 상태와 결과 파일 inventory
- `junit.xml`: CI 또는 테스트 결과 수집기용 정규화 결과
- `logs/matlab-unit-junit.xml`: MATLAB 단위 테스트 공식 JUnit 결과

JUnit에서는 `FAIL`만 failure입니다. `BLOCKED`와 `SKIP`은 skipped이며 `WARN`은
테스트를 실패시키지 않습니다.

### 8.3 최신 결과 찾기

```matlab
latest = jsondecode(fileread( ...
    fullfile(st_project_root(), 'result', 'verification', 'latest.json')));
disp(latest.Status)
disp(latest.RunDirectory)
```

## 9. 상태별 대응 방법

| 상태 | 의미 | 권장 조치 |
| --- | --- | --- |
| `PASS` | 필수 검사가 모두 통과 | manifest와 요약 보관 |
| `PASS_WITH_WARNINGS` | 비차단 WARN 또는 선택 항목 문제 | WARN 검토 후 사용 가능 여부 판단 |
| `BLOCKED` | 검사를 완료할 선행 조건 부족 | 제품·라이선스·파일·증거를 보완하고 재실행 |
| `FAIL` | 기능 또는 무결성 오류 | workspace와 EvidencePath를 확인하고 수정 후 재실행 |
| `SKIP` | 선택한 대상에 해당하지 않음 | 일반적으로 조치 불필요 |

전체 상태는 다음 우선순위를 사용합니다.

```text
FAIL > BLOCKED > PASS_WITH_WARNINGS > PASS
```

`FailOnNonPass=true`에서 MATLAB 오류가 표시되더라도 결과 생성 실패를 의미하지
않습니다. 먼저 오류 메시지에 표시된 `Result directory`를 여십시오.

## 10. 자주 발생하는 문제

### `runtime_target.mat`이 없거나 잘못된 경우

증상:

- `RUNTIME_TARGET` 또는 `CURRENT_STRUCTURE`가 `BLOCKED`

조치:

```matlab
st_select_target_model
cfg = st_require_runtime_target();
```

### Test File이 없는 경우

증상:

- `CURRENT_TEST_FILE`이 `BLOCKED`

조치:

1. `TestManagement.xlsx`의 대상과 경로를 확인합니다.
2. 기존 Harness가 있으면 `st_run_after_harness`를 실행합니다.
3. Harness부터 준비해야 하면 `st_run_from_harness`를 실행합니다.
4. Test File 생성 후 QUICK을 다시 실행합니다.

### 제품 또는 라이선스가 BLOCKED인 경우

`Environment` 시트에서 `Installed`와 `Licensed`를 구분합니다.

- `Installed=false`: 해당 MATLAB 제품 설치 필요
- `Licensed=false`: 라이선스 구성 확인 필요
- 두 값이 true인데 실행 중 checkout 실패: 라이선스 서버 또는 동시 사용 상태 확인

### 수동 증거가 BLOCKED인 경우

다음을 순서대로 확인합니다.

1. JSON에 6개 `CheckId`가 모두 있는가
2. `Status`가 `PASS` 또는 `FAIL`인가
3. `VerifiedBy`, `VerifiedAt`이 비어 있지 않은가
4. 모든 `EvidencePaths` 파일이 실제로 존재하는가
5. 현재 fingerprint와 JSON 값이 같은가

모델, Test File 또는 Excel을 저장한 뒤에는 기존 증거가 stale이 될 수 있습니다.

### `SOURCE_UNCHANGED`가 FAIL인 경우

검증을 반복하기 전에 즉시 원본 변경 여부를 확인하십시오. 자동으로 원본을
되돌리지 마십시오. `Checks.EvidencePath`와 source inventory를 이용해 변경된
모델, Test File, Excel, dependency 또는 입력을 식별합니다.

### Coverage가 WARN인 경우

실제 업무 모델은 coverage 미달을 실패로 강제하지 않습니다. 누락된 분기와
미실행 블록을 보고서에서 검토하고 테스트 추가 여부를 결정합니다. 자동 fixture의
분모가 있는 Decision·Execution이 100% 미만이면 WARN이 아니라 `FAIL`입니다.

### 실행이 오래 걸리는 경우

- Harness 생성과 SLDV `GENERATE`는 정상적으로 수 분 이상 걸릴 수 있습니다.
- `logs`와 MATLAB Command Window의 현재 단계·대상 번호를 확인합니다.
- 실행을 중단하기 전에 동일 단계의 경과 시간을 기존 실행과 비교합니다.
- 일상 점검은 `QUICK`을 사용하고 `CERTIFY`를 매번 실행하지 않습니다.

### Excel/PDF/HTML 일부만 생성된 경우

`Artifacts` 시트와 `manifest.json`에서 실패한 산출물의 메시지를 확인합니다.
부분 산출물이 존재하더라도 전체 상태가 PASS라는 의미는 아닙니다.

### 독립 모델 실행이 시작 전에 거부되는 경우

| 오류 조건 | 조치 |
| --- | --- |
| `BATCH` 지정 | `ExecutionMode='AUTO'` 또는 `PER_CUT` 사용 |
| `CoverageFilterApplicationMode=PERSIST` | `st_config`에서 `RUNTIME`으로 변경 |
| 독립 모델에서 CUT을 하나로 식별하지 못함 | 원본 CUT 이름과 export된 최상위 Subsystem 이름 확인 |
| model shadowing | `which <모델명> -all`로 중복 경로 제거 |
| 저장되지 않은 원본 모델 또는 Harness | 저장한 뒤 다시 실행 |

CVF 복원이나 모델/path 정리에 실패한 경우에는 다음 CUT을 임의로 실행하지
마십시오. 오류에 기록된 실행 폴더와 Test Manager 필터 상태를 먼저 확인합니다.

## 11. 운영 권장 주기

| 시점 | 실행 |
| --- | --- |
| 작업 시작 또는 설정 변경 후 | `QUICK + CURRENT` |
| Test File, 모델, 입력 또는 expected-value 로직 변경 후 | `RUNTIME + CURRENT` |
| 검증 framework 자체 변경 후 | `CERTIFY + FIXTURE` |
| MATLAB 릴리스·제품·라이선스 환경 변경 후 | `CERTIFY + BOTH` |
| 배포 또는 릴리스 후보 확정 전 | 수동 증거를 포함한 `CERTIFY + BOTH` |

장시간 검증 결과는 모두 보관하되 `result/verification/latest.json`은 가장 최근
실행을 가리키는 pointer일 뿐 공식 승인 여부를 대신하지 않습니다. 공식 인증에
사용한 `RunId`, MATLAB 릴리스, manifest와 reviewer를 별도로 기록하십시오.

## 12. 최종 인증 체크리스트

- [ ] MATLAB 릴리스가 R2025b이다.
- [ ] 필요한 제품과 라이선스가 모두 준비됐다.
- [ ] 모델, dependency model, Test File과 Excel을 저장했다.
- [ ] `QUICK + CURRENT`에 required `FAIL/BLOCKED`가 없다.
- [ ] `CERTIFY + FIXTURE`가 PASS다.
- [ ] 현재 fingerprint로 수동 증거 6개를 작성했다.
- [ ] `CERTIFY + BOTH`를 실행했다.
- [ ] fixture Decision·Execution 100%를 확인했다.
- [ ] 실제 모델 최종 Test Case 결과를 확인했다.
- [ ] 최초·최종 PDF, HTML, Excel, MLDATX를 확인했다.
- [ ] source checksum 불변을 확인했다.
- [ ] 내보내기 bundle 두 번 재실행과 template 불변을 확인했다.
- [ ] `EXPORTED_MODEL`의 Model SUT, 이중 CVF와 Final 재내보내기를 확인했다.
- [ ] `STANDALONE-CHECK-v1 CODE=111111`을 보관했다.
- [ ] 전체 상태가 `PASS`인지 확인했다.
- [ ] `RunId`, manifest, reviewer와 검증일을 보관했다.

## 13. 빠른 명령 모음

```matlab
% 프로젝트 설정
st_setup
st_select_target_model

% 일상 상태 점검
quick = st_verify_all('FailOnNonPass', false);

% 실제 업무 모델 격리 실행
runtime = st_verify_all( ...
    'Profile', 'RUNTIME', 'Target', 'CURRENT', ...
    'FailOnNonPass', false);

% 업무 데이터 없이 framework 전체 인증
fixture = st_verify_all( ...
    'Profile', 'CERTIFY', 'Target', 'FIXTURE', ...
    'FailOnNonPass', false);

% 독립 Harness SLX를 Model SUT로 CUT별 실행
[results, updates, workflow, standalone] = st_run_from_harness( ...
    'SystemUnderTestMode', 'EXPORTED_MODEL', ...
    'ExecutionMode', 'AUTO', ...
    'ReportMode', 'SUMMARY', ...
    'FailOnNonPass', false);

% 최신 독립 모델 실행의 6비트 점검
[standaloneCode, standaloneDetails] = st_check_standalone_run();
disp(standaloneCode)
disp(standaloneDetails)

% 공식 통합 인증
certification = st_verify_all( ...
    'Profile', 'CERTIFY', 'Target', 'BOTH', ...
    'ManualEvidence', 'manual-evidence.json', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', true);
```
