# 익명 예제 생성 (선택 사항)

> 실제 모델로 바로 시작하려면 [처음 시작하기](../getting-started.md)를 보십시오.
> 이 문서는 **업무 모델을 건드리지 않고 흐름만 익히고 싶을 때** 씁니다.
>
> 예제는 임시 폴더에 만들어지고 기본 검색 경로 밖에 있으므로, 여기서만
> [모델 profile](model-profiles.md)로 경로를 지정합니다. 실제 모델에는 profile이
> 필요 없습니다.

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
실패 시 부분 생성물은 진단용으로 남습니다. 다시 생성할 때 새 디렉터리를 사용하십시오.

## 2. 준비와 실행

`DEMO` profile을 고른 뒤는 실제 모델과 똑같습니다.

```matlab
st_setup
st_select_model_profile('DEMO');
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
st_select_model_profile('');   % profile 해제
st_select_target_model         % 실제 모델 선택
```
