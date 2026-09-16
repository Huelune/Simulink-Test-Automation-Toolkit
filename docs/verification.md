# 종합 검증

`st_verify_all`은 **이 도구 자체가 제대로 동작하는지**를 확인하는 명령입니다.
모델을 테스트하는 일반 workflow와는 별개입니다.

| 목적 | 명령 |
| --- | --- |
| 모델을 테스트한다 | `st_run_from_harness` / `st_run_after_harness` |
| 이 도구와 환경을 검증한다 | `st_verify_all` |

> 현재 저장소에는 검증 코드와 자동 테스트가 구현되어 있지만, MATLAB R2025b에서의
> 최초 `CERTIFY + BOTH` 결과는 아직 확보되지 않았습니다. 실행하지 않은 검증을
> 통과로 기록하지 않습니다.

## 1. 무엇을 검사하는가

- MATLAB 제품, 주요 API, 라이선스 존재 여부
- `runtime_target.mat`, 관리 Excel, 모델, Test File
- CUT, Harness, Signal Editor, Test Assessment, Test Case, Iteration
- SLDV `OFF` / `FILE` / `GENERATE` 준비
- 기대값 `APPLY` 갱신과 명시적 `OFF` 보존
- 대상별 증분 캐시, 손상 상태 복구, 부분 실패 처리
- Decision 및 Block Execution coverage
- Excel, PDF, HTML, MLDATX 통합 보고서
- 재실행 가능한 내보내기 bundle과 template 불변성
- 대화상자, CUT highlight, 보고서 화면의 **사람이 확인한 증거**

## 2. Profile과 Target 고르기

### Profile — 얼마나 깊이 볼 것인가

| Profile | 하는 일 | 시뮬레이션 | 원본 변경 | 예상 시간 |
| --- | --- | --- | --- | --- |
| `QUICK` | 단위 테스트, 제품·라이선스 존재, 설정, 저장 상태, Test File/Harness/Scenario, 최신 산출물 점검 | 안 함 | 저장하지 않음 | 수십 초~수 분 |
| `RUNTIME` | QUICK + 실제 모델의 격리 사본에서 기존 Test File 실행과 보고서 생성 | 함 | 원본 대신 snapshot 실행 | 수 분~수 시간 |
| `CERTIFY` | 자동 fixture 전체 workflow, SLDV GENERATE/FILE, 캐시, 복구, 부분 실패, 보고서, 내보내기와 2회 재실행 | 함 | fixture와 snapshot만 | 수십 분~수 시간 |

시간은 모델 크기, Harness 수, SLDV 탐색 공간, 라이선스 서버 상태에 따라 크게
달라지는 운영 예상치입니다.

### Target — 무엇을 대상으로 볼 것인가

| Target | 의미 |
| --- | --- |
| `CURRENT` | `runtime_target.mat`이 가리키는 실제 업무 모델 |
| `FIXTURE` | 검증 실행이 임시 workspace에 자동 생성하는 익명 모델 |
| `BOTH` | 둘 다 |

바이너리 fixture는 Git에 저장하지 않고 실행마다 `workspace/fixture`에서 MATLAB
builder가 만듭니다. 실제 업무 모델은 원본에서 직접 실행하지 않고, 내보내기 수집기를
재사용한 snapshot과 새 실행 workspace에서만 변경합니다.

### 권장 조합

| 상황 | 조합 |
| --- | --- |
| 평상시 상태 점검 | `QUICK + CURRENT` |
| 실제 테스트 실행 확인 | `RUNTIME + CURRENT` |
| 업무 데이터 없이 프레임워크 전체 확인 | `CERTIFY + FIXTURE` |
| 릴리스 또는 최초 공식 인증 | `CERTIFY + BOTH` (수동 증거 포함) |

## 3. 실행 전 준비

### 3.1 필요한 제품

| 조합 | MATLAB | Simulink | Simulink Test | Coverage | SLDV |
| --- | --- | --- | --- | --- | --- |
| `QUICK + CURRENT` | 필수 | 필수 | 필수 | 필수 | 사용 대상에 따라 |
| `RUNTIME + CURRENT` | 필수 | 필수 | 필수 | 필수 | 기존 입력만 쓰면 불필요 |
| `CERTIFY + FIXTURE` | 필수 | 필수 | 필수 | 필수 | 필수 |

