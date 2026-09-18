# 처음 시작하기

MATLAB과 Simulink Test를 처음 쓰는 사람을 기준으로 설명합니다. 용어가 낯설면
[용어집](glossary.md)을 옆에 두고 읽으십시오.

> 이미 써 본 사람은 [내부 표준 명령](team-commands.md)가 더 빠릅니다.

## 1. 이 도구가 해 주는 일

Simulink 모델의 서브시스템(CUT)을 하나씩 테스트하려면 보통 다음 작업을 손으로
해야 합니다.

1. CUT마다 Test Harness를 만든다
2. Harness에 넣을 입력 신호를 만든다
3. 출력이 얼마여야 하는지 `verify` 문장을 적는다
4. Test Manager에 Test Case를 만들고 입력 개수만큼 Iteration을 건다
5. 실행하고, 커버리지를 뽑고, 보고서를 만든다

CUT이 20개면 이 작업을 20번 반복해야 합니다. 이 도구는 **Excel 한 장에 CUT
목록을 적어 두면 1번부터 5번까지를 자동으로 수행합니다.**

```text
TestManagement.xlsx  (무엇을 테스트할지 적는 표)
        │
        ▼
  Harness 생성 → 입력 생성 → verify 생성 → Test Case 생성
        │
        ▼
  테스트 실행 → 기대값 갱신 후 재실행 → Coverage 수집
        │
        ▼
  standalone 제출물 (독립 모델 + CVF + CVT + HTML + 요약 Excel)
```

## 2. 전체 순서 (이것만 알면 됩니다)

평소 쓰는 명령은 네 개입니다.

```matlab
st_setup
st_pre_validate_targets
st_run_from_harness

st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
```

| 명령 | 하는 일 |
| --- | --- |
| `st_setup` | 이 도구의 명령을 MATLAB이 찾을 수 있게 경로에 등록합니다 |
| `st_pre_validate_targets` | Excel에 적은 CUT 경로가 실제로 있는지 확인합니다 |
| `st_run_from_harness` | Harness·입력·verify·Test Case를 만들고 테스트를 실행합니다 |
| `st_run_standalone_coverage_pipeline` | 그 결과를 독립 실행 가능한 제출물로 묶습니다 |

각 단계의 자세한 내용은 아래에서 하나씩 설명합니다. 나머지 명령은 전부
선택 사항이며, 필요해질 때 [문서 지도](README.md)에서 찾으면 됩니다.

## 3. 준비물

### 3.1 설치해야 하는 MathWorks 제품

| 제품 | 필요 여부 | 없으면 |
| --- | --- | --- |
| MATLAB R2025b | 필수 | 실행 불가 |
| Simulink | 필수 | 실행 불가 |
| Simulink Test | 필수 | Harness·Test Manager 기능 전부 불가 |
| Simulink Coverage | 커버리지를 쓸 때 필수 | 커버리지·CVF·standalone 제출물 불가 |
| Simulink Design Verifier | `SldvMode=GENERATE`를 쓸 때만 | 입력 자동 생성만 불가 |

R2025b가 현재 기준 환경입니다. 다른 릴리스에서의 동작은 아직 확인하지 않았습니다.

### 3.2 준비해야 하는 파일

- 테스트할 Simulink 모델(`.slx`)과 그 모델이 참조하는 파일들
- CUT 목록을 적을 `TestManagement.xlsx` (저장소 루트)

### 3.3 실행 전 주의

이 도구는 **모델과 Test File을 실제로 수정합니다.** 처음 돌리기 전에 확인하십시오.

