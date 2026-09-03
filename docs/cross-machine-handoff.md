# 다른 PC에서 이어서 작업하기

이 문서는 현재 기능 구현과 MATLAB R2025b 검증 작업을 여러 PC의 Codex에서
끊기지 않게 이어가기 위한 기준 문서입니다. 채팅 기록보다 이 저장소의 커밋과
이 문서를 우선합니다.

## 1. 기준 브랜치와 현재 상태

| 항목 | 기준 |
| --- | --- |
| 원격 저장소 | `https://github.com/Huelune/Simulink-Test-Automation-Toolkit.git` |
| 기본 브랜치 | `main` |
| 현재 로컬 작업 브랜치 | `feat/standalone-harness-model-execution` |
| 원격 공유 기준 | `origin/feat/per-cut-filtered-execution` / `a48ec9e` |
| 독립 모델 로컬 기준 | `1af915c`, `cc10729` 이후 문서 커밋 |
| 개발 상태 | 독립 모델 기능 구현과 정적 계약 확인 완료, 미push, MATLAB R2025b runtime 미검증 |
| 우선 검증 환경 | MATLAB R2025b, Simulink, Simulink Test, Simulink Coverage, SLDV |

이 브랜치는 아직 `main`에 반영되지 않은 다음 기능을 모두 포함합니다.

- 대상별 증분 실행 체크포인트
- Decision·Execution 통합 보고서
- 재실행 가능한 테스트 번들 내보내기
- QUICK/RUNTIME/CERTIFY 종합 검증 프레임워크
- 자동 생성 검증 fixture와 사용자 매뉴얼
- CUT별 transient CVF 격리 실행과 개별 결과·Coverage 보고서
- 내부 Harness를 실행별 SLX Model SUT로 사용하는 독립 모델 실행과 이중 CVF

`main`을 기준으로 새 작업을 만들면 위 기능이 빠집니다. 현재 원격에서 바로
재개할 수 있는 기준은 `feat/per-cut-filtered-execution`입니다. 독립 모델 기능은
이 문서에 적힌 로컬 브랜치가 원격에 push된 뒤에만 다른 PC에서 재개할 수 있습니다.

## 2. 다른 PC에서 처음 시작하는 절차

```bash
git clone https://github.com/Huelune/Simulink-Test-Automation-Toolkit.git
cd Simulink-Test-Automation-Toolkit
git fetch origin
git switch --track origin/feat/standalone-harness-model-execution
git status --short --branch
git log -1 --oneline
```

이미 저장소가 있다면 다음처럼 동기화합니다.

```bash
git status --short --branch
git fetch origin
git switch feat/standalone-harness-model-execution
git pull --ff-only origin feat/standalone-harness-model-execution
```

위 명령은 독립 모델 브랜치를 원격에 push한 뒤 사용합니다. 그 전에는
`origin/feat/per-cut-filtered-execution`까지만 공유된 상태입니다.

수정 파일이 있으면 전환이나 pull 전에 임의로 버리지 않습니다. 변경의 소유자와
목적을 확인하고 별도 커밋 또는 작업 브랜치로 보존합니다.

## 3. 새 Codex 작업에 전달할 시작 문구

다른 PC에서 새 Codex 작업을 시작할 때 다음 내용을 그대로 전달할 수 있습니다.

```text
이 저장소의 AGENTS.md와 docs/cross-machine-handoff.md를 먼저 모두 읽어줘.
현재 독립 모델 작업 기준은 origin/feat/standalone-harness-model-execution이며
main에는 아직 기능이 병합되지 않았다. 해당 원격 브랜치가 없으면 작업을 시작하지
말고 origin/feat/per-cut-filtered-execution의 a48ec9e까지만 공유됐다고 보고해줘.
README.md, docs/user-manual.md, docs/verification.md,
docs/export-bundle.md, docs/TODO.md를 확인하고 현재 Git 상태와 MATLAB 제품 및
라이선스를 점검해줘. 실제로 실행하지 않은 검증은 통과로 기록하지 말고,
result/verification의 실행별 결과와 최종 커밋을 인수인계 문서에 남겨줘.
```

Codex 계정과 대화 기록이 동기화되더라도 로컬 파일, MATLAB 상태와 실행 결과가
자동으로 전달된다고 가정하지 않습니다. Git 원격 브랜치와 이 문서를 작업의
공통 기준으로 사용합니다.

## 4. R2025b 장비에서 진행할 검증 순서

한 번에 가장 긴 인증부터 실행하지 않습니다. 각 단계의 결과와 시간을 먼저
확인한 뒤 다음 단계로 진행합니다.

### 4.1 저장소와 MATLAB 준비

MATLAB에서 저장소 루트를 Current Folder로 열고 다음을 실행합니다.

```matlab
st_setup
st_select_target_model
```

