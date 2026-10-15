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
| 2 | `LimitChain` | Saturation, Dead Zone, Rate Limiter, Abs, MinMax | MAT | 결정 단위 D. 입력이 Saturation 한계에 닿지 않아 하한 `[T]`, 상한 `[F]`. Abs는 `[F]` |
| 3 | `StateKeeper` | Delay(enable, reset), Discrete-Time Integrator(reset, 한계), Relay | MAT | `Enable`, `Reset`, `X < LL` 같은 결정 이름 |
| 4 | `GearSelect` | Multiport Switch, Switch Case(default 포함) | MAT, Scenario 2개 | 결과가 셋 이상이라 정적 `[T/F]`로 남는 블록 |
| 5 | `EnabledStage` | Enabled Subsystem(CUT 자신), Switch, Sign | SLDV `GENERATE` | Enable D, SLDV 경로 |
| 6 | `TriggeredStage` | 함수 호출 Subsystem(CUT 자신), Switch | SLDV `GENERATE` | `FcnTriggerPort` 자동 제외, `executed` 단독 결과 `[T]` |
| 7 | `FilteredParent` | Switch, 직계 하위 Subsystem 2개 | MAT | 하위 Subsystem 안의 Switch가 커버리지에서 빠지는 것 |

테스트 케이스 이름은 `{CUT}_{ID}`(`ModeSelect_90001` 등)이고 ID는 지어낸 번호입니다.
최종 문서의 `Test Case ID`와 `ID` 열이 규칙대로 나뉩니다. Harness 이름은 `{CUT}_Harness`
입니다. standalone 파이프라인이 요구하므로 모든 행이 `ALL_CONTENT` + `CUT_ONLY` + `EXCLUDE`와
사유를 갖습니다. 다른 CUT의 하위 Subsystem은 Gain 하나뿐인 Action Subsystem이라 빠져도 분기가
줄지 않습니다. 기대값 갱신은 모두 `DEFAULT`(`APPLY`)이므로 첫 실행에서 기대값이 실제 출력으로
채워지고 모든 행이 `PASS`가 됩니다.

### 기대 결과

2026-10-15 R2025b에서 전 과정을 돌린 결과입니다. 최종 문서 9행이 모두 `PASS`이고
standalone 검사 코드는 `1111111111`입니다. `Description`의 D 줄 결과는 다음과 같습니다.
`GENERATE` 행(90005, 90006)은 SLDV가 만든 Scenario 수에 따라 행 수가 달라질 수 있습니다.

| ID | CUT | D 줄 결과 (D1부터) | 읽는 법 |
| --- | --- | --- | --- |
| 90001 | `ModeSelect` 1행 | `T/F T/F T/F` | if, elseif, Switch를 모두 양쪽으로 탐 |
| 90001 | `ModeSelect` 2행 | `F F F` | 낮은 입력만 넣은 Scenario라 모두 거짓 |
| 90002 | `LimitChain` | `T/F T T/F T F F T/F T/F` | MinMax(정적), Dead Zone 하한 `T`, Saturation 하한 `T`·상한 `F`, Abs `F`(입력이 음수가 된 적 없음), Rate Limiter 둘 |
| 90003 | `StateKeeper` | `T/F` ×7 | Discrete-Time Integrator 3, Delay 2, Relay 2 |
| 90004 | `GearSelect` 2행 | `T/F T/F` | Multiport Switch, Switch Case는 정적 표기 |
| 90005 | `EnabledStage` | `T/F T/F T/F` | Enable, Switch, Sign(정적) |
| 90006 | `TriggeredStage` | `T T/F` | 함수 호출은 실행 여부만 `T`, Switch |
| 90007 | `FilteredParent` | `T/F` | 하위 Subsystem 안의 Switch는 빠짐 |

### 실행

`st_setup_demo` 한 줄이 데모를 실행할 준비를 다 합니다.

1. 데모 모델, 입력 MAT, 관리 Excel을 만듭니다(`st_create_demo_model`).
2. 데모 Excel을 저장소 루트의 `TestManagement.xlsx`로 넣습니다. 툴킷은 이 한 자리만 읽습니다.
   원래 파일은 `TestManagement.backup_<시각>.xlsx`로 남깁니다.
3. `runtime_target.mat`도 같은 방식으로 백업한 뒤, 대상 모델을 데모로 고르고 standalone 결과
   폴더를 `<데모 폴더>\model_result`로 정합니다.

```matlab
%% MATLAB을 새로 켠 뒤
st_setup
demo = st_setup_demo();          % 툴킷 폴더 옆에 만듭니다. 위치를 주려면 st_setup_demo('D:\st_demo')
st_pre_validate_targets();

%% 1단계 → 5단계 (사용자 매뉴얼 9장과 같습니다)
st_run_from_harness
st_collect_per_cut_results
[~, specFile] = st_export_test_specification();
info = st_run_standalone_coverage_pipeline();
code = st_check_standalone_coverage()            % 1111111111
[~, finalFile] = st_export_final_document('CoveragePipelineId', info.PipelineId);
winopen(finalFile)
```

- 데모 위치는 **툴킷과 같은 드라이브**여야 합니다. 드라이브가 다르면 standalone이
  `NoCommonExportRoot`로 멈춥니다([문제 해결](troubleshooting.md#nocommonexportroot)).
- **MATLAB을 새로 켠 세션에서 돌리십시오.** 같은 세션에서 데모 폴더를 지우고 다시 만들자 Harness
  생성 중 모델 저장이 실패한 적이 있습니다.
- 데모 결과는 이 저장소의 `result` 폴더에 실제 업무 결과와 함께 쌓입니다. 섞이지 않게 하려면
  **툴킷을 다른 폴더에 복사해서** 그 복사본에서 돌리십시오. 복사본에서 `st_setup`을 부르기 전에
  원래 툴킷을 경로에서 빼야 합니다.
- `GENERATE` 두 행 때문에 Simulink Design Verifier가 필요합니다. 없으면 `TestManagement.xlsx`에서
  No 5, 6 행의 `Enabled`를 `false`로 바꾸십시오.

실제 모델로 돌아갈 때는 백업을 되돌립니다. 백업 경로는 `demo.Backups`에 있습니다.

```matlab
for k = 1:numel(demo.Backups)
    original = regexprep(demo.Backups(k), '\.backup_\d{8}_\d{6}', '');
    copyfile(demo.Backups(k), original);
end
```

백업이 없었다면(처음 쓰는 클론) `st_select_target_model`로 실제 모델을 다시 고르고
`TestManagement.xlsx`를 새로 작성하십시오.

