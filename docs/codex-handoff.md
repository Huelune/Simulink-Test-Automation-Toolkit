# Codex 전용 작업 인수인계

이 문서는 사용자용 매뉴얼이 아니다. 다른 PC나 새 Codex 작업이 현재 브랜치와
검증 경계를 잘못 해석하지 않도록 유지하는 작업 상태 문서다. AGENTS.md의 지시에
따라 브랜치 변경, 병합, MATLAB 런타임 작업 전에 반드시 읽는다.

## 현재 기준

- 기준일: 2026-09-09
- 활성 개발 브랜치: feat/harness-workflow-v2
- 필수 기능 기준: feat/per-cut-filtered-execution의 7f0825e
- 필수 handoff 기준: 2b3ba09 이후
- 필수 진단 기준: 현재 브랜치 최신 커밋의 st_check_actual_system 포함
- MATLAB R2025b 검증: 미수행
- 현재 PC: MATLAB 실행 파일과 실제 result 폴더 없음
- 완료 표현: 정적 구현 완료까지만 허용하며 인증 완료나 PR 준비 완료로 표현하지 않는다.

## 변경 불가 핵심 결정

CoverageFilterMode이 활성화된 CUT의 content rule은 CUT 자기 자신을 선택하면
안 된다. CUT의 직계 하위 Subsystem만 선택해야 한다.

- SUBSYSTEM: 각 직계 하위 Subsystem을 BlockInstance로 선택한다. 내부 일반 블록은
  직접 포함하지 않는다.
- ALL_CONTENT: 각 직계 하위 Subsystem을 SubsystemAllContent로 선택한다.
- CUT 자신은 두 모드 모두 제외한다.
- content rule은 일반 블록을 직접 선택하지 않는다. CUT_ONLY 경계 rule은 아래의
  별도 정책에 따라 CUT 외부 일반 블록을 직접 선택한다.
- 직계 하위 Subsystem이 없으면 CVF는 생성될 수 있지만 실제 rule은 0개다. 실제
  필터 효과를 확인하는 6비트 진단에서는 B3을 0으로 표시한다.
- CVF는 CUT별 실행 폴더에 보존하고 실행 후 원래 Test File, Suite, Test Case 필터
  목록을 복원해야 한다.
- `CoverageBoundaryMode=CUT_ONLY`는 위 모드와 독립이다. 실제 Harness 또는
  standalone 실행 루트에서 CUT 외부 최상위 Subsystem은 SubsystemAllContent,
  나머지 최상위 블록은 BlockInstance로 항상 EXCLUDE한다.
- standalone 모델은 원본 SID를 재사용하지 않으므로 실행 작업 사본에서 CVF를
  다시 생성하고 저장본의 SID, selector type, action, rationale, rule 수를 검증한다.

이 기준은 d109472에서 최신 기능 브랜치 위에 다시 반영됐다. 이전 원격 커밋
f60601e는 CUT 자신을 선택하므로 현재 요구사항의 기준으로 사용하지 않는다.

## 활성 브랜치 지도

| 브랜치 | 기준 커밋 | 역할과 처리 방침 |
| --- | --- | --- |
| backup/harness-full-copy | b6d30a8 | 완전 복사/Import 구현 보존. 수정하지 않는다. |
| feat/harness-content-import | b6d30a8 | 기존 Import 브랜치. clone 개발을 이어가지 않는다. |
| feat/harness-template-clone | b6d30a8 기반 | Import만 선별 제거한 Template clone 개발. MATLAB 검증 전 통합하지 않는다. |
| feat/harness-workflow-v2 | 53c7e410 기반 | 입력 시나리오, standalone 재실행, CUT 경계 필터 통합 개발. MATLAB 검증 전 main에 통합하지 않는다. |
| main | 0a0ace5 | 파일 구조 정리까지만 반영된 안정 기준. R2025b 검증 전 기능을 임의 backport하지 않는다. |
| feat/per-cut-filtered-execution | d109472 이후 | v2의 선행 Coverage 기준. 신규 v2 작업의 활성 브랜치는 아니다. |

## 정리된 과거 브랜치

다음 브랜치는 현재 활성 브랜치에 포함되었거나 필요한 변경을 선별 반영한 뒤
2026-09-03에 로컬 또는 원격에서 정리했다. 동일 이름으로 작업을 재개하지 않는다.

