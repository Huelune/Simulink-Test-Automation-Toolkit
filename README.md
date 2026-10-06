# Simulink Test Automation Toolkit

Excel에 적은 CUT 목록만으로 Simulink Test Harness, 입력 Scenario, Test Assessment,
Test Manager Test Case를 자동으로 구성하고, 테스트 실행·기대값 갱신·Coverage 수집·
보고서 작성·제출물 내보내기까지 수행하는 MATLAB 자동화 도구입니다.

저장소: [Huelune/Simulink-Test-Automation-Toolkit](https://github.com/Huelune/Simulink-Test-Automation-Toolkit)

> **처음 쓰신다면 [사용자 매뉴얼](docs/user-manual.md)부터 읽으십시오.**
> MATLAB과 Simulink Test를 모른다는 전제로 설명합니다.
> 용어가 낯설면 [용어집](docs/reference/glossary.md)을 함께 보십시오.

## 무엇을 대신해 주는가

CUT(테스트 대상 서브시스템) 하나를 테스트하려면 보통 Harness를 만들고, 입력을
만들고, `verify` 문장을 적고, Test Case와 Iteration을 걸고, 실행해서 커버리지를
뽑아야 합니다. CUT이 20개면 이 작업을 20번 해야 합니다.

이 도구는 Excel 한 장에 CUT 목록을 적어 두면 그 전부를 대신합니다.

```text
TestManagement.xlsx
  → 모델과 CUT 경로 확인
  → Harness · SLDV · Signal Editor · Assessment 준비
  → Test Manager 구성
  → BATCH 또는 CUT별 격리 실행
  → 기대값 갱신과 재실행
  → Decision · Execution Coverage와 보고서 저장
  → 상태 검증 또는 제출물 내보내기
```

| 영역 | 제공 기능 |
| --- | --- |
| 대상 관리 | Excel 행별 CUT, Harness, Test Case, SLDV, 기대값, CVF 정책 |
| 준비 자동화 | 누락 Harness 생성, Signal Editor Scenario, Assessment, Iteration 구성 |
| 증분 처리 | 대상·단계별 fingerprint와 checkpoint로 준비 결과 재사용 |
| 테스트 실행 | 전체 일괄 실행 또는 Excel 순서의 CUT별 독립 실행 |
| 기대값 처리 | 실패 결과의 실제값을 Assessment 기대값에 반영 후 재실행 |
| Coverage | Decision과 Block Execution 수집, CUT별 임시 CVF 적용·복원 |
| 제출물 | standalone 모델·CVF·CVT·HTML과 11열 `CoverageSummary.xlsx` |
| 보고서 | Excel, JSON manifest, MLDATX, HTML, 선택적 공식 PDF |
| 현장 점검 | 환경·실행·CVF 상태를 전달 가능한 고정 비트 코드로 요약 |

선택 기능으로 테스트 명세서 Excel 추출, 다른 PC용 재실행 번들, 여러 모델을 위한
이름별 profile, 중간 단계 재시작과 결과 재생성, `QUICK`/`RUNTIME`/`CERTIFY` 종합
검증이 있습니다.

## 요구 환경

| 제품 | 필요 범위 |
| --- | --- |
| MATLAB R2025b | 현재 검증 기준 릴리스 |
| Simulink | 필수 |
| Simulink Test | 필수 (Harness, Test Sequence, Test Manager) |
| Simulink Coverage | Coverage·CVF·커버리지 보고서를 쓸 때 필수 |
| Simulink Design Verifier | `SldvMode=GENERATE`를 쓸 때만 필수 |

입력으로 필요한 것은 대상 Top Model과 `TestManagement.xlsx` 두 가지입니다. 자세한
준비물은 [사용자 매뉴얼](docs/user-manual.md)에 있습니다.

## 가장 빠른 시작

MATLAB에서 툴킷 클론 루트를 Current Folder로 연 뒤 실행합니다. 모두 기본 옵션입니다.

```matlab
st_setup                          % 세션마다 한 번
st_select_target_model            % 처음이거나 모델을 바꿀 때
st_set_standalone_coverage_root   % 결과 루트 D:\model_result\<Top Model>
st_pre_validate_targets           % Excel을 고칠 때마다

st_run_from_harness               % Harness 생성 → 준비 → 실행
st_collect_per_cut_results        % 결과 정리 (필수)

info = st_run_standalone_coverage_pipeline();     % standalone 제출물
st_check_standalone_coverage();                    % 1111111111이면 정상
st_classify_standalone_results('PipelineId', info.PipelineId);   % 팀 제출 트리
st_export_final_document('CoveragePipelineId', info.PipelineId); % 최종 문서
```

단계마다 무엇을 확인하고 어떤 옵션이 있는지는 [사용자 매뉴얼](docs/user-manual.md)에
있습니다.

> **실행 전 주의:** 이 도구는 모델과 Test File을 실제로 수정합니다. 처음 돌리기
> 전에 백업하고, 기본 기대값 정책이 `APPLY`(실패 시 기대값 자동 갱신)라는 점을
> [사용자 매뉴얼 2.3절](docs/user-manual.md#23-실행-전-주의--모델이-바뀝니다)에서
> 확인하십시오.

모델 이름과 파일 경로는 추적되는 `src/config/st_config.m`에 기록하지 않습니다.
Git에서 제외된 `runtime_target.mat`에만 저장되므로 저장소를 pull해도 모델 선택이
충돌하지 않습니다.

## 관리 Excel

기본 파일은 저장소 루트의 `TestManagement.xlsx`, 시트 이름은 `Targets`입니다.
최소로 필요한 열은 네 개입니다.

| 열 | 뜻 |
| --- | --- |
| `CUTName` | 대상 Subsystem 이름 |
| `CUTPath` | Top Model부터의 전체 경로 |
| `HarnessName` | 만들거나 재사용할 Harness 이름 |
| `TestCaseName` | Test Manager에 만들 Test Case 이름 |

나머지 열(SLDV 입력, 기대값 정책, Coverage 필터, 준비 재실행, Harness 복제)은 전부
선택입니다. 모든 열의 역할·기본값·잘못 적었을 때의 동작은
**[관리 Excel 열 사전](docs/reference/workbook-reference.md)** 한 곳에 정리되어 있습니다.

전역 기본값은 **[설정 사전](docs/reference/config-reference.md)**, 명령과 그 옵션은
**[실행 명령 사전](docs/reference/execution-commands.md)** 을 보십시오.

## 실행 모드

기본값은 `PER_CUT`이며, 보통 그대로 두면 됩니다.

| 모드 | 동작 |
| --- | --- |
| `PER_CUT` (기본) | 모든 활성 Test Case를 Excel 순서로 개별 실행하고 결과도 CUT별로 저장 |
| `BATCH` | 모든 활성 Test Case를 `run(tf)`로 한 번에 실행 |

Test Case가 서로 영향을 주지 않고, 기대값을 고친 뒤에도 그 Test Case만 다시
돌기 때문에 `PER_CUT`을 기본으로 둡니다. 전부 한 번에 돌려 통합 보고서 하나로
끝내고 싶으면 `st_run_after_harness('ExecutionMode','BATCH')`로 지정합니다.

커버리지 필터는 이 선택과 무관합니다. 실행은 커버리지를 **필터 없이** 수집하고,
CVF는 결과물을 만들 때 결과 데이터에 붙습니다 — `PER_CUT`은
`st_collect_per_cut_results`, `BATCH`는 `st_generate_test_report`가 합니다.

> 예전 `AUTO`는 없어졌습니다. 활성 CVF가 있으면 `PER_CUT`을 골랐는데, 필터가
> 결과물 단계로 옮겨가면서 근거가 사라졌습니다. 넘기면
> `simtest:RemovedExecutionMode`로 막습니다.

## 결과가 저장되는 곳

```text
result/
├── reports/          # 단계별 INI 결과
├── sldv/             # SLDV 생성 데이터와 manifest
├── state/            # 증분 준비 checkpoint
├── runs/             # BATCH 실행 보고서
├── per_cut_runs/     # PER_CUT 실행 보고서 (CUT별 폴더)
├── exports/          # 자산 번들과 재실행 번들
├── standalone_coverage/  # standalone 제출물
├── verification/     # QUICK/RUNTIME/CERTIFY 결과
├── latest.json       # 최신 BATCH 실행 위치
├── per_cut_latest.json   # 최신 PER_CUT 실행 위치
└── TestSummary.xlsx  # 최신 BATCH 실행 요약
```

`result/`는 다시 만들 수 있는 생성물 영역이지만, 인증 증거나 전달한 제출물은
지우기 전에 따로 보관하십시오. 정리는 기본 dry-run인 `st_cleanup_results`로 합니다.

보고서는 전부 로컬 파일이며 외부 시스템으로 자동 전송하지 않습니다. 공유 전에는
모델 경로, CUT 이름, 진단 오류에 민감정보가 없는지 검토해야 합니다.

## 문서

| 문서 | 언제 보는가 |
| --- | --- |
| [사용자 매뉴얼](docs/user-manual.md) | **처음부터 끝까지 따라갈 때.** 단계마다 코드·확인 방법·옵션 |
| [문서 지도](docs/README.md) | 어떤 문서를 봐야 할지 모를 때 |
| [용어집](docs/reference/glossary.md) | 용어가 낯설 때 |
| [관리 Excel 열 사전](docs/reference/workbook-reference.md) | Excel 열의 뜻과 기본값을 찾을 때 |
| [설정 사전](docs/reference/config-reference.md) | 기본 동작을 바꾸고 싶을 때 |
| [실행 명령 사전](docs/reference/execution-commands.md) | 어떤 명령이 있고 어떤 옵션을 받는지 |
| [운영자 매뉴얼](docs/reference/operator-manual.md) | 단계별 전제조건·부작용·복구 방법을 확인할 때 |
| [문제 해결](docs/reference/troubleshooting.md) | 오류가 났을 때 |

`docs/`는 메인 매뉴얼 하나와 세 폴더로 나뉩니다. `reference/`는 자세히 볼 문서,
`design/`은 설계, `ai/`는 AI 에이전트 작업용입니다. 전체 목록은
[문서 지도](docs/README.md)에 있습니다.

## 저장소 구조

| 경로 | 역할 |
| --- | --- |
| `st_setup.m` | 프로젝트 bootstrap |
| `src/config/` | 전역 설정과 정책 정규화 |
| `src/workflow/` | workflow 진입점과 증분 계획 |
| `src/targets/` | Excel 로드, 모델 선택, CUT 경로 검증 |
| `src/harness/`, `src/signal_editor/` | Harness와 입력 Scenario 구성 |
| `src/sldv/`, `src/assessment/` | SLDV 준비와 Assessment 생성 |
| `src/test_manager/`, `src/execution/` | Test Case 구성과 BATCH/PER_CUT 실행 |
| `src/coverage/`, `src/reporting/` | CVF 세션, Coverage와 보고서 |
| `src/exporting/` | 자산 번들, 재실행 번들, 테스트 명세서 |
| `src/pipeline/` | standalone Coverage 파이프라인과 결과 재생성 |
| `src/verification/` | QUICK/RUNTIME/CERTIFY 검증과 readiness 검사 |
| `src/maintenance/` | 안전한 결과 정리 |
| `diagnostics/` | MATLAB·Python 읽기 전용 진단 |
| `tests/` | 단위·통합 테스트와 실행 시 생성 fixture |
| `docs/` | 문서. 메인 매뉴얼과 `reference/`·`design/`·`ai/` |

기존 공개 `st_*` 함수 이름은 호환성을 위해 유지합니다. 향후 `src/+simtest` package
이전 범위와 호환 기간은 아직 결정되지 않았습니다.

## Git 산출물 정책

| 종류 | Git | 이유 |
| --- | --- | --- |
| MATLAB 소스, 테스트, 문서 | 추적 | 제품과 검증 코드 |
| 실제 `TestManagement.xlsx`, MAT, MLDATX, 모델 | 제외 | 모델 경로와 업무 데이터 포함 가능 |
| `runtime_target.mat` | 제외 | PC별 로컬 선택값 |
| `result/`, `slprj/`, 코드 생성물 | 제외 | 실행마다 재생성되는 산출물 |
| 승인 baseline / test artifact | 정책 확정 전 제외 | 보관 절차 미결정 |

따라서 다른 PC에서 이어서 작업할 때는 업무 파일을 승인된 내부 경로로 별도
전달하고 `st_select_target_model`을 다시 실행해야 합니다. 민감한 모델이나 결과를
`git add -f`로 강제 등록하지 마십시오.

## 현재 검증 상태

| 항목 | 상태 |
| --- | --- |
| 버전 | `0.9.6` 이후 `Unreleased` |
| 기본 브랜치 | `main` |
| R2025b 인증 | 부분 확인. 전체 `CERTIFY + BOTH` 미완료 |

2026-09-15에 실제 업무 모델(대상 26개)로 standalone export → `EXECUTE` →
`PACKAGE` → `SUMMARY` → checker 경로를 처음 통과했습니다. 그 밖의 경로는 아직
R2025b 실기 결과가 없습니다. 실행하지 않은 검증을 통과로 기록하지 않습니다.

미검증으로 남은 주요 항목:

- `SUBSYSTEM+JUSTIFY`, `ALL_CONTENT+EXCLUDE`, `OFF` CUT의 순차 실행과 필터 무누출
- 기대값 최초 실패 → 갱신 → 같은 CVF 재실행 → 최종 PASS
- SLDV·일반 MAT `FILE`/`GENERATE`의 Scenario·Iteration과 `Tmax` timing
- `QUICK → RUNTIME → CERTIFY` 전체 인증과 재실행 번들 반복 실행
- 단계 재시작과 결과 재생성(PACKAGE/SUMMARY)

R2025b 장비에서는 먼저 단위 테스트를 실행하십시오.

```matlab
st_setup
results = runtests(fullfile(st_project_root(), 'tests', 'unit'));
```

이후 절차는 [종합 검증](docs/reference/verification.md)을 따르고, 배포 전 실기 확인 목록은
그 문서의 [13절](docs/reference/verification.md#13-r2025b-배포-전-실기-확인)에 있습니다. 아직 결정되지 않은 항목은
[TODO](docs/design/TODO.md)에 있습니다.

## 라이선스

[LICENSE](LICENSE)를 참조하십시오.
