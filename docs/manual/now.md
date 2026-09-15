# 지금 할 일

라이브러리 링크된 CUT에서 standalone Harness export가 멈추던 문제를 고쳤습니다.
이 파일 하나만 보면 됩니다. 다른 문서는 여기서 안내할 때만 여세요.

## 1. export 다시 실행

```matlab
st_setup
info = st_export_test_bundle('ExecutionModelMode', 'STANDALONE_HARNESS');
```

`Toolbox products` 단계에서 오래 멈춘다면 그 분석을 끄고 다시 실행하세요.
manifest의 `RequiredProducts`는 번들 README용 안내일 뿐 어떤 코드도 읽지 않습니다.

```matlab
info = st_export_test_bundle('ExecutionModelMode', 'STANDALONE_HARNESS', ...
    'AnalyzeProducts', false);
```

지금까지 쓰던 모델 선택(`runtime_target.mat`)을 그대로 씁니다. profile을 만들 필요
없습니다. 대상 모델을 바꾸려면 `st_select_target_model`을 먼저 실행하세요.

## 2. 결과 판정

**통과하면** — 12번째 대상에서 멈추지 않고 끝까지 진행됩니다.
그대로 [Standalone 제출물 생성](standalone-run.md)으로 넘어가세요.

**또 `StandaloneCUTIdentificationFailed`가 나오면** — 에러 메시지에 이번에
`Candidates=` 항목이 추가됩니다. **그 줄을 통째로 복사해서 전달해 주세요.**
후보 블록의 이름·타입·링크 상태가 들어 있어 원인이 바로 갈립니다.

**다른 오류가 나오면** — 오류 식별자(`simtest:` 로 시작하는 부분)와 stack을
그대로 복사해 주세요.

## 3. 통과 후 최종 확인

```matlab
[code, summary] = st_check_standalone_coverage('PipelineId', info.PipelineId);
disp(code)
```

`1111111111 PASS`면 정상입니다.

---

## 참고: 무엇이 원인이었나

CUT이 라이브러리 링크 **안에** 있는 블록(`StaticLinkStatus='implicit'`)이었습니다.
export 후 CUT을 다시 찾을 때 포트 구성을 비교하는데, `find_system`의 기본값은
링크 경계를 넘어가지 않습니다. 그래서 원본은 포트 0개, export본은 실제 포트로
보여 영원히 일치하지 않았습니다. 양쪽 모두 링크와 마스크를 풀고 비교하도록
`st_export_standalone_harnesses`를 고쳤습니다.

직접 확인하려면 (`n1`이 `n0`보다 크면 링크된 CUT):

```matlab
src = '여기에_CUT_경로';       % 에러 메시지의 Source= 값
n0 = numel(find_system(src,'SearchDepth',1,'Type','Block'))
n1 = numel(find_system(src,'SearchDepth',1, ...
    'FollowLinks','on','LookUnderMasks','all','Type','Block'))
```

옵션 이름은 `FollowLinks`, `LookUnderMasks`입니다. 철자가 틀리면 `find_system`이
오류 없이 블록 필터로 해석해 `0`을 돌려주므로, `n1=0`이 나오면 오타입니다.

MATLAB R2025b 실기 확인은 이 수정 이후 아직 이루어지지 않았습니다.

---

## 참고: 모델이 여러 개일 때만 — profile

한 모델만 쓴다면 필요 없습니다. 모델마다 결과 폴더와 Test File을 따로 두고
전환하고 싶을 때만 한 번 등록합니다.

```matlab
st_setup
st_save_model_profile('MODEL_A', ...
    'ModelFile',       'D:\models\MODEL_A\MODEL_A.slx', ...
    'ManagementExcel', 'D:\models\MODEL_A\TestManagement.xlsx', ...
    'OutputRoot',      'D:\results\MODEL_A');
```

- Model과 Excel은 **이미 존재해야** 합니다. 없으면 바로 실패합니다.
- `TestFile`과 `StandaloneCoverageRootDir`은 생략하면 `OutputRoot` 아래로 잡힙니다.
- `ManagementSheet`는 `Targets`, `TestSuiteName`은 `New Test Suite 1`이 기본값입니다.
- `OutputRoot`는 다른 profile의 결과 경로와 겹치면 거부됩니다.
- 같은 이름을 고칠 때만 `'Overwrite', true`를 붙입니다.

등록 후 전환합니다. 선택만 하고 모델을 열지는 않습니다.

```matlab
cfg = st_select_model_profile('MODEL_A');   % 이름으로
cfg = st_select_model_profile();            % 목록에서 고르기
cfg = st_select_model_profile('');          % 기존 방식으로 되돌리기
```

profile을 고르면 결과·상태·export 경로가 모두 그 `OutputRoot` 아래로 바뀝니다.
저장 위치는 저장소 루트의 `model_profiles.mat`이며 Git에 올라가지 않습니다.
