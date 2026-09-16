# 처음 시작하기

MATLAB과 Simulink Test를 처음 쓰는 사람을 기준으로 설명합니다. 용어가 낯설면
[용어집](glossary.md)을 옆에 두고 읽으십시오.

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
  Excel · HTML · PDF 보고서 / 다른 PC로 보낼 제출물
```

## 2. 준비물

### 2.1 설치해야 하는 MathWorks 제품

| 제품 | 필요 여부 | 없으면 |
| --- | --- | --- |
| MATLAB R2025b | 필수 | 실행 불가 |
| Simulink | 필수 | 실행 불가 |
| Simulink Test | 필수 | Harness·Test Manager 기능 전부 불가 |
| Simulink Coverage | 커버리지를 쓸 때 필수 | 커버리지·CVF·커버리지 보고서 불가 |
| Simulink Design Verifier | `SldvMode=GENERATE`를 쓸 때만 | 입력 자동 생성만 불가 |

R2025b가 현재 기준 환경입니다. 다른 릴리스에서의 동작은 아직 확인하지 않았습니다.

### 2.2 준비해야 하는 파일

- 테스트할 Simulink 모델(`.slx`)과 그 모델이 참조하는 파일들
- CUT 목록을 적을 `TestManagement.xlsx`

모델이 아직 없어도 괜찮습니다. 4장에서 연습용 예제를 만들어 볼 수 있습니다.

## 3. 설치와 첫 실행

### 3.1 저장소 받기

```bash
git clone https://github.com/Huelune/Simulink-Test-Automation-Toolkit.git
```

### 3.2 MATLAB에서 열기

1. MATLAB을 실행합니다.
2. 왼쪽 위 **Current Folder** 경로 칸에 방금 받은 폴더(`st_setup.m`이 보이는 폴더)를
   지정합니다. 이 도구의 모든 명령은 이 폴더를 현재 폴더로 둔 상태에서 실행합니다.
3. 가운데 아래 **Command Window**에 명령을 입력합니다.

### 3.3 경로 등록

```matlab
st_setup
```

`st_setup`은 이 도구의 명령들을 MATLAB이 찾을 수 있게 경로에 등록하고 `result/`
폴더를 만듭니다. **MATLAB을 새로 켤 때마다 한 번씩 실행해야 합니다.** 등록은 그
MATLAB 세션에만 유효하며 저장되지 않습니다.

성공하면 다음과 같이 출력됩니다.

```text
Automation project path added: D:\...\Simulink-Test-Automation-Toolkit
Source path added            : D:\...\Simulink-Test-Automation-Toolkit\src
```

### 3.4 MATLAB 명령 읽는 법

이 문서의 명령은 대부분 다음 형태입니다.

```matlab
st_run_from_harness('ExecutionMode', 'PER_CUT', 'ReportMode', 'SUMMARY')
```

- `st_run_from_harness`가 실행할 명령입니다.
- 괄호 안은 `'옵션이름', 값` 쌍이며 순서는 상관없습니다. 필요한 것만 적으면
  되고, 적지 않은 옵션은 기본값이 쓰입니다.
- 결과를 변수에 받으려면 왼쪽에 `변수 = `를 붙입니다.

```matlab
info = st_run_from_harness();   % 결과를 info에 담기
disp(info)                      % 담긴 내용 보기
```

명령이 오래 걸릴 때 Command Window가 멈춘 것처럼 보이는 것은 정상입니다. Harness
생성과 SLDV 분석은 모델 크기에 따라 몇 분 이상 걸립니다.

## 4. 연습: 예제 모델로 한 바퀴 돌려 보기

실제 업무 모델을 건드리기 전에 자동 생성 예제로 흐름을 익히는 것을 권합니다.
이 예제는 모델·입력 MAT·관리 Excel을 임시 폴더에 새로 만들며, 기존 파일을
건드리지 않습니다.

### 4.1 예제 만들기

```matlab
st_setup
exampleDir = fullfile(tempdir, ['st_demo_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
demo = st_create_example(exampleDir);
disp(demo)
```

### 4.2 이 예제를 쓰겠다고 등록하기

```matlab
st_save_model_profile('DEMO', ...
    'ModelFile',       demo.ModelFile, ...
    'ManagementExcel', demo.ManagementExcel, ...
    'OutputRoot',      demo.OutputRoot, ...
    'Overwrite',       true);
cfg = st_select_model_profile('DEMO');
```

`st_save_model_profile`은 경로를 이름으로 묶어 저장만 합니다.
`st_select_model_profile`이 실제로 그 설정을 켭니다. 자세한 내용은
[모델 profile](manual/model-profiles.md)에 있습니다.

### 4.3 실행해도 되는 상태인지 먼저 확인

```matlab
[ready, checks] = st_check_readiness('Workflow','FROM_HARNESS','FromStage','HARNESS');
disp(checks)
```

`st_check_readiness`는 **아무것도 바꾸지 않고** 검사만 합니다. 파일이 있는지,
쓰기가 되는지, 앞 단계 결과가 유효한지를 봅니다. `ready.Ready`가 `true`면 다음으로
넘어갑니다. `false`면 `checks.Message` 열에 이유가 적혀 있습니다.

### 4.4 전체 실행

```matlab
st_run_from_harness('PreparationMode','FORCE');
```

Harness 생성부터 테스트 실행, 보고서 작성까지 한 번에 진행합니다.
`PreparationMode='FORCE'`는 "이전에 해 둔 것을 재사용하지 말고 처음부터 다시
하라"는 뜻입니다. 처음 실행이라 재사용할 것이 없으므로 결과는 같지만, 예제에서는
전체 흐름을 보기 위해 명시했습니다.

### 4.5 결과 보기

```matlab
winopen(fullfile(cfg.ResultDir, 'TestSummary.xlsx'))
```

`TestSummary.xlsx`에 전체 요약이, `result/runs/` 또는 `result/per_cut_runs/`
아래에 실행별 상세 결과가 저장됩니다.

커버리지에 `0/0`이나 `N/A`가 보여도 오류가 아닙니다. 필터 때문에 셀 수 있는
대상이 남지 않았다는 뜻입니다.

## 5. 실제 모델로 시작하기

### 5.1 모델 고르기

모델을 하나만 쓴다면 프로필 없이 다음 명령으로 충분합니다.

```matlab
st_setup
st_select_target_model
```

목록에서 Top Model을 고르면 선택 결과가 `runtime_target.mat`에 저장됩니다. 이
파일은 Git에 올라가지 않으므로 저장소를 갱신해도 선택이 유지됩니다.

모델을 여러 개 다룬다면 [모델 profile](manual/model-profiles.md)을 쓰십시오.

### 5.2 관리 Excel 채우기

저장소 루트의 `TestManagement.xlsx`에 `Targets`라는 시트를 만들고 CUT을 한 줄씩
적습니다. 최소로 필요한 열은 네 개입니다.

| 열 | 뜻 | 예 |
| --- | --- | --- |
| `CUTName` | 대상 Subsystem 이름 | `Controller` |
| `CUTPath` | Top Model부터의 전체 경로 | `TopModel/Logic/Controller` |
| `HarnessName` | 만들거나 재사용할 Harness 이름 | `Controller_Harness` |
| `TestCaseName` | Test Manager에 만들 Test Case 이름 | `Controller_TC` |

나머지 열은 전부 선택입니다. 각 열의 역할과 기본값은
[관리 Excel 열 사전](workbook-reference.md)에 전부 정리되어 있습니다.

### 5.3 CUTPath를 손으로 적기 어려울 때

경로를 일일이 찾아 적는 대신 보조 명령을 쓸 수 있습니다.

```matlab
st_export_subsystem_paths     % 모델의 모든 Subsystem 경로를 Excel 시트로 뽑기
st_fill_temp_paths_from_indent % Excel 들여쓰기 계층을 읽어 빈 CUTPath 채우기
st_find_target_paths          % 같은 이름 후보를 문맥으로 순위화해 고르기
```

`st_find_target_paths`는 한 Subsystem을 두 행에 중복 배정하지 않습니다. 중복이나
해결하지 못한 행이 있으면 Excel을 절반만 고치지 않고 그대로 중단합니다. **Excel을
바꾸는 명령이므로 실행 전에 파일을 백업하십시오.**

### 5.4 실행 전 점검

```matlab
st_pre_validate_targets
```

Excel에 적은 경로가 실제로 존재하는지, 그 블록이 Subsystem이 맞는지를 모델을
바꾸지 않고 확인합니다. 결과는 `result/reports/PreValidationResult.ini`에
저장됩니다.

### 5.5 실행

```matlab
st_run_from_harness
```

Harness가 없어도 되는 전체 실행입니다. Harness가 이미 전부 있다면 생성 단계를
건너뛰는 다음 명령을 씁니다.

```matlab
st_run_after_harness
```

## 6. 실행 전에 반드시 알아 둘 것

이 도구는 **모델과 Test File을 실제로 수정합니다.** 처음 돌리기 전에 다음을
확인하십시오.

| 항목 | 확인 |
| --- | --- |
| 백업 | 모델·Excel·Test File을 백업했는가 |
| 저장 상태 | 열려 있는 모델과 Test File을 저장하고 닫았는가 |
| 기대값 정책 | 기본값이 `APPLY`입니다. 아래 설명을 읽었는가 |

### 기대값 자동 갱신(`APPLY`)이 무엇인가

테스트가 실패하면, 이 도구는 기본 설정에서 **실제 출력값을 정답으로 간주해
`verify` 문장의 기대값을 그 값으로 고쳐 쓰고 다시 실행합니다.**

이것은 아직 정답이 정해지지 않은 초기 단계에서 기준값을 만들기 위한 기능입니다.
이미 승인된 기준값이 있다면 값이 덮어써지므로 반드시 꺼야 합니다.

| 끄는 방법 | 범위 |
| --- | --- |
| Excel의 `ExpectedUpdateMode` 열을 `OFF` | 해당 행만 |
| `src/config/st_config.m`의 `cfg.ExpectedUpdateMode = 'OFF'` | 전체 |

## 7. 다음에 읽을 문서

| 하고 싶은 것 | 문서 |
| --- | --- |
| Excel 각 열이 무슨 뜻인지 | [관리 Excel 열 사전](workbook-reference.md) |
| 기본 동작을 바꾸고 싶다 | [설정 사전](config-reference.md) |
| 어떤 명령이 있는지 전부 보기 | [실행 명령 사전](execution-commands.md) |
| 작업별 복사용 코드 | [수동 실행 안내](manual/README.md) |
| 단계별 동작과 주의사항 | [운영자 매뉴얼](operator-manual.md) |
| 오류가 났을 때 | [문제 해결](troubleshooting.md) |
