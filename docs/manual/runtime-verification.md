# R2025b 배포 전 확인

현재 개발 PC에는 MATLAB이 없습니다. 이 문서는 **검증 계획**이며 통과 기록이 아닙니다.
업무 모델 대신 폐기 가능한 예제·복사본으로 먼저 실행하세요. 새 MATLAB 세션에서 저장소를
Current Folder로 선택합니다. 테스트는 자체 임시 checkout을 쓰지만 모델 callback 등의
외부 부작용까지 격리하는 것은 아니므로 다른 작업과 동시에 실행하지 마세요.

## 자동 테스트

```matlab
st_setup
assert(strcmp(version('-release'),'2025b'), 'Run this acceptance on R2025b.');
repo = st_project_root();
testFiles = { ...
    fullfile(repo,'tests','unit','test_model_profiles_and_restart.m'), ...
    fullfile(repo,'tests','unit','test_result_regeneration.m'), ...
    fullfile(repo,'tests','unit','test_standalone_coverage_pipeline.m'), ...
    fullfile(repo,'tests','integration','test_stage_restart_runtime.m'), ...
    fullfile(repo,'tests','integration','test_standalone_coverage_pipeline_runtime.m')};
results = runtests(testFiles);
disp(table(results))
assert(all([results.Passed]), 'Some tests failed or were incomplete; preserve the full output.');
```

새 테스트는 profile 전환/충돌, 선행 단계 고정, readiness 무저장, 입력 변경 시 SLDV 안내,
유효 증거 재생성, 파일 훼손/구버전 증거 누락 차단, N/A/EXCEPT 보존,
재생성 provenance·latest 보존을 검사합니다. 기존 전체 unit suite도 별도로 실행하세요.

## 실제 사용 흐름

1. [예제](example.md) 생성 → profile 선택 → 일반 준비/실행.
2. readiness 전후 원본 model/Excel/Test File SHA-256, `pwd`, `path`, 열린 모델을 비교.
3. ASSESSMENT부터 재시작: HARNESS/SLDV/입력 준비가 다시 실행되지 않는지 로그 확인.
4. 입력 MAT 변경 후 늦은 단계 재시작: BLOCKED와 SLDV 권고 확인. 원본을 복구한 뒤 재검사.
5. [Standalone](standalone-run.md) EXECUTE → PACKAGE → SUMMARY와 ALL 경로 확인.
6. [재생성](restart.md) PACKAGE → SUMMARY, SUMMARY만 실행. 새 id, 원본 불변,
   `LocalExecutionCount=0`, PACKAGE import 1회 / SUMMARY import 0회 확인.
7. 두 실행 경로와 정상 파생 결과에서 `1111111111 PASS`, TC별 HTML 생성,
   열린 standalone 모델 없음, CVF 적용/복원 상태를 확인.
8. [결과 열기](open-results.md): launcher 없이 MLDATX와 Model 폴더 버튼으로 각
   standalone 모델 연결. 다른 경로로 옮긴 제출 폴더에서도 Input/CVF 수동 연결 확인.
9. 원본 Coverage HTML Details와 Excel의 Decision/Execution Executed·Total을 대조.
   유효 N/A는 0/0로, 실제 미수집은 없는 값으로 구분. CVF 이름과 rationale `none` 확인.
10. 의도적으로 예외가 나는 TC를 넣어 EXCEPT, 가능한 Harness/Input 보존,
    후속 TC 실행을 확인. 필터 복원 실패와 일반 결함 예외를 구분해 기록.

실패 시 재시도를 반복하기 전에 full stack, profile 이름, source/new PipelineId,
pipeline manifest, execution log, readiness table을 보존하세요. 업무 경로가 포함된
증거는 저장소에 커밋하지 말고 승인된 위치에 보관합니다.
