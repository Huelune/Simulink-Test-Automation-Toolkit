# 익명 예제 생성

실제 업무 모델 없이 2개 CUT, Dataset MAT, 관리 Excel을 로컬에서 생성합니다.
SLDV 분석은 필요하지 않으며 `FILE+MAT`를 사용합니다. 생성기는 테스트를 실행하지 않습니다.
한 CUT은 일반 Decision, 다른 CUT은 직계 하위 Subsystem 필터를 확인하기 위한 구조입니다.

## 1. 생성 및 등록

```matlab
st_setup
exampleDir = fullfile(tempdir, ['st_demo_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
demo = st_create_example(exampleDir);
st_save_model_profile('DEMO', ...
    'ModelFile', demo.ModelFile, ...
    'ManagementExcel', demo.ManagementExcel, ...
    'OutputRoot', demo.OutputRoot, ...
    'Overwrite', true);
cfg = st_select_model_profile('DEMO');
disp(demo)
```

이미 내용이 있는 디렉터리나 로드된 `ST_ExampleModel`을 덮어쓰지 않습니다.
실패 시 부분 생성물은 진단용으로 남습니다. 다시 생성할 때 새 디렉터리를 사용하세요.

## 2. 일반 준비와 기대값 구성

```matlab
st_setup
cfg = st_select_model_profile('DEMO');
[ready, checks] = st_check_readiness('Workflow','FROM_HARNESS','FromStage','HARNESS');
disp(checks)
assert(ready.Ready, 'Resolve readiness checks first.');
st_run_from_harness('PreparationMode','FORCE');
```

기본 `APPLY`로 생성된 초기 expected 값을 갱신할 수 있습니다. 완료 후 저장된 모델과
Test File을 확인하고 [Standalone 실행](standalone-run.md)의 profile 이름을
`DEMO`로 바꿔 실행합니다. CVF로 유효 objective가 없어지는 metric의 `0/0, N/A`는
오류가 아닙니다. 샘플의 실제 숫자와 report 모양은 R2025b 검증 대상으로 남겨 둡니다.
