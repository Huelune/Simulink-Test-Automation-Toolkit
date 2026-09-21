# Standalone 제출물 생성

Harness를 **독립 실행 가능한 모델**로 떼어내 실행하고, 커버리지 결과와 부속 파일을
제출 가능한 형태로 묶습니다. 받는 쪽에 원본 Top Model이 없어도 열 수 있습니다.

## 1. 실행 전 조건

먼저 [준비 및 실행](prepare.md)을 끝내야 합니다. 이 명령은 준비된 자산을 복사해서
실행할 뿐 Harness나 Test Case를 새로 만들지 않습니다.

- 원본 Top Model과 Test File을 **저장**합니다.
- 열린 Harness와 Top Model을 **직접 닫습니다.** 복사된 작업 공간의 모델과 이름이
  충돌합니다. 이 명령은 사용자 모델을 강제로 닫지 않습니다.
- 관리 Excel의 각 활성 행이 다음 조합을 갖추어야 합니다.

```text
CoverageFilterMode      = ALL_CONTENT
CoverageBoundaryMode    = CUT_ONLY
CoverageFilterAction    = EXCLUDE
CoverageFilterRationale = (비어 있지 않은 사유)
```

기대값은 갱신하지 않습니다(`OFF`). 기대값이 바뀌는 것은 준비 단계입니다.

## 2. 실행

```matlab
st_setup

info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);

[code, summary, details] = st_check_standalone_coverage();
disp(code)
disp(summary)
disp(details)
```

| 옵션 | 왜 이 값인가 |
| --- | --- |
| `'Action','ALL'` | EXECUTE → PACKAGE → SUMMARY를 한 번에 수행합니다 |
| `'ContinueOnFailure', true` | 한 CUT이 실패해도 나머지를 계속 처리합니다 |
| `'FailOnNonPass', false` | 통과하지 못한 대상이 있어도 MATLAB 오류를 내지 않습니다. 실패는 `details` 표에서 확인합니다 |

`st_check_standalone_coverage`는 인자 없이 부르면 가장 최근 실행을 검사합니다.
특정 실행을 보려면 `'PipelineId', info.PipelineId`를 넘깁니다. 읽기 전용이므로
모델·Test File·CVF를 저장하거나 바꾸지 않습니다.

## 3. 정상 완료 기준

- checker 코드가 `1111111111`이고 `summary.Status = 'PASS'`
- CUT별 폴더 `{NUM}_UT_REQ_{TC_NAME}`에 standalone 모델, Input MAT,
  `UT_REQ_{TC_NAME}.cvf`, `UT_REQ_{TC_NAME}.cvt`, 원본 `UT_REQ_{TC_NAME}.html`
- root에 11열짜리 `CoverageSummary.xlsx`

실행하지 못한 대상도 폴더는 만들어집니다.

HTML은 Test Manager 요약 보고서가 아니라 Coverage REPORT 화살표가 여는 원본이며
부속 asset도 함께 보존합니다. 압축 파일은 캡처 증거용이지 최종 HTML 대신 제출하는
파일이 아닙니다.

만든 제출물을 Test Manager에 다시 올려 보려면 `st_open_standalone_test_manager`를
부릅니다. 수동으로 여는 방법은 [결과 열기](open-results.md)에 있습니다.

## 4. 예외가 난 대상

시뮬레이션 예외는 `ExecutionStatus=EXCEPT`로 남습니다.

- 만들 수 있었던 Harness와 Input은 패키징합니다.
- 없는 CVT/HTML/metric을 만들어 PASS로 위장하지 않습니다.
- 따라서 그런 결과의 PACKAGE/SUMMARY 또는 checker 판정은 `FAIL`/`PARTIAL`일 수
  있습니다. 모든 비트가 1이어도 `EXCEPT` 대상이 있으면 `PARTIAL`입니다.
- Harness와 Input이 만들어지기 **전에** 실패한 경우에는 보존을 보장하지 않습니다.

필터가 적용돼 objective가 없어진 유효한 `0/0`, `N/A`와 Coverage 객체 자체의 누락은
서로 다른 상황입니다.

## 5. dependency 수집 범위

standalone export는 Top Model 전체가 아니라 **생성된 standalone Harness 모델의
dependency만** 수집합니다.

- 대상과 무관한 Top Model branch의 미해결 dependency는 export를 막지 않습니다.
- 반대로 standalone `.slx` 자체가 필요한 파일을 찾지 못하면, 받는 PC에서 열리지
  않는 제출물을 만들지 않도록 export를 중단합니다.

## 6. 실패 상세 확인

`info`가 정상적으로 반환되지 않았다면 PipelineId를 직접 넣습니다.

```matlab
st_setup
cfg = st_config();
pipelineId = '여기에_PipelineId';

[m, manifestPath] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, pipelineId);
fprintf('Manifest: %s\n', manifestPath);

T = struct2table(m.Targets);
disp(T(:, {'TestCaseName','ExecutionStatus','PackageEvidenceStatus', ...
    'PackageStatus','Message'}));

for k = 1:numel(m.Targets)
    if ~isfield(m.Targets, 'PackageFailure'), continue; end
    f = m.Targets(k).PackageFailure;
    if isempty(f.Identifier), continue; end
    fprintf('\n[%03d] %s\n%s: %s\n', k, m.Targets(k).TestCaseName, ...
        f.Identifier, f.Message);
end
```

오류 식별자별 대처는 [문제 해결](../troubleshooting.md)에 정리되어 있습니다.

## 7. 참고: 나눠서 실행하기

평소에는 `Action='ALL'` 하나면 됩니다. 실행이 아주 길거나 다른 MATLAB 세션에서
이어서 해야 할 때만 Action을 나눕니다.

```matlab
info = st_run_standalone_coverage_pipeline('Action','EXECUTE');
st_run_standalone_coverage_pipeline('Action','PACKAGE', 'PipelineId', info.PipelineId);
st_run_standalone_coverage_pipeline('Action','SUMMARY', 'PipelineId', info.PipelineId);
```

`EXECUTE` 단독 실행은 재개에 필요한 aggregate Result를 기본 저장합니다(`ALL`은
live Result를 그대로 넘기므로 저장하지 않습니다).

같은 PipelineId의 `PACKAGE`와 `SUMMARY`는 **각각 한 번만** 실행할 수 있습니다. 다시
만들어야 하면 [재시작](restart.md)의 재생성 절차를 쓰십시오.

경계와 결과 구조는
[Standalone Coverage 파이프라인](../standalone-coverage-pipeline.md)에 있습니다.