제품이 설치되어 있어도 실행 시 라이선스 checkout에 실패할 수 있습니다. 이 경우
기능 실패가 아니라 `BLOCKED`로 기록합니다. `license('test', feature)` 결과는 라이선스
존재 여부로만 씁니다.

### 3.2 필요한 파일

```text
st_setup.m
runtime_target.mat
TestManagement.xlsx
{선택한 모델}.slx 또는 .mdl
{TopModel}.mldatx
```

`CERTIFY + FIXTURE`는 업무용 SLX/XLSX/MAT을 요구하지 않습니다. 필요한 바이너리를
실행 workspace에 자동 생성합니다.

### 3.3 저장 상태

`RUNTIME`과 `CERTIFY` 전에 Top Model과 로드된 dependency 모델, 대상 Test File,
`TestManagement.xlsx`, 현재 쓰는 Signal Editor·SLDV 입력을 모두 저장하십시오.

검증은 원본을 수정하지 않지만, 저장되지 않은 상태를 snapshot의 기준으로 삼지
않습니다. **저장하지 않은 모델이 있으면 실행을 중단하는 것이 정상입니다.**

### 3.4 선택 상태 확인

```matlab
st_setup
st_select_target_model
cfg = st_require_runtime_target();
disp(cfg.TopModel); disp(cfg.ModelFile); disp(cfg.TestFile); disp(cfg.ManagementExcel)
```

## 4. 실행 순서

한 번에 가장 긴 인증부터 실행하지 마십시오. 각 단계의 결과와 시간을 확인한 뒤
다음으로 넘어갑니다.

### 4.1 1단계: QUICK

처음에는 오류를 바로 던지지 않고 결과를 전부 보는 방식을 권합니다.

```matlab
summary = st_verify_all( ...
    'Profile','QUICK', 'Target','CURRENT', ...
    'KeepWorkspace','ON_FAILURE', 'FailOnNonPass', false);

disp(summary.Status)
disp(summary.RunDirectory)
open(summary.Summary)
```

`Overview`에서 전체 상태를 보고 `Checks`에서 `FAIL`/`BLOCKED` 행을 거릅니다. 원인을
정리한 뒤 같은 명령을 다시 실행하십시오.

차단 원인이 모두 정리되면 엄격 모드를 쓸 수 있습니다.

```matlab
summary = st_verify_all('FailOnNonPass', true);
```

### 4.2 2단계: 자동 fixture 전체 인증

업무 모델과 무관하게 framework 자체를 먼저 인증합니다.

```matlab
summary = st_verify_all( ...
    'Profile','CERTIFY', 'Target','FIXTURE', ...
    'KeepWorkspace','ON_FAILURE', 'FailOnNonPass', false);
```

이 실행은 다음을 실제로 수행하므로 오래 걸립니다.

1. scalar, numeric array, nested Bus, Bus array, no-Inport 모델 생성
2. 분기와 파라미터를 가진 SLDV 대상 생성
3. 전체 `FORCE` workflow와 테스트 실행
4. 최초 실패 → `APPLY` 갱신 → 최종 PASS 확인
5. 명시적 `OFF` 대상이 변경되지 않았는지 확인
6. SLDV `GENERATE` 결과를 `FILE` 모드에서 재사용
7. 두 번째 `AUTO`에서 준비 캐시 재사용과 테스트 재실행 확인
8. 손상된 상태 복구와 준비 실패 시 테스트 미실행 확인
9. 보고서, coverage, 내보내기와 두 번의 재실행 확인

fixture에는 `SUBSYSTEM+JUSTIFY`, `ALL_CONTENT+EXCLUDE`, `OFF` 대상이 들어 있습니다.
활성 필터가 있으므로 `AUTO`는 `PER_CUT`을 선택하고 결과는 `result/per_cut_runs`에
저장됩니다.

> **fixture에서 분모가 있는 Decision·Execution coverage는 100%여야 합니다.** 미달이면
> `WARN`이 아니라 `FAIL`입니다.

### 4.3 3단계: 실제 업무 Test File 실행

```matlab
summary = st_verify_all( ...
    'Profile','RUNTIME', 'Target','CURRENT', ...
    'KeepWorkspace','ON_FAILURE', 'FailOnNonPass', false);
```

검증기는 내보내기 수집기로 모델, dependency, Test File, Excel, Signal Editor와 SLDV
입력을 snapshot에 복사합니다. 테스트와 기대값 갱신은 snapshot의 새 workspace에서만
수행하고, 원본 파일은 실행 전후 SHA-256을 비교합니다.