원본 모델, dependency model, Test File, `TestManagement.xlsx`, Signal Editor와
SLDV 입력을 모두 저장합니다. 실제 업무 파일과 민감한 결과는 Git에 추가하지
않습니다.

### 4.2 QUICK + CURRENT

```matlab
summary = st_verify_all( ...
    'Profile', 'QUICK', ...
    'Target', 'CURRENT', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

`VerificationSummary.xlsx`의 `FAIL`과 `BLOCKED`를 확인하고 선행 환경 문제를
먼저 해결합니다.

### 4.3 RUNTIME + FIXTURE

```matlab
summary = st_verify_all( ...
    'Profile', 'RUNTIME', ...
    'Target', 'FIXTURE', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

전체 인증 전에 fixture 생성, Harness와 기본 실행 경로가 해당 장비에서
동작하는지 확인하는 중간 smoke 단계입니다.

fixture에는 `SUBSYSTEM+JUSTIFY`, `ALL_CONTENT+EXCLUDE`, `OFF` Coverage 필터
대상이 포함됩니다. 활성 필터가 있으므로 `AUTO`는 모든 활성 CUT을 `PER_CUT`으로
실행하고 결과는 `result/per_cut_runs`에 저장합니다.

### 4.4 CERTIFY + FIXTURE

```matlab
summary = st_verify_all( ...
    'Profile', 'CERTIFY', ...
    'Target', 'FIXTURE', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

Decision·Execution 100%, 기대값 APPLY/OFF, SLDV GENERATE/FILE, 캐시 재사용,
상태 복구, 부분 실패, 보고서와 내보내기 2회 재실행을 확인합니다.

### 4.5 RUNTIME + CURRENT

```matlab
summary = st_verify_all( ...
    'Profile', 'RUNTIME', ...
    'Target', 'CURRENT', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

실제 업무 모델은 snapshot에서만 실행하고 원본 inventory checksum이 실행 전후
같은지 확인합니다. 실제 모델 coverage 미달은 현재 정책상 보고용 `WARN`이며
그 자체로 실패가 아닙니다.

### 4.6 CERTIFY + BOTH

현재 fingerprint와 일치하는 수동 증거를 준비한 뒤 최종 인증합니다.

```matlab
summary = st_verify_all( ...
    'Profile', 'CERTIFY', ...
    'Target', 'BOTH', ...
    'ManualEvidence', 'manual-evidence.json', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

최초 결과는 삭제하지 않고 실행 디렉터리, 전체 상태, MATLAB 릴리스, 제품과
라이선스 상태, 단계별 시간, 실패 또는 차단 원인을 기록합니다. 자세한 판정
기준은 [종합 검증 사용자 매뉴얼](user-manual.md)과
[검증 기술 문서](verification.md)를 따릅니다.

## 5. 다음 구현 우선순위

### P1. 인증 재개와 실패 검사만 재실행

Harness와 SLDV처럼 오래 걸리는 단계를 뒤쪽 실패 때문에 다시 만들지 않도록
인증 실행 자체에 체크포인트를 추가합니다. 권장 공개 옵션은 다음과 같습니다.

```matlab
summary = st_verify_all( ...
    'Profile', 'CERTIFY', ...
    'Target', 'FIXTURE', ...
    'ResumeRunId', 'previous-run-id', ...
    'RetryFailedOnly', true);
```

권장 인증 단계는 `FIXTURE_BUILD`, `FORCE_WORKFLOW`, `CACHE_REUSE`,
`SLDV_FILE`, `STATE_RECOVERY`, `PARTIAL_FAILURE`, `EXPORT_RERUN`입니다.
MATLAB 릴리스, Git 커밋, 설정, target과 입력 checksum, fixture builder 지문이
모두 같은 경우에만 PASS 단계의 workspace와 결과를 재사용합니다. 이전 결과는
덮어쓰지 않고 attempt 이력으로 남깁니다.

실제 단계별 시간과 실패 위치가 필요한 설계이므로 `RUNTIME + FIXTURE` 결과를
먼저 확보한 뒤 공개 API와 무효화 규칙을 확정합니다.

### P2. 수동 증거 템플릿 생성과 검증

`st_prepare_manual_evidence`가 현재 fingerprint, 수동 CheckId와 evidence 폴더를
포함한 JSON 뼈대를 만들고, `st_validate_manual_evidence`가 필드·경로·지문을
실행 전에 검사하도록 합니다.

### P3. 검증 실행 간 비교

`st_compare_verification_runs`에서 이전 실행과 현재 실행의 상태 변화, 수행시간,
환경, coverage와 산출물 checksum 차이를 JSON과 Excel로 제공합니다.

### P4. 내보내기 의존성 정책

manifest에서 파일을 `COLLECTED`, `EXTERNAL_REQUIRED`, `UNRESOLVED`,
`OPTIONAL`로 구분합니다. Test File baseline, callback, requirement, 사용자 정의
criteria, 환경 변수와 라이선스가 필요한 사내 코드를 어떻게 수집하거나 외부
요구사항으로 표시할지 확정합니다.

### 보류할 작업

다음 작업은 최초 R2025b 결과가 확보될 때까지 범위를 확대하지 않습니다.

- `+simtest` 패키지 구조 이전
- expected-value `REVIEW` 모드와 baseline 보관 정책
- 대규모 GUI 대시보드
- R2024a 지원 선언
- 릴리스 버전 확정과 Notion 완료 등록

## 6. 두 PC의 작업 동기화 규칙

### 순차 작업

같은 브랜치를 사용하는 경우 한 번에 한 PC만 커밋합니다.

1. 시작 전에 `git fetch`와 `git pull --ff-only`를 실행합니다.
2. 작업 범위에 맞는 검증을 실행합니다.
3. 이 문서의 작업 기록에 실행 결과와 다음 단계를 갱신합니다.
4. 의도한 파일만 커밋하고 원격에 push합니다.
5. 다른 PC는 작업 시작 전에 새 커밋을 pull합니다.

force push와 원격 이력 재작성은 사용하지 않습니다.

### 병렬 작업

두 PC에서 동시에 작업해야 하면 인수인계 브랜치를 직접 함께 수정하지 않고
각 작업 브랜치를 만듭니다.

```bash
# R2025b 장비 예시
git switch -c verify/r2025b-first-certification \
  origin/feat/per-cut-filtered-execution

# 다른 개발 장비 예시
git switch -c feat/verification-resume \
  origin/feat/per-cut-filtered-execution
```

각 브랜치를 push하고 검증 결과를 공유한 뒤 인수인계 브랜치에 통합합니다.
동일한 파일을 동시에 수정해야 한다면 한쪽 작업을 먼저 통합한 후 다른 쪽이
최신 기준으로 재동기화합니다.

## 7. Git으로 전달되지 않는 항목

`.gitignore` 정책에 따라 다음 항목은 원격 브랜치에 포함되지 않습니다.

- `runtime_target.mat`
- `TestManagement.xlsx`와 일반 XLSX/MAT 파일
- 실제 모델, Test File과 실행 입력
- `result/` 아래 검증·보고서·내보내기 결과
- MATLAB 생성 캐시와 코드 생성 결과

따라서 다른 PC에서는 업무 파일을 승인된 내부 경로로 별도 전달하고
`st_select_target_model`을 다시 실행해야 합니다. 민감한 모델이나 결과를
`git add -f`로 강제 등록하지 않습니다.

특정 실행 결과를 다른 PC에서 분석해야 하면 해당
`result/verification/runs/{run-id}`를 승인된 내부 저장소로 전달하고 checksum을
함께 확인합니다. 아직 인증 재개 기능이 없으므로 결과 폴더만 복사해도 이전
실행에서 자동으로 재개되지는 않습니다.

## 8. 작업 기록

아래 표는 코드로 확인되거나 실제 실행된 사실만 기록합니다. 실행하지 않은
MATLAB 검증을 PASS로 적지 않습니다.

| 날짜 | 환경 | 브랜치/커밋 | 수행 내용 | 검증 상태 | 다음 작업 |
| --- | --- | --- | --- | --- | --- |
| 2026-08-30 | 현재 개발 PC, MATLAB runtime 없음 | `handoff/r2025b-cross-machine` | 증분 실행·보고서·내보내기·검증 코드와 매뉴얼을 인수인계 브랜치로 구성 | 정적 확인만 완료, R2025b 미검증 | R2025b 장비에서 `QUICK + CURRENT`와 `RUNTIME + FIXTURE` 실행 |
| 2026-09-03 | 현재 개발 PC, MATLAB runtime 없음 | `feat/per-cut-filtered-execution` (기반 `78101c0`) | CUT별 CVF 적용, 독립 Test Case 실행·보고서, 기대값 재실행, 복원 검증과 별도 pointer 구현 | 정적 확인만 수행, R2025b fixture 미검증 | 원격 브랜치 동기화 후 `CERTIFY + FIXTURE`로 실행·복원 순서 확인 |
| 2026-09-04 | 현재 개발 PC, MATLAB runtime 없음 | `feat/standalone-harness-model-execution` (`1af915c`, `cc10729`, 로컬) | 내부 Harness를 실행별 SLX Model SUT로 export하고 Harness/CUT 이중 CVF, 기대값 Final 재export, 별도 보고서와 6비트 진단 추가 | 정적 계약 확인만 수행, R2025b EXPORTED_MODEL 미검증, 아직 push하지 않음 | 별도 push 요청 후 R2025b에서 `STANDALONE-CHECK-v1`과 FULL 산출물 확인 |

새 세션은 마지막 행과 Git 로그를 비교하여 어느 쪽이 최신인지 확인한 후
시작합니다.
