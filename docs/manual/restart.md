# 선택한 단계부터 재시작 (선택 사항)

> **평소에는 필요 없습니다.** 다시 실행할 때는 [준비 및 실행](prepare.md)의
> `st_run_from_harness('PreparationMode','FORCE','FromStage',...)`으로 충분합니다.
>
> 이 문서는 **오래 걸리는 앞 단계를 절대 다시 실행하면 안 되는 경우**와, 이미 끝난
> standalone 결과를 **테스트 재실행 없이 다시 만들어야 하는 경우**를 다룹니다.

`st_run_from_stage`는 선택한 단계부터 해당 workflow 끝까지 실행합니다. 앞 단계는
파일·설정 fingerprint와 실제 연결/시나리오 readback으로 검사하며, 유효하지 않으면
자동으로 고치거나 실행하지 않고 **중단합니다.**

TC별 실패만 골라 재실행하거나 중간 단계에서 멈추는 기능은 아직 없습니다.

## 1. 준비 중간 단계부터

```matlab
st_setup
workflow  = 'FROM_HARNESS';
fromStage = 'ASSESSMENT';

[ready, checks] = st_check_readiness('Workflow',workflow,'FromStage',fromStage);
disp(checks)
disp(ready)
assert(ready.Ready, 'checks를 확인하고 RecommendedFromStage를 쓰십시오.');

info = st_run_from_stage('Workflow',workflow,'FromStage',fromStage);
```

`st_check_readiness`는 **아무것도 바꾸지 않고** 검사만 합니다. `BLOCKED`이면
`checks.Message`와 `checks.RequiredFromStage`에 어느 단계부터 시작해야 하는지가
적혀 있습니다.

선택 가능한 단계:

| Workflow | FromStage |
| --- | --- |
| `FROM_HARNESS` | HARNESS, SLDV, HARNESS_CONFIG, SIGNAL_EDITOR, ASSESSMENT, TEST_MANAGER, ALIGNMENT, EXECUTE |
| `AFTER_HARNESS` | 위 목록 중 HARNESS 제외 |
| `STANDALONE` | EXECUTE, PACKAGE, SUMMARY |

예를 들어 입력 MAT이 바뀌었으면 `SLDV`부터, Assessment가 바뀌었으면 `ASSESSMENT`부터
시작하라는 검사를 받습니다.

기존 v1 checkpoint는 읽을 수 있지만, FILE/GENERATE의 입력 준비와 Assessment에 새
readback 증거가 없으면 그 단계부터 한 번 실행해야 합니다. 코드 변경 후에도 readback이
판별하지 못하는 의미 변경은 있을 수 있으므로 배포 전 runtime 검증은 필수입니다.

## 2. PACKAGE부터 결과 다시 만들기

같은 PipelineId로 `PACKAGE`나 `SUMMARY`를 두 번 실행할 수는 없습니다. 저장된 증거를
검증해 **새 PipelineId로 재생성**합니다. 테스트를 다시 실행하지 않습니다.

```matlab
st_setup
cfg = st_config();
sourceId = '여기에_원본_PipelineId';

[ready, checks] = st_check_readiness('Workflow','STANDALONE', ...
    'FromStage','PACKAGE', 'SourcePipelineId', sourceId);
disp(checks)
assert(ready.Ready, '저장된 실행 증거가 불완전하거나 변경되었습니다.');

info = st_run_from_stage('Workflow','STANDALONE', ...
    'FromStage','PACKAGE', 'SourcePipelineId', sourceId);
disp(info)
```

필요한 원본 증거:

- `SaveTestResult=true`로 만든 aggregate Result
- execution workspace의 모델 / Input / Test File
- CVF와 캡처된 CVT, 원본 HTML ZIP, metric 증거 및 해시

> `.work` 폴더를 지웠거나 report 캡처 자체가 실패했다면 PACKAGE 재생성으로 복구할 수
> 없습니다. 증거가 없는 구버전 결과도 `EXECUTE`부터 다시 실행해야 합니다.
> `EXCEPT` 대상은 그대로 유지됩니다.

## 3. SUMMARY만 다시 만들기

위 코드의 두 `FromStage` 값을 `'SUMMARY'`로 바꿉니다. 원본 PACKAGE가 끝났고 모든
최종 제출 파일이 저장 inventory와 일치해야 합니다.

기존 파일을 새 root로 복사하고 manifest의 숫자에서 Excel만 다시 씁니다. 모델
로드/저장, Result import, 테스트 실행이 전혀 없습니다. `.work`와 저장 Result도 쓰지
않습니다.

## 4. 재생성의 공통 규칙

| 항목 | PACKAGE 재생성 | SUMMARY 재생성 |
| --- | --- | --- |
| 원본 결과 변경 | 없음 | 없음 |
| Result import | 1회 | 0회 |
| 테스트 실행 | 0회 (`LocalExecutionCount=0`) | 0회 |
| Result 재export | 없음 | 없음 |

새 결과에는 새 PipelineId와 `SourcePipelineId`, 원본 manifest 사본과 해시가
기록됩니다. 실행 횟수는 원본 이력과 구분됩니다.

- 정상 `OK` 결과만 `latest`로 승격합니다. `PARTIAL`이나 실패 결과는 반환된 id 또는
  생성 로그의 id로 확인합니다.
- 재생성을 원본과 동시에 실행하지 마십시오.
- 제출 폴더만 다른 위치로 옮겨 쓰는 것은 가능하지만, 재생성과 provenance 검증을
  계속하려면 원본/파생 결과의 기록된 경로를 보존해야 합니다.
- 원본 소스 모델이 나중에 바뀌었다면, 역사적 결과 재생성이 성공해도 현재 소스 불변을
  검사하는 B9는 실패할 수 있습니다.
