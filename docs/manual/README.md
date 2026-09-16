# 수동 실행 안내

작업별로 복사해서 바로 쓸 수 있는 코드 모음입니다. MATLAB에서 저장소 루트를
Current Folder로 선택한 뒤 실행하고, 각 문서의 경로·profile 이름·PipelineId를
자신의 값으로 바꾸십시오.

처음이라면 여기보다 [처음 시작하기](../getting-started.md)를 먼저 읽으십시오.

| 하고 싶은 작업 | 문서 |
| --- | --- |
| 익명 예제로 흐름 확인 | [예제 생성](example.md) |
| 여러 모델의 설정을 따로 저장하고 전환 | [모델 profile](model-profiles.md) |
| 새 Harness 생성 또는 기존 Harness 준비 | [준비 및 실행](prepare.md) |
| Standalone 제출물 생성 | [Standalone 실행](standalone-run.md) |
| 제출 MLDATX와 Harness를 Test Manager에서 열기 | [결과 열기](open-results.md) |
| 원하는 단계부터 재시작 또는 결과만 재생성 | [재시작](restart.md) |
| 배포 전 R2025b에서 확인 | [R2025b 배포 전 확인](runtime-verification.md) |
| 오류가 났을 때 | [문제 해결](../troubleshooting.md) |

## 두 가지 실행 경로의 차이

| | 일반 workflow | Standalone pipeline |
| --- | --- | --- |
| 하는 일 | Harness·입력·Assessment·Test File을 **만들고 바꿉니다** | 이미 준비된 자산을 **복사해서 실행합니다** |
| 기대값 갱신 | 기본 `APPLY` (실패 시 자동 갱신) | 하지 않음 (`OFF`) |
| 먼저 할 일 | — | 일반 workflow를 먼저 끝내야 합니다 |

승인된 기준값이 있다면 일반 workflow를 실행하기 전에 관리 Excel의
`ExpectedUpdateMode`를 검토하십시오.

## `st_check_readiness`의 경계

각 문서의 실행 코드는 대부분 `st_check_readiness`로 시작합니다. 이 명령이 하는 일과
하지 않는 일은 다음과 같습니다.

**하는 일**

- 필요한 모델과 Test File을 잠시 로드해 상태를 읽습니다.
- 자신이 연 것만 **저장 없이** 닫습니다.
- 출력 디렉터리에 임시 파일을 만들었다 지워 쓰기 가능 여부를 확인합니다.

**하지 않는 일**

- 준비, 테스트 실행, checkpoint 저장을 하지 않습니다.
- 모델 callback의 부작용과 라이선스 실제 checkout까지 막아 주지는 않습니다.
- 사용자가 이미 열어 둔 모델을 닫지 않습니다.

따라서 실행 전에 **원본 저장, 열린 Harness 닫기, 다른 실행 종료**를 먼저 하십시오.
