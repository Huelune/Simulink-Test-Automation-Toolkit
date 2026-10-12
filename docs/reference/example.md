# 익명 예제 생성 (선택 사항)

> 실제 모델로 바로 시작하려면 [사용자 매뉴얼](../user-manual.md)를 보십시오.
> 이 문서는 **업무 모델을 건드리지 않고 흐름만 익히고 싶을 때** 씁니다.
>
> 예제는 임시 폴더에 만들어지고 기본 검색 경로 밖에 있으므로, 대상 모델과 관리
> Excel을 직접 지정해야 합니다. 관리 Excel은 저장소 루트의
> `TestManagement.xlsx` 한 자리만 읽으므로 **기존 파일을 먼저 백업**하십시오.

생성기는 두 개입니다.

- `st_create_example`: CUT 2개짜리 최소 예제. SLDV 없이 흐름만 봅니다(1~4절).
- `st_create_demo_model`: 분기 블록을 고루 갖춘 CUT 7개짜리 데모. 모든 단계를 시험하고
  명세서·최종 문서 예시를 만들 때 씁니다([데모 모델](#데모-모델)).

실제 업무 모델 없이 2개 CUT, Dataset MAT, 관리 Excel을 로컬에서 생성합니다.
SLDV 분석은 필요하지 않으며 `FILE+MAT`를 사용합니다. 생성기는 테스트를 실행하지 않습니다.
한 CUT은 일반 Decision, 다른 CUT은 직계 하위 Subsystem 필터를 확인하기 위한 구조입니다.

## 1. 생성 및 등록

```matlab
st_setup
exampleDir = fullfile(tempdir, ['st_demo_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
demo = st_create_example(exampleDir);

% 기존 관리 Excel이 있으면 먼저 백업하십시오.
backup = fullfile(st_project_root(), 'TestManagement.backup.xlsx');
if isfile(fullfile(st_project_root(),'TestManagement.xlsx'))
    copyfile(fullfile(st_project_root(),'TestManagement.xlsx'), backup);
end
copyfile(demo.ManagementExcel, fullfile(st_project_root(),'TestManagement.xlsx'));

[~, demoModel] = fileparts(demo.ModelFile);
st_save_runtime_target_fields(fullfile(st_project_root(),'runtime_target.mat'), ...
    struct('TopModel', demoModel, 'ModelFile', demo.ModelFile));
cfg = st_config();
disp(demo)
```

이미 내용이 있는 디렉터리나 로드된 `ST_ExampleModel`을 덮어쓰지 않습니다.
실패 시 부분 생성물은 진단용으로 남습니다. 다시 생성할 때 새 디렉터리를 사용하십시오.

## 2. 준비와 실행

대상을 지정한 뒤는 실제 모델과 똑같습니다.

```matlab
st_setup
st_pre_validate_targets
st_run_from_harness('PreparationMode','FORCE');
```

기본 기대값 정책이 `APPLY`이므로 초기 expected 값이 실제 출력으로 갱신됩니다.

## 3. Standalone 제출물까지

```matlab
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);

[code, summary, details] = st_check_standalone_coverage();
disp(code)
```

CVF로 유효 objective가 없어진 metric의 `0/0`, `N/A`는 오류가 아닙니다. 샘플의 실제
숫자와 report 모양은 R2025b 검증 대상으로 남겨 둡니다.

## 4. 실제 모델로 돌아가기

```matlab
% 백업해 둔 관리 Excel을 되돌린 뒤 실제 모델을 다시 고릅니다.
copyfile(fullfile(st_project_root(),'TestManagement.backup.xlsx'), ...
    fullfile(st_project_root(),'TestManagement.xlsx'));
st_select_target_model
```

## 데모 모델

`st_create_demo_model`은 지금까지의 기능을 한 번에 지나가는 데모를 만듭니다. 모델
`ST_DemoModel`, CUT별 Dataset MAT(`inputs/`), 관리 Excel(`TestManagement.demo.xlsx`)이
생깁니다. 모델·CUT·블록·신호 이름이 모두 지어낸 것이라 Harness, 보고서, 명세서, 최종
문서를 캡처해 매뉴얼이나 교육 자료에 그대로 써도 됩니다.

### CUT 구성

| No | CUT | 분기 블록 | 입력 | 보려는 것 |
| --- | --- | --- | --- | --- |
| 1 | `ModeSelect` | If(if, elseif, else), Switch | MAT, Scenario 2개 | If가 D를 조건마다 받는 것. 두 번째 Scenario는 모든 분기가 `[F]` |
| 2 | `LimitChain` | Saturation, Dead Zone, Rate Limiter, Abs, MinMax | MAT | 결정 단위 D. 입력이 Saturation 한계에 닿지 않아 하한 `[T]`, 상한 `[F]` |
| 3 | `StateKeeper` | Delay(enable, reset), Discrete-Time Integrator(reset, 한계), Relay | MAT | `Enable`, `Reset`, `X < LL` 같은 결정 이름 |
| 4 | `GearSelect` | Multiport Switch, Switch Case(default 포함) | MAT, Scenario 2개 | 결과가 셋 이상이라 정적 `[T/F]`로 남는 블록 |
| 5 | `EnabledStage` | Enabled Subsystem(CUT 자신), Switch, Sign | SLDV `GENERATE` | Enable D, SLDV 경로 |
| 6 | `TriggeredStage` | 함수 호출 Subsystem(CUT 자신), Switch | SLDV `GENERATE` | `FcnTriggerPort` 자동 제외, `executed` 단독 결과 `[T]` |
| 7 | `FilteredParent` | Switch, 직계 하위 Subsystem 2개 | MAT | `ALL_CONTENT` + `EXCLUDE`, `CUT_ONLY` 경계 |

테스트 케이스 이름은 `{CUT}_{ID}`(`ModeSelect_90001` 등)이고 ID는 지어낸 번호입니다.
최종 문서의 `Test Case ID`와 `ID` 열이 규칙대로 나뉩니다. Harness 이름은 `{CUT}_Harness`
입니다. 기대값 갱신은 모두 `DEFAULT`(`APPLY`)이므로 첫 실행에서 기대값이 실제 출력으로
채워지고 모든 행이 `PASS`가 됩니다.

### 실행

관리 Excel과 `result`가 저장소 루트 한 자리라서, 업무 결과와 섞이지 않게 **툴킷을 다른
폴더에 복사해서** 돌리는 것을 권합니다. 복사본에서 `st_setup`을 부르기 전에 원래 툴킷을
경로에서 빼십시오.

```matlab
% 툴킷 복사본의 루트에서
st_setup
demo = st_create_demo_model(fullfile(tempdir, 'st_demo_model'));
copyfile(demo.ManagementExcel, fullfile(st_project_root(), 'TestManagement.xlsx'));
st_save_runtime_target_fields(fullfile(st_project_root(), 'runtime_target.mat'), ...
    struct('TopModel', demo.TopModel, 'ModelFile', demo.ModelFile));
st_set_standalone_coverage_root(fullfile(tempdir, 'st_demo_result'));
```

그다음은 [사용자 매뉴얼 9장](../user-manual.md#9-복사용-전체-코드)의 전체 코드를 그대로
씁니다(`st_select_target_model`은 위에서 대신했으므로 건너뜁니다).

`GENERATE` 두 행 때문에 Simulink Design Verifier가 필요합니다. 없으면 관리 Excel에서
No 5, 6 행의 `Enabled`를 `false`로 바꾸십시오.