실제 업무 모델의 coverage는 보고 전용입니다. 100% 미만은 `WARN`일 수 있지만
coverage 미달만으로 테스트 실패가 되지 않습니다.

### 4.4 4단계: 최종 통합 인증

수동 증거가 필요합니다. 6개의 screenshot 또는 대응 log를 먼저 준비하십시오(6장).

```matlab
summary = st_verify_all( ...
    'Profile','CERTIFY', 'Target','BOTH', ...
    'ManualEvidence','manual-evidence.json', ...
    'KeepWorkspace','ON_FAILURE', 'FailOnNonPass', false);
```

결과가 `PASS`이면 `FailOnNonPass=true`로 한 번 더 실행할 필요는 없습니다. 이 옵션은
오류를 던질지만 바꾸며 판정과 결과 내용은 바꾸지 않습니다.

## 5. 옵션

```matlab
summary = st_verify_all( ...
    'Profile','QUICK', 'Target','CURRENT', 'ManualEvidence','', ...
    'KeepWorkspace','ON_FAILURE', 'FailOnNonPass', true);
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `Profile` | `'QUICK'` | 검사 깊이 |
| `Target` | `'CURRENT'` | 실제 모델, fixture 또는 둘 다 |
| `ManualEvidence` | `''` | `CERTIFY + CURRENT/BOTH`에서 수동 증거 JSON 경로 |
| `KeepWorkspace` | `'ON_FAILURE'` | 격리 workspace 보존 정책 |
| `FailOnNonPass` | `true` | `FAIL`/`BLOCKED`에서 MATLAB 오류를 낼지 |

`KeepWorkspace` 값의 의미:

| 값 | 동작 |
| --- | --- |
| `'ALWAYS'` | 성공 여부와 관계없이 보존 |
| `'ON_FAILURE'` | `FAIL` 또는 `BLOCKED`일 때만 보존 |
| `'NEVER'` | 결과 writer가 끝나면 삭제 |

문제를 분석하는 중에는 `'ON_FAILURE'` 또는 `'ALWAYS'`를 쓰십시오. `'NEVER'`는 실패한
snapshot과 fixture를 사후 검사할 수 없게 만듭니다. 실행별 결과와 `latest.json`은 어느
값에서도 삭제하지 않습니다.

## 6. 수동 증거 만들기

자동으로 판정할 수 없는 항목은 사람이 확인하고 그 증거를 JSON으로 제출합니다.

### 6.1 폴더 준비

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
copyfile(fullfile(st_project_root(),'examples','manual-evidence.example.json'), ...
    'manual-evidence.json');
```

### 6.2 현재 fingerprint 만들기

모델, Test File 또는 Excel이 바뀔 때마다 다시 만들어야 합니다.

```matlab
cfg = st_require_runtime_target();
fingerprint = st_verification_target_fingerprint(cfg)
```

출력된 문자열을 JSON의 모든 `TargetFingerprint`에 넣습니다.

### 6.3 필수 CheckId 6개

| CheckId | 확인할 내용 | 권장 증거 |
| --- | --- | --- |
| `MANUAL.SUBSYSTEM_EXCEL_INDENT` | Subsystem 계층이 Excel 들여쓰기로 표시됨 | Excel screenshot |
| `MANUAL.DUPLICATE_CUT_SELECTION` | 중복 CUT 후보 순위와 선택 결과가 올바름 | 선택 대화상자 screenshot |
| `MANUAL.REPORT_VISUAL` | PDF, HTML, Excel이 읽을 수 있는 형태로 생성됨 | 대표 보고서 screenshot |
| `MANUAL.EXCEL_APPLICATION` | 실제 Excel에서 workbook과 시트를 열 수 있음 | Excel screenshot 또는 진단 log |
| `MANUAL.MODEL_SELECTION` | 모델 선택 대화상자와 선택 결과가 올바름 | 선택 전후 screenshot |
| `MANUAL.CUT_HIGHLIGHT` | 선택한 CUT이 실제 모델에서 highlight됨 | Simulink screenshot |

각 항목에 필요한 필드:

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

`EvidencePaths`의 상대 경로는 JSON 파일이 있는 폴더 기준입니다. 검증에 쓴 JSON과
증거 파일은 그 실행의 `evidence/` 폴더로 복사됩니다.

다음 경우 증거는 `BLOCKED`입니다.

- 항목 또는 필수 필드가 없음
- `VerifiedBy` 또는 `VerifiedAt`이 유효하지 않음
- screenshot/log 파일이 없음
- fingerprint가 현재 모델·Test File·Excel과 다름

