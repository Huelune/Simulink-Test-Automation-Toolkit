# 사용자 매뉴얼

CUT 목록을 적은 Excel 한 장에서 시작해 **고객 제출용 최종 문서와 제출 폴더가
나오기까지**를 순서대로 따라가는 문서입니다. MATLAB과 Simulink Test를 처음 쓰는
사람도 이 문서 하나로 끝까지 갈 수 있게 썼습니다. 용어가 낯설면
[용어집](reference/glossary.md)을 옆에 두십시오.

단계마다 **무엇을 하는지 → 실행할 코드 → 끝났는지 확인하는 법 → 옵션**의 순서로
적었습니다. 전부 기본 옵션으로 돌리면 되도록 맞춰져 있으니, 옵션 표는 필요할 때만
보면 됩니다. 한 번에 복사해 쓸 코드는 [9절](#9-복사용-전체-코드)에 있습니다.

## 목차

0. [이 도구가 하는 일](#0-이-도구가-하는-일)
1. [한눈에 보기](#1-한눈에-보기)
2. [시작 전에 한 번만](#2-시작-전에-한-번만)
3. [1단계 — 준비와 실행, 결과 정리](#3-1단계--준비와-실행-결과-정리)
4. [2단계 (선택) — 테스트 명세서](#4-2단계-선택--테스트-명세서)
5. [3단계 — standalone 제출물](#5-3단계--standalone-제출물)
6. [4단계 — 팀 제출 트리](#6-4단계--팀-제출-트리)
7. [5단계 — 고객 제출용 최종 문서](#7-5단계--고객-제출용-최종-문서)
8. [제출 묶음](#8-제출-묶음)
9. [복사용 전체 코드](#9-복사용-전체-코드)
10. [상황별로 무엇을 부를까](#10-상황별로-무엇을-부를까)
11. [자주 막히는 곳](#11-자주-막히는-곳)
12. [반드시 지킬 것](#12-반드시-지킬-것)
13. [더 자세히 볼 문서](#13-더-자세히-볼-문서)

## 0. 이 도구가 하는 일

Simulink 모델의 서브시스템(CUT)을 하나씩 테스트하려면 보통 다음을 손으로 합니다.

1. CUT마다 Test Harness를 만든다
2. Harness에 넣을 입력 신호를 만든다
3. 출력이 얼마여야 하는지 `verify` 문장을 적는다
4. Test Manager에 Test Case를 만들고 입력 개수만큼 Iteration을 건다
5. 실행하고, 커버리지를 뽑고, 보고서를 만든다

CUT이 20개면 이 작업을 20번 해야 합니다. 이 도구는 **Excel 한 장에 CUT 목록을
적어 두면 1번부터 5번까지를 자동으로 하고**, 원본 모델 없이도 열리는 제출물과
고객 제출용 문서까지 만듭니다.

## 1. 한눈에 보기

```text
준비        st_setup                               MATLAB을 켤 때마다
   │        st_select_target_model                 처음 1회, 모델을 바꿀 때
   │        st_set_standalone_coverage_root        결과 루트 D:\model_result\<Top Model>
   │        st_pre_validate_targets                Excel을 고칠 때마다
   │
1단계       st_run_from_harness                    준비 + 실행
   │          HARNESS → SLDV → HARNESS_CONFIG → SIGNAL_EDITOR
   │          → ASSESSMENT → TEST_MANAGER → ALIGNMENT → EXECUTE
   │        st_collect_per_cut_results             결과 정리 (필수)
   │
2단계       st_export_test_specification           (선택) 명세서 Excel
   │
3단계       st_run_standalone_coverage_pipeline    standalone 제출물
   │          EXECUTE → PACKAGE → SUMMARY
   │        st_check_standalone_coverage           1111111111이면 통과
   │
4단계       st_classify_standalone_results         팀 제출 트리 (세 갈래)
   │
5단계       st_export_final_document               고객 제출용 최종 문서
```

| 단계 | 명령 | 만들어지는 것 | 끝났다는 증거 |
| --- | --- | --- | --- |
| 준비 | `st_pre_validate_targets` | `result/reports/PreValidationResult.ini` | 모든 행이 통과 |
| 1 | `st_run_from_harness` | 모델 안 Harness, Test File, 실행 기록 | 마지막 로그가 `EXECUTE` 완료 |
| 1 | `st_collect_per_cut_results` | `result/per_cut_runs/`, CVF, CUT별 보고서 | `latest.Status = PASS` |
| 2 | `st_export_test_specification` | `result/test_specification_<시각>.xlsx` | 행 수가 시나리오 수와 같음 |
| 3 | `st_run_standalone_coverage_pipeline` | `D:\model_result\<Top Model>\<PipelineId>\` | 검사 코드 `1111111111` |
| 4 | `st_classify_standalone_results` | `D:\model_result\<Top Model>\<TopModel>\` | 건너뛴 목록에 제출 파일이 없음 |
| 5 | `st_export_final_document` | `result/final_document_<시각>.xlsx` | `확인 필요 = Y`가 없거나 전부 검토됨 |

### MATLAB 명령 읽는 법

```matlab
info = st_run_standalone_coverage_pipeline('Action', 'ALL', 'FailOnNonPass', true);
```

- 맨 앞(`st_run_...`)이 실행할 명령입니다.
- 괄호 안은 `'옵션이름', 값` 쌍이며 순서는 상관없습니다. 필요한 것만 적으면 되고,
  적지 않은 옵션은 기본값이 쓰입니다.
- 결과를 변수로 받으려면 왼쪽에 `변수 =`를 붙입니다. `disp(info)`로 내용을 봅니다.

명령이 오래 걸릴 때 Command Window가 멈춘 것처럼 보이는 것은 정상입니다. Harness
생성과 SLDV 분석은 CUT 하나에 몇 분씩 걸립니다. 지금 어디서 기다리는지는 **마지막
`START` 로그**로 확인합니다.

## 2. 시작 전에 한 번만

### 2.1 준비물

| 제품 | 필요 여부 | 없으면 |
| --- | --- | --- |
| MATLAB R2025b | 필수 | 실행 불가 |
| Simulink | 필수 | 실행 불가 |
| Simulink Test | 필수 | Harness·Test Manager 기능 전부 불가 |
| Simulink Coverage | 커버리지를 쓸 때 필수 | 커버리지·CVF·standalone 제출물 불가 |
| Simulink Design Verifier | `SldvMode = GENERATE`를 쓸 때만 | 입력 자동 생성만 불가 |

R2025b가 현재 기준 환경입니다. 다른 릴리스에서의 동작은 확인하지 않았습니다.

### 2.2 툴킷 받기와 최신으로 유지하기

MATLAB이 쓰는 툴킷은 **모델 프로젝트 안에 둔 클론**입니다.

```bash
git clone https://github.com/Huelune/Simulink-Test-Automation-Toolkit.git
```

작업을 시작할 때마다 그 클론에서 최신을 받으십시오.

```bash
git pull
```

이미 고쳐진 오류가 다시 나면 MATLAB이 예전 커밋에서 돌고 있는 것입니다.
MATLAB에서 `which -all st_setup`으로 어느 폴더가 잡혔는지 확인하십시오.

### 2.3 실행 전 주의 — 모델이 바뀝니다

이 도구는 **모델과 Test File을 실제로 수정하고 저장합니다.**

| 항목 | 확인 |
| --- | --- |
| 백업 | 원본 모델·Excel·Test File을 백업했는가 |
| 저장 상태 | 열려 있는 모델과 Test File을 저장했는가 |
| 기대값 정책 | 아래 "기대값 자동 갱신"을 읽었는가 |

#### 기대값 자동 갱신 (`APPLY`)

테스트가 실패하면 이 도구는 기본 설정에서 **실제 출력값을 정답으로 보고 `verify`
문장의 기대값을 그 값으로 고쳐 쓴 뒤 다시 실행합니다.** 정답이 아직 없는 초기
단계에서 기준값을 만들기 위한 기능입니다. **이미 승인된 기준값이 있으면 덮어써지므로
반드시 끄십시오.**

| 끄는 방법 | 범위 |
| --- | --- |
| Excel의 `ExpectedUpdateMode` 열을 `OFF` | 그 행만 |
| `src/config/st_config.m`의 `cfg.ExpectedUpdateMode = 'OFF'` | 전체 |

기대값이 바뀌는 것은 1단계뿐입니다. 3단계 standalone은 기대값을 갱신하지 않습니다.

### 2.4 `TestManagement.xlsx` 작성

저장소 루트의 `TestManagement.xlsx`, `Targets` 시트가 유일한 입력입니다. 한 행이
CUT 하나입니다. 열 순서는 상관없고 이름으로 찾습니다.

**필수 4열**

| 열 | 적는 것 | 예 |
| --- | --- | --- |
| `CUTName` | Subsystem 블록 이름 | `Controller` |
| `CUTPath` | Top Model 이름부터의 전체 경로. Top Model 이름을 빼고 적으면 앞에 붙여 해석합니다 | `TopModel/Logic/Controller` |
| `HarnessName` | 만들거나 재사용할 Harness 이름 | `Controller_Harness1` |
| `TestCaseName` | Test Manager에 만들 Test Case 이름 | `Controller_12345` |

**같이 정해 두는 열**

| 열 | 권장 값 | 왜 |
| --- | --- | --- |
| `Enabled` | `TRUE` | 이번에 처리할 행만 `TRUE` |
| `SldvMode` | `OFF` / `FILE` / `GENERATE` | 입력을 어디서 가져올지. `FILE`이면 `SldvDataFile`도 적습니다 |
| `ExpectedUpdateMode` | 승인된 기준값이 있으면 **`OFF`** | 기본은 `APPLY` |
| `CoverageFilterMode` | `ALL_CONTENT` | 3단계 standalone이 요구하는 조합 |
| `CoverageBoundaryMode` | `CUT_ONLY` | 〃 |
| `CoverageFilterAction` | `EXCLUDE` | 〃 |
| `CoverageFilterRationale` | 비어 있지 않은 사유 | 비어 있으면 3단계가 시작하지 않습니다. 커버리지를 검토하는 사람이 "왜 이 블록을 뺐는가"를 알아야 하기 때문입니다 |

- 같은 `CUTPath`를 두 활성 행에 적지 마십시오. 서로의 Harness 설정을 덮어씁니다.
- `SldvDataFile`의 상대 경로 기준은 **Excel 파일이 있는 폴더**입니다.
- 모든 열의 뜻, 기본값, 잘못 적었을 때의 동작은
  [관리 Excel 열 사전](reference/workbook-reference.md)에 있습니다.

`CUTPath`를 손으로 찾기 어려우면 보조 명령을 씁니다. 셋 다 **관리 Excel을
바꾸므로** 먼저 백업하십시오.

```matlab
st_export_subsystem_paths       % 모델의 모든 Subsystem 경로를 Excel 시트로 뽑기
st_fill_temp_paths_from_indent  % Excel 들여쓰기 계층을 읽어 빈 CUTPath 채우기
st_find_target_paths            % 같은 이름 후보를 문맥으로 순위화해 고르기
```

### 2.5 MATLAB 세션 열기

1. MATLAB을 실행합니다.
2. **Current Folder**를 툴킷 클론 루트(`st_setup.m`이 보이는 폴더)로 맞춥니다.
3. **Command Window**에서 아래를 실행합니다.

```matlab
st_setup                          % MATLAB을 켤 때마다 1회
st_select_target_model            % 처음 1회, 또는 모델을 바꿀 때만
st_set_standalone_coverage_root   % 처음 1회. 3단계 결과를 D:\model_result\<Top Model>에
```

`st_setup`이 성공하면 이렇게 나옵니다.

```text
Automation project path added: D:\...\Simulink-Test-Automation-Toolkit
Source path added            : D:\...\Simulink-Test-Automation-Toolkit\src
```

`st_select_target_model`과 `st_set_standalone_coverage_root`의 선택은 로컬
`runtime_target.mat`에 저장되므로 MATLAB을 다시 켜도 유지되고, Git에 올라가지
않아 다른 사람의 선택과 충돌하지 않습니다.

| 명령 | 인자 | 기본 | 뜻 |
| --- | --- | --- | --- |
| `st_setup` | 없음 | | 툴킷 경로를 MATLAB path에 올리고 `result/`를 만듭니다. 그 세션에만 유효합니다 |
| `st_select_target_model` | `forceSelectModel` | `false` | `true`면 저장된 선택을 무시하고 모델 선택 창을 다시 띄웁니다 |
| `st_set_standalone_coverage_root` | `rootDir` | 생략 | 생략하면 `D:\model_result\<Top Model>`, 경로를 주면 그 경로, `''`면 지정 해제(`result/standalone_coverage`) |

결과 루트를 지정하지 않으면 3단계 결과가 툴킷 클론의 `result\standalone_coverage\`에
만들어지는데, 모델 폴더가 깊으면 Windows 260자 경로 제한에 걸리므로 권하지 않습니다.

### 2.6 Excel 검사 — `st_pre_validate_targets`

```matlab
R = st_pre_validate_targets();
disp(R)
```

`CUTPath`가 실제로 존재하는 Subsystem인지 **모델을 바꾸지 않고** 확인합니다. 결과는
`result/reports/PreValidationResult.ini`에도 남습니다. 인자는 없습니다.

> **여기서 걸리면 다음으로 넘어가지 마십시오.** Harness를 엉뚱한 블록에 만들게
> 됩니다. 대부분 `CUTPath` 오타이거나 중간 Subsystem을 빠뜨린 경로입니다.

Excel을 고칠 때마다 다시 실행합니다.

## 3. 1단계 — 준비와 실행, 결과 정리

1단계는 **명령 두 개**입니다. 결과 정리를 부르지 않으면 1단계는 끝난 것이 아닙니다.

```matlab
st_run_from_harness            % (1) Harness 생성 → 준비 → 실행
st_collect_per_cut_results     % (2) 결과 정리 — 필수
```

### 3.1 `st_run_from_harness`가 하는 일

| 단계 | 하는 일 | 바뀌는 것 |
| --- | --- | --- |
| `HARNESS` | 없는 Harness를 만듭니다. **있는 Harness는 그대로 둡니다** | 모델 |
| `SLDV` | 입력 데이터를 준비합니다 (`OFF`/`FILE`/`GENERATE`) | 입력 MAT |
| `HARNESS_CONFIG` | StopTime 등 Harness 설정 | Harness |
| `SIGNAL_EDITOR` | 입력 Scenario를 만들어 Harness에 연결 | Harness |
| `ASSESSMENT` | `verify` 문장 구성 | Harness |
| `TEST_MANAGER` | Test File, Test Case, Iteration 구성 | Test File |
| `ALIGNMENT` | Scenario 이름이 서로 맞는지 검사만 | 없음 |
| `EXECUTE` | 실행 → 실패 시 기대값 갱신 → 재실행 → 실행 기록 저장 | Harness, 실행 기록 |

Harness가 **이미 전부 있으면** `st_run_after_harness`를 써도 됩니다. `HARNESS` 단계만
빠지고 나머지와 옵션은 같습니다.

기본 실행 방식은 `PER_CUT`입니다. Test Case를 하나씩 돌리므로 서로 영향을 주지 않고,
한 CUT이 예외로 죽어도 기록하고 다음 CUT으로 넘어갑니다. SLDV·Harness 생성·실행은
Windows 경로 길이 제한을 피하려고 `%TEMP%\stt_build` 아래 짧은 폴더에서 돌고, 끝나면
원래 폴더로 돌아옵니다.

두 번째 실행부터는 입력(Excel·설정·모델·입력 MAT)이 그대로인 단계를 건너뜁니다.
각 단계가 성공할 때 입력 지문을 `result/state/`에 저장해 두기 때문입니다.

### 3.2 결과 정리 `st_collect_per_cut_results` — 필수

실행은 **기록만 남기고 끝납니다.** 판정 표, 커버리지 필터(CVF), CUT별 보고서는 이
명령이 만듭니다. 기본 설정에서는 자동으로 돌지 않으므로 **실행이 끝나면 반드시
이어서 부릅니다.**

빼먹으면 이렇게 됩니다.

- 5단계 최종 문서의 `판정 결과`가 전부 빈 칸이 되고 `TestResults` 시트에
  `NOT_COLLECTED`가 적힙니다.
- `Description` 열이 커버리지가 잡은 분기 대신 정적 스캔 결과로 채워집니다.
- 커버리지 필터(CVF)가 만들어지지 않습니다.

> **정리한 뒤 테스트를 다시 돌리면 정리 결과가 무효가 됩니다.** 새 실행이 최신
> 실행 포인터를 옮기기 때문입니다. **다시 돌렸으면 다시 정리하십시오.** 헷갈리면
> 한 번 더 불러도 됩니다. 저장된 결과에서 산출물을 다시 만들 뿐입니다.

두 명령을 한 줄로 합치려면 `st_run_from_harness('AutoCollect', true)`입니다.
`'ExecutionMode','BATCH'`로 돌렸을 때만 결과 정리 명령이 `st_generate_test_report`입니다.

### 3.3 끝났는지 확인

```matlab
cfg = st_config();
latest = jsondecode(fileread(cfg.PerCutLatestPointer));
disp(latest.Status)          % 전체 상태
winopen(latest.Summary)      % CUT별 결과 요약 Excel
```

| 볼 것 | 정상 |
| --- | --- |
| `latest.Status` | `PASS`. `PASS_WITH_WARNINGS`는 경고를 읽고 넘어가고, `PARTIAL`·`FAIL`은 원인을 찾습니다 |
| 요약 Excel의 `Targets` 시트 | 모든 CUT의 `Status`가 `PASS` |
| CUT 폴더의 `TestSummary.xlsx` → `Iterations` 시트 | 모든 iteration이 `Passed` (재실행이 있었으면 `final/` 쪽) |
| Simulink 모델 창 | Harness가 Excel의 `HarnessName`대로 생겼음 |
| Test Manager | `TestCaseName`대로 Test Case가 있고 Iteration 수가 Scenario 수와 같음 |

포인터 파일이 없거나 `Status`가 비어 있으면 결과 정리를 안 한 것입니다. `Failed`가
있으면 `result/per_cut_runs/` 아래 그 CUT 폴더의 `.mldatx`를 Test Manager에서 열어
어느 verify가 틀렸는지 봅니다. `ExpectedUpdateMode`가 `APPLY`였다면 첫 실행 실패는
기대값이 갱신되고 재실행에서 `Passed`로 바뀌어야 정상입니다.

### 3.4 다시 돌려야 할 때

| 무엇을 고쳤나 | 명령 |
| --- | --- |
| Excel의 CUT 목록 (행 추가·삭제) | `st_pre_validate_targets` → `st_run_from_harness` |
| 입력 MAT, `SldvMode` | `st_run_from_harness('PreparationMode','FORCE','FromStage','SLDV')` |
| Harness StopTime 등 설정 | `... 'FromStage','HARNESS_CONFIG' ...` |
| verify 대상, Assessment | `... 'FromStage','ASSESSMENT' ...` |
| Test Case 이름, Iteration | `... 'FromStage','TEST_MANAGER' ...` |
| `Coverage*` 네 열만 | **다시 돌리지 않습니다.** `st_collect_per_cut_results`만 다시 합니다 |
| 전부 처음부터 | `st_run_from_harness('PreparationMode','FORCE')` |

**어느 경우든 실행이 다시 돌았으면 `st_collect_per_cut_results`를 다시 부릅니다.**
특정 CUT만 다시 돌리려면 나머지 행의 `Enabled`를 `FALSE`로 내리는 것이 가장
간단합니다.

`FromStage`는 앞 단계를 건너뛰라는 뜻이 아니라 **그 단계부터 강제로 다시 하라**는
뜻입니다. 앞 단계는 여전히 입력 지문으로 판정하므로, 모델이 바뀌었으면 앞 단계도
함께 돕니다. 앞 단계를 절대 건드리지 않으려면 [재시작](reference/restart.md)의
`st_run_from_stage`를 씁니다.

### 3.5 옵션

**`st_run_from_harness` / `st_run_after_harness`** — 빈 값은 `st_config.m`의 값을 씁니다.

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `PreparationMode` | `'AUTO'` | `AUTO`는 입력이 그대로인 단계를 건너뜁니다. `FORCE`는 `FromStage`부터 다시 합니다 |
| `FromStage` | 처음 단계 | `FORCE`로 다시 할 첫 단계. `HARNESS`, `SLDV`, `HARNESS_CONFIG`, `SIGNAL_EDITOR`, `ASSESSMENT`, `TEST_MANAGER`, `ALIGNMENT`. `EXECUTE`는 준비 없이 실행만 합니다 |
| `ExecuteTests` | `true` | `false`면 Test Case까지 만들고 실행하지 않습니다 |
| `ExecutionMode` | `'PER_CUT'` | `PER_CUT`은 Test Case마다 따로, `BATCH`는 `run(tf)` 한 번에 전부 |
| `ContinueOnFailure` | `true` | 한 CUT이 **예외**로 죽어도 다음 CUT으로 넘어갑니다. verify FAIL은 예외가 아니라 이 옵션과 상관없이 넘어갑니다 |
| `FailOnNonPass` | `false` | `true`면 끝난 뒤 FAIL·EXCEPT·WARN인 CUT이 있을 때 MATLAB 오류를 냅니다 |
| `ReportMode` | `'SUMMARY'` | CUT별 보고서 수준. `FULL`은 공식 Test Manager PDF와 전체 Coverage HTML을 더합니다 |
| `AutoCollect` | `false` | `true`면 실행 끝에 `st_collect_per_cut_results`까지 이어서 합니다 |
| `IgnoreUnexpectedSldvInputs` | `true` | SLDV가 만든 입력 중 Harness에 없는 신호를 버립니다. `false`면 그 행을 실패로 멈춥니다. 이 실행에만 적용되며, 값이 SLDV 단계 지문에 들어가므로 붙였다 뗐다 하면 SLDV부터 다시 준비합니다 |
| `StrictRestart` | `false` | 앞 단계를 건드리지 않는 엄격 재시작. `st_run_from_stage`가 쓰므로 직접 줄 일은 없습니다 |

`PER_CUT`과 `BATCH`의 차이입니다.

| | `PER_CUT` (기본) | `BATCH` |
| --- | --- | --- |
| 실행 | Test Case마다 따로 | `run(tf)` 한 번에 전부 |
| 기대값 고친 뒤 재실행 | 그 Test Case만 | Test File 전체 |
| 결과 정리 명령 | `st_collect_per_cut_results` | `st_generate_test_report` |
| 결과물 | CUT별 폴더 | 통합 보고서 하나 |

**`st_collect_per_cut_results`**

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `RunId` | `'LATEST'` | 정리할 PER_CUT 실행 |
| `ReportMode` | 실행 때 값 | `SUMMARY` 또는 `FULL`. 비우면 그 실행이 기록한 값을 씁니다 |

## 4. 2단계 (선택) — 테스트 명세서

테스트를 돌리지 않고 저장된 Harness에서 시나리오, 입력 마지막 값, verify 문장을
Excel로 뽑습니다. 검토용이며, 5단계 최종 문서는 이 파일을 읽지 않고 같은 내용을
다시 추출합니다. 필요 없으면 건너뜁니다.

```matlab
[T, specFile] = st_export_test_specification();
winopen(specFile)
```

모델·Harness·Test File이 **저장**되어 있어야 합니다. 저장되지 않은 것이 있으면
`SpecificationUnsaved`로 어느 모델인지 알려 주고 멈춥니다.

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `OutputFile` | `result/test_specification_<시각>.xlsx` | 출력 파일. 이미 있으면 거부합니다 |
| `VerifyMode` | `'STEP2'` | `STEP2`는 Step 2의 verify만, `ALL_STEPS_COLUMNS`는 verify가 있는 모든 스텝을 열로 |
| `DecisionBlockScope` | `'ALL'` | `ALL`은 커버리지 목표를 만드는 블록까지, `EXPLICIT`는 조건이 적힌 블록만, `NONE`은 비움 |

열 구성은 [테스트 명세서 추출](reference/test-specification.md)에 있습니다.

## 5. 3단계 — standalone 제출물

Harness를 원본 모델 없이도 열리는 **독립 모델**로 떼어내 실행하고, 커버리지 결과와
부속 파일을 제출물로 묶습니다. 준비된 자산을 복사해 **한 번만** 실행하며 기대값은
갱신하지 않습니다.

### 5.1 실행 전

1. 원본 Top Model, Harness, Test File은 **파이프라인이 저장하고 닫습니다.** 내보낸
   복사본이 같은 모델 이름을 쓰기 때문입니다. 미저장 변경은 폐기하지 않고
   저장하므로, **저장하면 안 되는 변경이 있으면 먼저 되돌리십시오.**
2. Excel의 활성 행마다 `Coverage*` 네 열이 [2.4절](#24-testmanagementxlsx-작성)의
   조합인지 확인합니다.

### 5.2 실행

```matlab
info = st_run_standalone_coverage_pipeline();
disp(info.PipelineId)
```

`EXECUTE → PACKAGE → SUMMARY`를 한 번에 합니다. `info.PipelineId`는 4·5단계에서
씁니다.

### 5.3 검사

```matlab
[code, summary, details] = st_check_standalone_coverage();
disp(code)
disp(summary)
```

읽기 전용 검사입니다. 몇 번을 돌려도 무엇도 바뀌지 않습니다. 화면 출력은 최대
20줄이고 전체 CUT 결과는 `details` 표에 있습니다.

| 결과 | 뜻 |
| --- | --- |
| `1111111111` + `summary.Status = 'PASS'` | 정상. 다음 단계로 |
| 자리에 `0` | 그 검사 실패. `details`에서 어느 CUT인지 확인 |
| 자리에 `-` | 아직 적용할 수 없는 검사. 전체는 `PARTIAL` |
| 전부 `1`인데 `PARTIAL` | `EXCEPT`로 끝난 CUT이 있음 |

| 자리 | 검사 |
| --- | --- |
| 1 | manifest, Action, Result 저장·재개 정책 |
| 2 | Harness명 = standalone 모델명 = `.slx` 이름 |
| 3 | SUT / iteration / input / assessment readback |
| 4 | 한 번만 실행, 재실행 없음 |
| 5 | CVF 생성, 규칙·파일·해시, Result 등록 1회 |
| 6 | 필수 파일 존재, 금지 산출물 없음 |
| 7 | Decision/Execution 수치와 출처 |
| 8 | Summary 파일, 11개 열, CUT 행 수 |
| 9 | 원본 모델·Test File·Harness·Input·Excel 불변 |
| 10 | 필터 복원, 모델·path 정리, CUT 폴더 격리 |

### 5.4 만들어진 것

```text
D:\model_result\<Top Model>\<PipelineId>\
├── 001_UT_REQ_{TestCaseName}/        CUT 폴더
│   ├── {HarnessName}.slx               standalone 모델
│   ├── {...}_HarnessInputs.mat         Signal Editor 입력
│   ├── UT_REQ_{TestCaseName}.cvf       적용한 커버리지 필터
│   ├── UT_REQ_{TestCaseName}.cvt       커버리지 원본 데이터
│   ├── UT_REQ_{TestCaseName}.html      커버리지 보고서 (+ 부속 asset 폴더)
│   └── target-manifest.json
├── 002_UT_REQ_.../
├── TestManager/{TopModel}.mldatx      standalone 모델로 재배선된 Test File
└── CoverageSummary.xlsx               11열 커버리지 요약
```

실행하지 못한 CUT도 폴더는 만들어지며, 없는 CVT·HTML을 만들어 PASS로 꾸미지
않습니다. 예외 처리와 산출물 규칙은
[Standalone Coverage 파이프라인](reference/standalone-coverage-pipeline.md)에 있습니다.

제출물을 Test Manager에서 열어 볼 때는 다음 명령 하나면 됩니다. 파일은 바꾸지 않습니다.

```matlab
st_open_standalone_test_manager                          % 가장 최근 제출물
st_open_standalone_test_manager('PipelineId', info.PipelineId)
```

같은 이름의 Test File이 이미 열려 있다고 멈추면 `'ClearTestManager', true`를
붙입니다. 열린 Test File과 Result를 모두 닫으니 저장할 것이 있으면 먼저 저장하십시오.
수동으로 여는 방법은 [결과 열기](reference/open-results.md)에 있습니다.

### 5.5 옵션

**`st_run_standalone_coverage_pipeline`**

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `Action` | `'ALL'` | `ALL`은 EXECUTE → PACKAGE → SUMMARY. 나눠 돌릴 때 `EXECUTE`, `PACKAGE`, `SUMMARY`. `PREPARE`는 재배선한 Test File만 만들고 실행하지 않습니다 |
| `PipelineId` | `'LATEST'` | `PACKAGE`·`SUMMARY`가 이어 받을 실행 |
| `ContinueOnFailure` | `true` | 한 CUT이 예외로 죽어도 다음 CUT으로 넘어갑니다 |
| `FailOnNonPass` | `false` | `true`면 PASS가 아닌 CUT이 있을 때 오류를 내고, 뒤의 PACKAGE·SUMMARY를 하지 않습니다 |
| `CloseSourceModel` | `true` | 실행 전에 원본 Top Model·Harness·Test File을 저장하고 닫습니다 |
| `ClassifyResults` | `false` | `true`면 `ALL` 끝에 4단계 팀 제출 트리를 자동으로 만들고 `info.SubmissionTree`에 위치를 돌려줍니다 |
| `SaveTestResult` | `ALL`은 `false`, `EXECUTE`는 `true` | Test Result를 파일로 남깁니다. 다른 세션에서 PACKAGE를 이어 하거나 제출물의 Results를 볼 때 필요합니다 |
| `OutputRoot` | 결과 루트 | 비우면 `st_set_standalone_coverage_root`로 정한 곳 |

같은 PipelineId의 `PACKAGE`와 `SUMMARY`는 각각 한 번만 실행할 수 있습니다. 다시
만들어야 하면 [재시작](reference/restart.md)의 재생성 절차를 씁니다.

**`st_check_standalone_coverage`**

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `PipelineId` | `'LATEST'` | 검사할 실행 |
| `OutputRoot` | 결과 루트 | 비우면 `st_set_standalone_coverage_root`로 정한 곳 |

**`st_open_standalone_test_manager`**

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `PipelineId` | `'LATEST'` | 열 실행 |
| `ImportResults` | `false` | 파이프라인이 `SaveTestResult=true`로 저장한 Result를 import합니다 |
| `ClearTestManager` | `false` | 열기 전에 Test Manager에 열린 Test File과 Result를 전부 닫습니다 |
| `LoadModels` | `false` | standalone 모델까지 로드합니다. CVF 뷰어 이름이 `n/a`로 나올 때 |
| `ApplyFilters` | `false` | Test Case마다 옆의 CVF를 다시 걸고 확인합니다 |
| `View` | `true` | Test Manager 창을 엽니다 |

## 6. 4단계 — 팀 제출 트리

파이프라인 폴더는 CUT별로 파일 종류가 섞여 있지만, 팀 제출은 **파일 종류별 세
갈래**를 씁니다. 파일 이름은 바꾸지 않고 복사만 하며, 원본 파이프라인 폴더는 그대로
둡니다.

```matlab
tree = st_classify_standalone_results('PipelineId', info.PipelineId);
disp(tree.OutputDir)
```

파이프라인 폴더 **옆에** `{TopModel}\`이 생깁니다.

```text
D:\model_result\<Top Model>\{TopModel}\
├── 테스트 케이스/{NUM}_UT_REQ_{TestCaseName}/    Input .mat
├── 테스트 보고서/{TopModel}.mldatx
├── 테스트 보고서/{NUM}_UT_REQ_{TestCaseName}/    .cvf .cvt .html + 부속 asset 폴더
└── 프로젝트/{NUM}_UT_REQ_{TestCaseName}/         standalone 모델 .slx
```

- 이미 트리가 있으면 지우고 새로 만듭니다. 이전 실행의 CUT 폴더가 섞이지 않습니다.
  그 폴더에 세 갈래 폴더 말고 다른 것이 있으면 지우지 않고 멈춥니다.
- `CoverageSummary.xlsx`, manifest, 로그, launcher, CUT 폴더 안의 `scv_images`는
  복사하지 않고 **건너뛴 목록**(`tree.Skipped`)에만 남깁니다. 그 목록에 `.slx`·`.mat`·
  `.cvf`·`.cvt`·`.html`이 보이면 CUT 폴더 이름이 `NNN_UT_REQ_` 규칙을 벗어난 것입니다.
- **HTML은 옆의 부속 폴더 없이 렌더링되지 않으니** 전달할 때는 폴더 단위로 통째로
  복사하십시오.

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `PipelineId` | `'LATEST'` | 정리할 실행 |
| `PipelineRoot` | `''` | id 대신 파이프라인 폴더를 직접 지정 |
| `OutputDir` | 파이프라인 폴더 옆 `{TopModel}` | 출력 폴더 |
| `Replace` | `true` | 출력 폴더가 있으면 지우고 다시 만듭니다. `false`면 폴더가 있을 때 멈춥니다 |
| `DryRun` | `false` | 계획만 출력하고 복사하지 않습니다 |

MATLAB이 없는 PC에서는 같은 규칙의 Python 스크립트를 씁니다(`--dry-run`, `--out`,
`--overwrite`).

```bash
python tools/python/classify_standalone_results.py D:\model_result\<Top Model>\<PipelineId>
```

## 7. 5단계 — 고객 제출용 최종 문서

명세서 내용, 1단계 결과 정리의 판정, 3단계 `CoverageSummary.xlsx`를 한 Excel로
모읍니다. 테스트를 돌리지 않고 모델을 바꾸지 않습니다.

### 7.1 실행 전 확인

| 조건 | 안 되어 있으면 |
| --- | --- |
| 1단계 결과 정리가 끝났고, 그 뒤 테스트를 다시 돌리지 않았다 | `판정 결과`가 전부 빈 칸, `TestResults`에 `NOT_COLLECTED` |
| 3단계 제출물이 있다 | `Coverage` 시트가 전부 `N/A`, `NO_COVERAGE_SOURCE` |
| 모델·Harness·Test File이 저장되어 있다 | `simtest:SpecificationUnsaved`로 중단 |

최종 문서는 결과 정리 산출물에서 판정을 **읽기만** 합니다. 확실하지 않으면 결과
정리를 한 번 더 부른 뒤 만드십시오.

### 7.2 실행

```matlab
[T, finalFile] = st_export_final_document('CoveragePipelineId', info.PipelineId);
winopen(finalFile)
```

판정은 1단계에서, 커버리지는 3단계에서 가져옵니다. standalone은 독립 모델로 돌아
PASS/FAIL이 다를 수 있기 때문입니다. `Metadata` 시트에 두 실행의 식별자가 모두
남습니다.

### 7.3 제출 전 검토

| 시트 | 볼 것 |
| --- | --- |
| `TestResults` | **`확인 필요`가 `Y`인 행만** 봅니다. `FAILED`면 `확인 위치`의 `.mldatx`를 Test Manager에서 엽니다 |
| `Metadata` | `ResultRunId`가 방금 돌린 1단계 실행인지, `CoveragePipelineId`가 방금 만든 3단계 제출물인지 |
| `TestCase` | `Test Case ID`가 `UT_REQ_{CUT}_{ID}_{NUM}`, `ID`가 codeBeamer ID로 나뉘어 있는지. `TESTCASE_ID_PATTERN_UNMATCHED`가 있으면 그 행은 이름 규칙 밖입니다 |
| `Coverage` | CUT 수가 Excel 활성 행 수와 같은지, 분자·분모가 `CoverageSummary.xlsx`와 같은지 |

### 7.4 옵션

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `CoveragePipelineId` | `'LATEST'` | 커버리지를 가져올 standalone 실행 |
| `CoverageSource` | `'STANDALONE'` | `STANDALONE`은 3단계 결과, `TEST_RUN`은 1단계 실행의 커버리지, `NONE`은 비움 |
| `ResultRun` | `'AUTO'` | 판정을 가져올 실행. `AUTO`는 BATCH·PER_CUT 중 더 최근 것. `BATCH`, `PER_CUT`, 폴더 경로도 됩니다 |
| `DecisionBlockScope` | `'ALL'` | 명세서와 달리 `cfg.DecisionBlockScope`를 따르지 않습니다 |
| `RequireTestResults` | `false` | `true`면 판정이 없을 때 파일을 만들지 않고 오류 |
| `RequireCoverage` | `false` | `true`면 커버리지가 없을 때 파일을 만들지 않고 오류 |
| `IncludeUsageSheet` | `false` | 사용법 시트를 맨 뒤에 붙입니다 |
| `OutputFile` | `result/final_document_<시각>.xlsx` | 출력 파일 |

시트별 열 구성과 `확인 사유` 코드 전체는 [최종 문서 추출](reference/final-document.md)에
있습니다.

## 8. 제출 묶음

| 무엇 | 어디서 | 비고 |
| --- | --- | --- |
| 최종 문서 Excel | `result/final_document_<시각>.xlsx` | 5단계 |
| 팀 제출 트리 `{TopModel}\` | `D:\model_result\<Top Model>\{TopModel}\` | 4단계. 폴더 단위로 통째로 |
| `CoverageSummary.xlsx` | `D:\model_result\<Top Model>\<PipelineId>\` | 4단계가 복사하지 않으므로 필요하면 따로 |
| 명세서 Excel (요청 시) | `result/test_specification_<시각>.xlsx` | 2단계 |

실제 모델·Excel·MAT·MLDATX와 `result/` 폴더는 **Git에 올리지 않습니다.**

## 9. 복사용 전체 코드

처음부터 끝까지 한 세션에서 하는 경우입니다. 모든 명령을 기본 옵션으로 부릅니다.

```matlab
%% 준비 — MATLAB을 켤 때마다
st_setup
st_select_target_model           % 처음 1회, 또는 모델을 바꿀 때만
st_set_standalone_coverage_root  % 필수. 3단계 결과를 D:\model_result\<Top Model>에 둡니다
R = st_pre_validate_targets();   % Excel을 고칠 때마다
disp(R)

%% 1단계 — Harness 생성 → 실행
st_run_from_harness
% Harness가 이미 전부 있으면: st_run_after_harness

%% 1단계 — 결과 정리 (필수. 빼면 5단계 판정이 빈 칸)
st_collect_per_cut_results

cfg = st_config();
latest = jsondecode(fileread(cfg.PerCutLatestPointer));
disp(latest.Status)
winopen(latest.Summary)

%% 2단계 (선택) — 명세서 Excel
[T, specFile] = st_export_test_specification();
disp(specFile)

%% 3단계 — 원본 Top Model과 Harness는 파이프라인이 저장하고 닫습니다
info = st_run_standalone_coverage_pipeline();
disp(info.PipelineId)

[code, summary, details] = st_check_standalone_coverage();
disp(code)                       % 1111111111 이어야 합니다
disp(summary)

%% 4단계 — 팀 제출 트리 (기존 트리는 지우고 다시 만듭니다)
tree = st_classify_standalone_results('PipelineId', info.PipelineId);
disp(tree.OutputDir)

%% 5단계 — 고객 제출용 최종 문서
[T, finalFile] = st_export_final_document('CoveragePipelineId', info.PipelineId);
winopen(finalFile)
```

결과 확인과 2단계 명세서를 뺀 짧은 코드입니다.

```matlab
%% 준비 — MATLAB을 켤 때마다
st_setup
st_select_target_model           % 처음 1회, 또는 모델을 바꿀 때만
st_set_standalone_coverage_root  % 필수. 3단계 결과를 D:\model_result\<Top Model>에 둡니다
R = st_pre_validate_targets();   % Excel을 고칠 때마다
disp(R)

%% 1단계 — Harness 생성 → 실행 → 결과 정리
st_run_from_harness
st_collect_per_cut_results

%% 3단계 — 원본 Top Model과 Harness는 파이프라인이 저장하고 닫습니다
info = st_run_standalone_coverage_pipeline();
disp(info.PipelineId)

[code, summary, details] = st_check_standalone_coverage();
disp(code)                       % 1111111111 이어야 합니다
disp(summary)

%% 4단계 — 팀 제출 트리
tree = st_classify_standalone_results('PipelineId', info.PipelineId);
disp(tree.OutputDir)

%% 5단계 — 고객 제출용 최종 문서
[T, finalFile] = st_export_final_document('CoveragePipelineId', info.PipelineId);
winopen(finalFile)
```

## 10. 상황별로 무엇을 부를까

| 상황 | 코드 |
| --- | --- |
| MATLAB을 새로 켰다 | `st_setup` |
| 대상 모델을 바꾼다 | `st_select_target_model(true)` 후 `st_set_standalone_coverage_root` |
| Harness가 이미 다 있다 | `st_run_after_harness` |
| 입력 MAT이나 SLDV 설정을 바꿨다 | `st_run_from_harness('PreparationMode','FORCE','FromStage','SLDV')` |
| Assessment를 바꿨다 | `st_run_from_harness('PreparationMode','FORCE','FromStage','ASSESSMENT')` |
| 준비만 하고 실행은 나중에 | `st_run_from_harness('ExecuteTests', false)` |
| 준비는 그대로 두고 실행만 | `st_run_from_harness('FromStage','EXECUTE')` |
| 실행과 결과 정리를 한 번에 | `st_run_from_harness('AutoCollect', true)` |
| Harness에 없는 SLDV 입력을 버리지 말고 멈춰야 한다 | `st_run_from_harness('IgnoreUnexpectedSldvInputs', false)` |
| 하나라도 실패하면 멈춰야 한다 | `st_run_from_harness('FailOnNonPass', true)` |
| Coverage 필터 설정만 바꿨다 | 준비는 그대로. `st_collect_per_cut_results`만 다시 |
| 3단계에서 팀 제출 트리까지 한 번에 | `st_run_standalone_coverage_pipeline('ClassifyResults', true)` |
| 제출물을 Test Manager에서 연다 | `st_open_standalone_test_manager` |
| 제출물의 Results까지 본다 | `st_run_standalone_coverage_pipeline('SaveTestResult', true)` 후 `st_open_standalone_test_manager('ImportResults', true)` |
| 팀 제출 트리를 다시 만든다 | `st_classify_standalone_results` |
| 오래 걸린 앞 단계를 절대 다시 돌리지 않고 중간부터 | [재시작](reference/restart.md)의 `st_run_from_stage` |
| 단계를 하나씩 끊어서 돌린다 | [단계별로 끊어서 실행하기](reference/step-by-step.md) |

## 11. 자주 막히는 곳

| 증상 | 대처 |
| --- | --- |
| `st_setup` 뒤에도 명령을 못 찾는다 | Current Folder가 클론 루트가 아닙니다 |
| 고쳐진 오류가 다시 난다 | 클론이 예전 커밋입니다. `git pull` 후 MATLAB에서 `which -all st_setup` |
| `CUTPath`를 찾을 수 없다 | 블록 이름의 철자·공백을 확인합니다. Top Model 이름은 빼도 되지만 그 아래 경로는 빠짐없이 적어야 합니다 |
| SLDV MAT을 찾을 수 없다 | `SldvDataFile` 상대 경로 기준은 Excel 파일이 있는 폴더입니다 |
| Atomic이 아니라고 중단 | `FILE+SLDV`/`GENERATE`는 Atomic Subsystem이 필요합니다. 라이브러리 링크된 CUT은 원본 라이브러리에서 고치거나 `cfg.DisableLibraryLinkForSldvTargets`를 검토합니다 |
| `Scenario`와 `Iteration` 수가 안 맞는다 | `'PreparationMode','FORCE','FromStage','SLDV'`로 다시 돌립니다 |
| 기대값이 마음대로 바뀌었다 | `ExpectedUpdateMode`가 비어 있으면 `APPLY`입니다. `OFF`로 내리십시오 |
| 실행은 끝났는데 판정이나 보고서가 없다 | 결과 정리를 안 했거나, 정리 뒤 다시 돌렸습니다. `st_collect_per_cut_results` |
| 커버리지에 필터가 안 걸린 것 같다 | 실행 결과가 아니라 결과 정리 **후** 보고서를 보십시오. 필터는 그때 붙습니다 |
| 커버리지가 `0/0`, `N/A` | 필터가 목표를 다 뺀 정상 상태일 수 있습니다 |
| 빌드 파일 이름이 260자를 넘는다는 오류 | 결과 루트를 짧게(`st_set_standalone_coverage_root`), 그래도 나면 `cfg.StandaloneBuildCacheDir`에 `'D:\stt_build'` 같은 짧은 경로 |
| 필터 사유가 없다고 중단 | `CoverageFilterRationale`을 채우십시오 |
| 같은 이름의 모델이 열려 있다고 멈춘다 | `CloseSourceModel`을 `false`로 줬거나 저장에 실패한 경우입니다. 저장하고 닫거나 MATLAB 재시작 |
| 검사 코드에 `0`이 있다 | `details` 표에서 그 CUT의 원인을 보고 3단계를 다시 |
| 명세서나 최종 문서가 `SpecificationUnsaved`로 멈춘다 | 오류 메시지에 적힌 모델·Harness를 열어 보고 저장하거나 닫습니다 |
| 파이프라인이 `StandalonePipelineHarnessInternalizeFailed`로 멈춘다 | 외부 저장 Harness를 모델 안으로 옮기다 실패했습니다. 모델을 열어 그 Harness의 저장 방식을 내부로 바꾸고 저장 |
| 같은 이름의 Test File이 열려 있다고 멈춘다 | `st_open_standalone_test_manager('ClearTestManager', true)` |
| 연 Test Manager에 Results가 없다 | `'ImportResults', true`를 주고, 파이프라인도 `'SaveTestResult', true`로 돌렸어야 합니다 |
| CVF 뷰어 이름이 `n/a` | 그 CVF 옆의 standalone 모델을 먼저 여십시오(원본 Top Model 아님) |
| 재배치가 출력 폴더 때문에 멈춘다 | 그 폴더에 세 갈래 말고 다른 것이 있습니다. 옮기거나 `OutputDir`을 바꿉니다 |
| `Metadata`의 `ResultRunId`가 옛 실행이다 | 결과 정리를 다시 하고 최종 문서를 다시 만듭니다 |
| `RemovedExecutionMode` | `ExecutionMode='AUTO'`는 없어졌습니다. `'BATCH'` 또는 `'PER_CUT'` |

오류 식별자별 대처는 [문제 해결](reference/troubleshooting.md)에 있습니다.

## 12. 반드시 지킬 것

- 1단계는 **모델과 Test File을 저장합니다.** 처음 돌리기 전에 백업하십시오.
- 기대값 기본 정책은 `APPLY`입니다. 승인된 기준값이 있으면 먼저 `OFF`로 내리십시오.
- 실행이 끝나도 결과는 **자동으로 정리되지 않습니다.** `st_collect_per_cut_results`를
  부르십시오. 다시 돌렸으면 다시 정리하십시오.
- 3단계는 **원본 Top Model을 저장하고 닫은 뒤 시작합니다.** 저장하면 안 되는 변경은
  먼저 되돌리십시오.
- 제출물은 폴더 전체를 복사해 전달하십시오.
- 실제 모델·Excel·MAT·MLDATX와 `result/`는 **Git에 올리지 않습니다.**

## 13. 더 자세히 볼 문서

| 찾는 것 | 문서 |
| --- | --- |
| 용어 (CUT, Harness, CVF, SLDV…) | [용어집](reference/glossary.md) |
| Excel 열의 뜻, 기본값, 잘못 적었을 때 | [관리 Excel 열 사전](reference/workbook-reference.md) |
| `st_config.m` 설정 | [설정 사전](reference/config-reference.md) |
| 모든 명령과 옵션 전체 | [실행 명령 사전](reference/execution-commands.md) |
| 단계마다 내부에서 일어나는 일 | [운영자 매뉴얼](reference/operator-manual.md) |
| 단계를 하나씩 끊어서 실행 | [단계별로 끊어서 실행하기](reference/step-by-step.md) |
| 오류 대처 | [문제 해결](reference/troubleshooting.md) |
| 명세서 Excel의 열 구성 | [테스트 명세서 추출](reference/test-specification.md) |
| 최종 문서의 시트 구성과 판정 출처 | [최종 문서 추출](reference/final-document.md) |
| standalone 파이프라인의 경계와 산출물 규칙 | [Standalone Coverage 파이프라인](reference/standalone-coverage-pipeline.md) |
| 제출물을 수동으로 열기 | [결과 열기](reference/open-results.md) |
| 앞 단계를 보존한 채 중간부터 재시작, 결과 재생성 | [재시작](reference/restart.md) |
| 전체 문서 목록 | [문서 지도](README.md) |

### 줄여 부르는 이름

팀에서 줄여 부르는 이름과 실제 함수 이름이 다릅니다. MATLAB에는 오른쪽 이름을
입력합니다.

| 줄여 부르는 이름 | 실제 함수 이름 |
| --- | --- |
| `st_select_model` | `st_select_target_model` |
| `st_pre_validate` | `st_pre_validate_targets` |
| `st_export_spec` | `st_export_test_specification` |
| `st_report` | `st_generate_test_report` |
| `st_collect` | `st_collect_per_cut_results` |
| `st_check_standalone` | `st_check_standalone_coverage` |
| `st_open_standalone` | `st_open_standalone_test_manager` |
| `st_export_final` | `st_export_final_document` |