| 과거 브랜치 | 마지막 기준 | 정리 근거 |
| --- | --- | --- |
| integration/comprehensive | 34cf49f | 현재 활성 브랜치의 공통 기반으로 전부 포함됨 |
| feature/api-per-testcase-coverage-filters | e27ffbb | SLDV 수정은 현재 브랜치의 547c9c9에 동일하게 반영됨 |
| fix/rebuild-coverage-filter-from-687aa78 | baadd60 | 하위 Subsystem 선택 의도를 d109472에 최신 기준으로 선별 반영함 |
| fix/rebuild-coverage-filter-from-9165bc9 | a5469f7 | 같은 의도의 과거 실행 기준 비교 브랜치로 d109472가 대체함 |
| feat/comprehensive-verification | b458d2a | 현재 활성 브랜치에 포함됨 |
| feat/incremental-execution-reporting | 8663b36 | 현재 활성 브랜치에 포함됨 |
| feat/reproducible-test-bundle-export | 0812582 | 현재 활성 브랜치에 포함됨 |
| handoff/r2025b-cross-machine | 96926cf | 현재 handoff 문서와 활성 브랜치가 대체함 |

과거 커밋 해시는 추적 근거로만 유지한다. Harness Workflow v2 후속 수정은
main이나 과거 Coverage 브랜치가 아니라 `feat/harness-workflow-v2`에서 이어간다.

## 실제 시스템 CVF 점검

실제 시스템의 기본 진단 진입점은 전체 18비트 검사다.

    st_setup
    summary = st_check_actual_system();
    disp(summary.Environment)
    disp(summary.Run)
    disp(summary.CVF)

SYSTEM-CHECK-v1의 ENV, RUN, CVF가 각각 111111일 때만 환경, 실행 연결과 CVF
자동 검사가 모두 통과한 것이다. ENV는 R2025b·제품·라이선스·입력·API·경로
중복을, RUN은 실행 root·CUT 매핑·실행 완료·기대값 갱신·산출물·필터 누출을
확인한다. 이 검사는 읽기 전용이며 PDF/HTML 시각 품질과 Test Manager GUI는
자동 판정 범위가 아니다.

CVF selector만 다시 확인하려면 아래 개별 검사를 사용한다.

최신 PER_CUT 실행이 끝난 뒤 다음을 실행한다.

    st_setup
    [code, details] = st_check_per_cut_cvf();
    disp(details(:, {'No','TestCaseName','Code','Status','Message'}))

특정 실행 폴더를 검사하려면 다음과 같이 지정한다.

    [code, details] = st_check_per_cut_cvf( ...
        'RunDirectory', 'result/per_cut_runs/<run-id>');

출력되는 CVF-CHECK-v2 줄 전체를 사용자 또는 다른 Codex에 전달한다. 종합 코드가
111111일 때만 모든 활성 CVF CUT이 여섯 검사를 통과한 것이다.

| 비트 | 검사 |
| --- | --- |
| B1 | target manifest, CVF 파일, SHA-256 일치 |
| B2 | 생성, 적용, 복원 상태가 모두 OK |
| B3 | 실제 rule 수가 manifest와 같고 0보다 큼 |
| B4 | selector가 고유하고 SID가 비어 있지 않은 block selector임 |
| B5 | 활성화한 CUT-child/boundary rule 범주가 존재함 |
| B6 | 범주별 selector, action, rationale 정책 일치 |

한 CUT이라도 특정 비트가 0이면 종합 코드의 같은 위치도 0이다. 진단 명령은
result와 CVF를 읽기만 하며, 점검을 위해 연 모델은 저장하지 않고 닫는다.

## R2025b에서 반드시 확인할 항목

1. MATLAB 경로 중복 여부를 which 함수명 -all 형태로 확인한다.
2. SUBSYSTEM, ALL_CONTENT, OFF와 CUT_ONLY 조합이 포함된 PER_CUT 실행을 수행한다.
3. st_check_actual_system과 st_check_per_cut_cvf 출력 및 상세 표를 보관한다.
4. 생성 CVF에서 CUT 자신이 없고 content rule은 직계 하위 Subsystem에만,
   boundary rule은 CUT 외부 최상위 블록에만 있는지 확인한다.
