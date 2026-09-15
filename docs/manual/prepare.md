# Harness 준비 및 일반 실행

먼저 [profile](model-profiles.md)을 등록하고 원본을 백업하세요.
각 코드는 준비부터 테스트·일반 보고서까지 실행하며 Standalone 제출물은 별도입니다.

## 새 Harness부터

```matlab
st_setup
cfg = st_select_model_profile('MODEL_A');
[ready, checks] = st_check_readiness('Workflow','FROM_HARNESS','FromStage','HARNESS');
disp(checks)
assert(ready.Ready, 'Resolve readiness checks first.');
info = st_run_from_stage('Workflow','FROM_HARNESS','FromStage','HARNESS');
```

## 이미 저장된 Harness부터

```matlab
st_setup
cfg = st_select_model_profile('MODEL_A');
[ready, checks] = st_check_readiness('Workflow','AFTER_HARNESS','FromStage','SLDV');
disp(checks)
assert(ready.Ready, 'Resolve readiness checks first.');
info = st_run_from_stage('Workflow','AFTER_HARNESS','FromStage','SLDV');
```

진행 순서는 `HARNESS → SLDV → HARNESS_CONFIG → SIGNAL_EDITOR → ASSESSMENT →
COVERAGE_FILTER → TEST_MANAGER → ALIGNMENT → EXECUTE`입니다. AFTER_HARNESS는
HARNESS를 생성하지 않습니다. `SLDV`라는 단계 이름에는 `OFF`와 `FILE` 준비도 포함됩니다.
`PER_CUT`의 CVF 생성은 대상 실행 직전으로 미루는 것이 정상입니다.

`BLOCKED`이면 `checks.Message`와 `RequiredFromStage`를 확인하세요. 기존 Harness가
없거나 연결 보호가 필요하면 FROM_HARNESS의 HARNESS부터 실행합니다. 파일·라이선스·
동명 모델 충돌은 해당 환경 문제를 먼저 해결합니다. 준비가 실패하면 그 이후 실행은
차단됩니다. 테스트 예외 후 다음 TC 계속 여부는 기존 실행 정책을 유지합니다.

기존 `st_run_from_harness` / `st_run_after_harness`의 AUTO/FORCE API도 유지됩니다.
단, 그 API의 기존 증분 계산은 앞 단계까지 무효화할 수 있습니다. **앞 단계 재실행 금지**가
중요하면 새 `st_run_from_stage`를 사용하세요.
