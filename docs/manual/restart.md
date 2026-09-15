# 선택한 단계부터 끝까지 재시작

`st_run_from_stage`는 **선택한 단계부터 해당 workflow 끝까지** 실행합니다.
앞 단계는 파일·설정 fingerprint와 실제 연결/시나리오 readback으로 검사합니다.
앞 단계가 유효하지 않으면 자동으로 고치거나 실행하지 않고 중단합니다.
TC별 실패만 골라 재실행하거나 중간 단계에서 멈추는 API는 이번 범위가 아닙니다.

## 준비 중간부터

```matlab
st_setup
cfg = st_select_model_profile('MODEL_A');
workflow = 'FROM_HARNESS';
fromStage = 'ASSESSMENT';
[ready, checks] = st_check_readiness('Workflow',workflow,'FromStage',fromStage);
disp(checks)
disp(ready)
assert(ready.Ready, 'Use RecommendedFromStage after reviewing the checks.');
info = st_run_from_stage('Workflow',workflow,'FromStage',fromStage);
```

선택 가능 단계:

| Workflow | FromStage |
| --- | --- |
| `FROM_HARNESS` | HARNESS, SLDV, HARNESS_CONFIG, SIGNAL_EDITOR, ASSESSMENT, COVERAGE_FILTER, TEST_MANAGER, ALIGNMENT, EXECUTE |
| `AFTER_HARNESS` | 위 목록 중 HARNESS 제외 |
| `STANDALONE` | EXECUTE, PACKAGE, SUMMARY |

예를 들어 입력 MAT이 변했으면 `SLDV`부터, Assessment가 변했으면 `ASSESSMENT`부터
시작하라는 검사를 받습니다. 기존 v1 checkpoint는 읽을 수 있지만 FILE/GENERATE의
입력 준비와 Assessment에 새 readback 증거가 없으면 해당 단계부터 한 번 실행해야 합니다.
그 외 일부 이전 단계는 실제 구조 검사로 기존 자산을 확인합니다. 코드 변경 후에도
readback이 판별하지 못하는 의미 변경은 있을 수 있으므로 배포 전 runtime 검증은 필수입니다.

## PACKAGE부터 새 결과 생성

```matlab
st_setup
cfg = st_select_model_profile('MODEL_A');
sourceId = '여기에_원본_PipelineId';
[ready, checks] = st_check_readiness('Workflow','STANDALONE', ...
    'FromStage','PACKAGE','SourcePipelineId',sourceId);
disp(checks)
assert(ready.Ready, 'Saved execution evidence is incomplete or changed.');
info = st_run_from_stage('Workflow','STANDALONE', ...
    'FromStage','PACKAGE','SourcePipelineId',sourceId);
disp(info)
```

필요한 원본: `SaveTestResult=true`의 aggregate Result, execution workspace 모델/Input/
Test File, CVF와 캡처된 CVT·원본 HTML ZIP·metric 증거 및 해시입니다.
`.work`를 지웠거나 report 캡처 자체가 실패했다면 PACKAGE 재생성으로 복구할 수 없습니다.
기존 증거가 없는 구버전 결과도 새 EXECUTE가 필요합니다. EXCEPT는 그대로 유지합니다.

## SUMMARY만 새로 생성

위 코드의 두 `FromStage` 값을 `SUMMARY`로 바꾸세요. 원본 PACKAGE가 끝났고 모든
최종 제출 파일이 저장 inventory와 일치해야 합니다. 기존 파일을 새 root로 복사하고
manifest의 숫자에서 Excel만 재작성합니다. 모델 로드/저장, Result import, 테스트 실행은 없습니다.
SUMMARY는 `.work`와 저장 Result를 사용하지 않습니다.

두 재생성 모두 원본 결과를 변경하지 않고 새 PipelineId와 `SourcePipelineId`, 원본 manifest
사본/해시, `LocalExecutionCount=0`을 기록합니다. PACKAGE는 Result import 1회,
SUMMARY는 0회이며 Result를 다시 export하지 않습니다. 실행 횟수는 원본 이력과 구분합니다.
정상 `OK` 결과만 `latest`로 승격하며 PARTIAL/실패 결과는 반환된 id 또는 생성 로그의 id로 확인합니다.
원본 실행에 사용한 profile을 선택해야 합니다. 원본 소스 모델이 나중에 바뀌었다면
역사적 결과 재생성이 성공해도 현재 소스 불변을 검사하는 B9는 실패할 수 있습니다.

동일 PipelineId의 기존 `Action=PACKAGE/SUMMARY` 1회 제한은 그대로입니다.
재생성도 원본과 동시에 실행하지 마세요. 제출 폴더만 이동해 사용은 가능하지만
재생성과 provenance 검증을 계속하려면 원본/파생 결과의 기록된 경로를 보존하세요.