5. SUBSYSTEM이 내부 일반 블록 전체를 필터링하지 않는지 Coverage HTML로 확인한다.
6. ALL_CONTENT만 선택된 하위 Subsystem 내부 전체를 처리하는지 확인한다.
7. 실행 전후 Test File, Suite, Test Case의 기존 필터 목록이 동일한지 확인한다.
8. Test Manager Coverage 화면에서 점 인덱싱 오류가 재발하지 않는지 확인한다.
9. 각 CUT의 MLDATX, CVT, CVF, Excel, HTML과 선택적 PDF를 확인한다.
10. 모델, Test File, Excel과 입력 파일의 원본 checksum 불변을 확인한다.
11. 직계 Inport 없음+Signal Editor 있음, Signal Editor 없음, 손상/중복 Signal
    Editor의 성공·WARN·실패 경계를 TC 연결과 명세서 추출에서 각각 확인한다.
12. ORIGINAL/STANDALONE_HARNESS × OFF/CUT_ONLY와 기존 필터 동시 적용을 확인한다.
13. 여러 CUT가 manifest 순서대로 실행되고 각 standalone 모델이 다음 CUT 전에
    닫히는지 확인한다.
14. ExpectedUpdateMode=APPLY 갱신과 선택적 재실행 결과가 종합 보고서에 남는지 확인한다.
15. export 전후 원본 모델·Test File checksum, Dirty 상태와 Harness inventory가
    불변인지 확인한다.
16. If/Switch/MinMax/MultiPortSwitch/SwitchCase가 있는 CUT의 명세서를 export하고,
    블록 이름 다음 줄의 D번호·분기종류·저장 파라미터 표현과 DecisionBlockDetails의
    Outcome/Expression/ReadStatus가 실제 블록 설정과 일치하는지 확인한다.

실패 시 최소 전달 자료:

- CVF-CHECK-v2로 시작하는 모든 출력 줄
- SYSTEM-CHECK-v1로 시작하는 모든 출력 줄과 summary 상세 표
- details 표
- result/per_cut_latest.json
- 해당 run의 manifest.json과 logs/execution.log
- 실패 CUT의 target-manifest.json과 filter 폴더
- MATLAB 오류의 getReport extended 출력과 dbstack completenames 출력

## 다른 Codex의 시작 절차

1. git fetch --prune origin을 실행한다.
2. 원격 feat/harness-workflow-v2의 최신 커밋을 확인한다.
3. 작업 트리가 깨끗할 때만 fast-forward한다.
4. 이 문서의 브랜치 지도와 변경 불가 핵심 결정을 읽는다.
5. st_setup 후 st_check_actual_system을 실행한다. E6이 주요 st 함수 중복을
   자동 확인하며 필요할 때만 which 함수명 -all로 상세 경로를 확인한다.
6. 정리된 과거 브랜치를 다시 만들거나 과거 tip을 전체 병합하지 않는다.
7. R2025b 결과가 없으면 정적 검증과 런타임 검증을 명확히 분리한다.
8. 새 런타임 결과와 결정이 생기면 이 문서의 기준일, 커밋, 검증 상태를 갱신한다.

## 다음 작업 순서

### 2026-09-09 Harness Workflow v2

- 브랜치 `feat/harness-workflow-v2`는 `53c7e41076996be36cedf901a75d82e72662be55`에서
  시작했다. 제품 `VERSION.txt`는 0.9.6을 유지한다.
- `6bea60e`는 OFF 대상의 직계 Inport 조건을 제거했다. Signal Editor가 있으면
  `UT_REQ_{CUTName}_001`로 연결하고, 블록 자체가 없을 때만 WARN과
  `SKIP_NO_SIGNAL_EDITOR`로 입력 없는 TC를 계속한다. 손상/중복은 실패한다.
- `e0add98`은 `ExecutionModelMode=ORIGINAL|STANDALONE_HARNESS`, manifest v2,
  일회용 모델 복사본 export, CUT 이름/인터페이스 검증, 실행 Test Case API 재배선,
  manifest 순서 PER_CUT 실행과 기대값 갱신 경로를 추가했다.
- `CoverageBoundaryMode=OFF|CUT_ONLY`는 기존 CoverageFilterMode와 독립적으로
  해석한다. OFF+CUT_ONLY도 AUTO에서 PER_CUT을 선택하며 internal Harness와
  standalone 모델의 실제 실행 CUT를 기준으로 외부 규칙을 생성한다.
