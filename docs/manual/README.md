# 수동 실행 안내

MATLAB R2025b를 사용하는 동료를 위한 작업별 복사용 코드입니다.
실제 모델은 다른 PC에서 검증하며, 새 기능의 R2025b 검증은 아직 완료되지 않았습니다.
코드는 MATLAB에서 저장소 루트를 Current Folder로 선택한 뒤 실행합니다.
각 문서의 경로·profile 이름·PipelineId를 자신의 값으로 바꾸세요.

| 하고 싶은 작업 | 문서 |
| --- | --- |
| **지금 무엇을 할지 모르겠을 때** | **[지금 할 일](now.md)** |
| 처음 설치하고 익명 예제로 확인 | [예제 생성](example.md) |
| 여러 모델의 설정을 따로 저장하고 전환 | [모델 profile](model-profiles.md) |
| 새 Harness 생성 또는 기존 Harness 준비 | [준비 및 실행](prepare.md) |
| Standalone 제출물 생성 | [Standalone 실행](standalone-run.md) |
| 제출 MLDATX와 Harness를 Test Manager에서 사용 | [결과 열기](open-results.md) |
| 원하는 단계부터 재시작 또는 결과만 재생성 | [재시작](restart.md) |
| 다른 PC에서 배포 전 검증 | [R2025b 검증](runtime-verification.md) |
| 기존 오류의 상세 메시지·stack 수집 | [Standalone 진단](standalone-coverage-runtime.md) |

일반 준비 workflow는 Harness·입력·Assessment·Test File을 변경하며 기본 기대값
정책은 `APPLY`입니다. Standalone은 준비된 자산을 복사해서 실행하고 기대값을
갱신하지 않습니다(`OFF`). 승인된 기준값이 있다면 관리 Excel의
`ExpectedUpdateMode`를 검토한 후 일반 workflow를 실행하세요.

`st_check_readiness`는 준비·테스트 실행·checkpoint 저장을 하지 않습니다.
필요한 모델/Test File을 잠시 로드하고 자신이 연 것만 저장 없이 닫습니다.
출력 디렉터리는 임시 파일을 생성·삭제해 쓰기 가능 여부를 검사합니다.
모델 callback의 부작용과 라이선스 실제 checkout까지 보장하는 sandbox는 아닙니다.
원본 저장, 열린 Harness 닫기, 다른 실행 종료가 선행되어야 합니다.
