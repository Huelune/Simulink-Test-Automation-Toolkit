# 모델별 profile 등록과 전환

profile은 모델·관리 Excel·Test File·일반 결과 root·Standalone root를 묶습니다.
동시에 여러 모델을 실행하는 기능이 아니라, 하나씩 선택해 독립적으로 관리하는 기능입니다.
모델마다 서로 겹치지 않는 결과 root와 Test File을 사용하세요.

## 1. 한 번 등록

```matlab
st_setup
st_save_model_profile('MODEL_A', ...
    'ModelFile', 'D:\models\MODEL_A\MODEL_A.slx', ...
    'ManagementExcel', 'D:\models\MODEL_A\TestManagement.xlsx', ...
    'ManagementSheet', 'Targets', ...
    'TestFile', 'D:\results\MODEL_A\MODEL_A.mldatx', ...
    'TestSuiteName', 'New Test Suite 1', ...
    'OutputRoot', 'D:\results\MODEL_A', ...
    'StandaloneCoverageRootDir', 'D:\delivery\MODEL_A');
```

Model/Excel은 이미 존재해야 합니다. Test File은 준비 단계가 새로 생성할 수 있습니다.
동일 이름을 갱신할 때만 위 인수에 `'Overwrite', true`를 추가합니다.
등록만으로 모델을 열거나 profile을 선택하지 않습니다.

## 2. 이름 또는 목록으로 선택

```matlab
st_setup
st_list_model_profiles();
cfg = st_select_model_profile('MODEL_A');
disp(cfg.ModelFile)
disp(cfg.ManagementExcel)
disp(cfg.TestFile)
disp(cfg.WorkflowStateFile)
disp(cfg.StandaloneCoverageRootDir)
```

```matlab
st_setup
cfg = st_select_model_profile(); % 목록 선택; 취소 시 기존 선택 유지
```

다른 모델도 1번 코드로 별도 이름과 경로를 등록한 뒤 선택합니다. A → B → A로
돌아오면 A의 checkpoint·SLDV·결과 경로를 다시 사용합니다. 이름이 같은 다른 모델이
로드돼 있으면 자동으로 닫지 않고 선택을 거부합니다. 전환 전 현재 작업을 저장하세요.

`model_profiles.mat`와 `runtime_target.mat`는 로컬 설정이며 Git에 포함하지 않습니다.
다른 PC에서는 경로를 다시 등록합니다. 사용자 callback·base workspace·프로젝트
dependency를 profile이 자동 초기화해 주지는 않습니다.

## 3. 기존 단일 모델 설정으로 복귀

```matlab
st_setup
cfg = st_select_model_profile('');
```

기존 설정을 삭제하지 않고 profile 적용만 해제합니다. 기존 `st_select_target_model`로
다른 모델을 선택하면 활성 profile을 해제해 서로 다른 모델/Excel 설정이 섞이지 않게 합니다.