| 항목 | 확인 |
| --- | --- |
| 백업 | 모델·Excel·Test File을 백업했는가 |
| 저장 상태 | 열려 있는 모델과 Test File을 저장하고 닫았는가 |
| 기대값 정책 | 기본값이 `APPLY`입니다. [7장](#7-기대값-자동-갱신apply-주의)을 읽었는가 |

## 4. 설치와 경로 등록

### 4.1 저장소 받기

```bash
git clone https://github.com/Huelune/Simulink-Test-Automation-Toolkit.git
```

### 4.2 MATLAB에서 열기

1. MATLAB을 실행합니다.
2. 왼쪽 위 **Current Folder** 경로 칸에 방금 받은 폴더(`st_setup.m`이 보이는 폴더)를
   지정합니다. 이 도구의 모든 명령은 이 폴더를 현재 폴더로 둔 상태에서 실행합니다.
3. 가운데 아래 **Command Window**에 명령을 입력합니다.

### 4.3 `st_setup`

```matlab
st_setup
```

이 도구의 명령들을 MATLAB이 찾을 수 있게 경로에 등록하고 `result/` 폴더를 만듭니다.
**MATLAB을 새로 켤 때마다 한 번씩 실행해야 합니다.** 등록은 그 MATLAB 세션에만
유효하며 저장되지 않습니다.

성공하면 다음과 같이 출력됩니다.

```text
Automation project path added: D:\...\Simulink-Test-Automation-Toolkit
Source path added            : D:\...\Simulink-Test-Automation-Toolkit\src
```

### 4.4 MATLAB 명령 읽는 법

이 문서의 명령은 대부분 다음 형태입니다.

```matlab
st_run_standalone_coverage_pipeline('Action','ALL', 'ContinueOnFailure', true)
```

- 맨 앞이 실행할 명령입니다.
- 괄호 안은 `'옵션이름', 값` 쌍이며 순서는 상관없습니다. 필요한 것만 적으면 되고,
  적지 않은 옵션은 기본값이 쓰입니다.
- 결과를 변수에 받으려면 왼쪽에 `변수 = `를 붙입니다.

```matlab
info = st_run_standalone_coverage_pipeline('Action','ALL');
disp(info)
```

명령이 오래 걸릴 때 Command Window가 멈춘 것처럼 보이는 것은 정상입니다. Harness
생성과 SLDV 분석은 모델 크기에 따라 몇 분 이상 걸립니다. 지금 어디서 기다리는지는
**마지막 `START` 로그**로 확인합니다.

## 5. 대상 모델 고르기

처음 한 번, 또는 대상 모델을 바꿀 때만 실행합니다.

```matlab
st_select_target_model
```

목록에서 Top Model을 고르면 선택 결과가 `runtime_target.mat`에 저장됩니다. 이후
실행에서는 그 선택을 그대로 재사용하므로 다시 부를 필요가 없습니다.

`runtime_target.mat`은 Git에 올라가지 않으므로 저장소를 갱신해도 다른 사람의 모델
선택과 충돌하지 않습니다. 모델 이름을 추적되는 코드 파일에 적지 않는 이유도
이것입니다.

모델을 다시 고르려면:

```matlab
st_select_target_model(true)
```

## 6. 관리 Excel 채우기

저장소 루트의 `TestManagement.xlsx`에 `Targets` 시트를 만들고 CUT을 한 줄씩
적습니다. 최소로 필요한 열은 네 개입니다.

| 열 | 뜻 | 예 |
| --- | --- | --- |
| `CUTName` | 대상 Subsystem 이름 | `Controller` |
| `CUTPath` | Top Model부터의 전체 경로 | `TopModel/Logic/Controller` |
| `HarnessName` | 만들거나 재사용할 Harness 이름 | `Controller_Harness` |
| `TestCaseName` | Test Manager에 만들 Test Case 이름 | `Controller_TC` |

나머지 열은 전부 선택입니다. 각 열의 역할과 기본값은
[관리 Excel 열 사전](workbook-reference.md)에 전부 정리되어 있습니다.

### CUTPath를 손으로 적기 어려울 때

경로를 일일이 찾아 적는 대신 보조 명령을 쓸 수 있습니다.

```matlab
st_export_subsystem_paths       % 모델의 모든 Subsystem 경로를 Excel 시트로 뽑기
st_fill_temp_paths_from_indent  % Excel 들여쓰기 계층을 읽어 빈 CUTPath 채우기
st_find_target_paths            % 같은 이름 후보를 문맥으로 순위화해 고르기
```

세 명령 모두 **관리 Excel을 바꿉니다. 실행 전에 백업하십시오.**

### standalone 제출물을 만들 예정이라면

standalone pipeline은 각 활성 행이 다음 조합을 갖출 것을 요구합니다.

```text
CoverageFilterMode      = ALL_CONTENT
CoverageBoundaryMode    = CUT_ONLY
CoverageFilterAction    = EXCLUDE
CoverageFilterRationale = (비어 있지 않은 사유)
```

`CoverageFilterRationale`을 비워 두면 실행되지 않습니다. 나중에 커버리지를 검토하는
사람이 "왜 이 블록을 뺐는가"를 알 수 없으면 수치를 신뢰할 수 없기 때문에
강제합니다.

## 7. 기대값 자동 갱신(`APPLY`) 주의

테스트가 실패하면, 이 도구는 기본 설정에서 **실제 출력값을 정답으로 간주해
`verify` 문장의 기대값을 그 값으로 고쳐 쓰고 다시 실행합니다.**

아직 정답이 정해지지 않은 초기 단계에서 기준값을 만들기 위한 기능입니다. **이미
승인된 기준값이 있다면 값이 덮어써지므로 반드시 꺼야 합니다.**

| 끄는 방법 | 범위 |
| --- | --- |
| Excel의 `ExpectedUpdateMode` 열을 `OFF` | 해당 행만 |
| `src/config/st_config.m`의 `cfg.ExpectedUpdateMode = 'OFF'` | 전체 |

standalone pipeline은 준비된 자산을 복사해 실행하기만 하므로 기대값을 갱신하지
않습니다. 기대값이 바뀌는 것은 `st_run_from_harness` 단계입니다.

## 8. 실행 전 점검 — `st_pre_validate_targets`

```matlab
st_pre_validate_targets
```

Excel에 적은 경로가 실제로 존재하는지, 그 블록이 Subsystem이 맞는지를 **모델을
바꾸지 않고** 확인합니다. 결과는 `result/reports/PreValidationResult.ini`에
저장됩니다.

여기서 걸리는 문제는 대부분 `CUTPath` 오타이거나, 모델 이름부터 시작하지 않는
경로입니다.

## 9. 준비와 실행 — `st_run_from_harness`

```matlab
st_run_from_harness
```

한 번에 다음을 수행합니다.

```text
HARNESS          없는 Harness 생성 (기존 것은 지우지 않습니다)
SLDV             입력 데이터 준비 (OFF/FILE/GENERATE 전부 포함)
HARNESS_CONFIG   StopTime 등 Harness 설정
SIGNAL_EDITOR    입력 Scenario 생성과 연결
ASSESSMENT       verify 문장 구성
TEST_MANAGER     Test File, Test Case, Iteration 구성
ALIGNMENT        Scenario와 Iteration 정렬 검사 (검사만)
EXECUTE          테스트 실행 → 기대값 갱신 → 재실행 → 실행 기록 저장
```

여기까지가 workflow입니다. **보고서는 자동으로 만들어지지 않습니다.**

Harness가 이미 전부 있으면 생성 단계를 건너뛰는 진입점을 쓸 수 있습니다.

```matlab
st_run_after_harness
```

### 두 번째 실행부터는 빨라집니다

각 단계가 성공하면 그 시점의 입력 지문을 `result/state/`에 저장합니다. 다음
실행에서 Excel·설정·모델·입력이 그대로면 그 단계를 건너뛰고 재사용합니다. Harness
생성처럼 몇 분씩 걸리는 단계를 매번 다시 하지 않기 위한 장치입니다.

캐시를 무시하고 처음부터 다시 하려면:

```matlab
st_run_from_harness('PreparationMode','FORCE');
```

특정 단계부터만 다시 하려면:

```matlab
st_run_from_harness('PreparationMode','FORCE', 'FromStage','SLDV');
```

### 결과 정리하고 보기

실행은 `result/run_records/`에 기록만 남기고 끝납니다. Test Manager의 결과는 그
MATLAB 세션 안에서만 살아 있어서, 나중에 보고서를 만들 수 있도록 저장해 두는
것입니다.

```matlab
st_generate_test_report                 % 기본 BATCH로 돌렸을 때
% 'ExecutionMode','PER_CUT'으로 돌렸으면: st_collect_per_cut_results

cfg = st_config();
winopen(cfg.LatestSummaryFile)
```

`result/runs/` 또는 `result/per_cut_runs/` 아래에 실행별 상세 결과가 저장됩니다.
커버리지 필터(CVF)도 이 단계에서 만들어져 결과에 붙습니다.

## 10. 제출물 만들기 — `st_run_standalone_coverage_pipeline`

`st_run_from_harness`가 끝난 뒤 실행합니다. Harness를 **독립 실행 가능한 모델**로
떼어내 실행하고, 커버리지 결과와 부속 파일을 제출 가능한 형태로 묶습니다.

### 실행 전 확인

- 원본 Top Model과 Test File을 저장했는가
- **Top Model과 열린 Harness를 닫았는가** — 복사된 작업 공간의 모델과 이름이
  충돌합니다

### 실행

```matlab
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
```

| 옵션 | 왜 이 값인가 |
| --- | --- |
| `'Action','ALL'` | EXECUTE → PACKAGE → SUMMARY를 한 번에 수행합니다 |
| `'ContinueOnFailure', true` | 한 CUT이 실패해도 나머지를 계속 처리합니다 |
| `'FailOnNonPass', false` | 통과하지 못한 대상이 있어도 MATLAB 오류를 내지 않습니다. 실패는 결과 표에서 확인합니다 |

### 결과 확인

```matlab
[code, summary, details] = st_check_standalone_coverage();
disp(code)
disp(summary)
disp(details)
```

`1111111111`이고 `summary.Status = 'PASS'`면 정상입니다. 화면 출력은 최대 20줄이며
전체 CUT 결과는 `details` 표에 있습니다.

읽기 전용 검사이므로 모델·Test File·CVF를 저장하거나 바꾸지 않습니다.

### 만들어지는 것

각 CUT 폴더(`{NUM}_UT_REQ_{TC_NAME}`)에 다음이 들어갑니다.

- standalone 모델 (`.slx`)
- Signal Editor Input MAT
- `UT_REQ_{TC_NAME}.cvf` — 적용한 커버리지 필터
- `UT_REQ_{TC_NAME}.cvt` — 커버리지 원본 데이터
- `UT_REQ_{TC_NAME}.html` — Coverage 보고서
- target manifest

root에는 재배선된 Test File과 11열짜리 `CoverageSummary.xlsx`가 생깁니다.

제출물을 Test Manager에서 여는 방법은 [결과 열기](manual/open-results.md)에
있습니다.

## 11. 전체 코드 한 번에

```matlab
% --- MATLAB 세션마다 한 번 ---
st_setup

% --- 처음 한 번, 또는 대상 모델을 바꿀 때 ---
st_select_target_model

% --- Excel을 고칠 때마다 ---
st_pre_validate_targets

% --- 준비와 테스트 실행 ---
st_run_from_harness

% --- 제출물 생성 ---
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);

% --- 제출물 확인 ---
[code, summary, details] = st_check_standalone_coverage();
disp(code)
```

## 12. 다음에 읽을 문서

| 하고 싶은 것 | 문서 |
| --- | --- |
| Excel 각 열이 무슨 뜻인지 | [관리 Excel 열 사전](workbook-reference.md) |
| 기본 동작을 바꾸고 싶다 | [설정 사전](config-reference.md) |
| 오류가 났을 때 | [문제 해결](troubleshooting.md) |
| 단계별로 실제 무슨 일이 일어나는지 | [운영자 매뉴얼](operator-manual.md) |
| 복사해서 바로 쓸 코드 | [수동 실행 안내](manual/README.md) |
| 단계별로 끊어서 실행하기 | [단계별 실행](manual/step-by-step.md) |
| 제출물을 Test Manager에서 열기 | [결과 열기](manual/open-results.md) |
| 실행 없이 테스트 명세서 Excel 뽑기 | [테스트 명세서 추출](test-specification.md) |

다음은 **필요해질 때만** 보면 되는 선택 기능입니다.

| 상황 | 문서 |
| --- | --- |
| 오래 걸리는 앞 단계를 보존한 채 중간부터 재시작한다 | [재시작](manual/restart.md) |
| 실제 모델 없이 예제로 연습한다 | [익명 예제 생성](manual/example.md) |
| 다른 PC에서 재실행할 번들을 만든다 | [내보내기 번들](export-bundle.md) |
| 도구 자체를 인증한다 | [종합 검증](verification.md) |