- `st_export_test_specification`도 직계 Inport가 아니라 Signal Editor 존재와 실제
  TC 연결을 기준으로 입력을 추출한다. OFF+no-Inport라도 연결된 시나리오를 출력하고,
  Signal Editor 자체가 없을 때만 `SKIP_NO_SIGNAL_EDITOR` WARN으로 처리한다.
- 현재 PC에는 MATLAB과 MISS_HIT 실행 환경이 없다. `git diff --check`와 정적 계약
  테스트 소스 검토만 수행했으며 MATLAB 단위/통합/fixture는 실행하지 못했다.
- R2025b에서는 위 "반드시 확인할 항목"의 15개 증거와 `CVF-CHECK-v2`,
  `SYSTEM-CHECK-v1`, 대상 manifest/CVF/보고서를 보관해야 한다. 그 전에는 main에
  통합하거나 런타임 인증 완료로 표현하지 않는다.

### 2026-09-09 Template Harness clone 전환

- `09b16ee` 및 `b6d30a8`의 Import 전용 변경만 제거하고 후속 명세서 개선은 유지했다.
- `HARNESS_CLONE`, `SourceCUTPath`, `SourceHarnessName`으로 Template을 선택한다.
  SourceCUTPath는 원본 모델 이름을 포함한 전체 경로다. 기본 `OverwriteHarness=false`.
- clone은 DestinationOwner를 명시한다. 입력 MAT를 독립 보존한 뒤 기존 SLDV·입력·
  Assessment·Harness 설정 함수를 재사용한다. Step1은 비어 있고 Step2 전이는
  after(ExpectedValueSampleTime, sec), 기본 0.01초다.
- 기존 대상 교체는 recovery Harness clone을 저장한 뒤 수행한다. 복구 실패 시
  로그의 recovery Harness와 result/harness_clone transaction을 보존한다.
- 실패 CUT는 후속 준비와 실행에서 제외하며 정상 CUT는 계속 처리한다.
- 세부 사용법과 런타임 체크: `docs/harness-template-clone.md`.
- MATLAB은 이 PC에서 발견되지 않았다. 새 단위/통합 테스트는 런타임 미수행이다.
  정적 검사 결과만으로 clone/CUT 연결이나 복구가 런타임 검증됐다고 표현하지 않는다.


### 2026-09-04 테스트 명세서 추출 추가

- verify 기본 모드는 직계 Step 2이며, 이름의 대소문자와 `_`, 공백, `-`, 앞자리 0을
  정규화해 `step2`, `step_2`, `Step 2`, `STEP-02` 등을 같은 단계로 인식한다. 정확한
  `step2`가 있으면 우선하고 중첩 단계는 선택하지 않는다. `VerifyMode=ALL_STEPS_COLUMNS`를 지정하면
  verify가 있는 스텝마다 오른쪽 열을 추가한다. 실패한 다른 스텝·전이 때문에 정상
  step2 내용이 사라지지 않도록 수집을 분리했고, 상세 시트에 ReadStatus/Message를 추가했다.
- `test_specification_verify_modes.m`에 스텝 선택·순서·부분 실패·동적 열/셀 제한
  회귀 검사를 추가했다. MATLAB 없는 PC에서 정적 검사만 가능하며 실제 대상은 실행하지 않는다.
- 추가 요청으로 MaxTime 열을 넣었다. 이후 의미를 생성 방식별로 바로잡아 SLDV
  `FILE/GENERATE`는 연결된 TC 입력 시나리오의 Tmax를, `OFF` 대상은
  실제 Harness Solver `StopTime`을 기록한다. 해당 기준값을 확인할 수 없으면
  NaN(Excel 빈 셀)과 비고를 남기며 다른 기준으로 자동 대체하지 않는다.
- 시간값 선택은 `st_specification_max_time`으로 분리했고, OFF에 시간 입력이 있어도
  입력 Tmax를 쓰지 않는 회귀 검사와 SLDV의 StopTime fallback 금지 검사를 추가했다.
  현재 PC에는 MATLAB이 없어 이 변경도 정적 검사만 수행했다.
