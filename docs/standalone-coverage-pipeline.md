# Standalone Harness Coverage Pipeline

`st_run_standalone_coverage_pipeline`은 기존 프로젝트 자산을 직접 수정하지 않고,
Harness를 standalone 모델로 내보낸 작업 사본에서 Test Case와 Coverage 결과를
만드는 단계형 실행 명령이다. 제품 버전은 `0.9.6`을 유지한다.

## 실행 단계

```matlab
% Harness부터 Test Manager alignment까지만 준비
st_run_standalone_coverage_pipeline('RunMode', 'STEP1');

% export + TC 재연결 + CUT별 실행 + 결과 CVF 등록
info = st_run_standalone_coverage_pipeline('RunMode', 'STEP234');

% 새 MATLAB 세션에서 최종 산출물과 Excel 재개
st_run_standalone_coverage_pipeline( ...
    'RunMode', 'STEP5', 'PipelineId', info.PipelineId);
st_run_standalone_coverage_pipeline( ...
    'RunMode', 'STEP6', 'PipelineId', info.PipelineId);

% STEP234부터 STEP6까지 연속 실행
info = st_run_standalone_coverage_pipeline('RunMode', 'STEP2_TO_6');
```

`PipelineId`를 생략하거나 `LATEST`로 지정한 `STEP234`/`STEP2_TO_6`은 새 ID를
만든다. `STEP5`/`STEP6`의 기본 `LATEST`는
`result/standalone_coverage/latest.json`이 가리키는 기존 실행을 읽는다.

## 필수 Targets 정책

이 pipeline은 결과 필터가 선택 사항이 아니므로 모든 활성 대상에서 다음 설정을
검증한다.

- `CoverageFilterMode=ALL_CONTENT`
- `CoverageBoundaryMode=CUT_ONLY`
- `CoverageFilterAction=EXCLUDE`
- `CoverageFilterRationale`이 비어 있지 않음
- `cfg.CoverageFilterExistingPolicy='REPLACE'`

CVF는 standalone 모델의 SID로 다시 생성된다. CUT 외부 최상위 Subsystem은
`SubsystemAllContent`, CUT 외부 나머지 최상위 블록은 `BlockInstance`, CUT 직계
하위 Subsystem은 `SubsystemAllContent`로 제외한다. CUT 자체와 recursive 손자
Subsystem은 직접 rule로 추가하지 않는다.

일반 `PER_CUT` 실행은 기존처럼 실행 중 필터를 적용한다. 이 pipeline만
`ResultFilterMode=POST_RUN_REQUIRED`를 사용해 필터 없는 전체 Coverage를 먼저
수집한다. 따라서 기존 Test File/Suite/Test Case 필터를 병합하는 `MERGE`는 이
pipeline에서 거부한다. 실행 후 `cvdata.filter`에 CVF 절대 경로를 등록하며, 등록 뒤
`decisioninfo`/`executioninfo`, MLDATX export/import와 filter readback이 모두
성공해야 해당 CUT가 성공한다.

## 결과 구조

```text
result/standalone_coverage/<PipelineId>/
├─ pipeline-manifest.json
├─ logs/
├─ TestManager/<TopModel>.mldatx
├─ 001_<CUT>/
│  ├─ <standalone-model>.slx
│  ├─ <CUT>_Input.mat
│  ├─ <CUT>_CoverageFilter.cvf
│  ├─ <CUT>_CoverageResult.cvt
│  ├─ target-manifest.json
│  └─ <CUT>_TestReport/
│     ├─ report.html
│     └─ coverage/
├─ CoverageSummary.xlsx
└─ .work/
```

`CoverageSummary.xlsx`는 실패 CUT도 한 행으로 유지한다. Decision 또는 Execution
분모가 없으면 manifest의 숫자는 `NaN`이며 Excel 백분율은 `N/A`다.
`.work`는 재개와 checksum 감사 증거이므로 성공 후에도 유지한다.

## 안전 경계와 검증 상태

STEP234 전후에 원본 모델, Test File, 관리 Excel checksum과 모델/Test File Dirty
상태, Harness inventory를 비교한다. 필터 복원 실패나 manifest checksum 손상은
다른 CUT로 계속하지 않는 전역 안전 오류다. 개별 CUT 실행·보고서 오류는
`ContinueOnFailure=true`에서 다음 CUT 처리를 계속한다.

현재 개발 PC에는 MATLAB이 없으므로 구현은 정적 검사까지만 수행했다. MATLAB
R2025b에서 새 세션 재개, Test Manager GUI의 Coverage Filters 표시, ZIP report,
CVT/CVF readback, 다중 CUT와 원본 불변 증거를 확인하기 전에는 main에 통합하지
않는다.
