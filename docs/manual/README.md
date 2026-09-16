# 수동 실행 안내

작업별로 복사해서 바로 쓸 수 있는 코드 모음입니다. MATLAB에서 저장소 루트를
Current Folder로 선택한 뒤 실행하십시오.

처음이라면 여기보다 [처음 시작하기](../getting-started.md)를 먼저 읽으십시오.

## 기본 흐름

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

처음이거나 대상 모델을 바꿀 때만 `st_select_target_model`을 사이에 넣습니다.

| 하고 싶은 작업 | 문서 |
| --- | --- |
| Harness·입력·Test Case 준비와 테스트 실행 | [준비 및 실행](prepare.md) |
| Standalone 제출물 생성 | [Standalone 실행](standalone-run.md) |
| 제출 MLDATX와 standalone 모델을 Test Manager에서 열기 | [결과 열기](open-results.md) |
| 오류가 났을 때 | [문제 해결](../troubleshooting.md) |

## 선택 기능

필요해질 때만 보면 됩니다.

| 상황 | 문서 |
| --- | --- |
| 실제 모델 없이 예제로 연습 | [익명 예제 생성](example.md) |
| 모델을 여러 개 번갈아 사용 | [모델 profile](model-profiles.md) |
| 오래 걸리는 앞 단계를 보존한 채 중간부터 재시작 | [재시작](restart.md) |
| 이미 끝난 standalone 결과를 재실행 없이 다시 생성 | [재시작](restart.md) |
| 배포 전 R2025b에서 확인 | [R2025b 배포 전 확인](runtime-verification.md) |

## 두 가지 실행 경로의 차이

| | `st_run_from_harness` | `st_run_standalone_coverage_pipeline` |
| --- | --- | --- |
| 하는 일 | Harness·입력·Assessment·Test File을 **만들고 바꿉니다** | 준비된 자산을 **복사해서 실행합니다** |
| 기대값 갱신 | 기본 `APPLY` (실패 시 자동 갱신) | 하지 않음 (`OFF`) |
| 먼저 할 일 | — | `st_run_from_harness`를 먼저 끝내야 합니다 |
| 실행 전 | 모델·Excel·Test File 백업 | 원본 Top Model과 Harness를 **저장하고 닫기** |

승인된 기준값이 있다면 `st_run_from_harness`를 실행하기 전에 관리 Excel의
`ExpectedUpdateMode`를 `OFF`로 검토하십시오.