## 7. 결과 읽기

### 7.1 결과 구조

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
    │   └── matlab-unit-junit.xml
    ├── evidence/
    └── workspace/
```

### 7.2 Excel 읽는 순서

| 시트 | 먼저 볼 것 |
| --- | --- |
| `Overview` | 전체 상태와 PASS/FAIL/BLOCKED/WARN 개수 |
| `Features` | 기능 단위 상태와 연결된 검사 수 |
| `Checks` | 실제 원인, 증거 경로, 실행 시간 |
| `Environment` | 제품 설치, 버전, 라이선스 존재 여부 |
| `ManualEvidence` | reviewer, fingerprint, 증거 파일 |
| `Artifacts` | 생성된 결과 경로와 checksum |

1. `Overview.Status` 확인
2. `Checks.Required=true`이면서 `FAIL` 또는 `BLOCKED`인 행 확인
3. 그 행의 `Message`와 `EvidencePath` 확인
4. `Environment`와 `Artifacts`에서 선행 원인 확인
5. `workspace` 또는 `logs`로 상세 추적

각 검사 행에는 `CheckId`, `FeatureId`, `Profile`, `Target`, `Required`, `Status`,
`Message`, `EvidencePath`, `DurationSec`, `StartedAt`, `CompletedAt`이 기록됩니다.

### 7.3 JSON과 JUnit

| 파일 | 용도 |
| --- | --- |
| `verification.json` | 자동 처리와 상세 분석용 전체 검사 결과 |
| `environment.json` | MATLAB 릴리스와 제품 상태 |
| `manifest.json` | 실행 ID, 전체 상태, 결과 파일 inventory |
| `junit.xml` | CI 또는 테스트 결과 수집기용 정규화 결과 |
| `logs/matlab-unit-junit.xml` | MATLAB 단위 테스트 공식 JUnit 결과 |

JUnit에서는 `FAIL`만 failure입니다. `BLOCKED`와 `SKIP`은 skipped이고 `WARN`은
테스트를 실패시키지 않습니다.

### 7.4 최신 결과 찾기

```matlab
latest = jsondecode(fileread( ...
    fullfile(st_project_root(),'result','verification','latest.json')));
