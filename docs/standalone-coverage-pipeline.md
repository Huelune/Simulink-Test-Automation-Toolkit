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

## 출력 루트가 깊게 중첩된 저장소에서 경로 길이 초과

이 pipeline은 export한 Harness 모델을
`template/workspace/standalone/{CUTName}/...`까지 여러 단계로 중첩한다.
저장소 checkout 경로 자체가 깊으면(예: 회사 표준 폴더 구조) 합쳐진 전체 경로가
Windows 260자 제한(`MATLAB:cd:DirectoryNameTooLong`)을 넘을 수 있다.

출력 루트를 프로젝트 바깥의 짧은 경로로 옮기면 해결된다. 이 설정은 로컬
`runtime_target.mat`에 저장되므로 저장소 기본값(`st_config.m`)에는 영향이
없고, 머신마다 따로 지정한다.

```matlab
st_set_standalone_coverage_root('D:\stt_work');
```

설정을 저장하지 않고 한 번의 실행 위치만 바꾸려면 `OutputRoot`를 지정한다.

```matlab
info = st_run_standalone_coverage_pipeline( ...
    'RunMode', 'STEP2_TO_6', ...
    'OutputRoot', 'D:\stcov', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false, ...
    'ReportMode', 'FULL');
```

원래 기본값(저장소 아래 `result/standalone_coverage`)으로 되돌리려면:

```matlab
st_set_standalone_coverage_root('');
```

## 실패 상태 한 화면 출력

파이프라인 실행이 끝나거나 실패한 직후 아래 명령을 실행한다.

```matlab
clc
st_print_standalone_coverage_status( ...
    'OutputRoot', 'D:\stcov', ...
    'PipelineId', 'LATEST');
```

`STANDALONE-STATUS-v1 BEGIN`부터 `END`까지 보이도록 명령창을 캡처해 전달한다.
출력은 코드 경로 중복과 수정 반영 flag, STEP 상태, CUT별 작업/최종 파일 존재,
ResultSet 최상위와 하위 계층 Coverage 객체 수를 한 화면 크기로 요약한다.
STEP234가 WARN/FAIL이면 PER_CUT manifest의 실패 artifact를 유형과 메시지 기준으로
묶어 `AF <Type> x<개수> T=<대상 번호> | <오류>` 형식으로 최대 6개 출력한다.

## 원본 모델 세션 격리

pipeline은 같은 모델명의 standalone 사본을 실행하므로 시작 시 원본 Top Model이
로드되어 있으면 즉시 중단한다. 반면 dependency 분석이나 Harness 입력 수집이
내부적으로 모델을 로드한 경우에는 export 진입 당시 상태를 기준으로 자동 정리한다.
pipeline과 bundle exporter의 대상 설정 확인은
`st_require_runtime_target('LoadModel', false)`를 사용하므로, 선택된 모델 파일을
검증하는 행위 자체가 원본 모델을 로드하지 않는다.
따라서 사용자가 모델을 열지 않은 상태로 시작했다면 bundle runner 직전에도 원본
모델은 unload 상태여야 한다. 내부 로드가 남거나 모델이 뜻하지 않게 Dirty가 되면
자동 저장·폐기하지 않고 명시적인 세션 복원 오류로 중단한다.

Subsystem 소유 Harness의 Signal Editor 입력을 읽는 동안에는 해당 CUT 경로를
Simulink 객체로 해석하기 위해 저장된 원본 모델을 입력 수집 범위 안에서만 명시적으로
로드한다. 각 Harness를 닫은 뒤 원본 모델도 export 진입 당시 상태로 복원하며,
standalone bundle runner와 동시에 로드된 상태로 두지 않는다.

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

Harness SUT를 standalone Model SUT로 재연결한 직후 작업용 Test File, Test Suite,
Test Case의 `RecordCoverage`를 다시 활성화하고 저장 후 readback한다. 따라서 SUT
전환 과정에서 유효 Coverage 설정이 초기화되면 실행 전에 명시적으로 실패하며,
성공한 TC 결과에는 사후 CVF를 연결할 model coverage 객체가 있어야 한다.

직접 `run(testCase)`한 결과는 MATLAB 릴리스와 결과 구성에 따라 model coverage가
ResultSet 최상위가 아니라 TestCaseResult 또는 TestIterationResult에만 노출될 수
있다. 파이프라인은 최상위 aggregate를 우선 사용하고 비어 있을 때만 하위 결과까지
내려가서 Coverage 객체를 수집한다.

Coverage Filter, `cvsave`, `cvhtml`은 절대 출력 경로를 전달해도 현재 MATLAB 폴더가
쓰기 가능한지 별도로 검사한다. 각 API 호출은 짧은 `tempdir` scratch로 잠시 이동해
수행하고 원래 폴더를 즉시 복원한다. standalone bundle의 중간 PER_CUT 보고서도
긴 `workspace/workspace/result` 아래가 아니라 execution의 짧은 `r` 폴더에 둔다.
Coverage 무결성은 실행 중 바뀔 수 있는 cvdata ID가 아니라 root, checksum, 정규화한
CVF 참조로 비교한다. standalone Coverage가 모델 root metadata만 제공하면 기록된
`StandaloneCUTPath`의 모델 구간과 연결해 CUT metric을 추출한다.

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
STEP234의 사후 Coverage 등록이 실패해도 CUT별 폴더에 standalone 모델, 존재하는
Signal Editor 입력과 `target-manifest.json`은 진단 자료로 먼저 복사한다. 이 경우
CVF/CVT/Test Report는 검증된 filtered result가 아니므로 생성하지 않는다.

## 안전 경계와 검증 상태

STEP234 전후에 원본 모델, Test File, 관리 Excel checksum과 모델/Test File Dirty
상태, Harness inventory를 비교한다. 필터 복원 실패나 manifest checksum 손상은
다른 CUT로 계속하지 않는 전역 안전 오류다. 개별 CUT 실행·보고서 오류는
`ContinueOnFailure=true`에서 다음 CUT 처리를 계속한다.

현재 개발 PC에는 MATLAB이 없으므로 구현은 정적 검사까지만 수행했다. MATLAB
R2025b에서 새 세션 재개, Test Manager GUI의 Coverage Filters 표시, ZIP report,
CVT/CVF readback, 다중 CUT와 원본 불변 증거를 확인하기 전에는 main에 통합하지
않는다.