- 명세서의 `DecisionBlocks` 열은 CUT 아래 If/MinMax/Switch/MultiPortSwitch/SwitchCase
  후보를 블록 이름과 `D번호 [분기종류]블록유형 (저장된 조건/선택 설정)` 두 줄씩
  기록한다. If/Switch는 `[T/F]`, MinMax/MultiPortSwitch는 `[SELECT]`, SwitchCase는
  `[CASE]`를 사용한다. 원본 Outcome, BlockType, Name, Expression, 전체 경로와 개별
  JSON 객체, 읽기 상태는 `DecisionBlockDetails` 시트에 블록별 행으로 기록한다.
  Name은 경로 문자열을 분리하지 않고 `get_param(path,'Name')`으로 읽는다. `SearchDepth=1`로
  CUT의 직계 자식만 정렬·중복 제거하며 하위 Subsystem, 마스크, 라이브러리 링크,
  Variant, 참조 모델 내부 및 Stateflow/MATLAB Function 내부 분기는 포함하지 않는다.
- 명세서 Excel의 첫 번째 시트는 `사용법`이다. 사용자 실행 진입점과 단계별 고급
  명령의 역할, 사용 시점, 대표 호출을 기록하며 같은 내용은
  `docs/execution-commands.md`에도 유지한다.
- `OverflowDetails` 시트는 overflow가 없어도 생성하며, Excel 셀 한도 초과 값은
  계속 해당 시트에 전체 분할 보존한다. 단,
  `input 시나리오 내용`과 `verify 내용*`은 원래 셀에 첫 분할 조각을 표시하고 같은
  행의 `비고`에 열 이름과 `[OverflowDetails!E시작:E끝]` 참조를 기록한다.
  DecisionBlocks 등 나머지 열은 기존처럼 원래 셀에 참조 문자열을 표시한다.
- 실제 PC에서 9행 수집 후 셀 제한 처리 중 char(string(...))에서 missing 변환 오류가
  보고됐다. MaxTime NaN을 포함한 숫자 셀은 텍스트 검사에서 제외하고 문자열 missing은
  빈 셀로 정규화했다. NaN·0·유효 시간·문자열 missing의 저장/읽기 회귀 검사를 추가했다.
  수정 후 MATLAB 실행 검증은 미수행이다.
- `st_export_test_specification`은 기존 실행 흐름과 독립된 읽기 전용 명세서 추출 명령이다.
- 실제 Assessment 시나리오 전체, iteration별 입력 연결, 마지막 입력 샘플 및 verify를
  Excel로 기록한다. 배열·버스 경로 생성은 `st_indexed_expressions`를 공유한다.
- MATLAB 없는 PC에서 MISS_HIT 구문/정적 검사만 수행했다. 실제 대상 테스트는 실행하지 않았다.
- R2025b에서는 `tests/unit/test_export_test_specification.m`의 비시뮬레이션 검사와
  저장된 실제 하네스의 Excel 추출을 확인해야 한다. API 반환 형식, 시나리오 스텝 순서,
  버스 배열 경로, 줄바꿈/overflow 서식과 원본·기존 세션 보존은 아직 런타임 미검증이다.
- 명령과 확인 절차는 `docs/test-specification.md`에 있다. 기존 CVF 검증 기준은 유지한다.
- 실제 PC 전달 로그: 미저장 Top Model에서 `SpecificationUnsaved`로 중단된 뒤
  중첩 `cleanup_session`이 해제된 `openedTestFile`을 참조하여 onCleanup 경고가 발생했다.
  정리 콜백을 인수를 캡처하는 로컬 함수로 분리했다. 미저장 보호는 유지하며, 해당 오류
  경로의 회귀 검사를 추가했다. 수정 후 실제 MATLAB 재검증은 아직 미수행이다.

### 기존 통합 검증

1. R2025b PC에서 최신 활성 브랜치를 fast-forward하고 실제 PER_CUT 실행을 수행한다.
2. 18비트 전체 코드, CUT별 6비트 코드와 상세 산출물을 분석해 필요한 수정만 새
   커밋으로 반영한다.
3. CERTIFY + BOTH와 수동 GUI 증거가 끝난 뒤에만 PR과 main 통합을 결정한다.

정적 검증: 변경·추가 MATLAB 파일 중 37개가 MISS_HIT UTF-8 검사에 통과했다.
Signal Editor의 `import(reader)` 파서 오류는 Import 이전 기준 `7f0825e`에서도
동일하게 재현되는 기존 도구 제한이다. MATLAB 단위·통합 테스트 실행 결과와 구분한다.