disp(latest.Status); disp(latest.RunDirectory)
```

## 8. 상태별 대응

| 상태 | 의미 | 조치 |
| --- | --- | --- |
| `PASS` | 필수 검사가 모두 통과 | manifest와 요약 보관 |
| `PASS_WITH_WARNINGS` | 비차단 WARN 또는 선택 항목 문제 | WARN 검토 후 사용 가능 여부 판단 |
| `BLOCKED` | 검사를 완료할 선행 조건 부족 | 제품·라이선스·파일·증거를 보완하고 재실행 |
| `FAIL` | 기능 또는 무결성 오류 | workspace와 `EvidencePath`를 확인하고 수정 후 재실행 |
| `SKIP` | 선택한 대상에 해당하지 않음 | 보통 조치 불필요 |
| `WARN` | Coverage 미달 등 비차단 관찰 사항 | 검토 |

전체 상태 우선순위:

```text
FAIL > BLOCKED > PASS_WITH_WARNINGS > PASS
```

`FailOnNonPass=true`에서 MATLAB 오류가 표시되어도 결과 생성이 실패했다는 뜻은
아닙니다. 먼저 오류 메시지의 `Result directory`를 여십시오.

자주 나오는 `BLOCKED`/`FAIL`의 대처는
[문제 해결 8장](troubleshooting.md#8-검증st_verify_all-오류)에 있습니다.

## 9. 운영 권장 주기

| 시점 | 실행 |
| --- | --- |
| 작업 시작 또는 설정 변경 후 | `QUICK + CURRENT` |
| Test File·모델·입력·기대값 로직 변경 후 | `RUNTIME + CURRENT` |
| 검증 framework 자체 변경 후 | `CERTIFY + FIXTURE` |
| MATLAB 릴리스·제품·라이선스 환경 변경 후 | `CERTIFY + BOTH` |
| 배포 또는 릴리스 후보 확정 전 | 수동 증거를 포함한 `CERTIFY + BOTH` |

검증 결과는 모두 보관하되, `result/verification/latest.json`은 가장 최근 실행을
가리키는 pointer일 뿐 공식 승인을 대신하지 않습니다. 공식 인증에 쓴 `RunId`, MATLAB
릴리스, manifest, reviewer를 따로 기록하십시오.

## 10. R2025b 최초 인증 절차

1. 원본 모델, Test File, Excel을 저장하고 `st_setup`을 실행합니다.
2. `QUICK + CURRENT`를 `FailOnNonPass=false`로 실행해 선행 `BLOCKED`를 정리합니다.
3. 수동 증거 JSON과 screenshot/log를 현재 fingerprint로 준비합니다.
4. `CERTIFY + BOTH`, `KeepWorkspace='ON_FAILURE'`를 실행합니다.
5. `VerificationSummary.xlsx`의 모든 required 검사와 `junit.xml`을 확인합니다.
6. fixture Decision·Execution 100%, 최초/최종 결과 연결, FILE/GENERATE, 두 번째 AUTO
   캐시 재사용, 손상 상태 복구, 부분 실패 시 테스트 미실행, 내보낸 template 불변과
   두 번의 재실행을 확인합니다.
7. fixture의 `SUBSYSTEM+JUSTIFY`, `ALL_CONTENT+EXCLUDE`, `OFF` CUT이 Excel 순서대로
   독립 실행되고, 각 target manifest의 CVF 적용·복원 상태와 SHA-256, 초기·최종
   ResultSet 연결이 일치하는지 확인합니다.
8. 실제 모델 source inventory가 실행 전후 동일한지 확인합니다.
9. `PASS` 실행의 manifest와 R2025b 버전을 최초 인증 근거로 보관합니다.

CVF 복원 실패 시 이후 CUT이 실행되지 않는지도 별도 실패 fixture로 확인해야 합니다.

### 최종 인증 체크리스트

- [ ] MATLAB 릴리스가 R2025b이다
- [ ] 필요한 제품과 라이선스가 모두 준비됐다
- [ ] 모델, dependency 모델, Test File, Excel을 저장했다
- [ ] `QUICK + CURRENT`에 required `FAIL`/`BLOCKED`가 없다
- [ ] `CERTIFY + FIXTURE`가 PASS다
- [ ] 현재 fingerprint로 수동 증거 6개를 작성했다
- [ ] `CERTIFY + BOTH`를 실행했다
- [ ] fixture Decision·Execution 100%를 확인했다
- [ ] 실제 모델 최종 Test Case 결과를 확인했다
- [ ] 최초·최종 PDF, HTML, Excel, MLDATX를 확인했다
- [ ] source checksum 불변을 확인했다
- [ ] 내보내기 bundle 두 번 재실행과 template 불변을 확인했다
- [ ] 전체 상태가 `PASS`다
- [ ] `RunId`, manifest, reviewer, 검증일을 보관했다

> 현재 개발 환경에서 R2025b runtime 결과를 만들지 않았다면, 코드와 문서가 존재해도
> 인증 완료로 기록하지 않습니다.

## 11. 현장 실행용 빠른 점검

이미 끝난 `PER_CUT` 실행을 새 검증 workspace 없이 읽기 전용으로 빠르게 볼 때는
다음을 씁니다.

```matlab
summary = st_check_actual_system();
```

환경 6비트, 실행 6비트, CVF 6비트를 합쳐 18비트로 출력합니다. 비트의 의미는
[실행 명령 사전 10장](execution-commands.md#10-상태-점검)에 있습니다.

이 명령은 `st_verify_all`의 fixture, source checksum, 수동 증거, JUnit 인증을
**대체하지 않습니다.** 현장 오류 분석을 요청할 때 코드 줄과
`summary.Environment`, `summary.Run`, `summary.CVF` 표를 함께 전달하는 용도입니다.

## 12. 빠른 명령 모음

```matlab
% 프로젝트 설정
st_setup
st_select_target_model

% 일상 상태 점검
quick = st_verify_all('FailOnNonPass', false);

% 실제 업무 모델 격리 실행
runtime = st_verify_all('Profile','RUNTIME', 'Target','CURRENT', 'FailOnNonPass', false);

% 업무 데이터 없이 framework 전체 인증
fixture = st_verify_all('Profile','CERTIFY', 'Target','FIXTURE', 'FailOnNonPass', false);

% 공식 통합 인증
certification = st_verify_all( ...
    'Profile','CERTIFY', 'Target','BOTH', ...
    'ManualEvidence','manual-evidence.json', ...
    'KeepWorkspace','ON_FAILURE', 'FailOnNonPass', true);
```
