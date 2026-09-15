# Codex 전용 작업 인수인계

이 문서는 사용자용 매뉴얼이 아니다. 다른 PC나 새 Codex 작업이 현재 브랜치와
검증 경계를 잘못 해석하지 않도록 유지하는 작업 상태 문서다. AGENTS.md의 지시에
따라 브랜치 변경, 병합, MATLAB 런타임 작업 전에 반드시 읽는다.

## 현재 기준

- 기준일: 2026-09-15
- 활성 개발 브랜치: feat/harness-workflow-v2
- Standalone Action 단순화 작업 시작 기준: 3e5ed63
- 필수 기능 기준: feat/per-cut-filtered-execution의 7f0825e
- 필수 handoff 기준: 2b3ba09 이후
- 필수 진단 기준: 현재 브랜치 최신 커밋의 st_check_actual_system 포함
- MATLAB R2025b 검증: 2026-09-15에 실제 업무 모델(대상 26개)로 standalone
  export → EXECUTE → PACKAGE → SUMMARY → checker 경로를 최초 통과했다. 범위는
  아래 "2026-09-15 R2025b 실행 확인"에 한정하며 그 밖은 여전히 미검증이다.
- 현재 PC(에이전트): MATLAB 실행 파일과 실제 result 폴더 없음. 실행 증거는
  사용자 PC에서만 나온다.
- 완료 표현: 정적 구현 완료까지만 허용하며 인증 완료나 PR 준비 완료로 표현하지 않는다.

## 2026-09-15 R2025b 실행 확인

실제 업무 모델에서 통과한 범위만 기록한다. 여기 없는 항목은 미검증으로 남는다.

- 확인된 경로: `st_run_standalone_coverage_pipeline('Action','ALL')`
  (`SaveTestResult=false`)로 EXECUTE → PACKAGE → SUMMARY, 이어서
  `st_check_standalone_coverage`. 대상 26개.
- 확인된 산출물: `FILES model=26 input=26 cvf=25 cvt=25 html=25 result=0
  forbidden=0`, `SUMMARY rows=26 columns=11 status=OK`. 11열 CoverageSummary와
  TC 이름 기반 `{TC}.cvf`/`{TC}.cvt`/`{TC}.html` 계약이 실제로 성립했다.
  이 확인 이후 제출물 이름 규칙에 `UT_REQ_` 접두사를 도입했으므로, 아래 기록의
  `{TC}` 표기는 현재 코드에서 `UT_REQ_{TC}`로 읽는다.
- 라이브러리 링크: CUT이 링크 **내부**에 있는 경우
  (`StaticLinkStatus='implicit'`, ReferenceBlock이 라이브러리 하위 블록)가 실재한다.
  `find_system` 기본값은 링크 경계를 넘지 않아 원본 CUT의 포트가 0개로 보이고
  export 사본은 실제 포트를 보고하므로 인터페이스 비교가 영원히 실패했다.
  `identify_standalone_cut`/`interface_signature`에 FollowLinks/LookUnderMasks를
  명시해 복구했고, 그 뒤 26개 중 25개가 정상 패키징됐다. 사용자 측정치:
  기본 옵션 1개(자기 자신) vs 링크 추적 5개.
- EXCEPT: 알려진 defect 모델 1개가 `ExecutionStatus=EXCEPT`로 끝났고 standalone
  Harness와 Input은 보존됐다. 이것이 정상 기대 동작이다. checker는 EXCEPT를
  몰라 26개 전부의 B1·B6을 0으로 만들었으므로 축소 계약으로 고쳤다.
  B5(필터)·B7(metric)은 비해당, B10(cleanup)은 계속 강제한다.
- 판정 정책: 모든 비트가 1이어도 EXCEPT 대상이 있으면 PASS가 아니라 PARTIAL이다.
  커버리지 누락을 녹색 코드 뒤에 숨기지 않는다는 사용자 결정이다.
- 성능 실측: `dependencies.toolboxDependencyAnalysis`가 manifest 단계를 지배해
  사용자가 중단했다. RequiredProducts를 읽는 코드가 없어 배송 번들은 옵션으로,
  pipeline/verification snapshot의 내부 번들은 무조건 끈다. checker는 금지 산출물
  스캔을 단일 순회로 바꾼 뒤에도 226초이며 남은 비용은 SHA-256 재해시다.
- 이 실행으로 검증되지 **않은** 것: 패키지 Test Manager launcher와 MLDATX 열기,
  Coverage REPORT 화살표가 여는 `UT_REQ_{TC}.html`, HTML의 CVF 표시 이름,
  결과 재생성(v3),
  model profile과 단계 재시작, `AnalyzeProducts=true`의 실제 소요시간,
  경고 억제(`cfg.SuppressedWarnings`).

## 2026-09-15 profile / 단계 재시작 구현

- `st_save_model_profile`, `st_list_model_profiles`, `st_select_model_profile`:
  로컬 `model_profiles.mat`, 활성 선택 `runtime_target.mat`. profile별 결과/상태 경로 분리.
  여러 모델 병렬 실행 기능이 아니며 기존 단일 모델 선택도 유지한다.
- `st_create_example(destination)`: FILE/MAT 익명 model/Excel/input 로컬 생성만 수행.
- `st_check_readiness` / `st_run_from_stage`: 선행 단계 무수정 검사 후 명시 단계부터
  끝까지 실행. 기존 AUTO/FORCE 동작과 구분한다. 무효 선행 단계는 자동 복구하지 않는다.
- workflow state v2 `RestartEvidence`: 독립 stage input/output hash, RUNNING/FAIL/
  UNVERIFIED/OK 상태. 기존 v1 구조 readback은 허용하지만 ASSESSMENT와 non-OFF SLDV는
  새 증거가 필요하다. readback 실패는 기존 workflow를 깨지 않고 WARN으로 남는다.
- pipeline manifest v3: ReplayInputs/PackageInventory; v2 로드는 유지한다.
  PACKAGE/SUMMARY 재생성은 새 id와 provenance 사본을 만들고 실행 0회, export 0회를 기록한다.
  PACKAGE import 1회 / SUMMARY import 0회. 기존 id의 Action 1회 제한은 바꾸지 않는다.
  실패/부분 파생 결과는 latest를 바꾸지 않는다. `.work` 유실 시 PACKAGE 재생성 불가.
- 실제 업무 MATLAB 실행은 하지 않았다. MISS_HIT 문법 검사와 diff 검사만 수행한다.
  `docs/manual/runtime-verification.md`에 새/기존 integration과 수동 GUI 검증을 모았다.
- 미검증 핵심: R2025b Harness read-only load/close의 Dirty/synchronization 동작,
  `TestIteration.TestParams` 실제 readback 형태, Assessment step 직렬화 안정성,
  예제의 기대값/APPLY 이후 재시작, EXCEPT와 저장 결과 import, 재생성 후 checker 전 비트.
  다른 릴리스에서 해석할 수 없는 binding은 성공으로 추정하지 않고 차단한다.
- 2026-09-15 후속: STANDALONE_HARNESS export의 전체 Top Model dependency 분석은
  unrelated branch와 Function Caller 이름 때문에 장시간/실패할 수 있어, 생성된
  standalone 모델별 분석으로 변경했다. runner와 standalone preparation은 설정용
  Top Model을 로드하지 않는다. R2025b에서 실제 dependency union, dependency 없는
  standalone 모델, 누락 standalone dependency의 fail-closed 경계를 검증해야 한다.
- 원본 모델이 바뀐 뒤 과거 결과를 재생성하면 현재 소스 불변 검사 B9는 실패할 수 있다.
  원본/파생 이력을 삭제·이동하기 전 재생성 및 provenance 경로 의존성을 안내한다.
- 사용자는 `docs/manual/README.md`부터 읽는다. 이 handoff는 사용자 설명을 대체하지 않는다.

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
16. If/Switch/MinMax/MultiPortSwitch/SwitchCase와 Saturate/Abs/DeadZone/RateLimiter/
    Relay/Lookup_n-D/Interpolation_n-D/PreLookup/Integrator/DiscreteIntegrator/
    ForIterator/WhileIterator/Logic이 있는 CUT의 명세서를 export하고, 블록 이름 다음
    줄의 D번호·저장 파라미터 표현과 DecisionBlockDetails의
    Outcome/Expression/ReadStatus가 실제 블록 설정과 일치하는지 확인한다. 메인 시트가
    전부 `[T/F]`이고 세부 시트 `Outcome`만 종류별로 갈리는지 확인한다. 각 암시적
    블록의 `BlockType` 문자열과 파라미터 이름이 실제 `get_param` 결과와 일치하는지,
    철자가 틀려 조용히 0건으로 나오지 않는지 확인한다.
17. FILE+MAT 단일/복수 Dataset, 명시적 MatVariableName, Scenario 간 및 Harness
    interface mismatch, Dataset 없음·시간 없음, nested dataNoEffect를 확인하고 MAT
    실행에서 sldvsimdata와 parameter override가 호출되지 않는 증거를 보관한다.
18. 사용 가능한 Harness 출력이 0개인 ORIGINAL/STANDALONE 대상을 실행하여
    Assessment 구성, verify timing, ExpectedUpdateMode=APPLY가 각각
    SKIP_NO_VERIFY_OUTPUT으로 계속되는지 확인한다. 출력이 있는 대상의 verify 결과
    누락과 Untested는 계속 실패하는 반대 사례도 함께 보관한다.
19. 실제 library-linked CUT에서 일반 생성과 HARNESS_CLONE을 각각 수행해 Harness가
    SyncOnOpen이고 원본 CUT의 StaticLinkStatus·ReferenceBlock·library 파일 checksum이
    전후 동일한지 확인한다. FILE+MAT는 Atomic 변환을 생략하고, 비-Atomic
    FILE+SLDV/GENERATE는 원본 링크를 바꾸지 않은 채 명시적으로 실패해야 한다.
20. `st_run_standalone_coverage_pipeline`의 `ALL` live Result 경로와 `EXECUTE` 뒤
    새 MATLAB 세션에서 `PACKAGE`/`SUMMARY`를 재개하는 경로를 모두 확인한다.
    standalone TC property readback, Test Case별 run 1회와 CVF 등록 1회, 공식 ZIP의
    `UT_REQ_` 접두사가 붙은 HTML/CVF/CVT, `%03d_UT_REQ_{TC}` 폴더와 정확한 11열
    CoverageSummary.xlsx를 확인한다.
    Decision/Execution 분모 0은 N/A여야 하며 원본 모델·Test File·Excel·Input
    checksum, Dirty와 Harness inventory가 전후 같아야 한다. 최종
    `st_check_standalone_coverage`가 `1111111111 PASS`인지 확인하고 Test Manager
    GUI의 Results and Artifacts → Results → Coverage Filters 표시도 수동 증거로
    남긴다.

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
- R2025b에서는 위 "반드시 확인할 항목"의 17개 증거와 `CVF-CHECK-v2`,
  `SYSTEM-CHECK-v1`, 대상 manifest/CVF/보고서를 보관해야 한다. 그 전에는 main에
  통합하거나 런타임 인증 완료로 표현하지 않는다.

### 2026-09-09 FILE 일반 MAT Dataset 입력

- `SldvMode=FILE`에서 optional `DataFileFormat=SLDV|MAT`와 `MatVariableName`을
  읽는다. 새 열이 없으면 `SLDV`가 기본이어서 기존 `sldvData` 흐름이 유지된다.
- MAT parser는 비어 있지 않은 scalar `Simulink.SimulationData.Dataset` 변수를
  이름순으로 선택하고, 모든 Scenario와 Harness ActiveScenario의 입력 개수·순서·
  이름·자료형·차원을 정확히 검증한다. 마지막 신호 시간의 최댓값을 EndTime으로
  사용하며 시간 없는 Dataset은 실패시킨다.
- MAT Scenario는 기존 이름 규칙을 사용하고 원래 변수명을 `OriginalNames`로 보존한다.
  `ParameterCounts=0`으로 정상화하여 Test Manager에서 `sldvsimdata`와
  `st_apply_sldv_parameters`를 건너뛴다.
- SLDV와 MAT parser는 공통 profile/meta schema로 합쳐지고 Signal Editor부터 같은
  workflow를 사용한다. Dataset 이름은 공통 `st_dataset_signature`의
  `getElementNames`로 읽고 nested cell `dataNoEffect`는 재귀적으로 처리한다.
- 현재 PC에는 MATLAB과 MISS_HIT 실행 환경이 없다. 정적 검사와 소스 계약 테스트만
  수행하며 R2025b에서는 위 17번의 성공/실패 경계와 원본 파일 불변 증거가 필요하다.

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

### 2026-09-09 출력 없는 대상의 verify 처리

- `VerifyHarnessOutportsOnly=true`에서 실제 실행 Harness 또는 standalone 모델에
  사용 가능한 최상위 출력 신호가 0개이면 빈 verify Action을 정상으로 허용한다.
  verify timing 검증과 기대값 갱신은 `SKIP_NO_VERIFY_OUTPUT`으로 기록한다.
- 출력이 하나라도 있으면 verify 결과 없음과 Untested는 이전과 동일하게 실패한다.
  `VerifyHarnessOutportsOnly=false`도 출력 개수와 무관하게 verify 결과가 필요하다.
- PER_CUT verify 검증은 현재 대상 행만 전달하여 standalone 실행 context와 다중 CUT
  매핑을 보존한다.
- 현재 PC에는 MATLAB이 없어 순수 정책 테스트와 정적 계약 검사만 작성했다. R2025b
  런타임 검증은 위 18번 증거를 추가한 뒤에만 완료로 판단한다.

### 2026-09-10 library-linked CUT Harness 보호

- 실제 `st_run_after_harness(..., 'ExecutionMode','PER_CUT')` 사용 중 원본을 복구해야
  할 정도로 library link가 끊긴 사례가 보고됐다. 당시 모델은 이미 원복되어 정확한
  StaticLinkStatus와 crash dump는 확보하지 못했다.
- linked CUT Harness는 `SyncOnOpen`으로 생성하고, 기존·clone Harness도 처음 열기 전에
  같은 모드로 보정한다. Harness 종료 시 CUT 복사본을 원본으로 push하는
  SyncOnOpenAndClose 경로를 사용하지 않는다.
- create/clone/close 전후 StaticLinkStatus와 ReferenceBlock을 비교해 변화가 있으면
  `HarnessChangedLibraryLink`으로 즉시 중단한다.
- FILE+MAT는 Atomic 변환을 생략한다. FILE+SLDV와 GENERATE의 비-Atomic linked CUT는
  자동 수정하지 않고 `SldvLinkedCUTRequiresAtomic`으로 실패시킨다.
- R2025b용 실제 library fixture를 추가했지만 현재 PC에는 MATLAB이 없어 실행하지
  못했다. 위 19번 증거 전에는 runtime 해결 완료로 판단하지 않는다.


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
- 명세서의 `DecisionBlocks` 열은 CUT 아래 명시적 분기(If/MinMax/Switch/
  MultiPortSwitch/SwitchCase)와 암시적 분기(Saturate/Abs/DeadZone/RateLimiter/Relay/
  Lookup_n-D/Interpolation_n-D/PreLookup/Integrator/DiscreteIntegrator/ForIterator/
  WhileIterator/Logic) 후보를 블록 이름과 `D번호 [T/F]블록유형 (저장된 조건/선택
  설정)` 두 줄씩 기록한다. **메인 시트는 분기 종류와 무관하게 항상 `[T/F]`를 쓴다.**
  구체적인 Outcome(`SELECT`, `CASE`, `LIMIT`, `BAND`, `RATE`, `ON/OFF`, `SIGN`,
  `INTERVAL`, `LOOP`, `CONDITION`)은 BlockType, Name, Expression, 전체 경로, 개별 JSON
  객체, 읽기 상태와 함께 `DecisionBlockDetails` 시트에 블록별 행으로만 기록한다.
  Name은 경로 문자열을 분리하지 않고 `get_param(path,'Name')`으로 읽는다. `SearchDepth=1`로
  CUT의 직계 자식만 정렬·중복 제거하며 하위 Subsystem, 마스크, 라이브러리 링크,
  Variant, 참조 모델 내부 및 Stateflow/MATLAB Function 내부 분기는 포함하지 않는다.
  자식 Enabled/Triggered Subsystem의 제어 포트 분기와 마스크 Subsystem으로 구현된
  Saturation Dynamic/Dead Zone Dynamic/Unit Delay Enabled/Unit Delay Resettable은
  `BlockType`이 `SubSystem`이므로 제외한다.
- 스캔 대상 BlockType, Outcome 토큰, 표시 별칭, 읽을 파라미터는 전부
  `src/exporting/st_specification_decision_catalog.m` 한 곳에 있다. 타입 추가는 catalog
  한 행이며, 표현식 조립이 불규칙한 타입만 `st_specification_decision_descriptor`의
  `case`를 추가로 필요로 한다(`Formatter` 열이 그 구분을 명시한다). 파라미터가
  비활성이어도 행을 거르지 않고 상태를 표현식에 남긴다. breakpoint 등 값은 workspace
  에서 평가하지 않고 저장된 문자열 그대로 옮긴다.
- 의도적으로 열어 둔 확장점 두 가지. (1) `outcome`이 `switch` 앞에서 배정되므로
  `Formatter="CUSTOM"` case가 읽은 값에 따라 Outcome을 덮어쓸 수 있다(메인 셀은
  `[T/F]` 고정이라 영향 없음). (2) `Delay` 블록과 Enabled/Triggered Subsystem 지원은
  각각 catalog 한 행 또는 포트 탐침 추가로 확장 가능하다.
- MATLAB 없이 작성한 미검증 런타임 가정: `PreLookup`의 대문자 L, `Lookup_n-D`와
  `Interpolation_n-D`의 하이픈 표기, `Saturate`(Saturation 블록) BlockType 철자.
  `find_system`은 모르는 BlockType에 에러가 아니라 빈 결과를 주므로 철자가 틀리면
  **조용히 0건**이 된다. 반면 필수 파라미터 이름이 틀리면 `조건식 읽기 실패` WARN 행이
  되어 note에 원인이 남는다. 그래서 BlockType 철자 세 개를 가장 먼저 확인한다.
  이름이 불확실한 파라미터는 catalog의 `OptionalParameters`에 두어 실패해도 표현식에서
  빠지기만 하게 했고, 런타임 확인 후 `Parameters`로 승격한다.
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

### 2026-09-09 SLDV 서브시스템 경로 임시 호환

- `cfg.AllowSldvSubsystemPathMismatch=true`를 기본값으로 추가했다. `FILE+SLDV`
  MAT의 `sldvData.ModelInformation.SubsystemPath`가 대상 CUT 전체 경로와 달라도
  예상·실제 경로와 파일을 WARN으로 기록하고 계속 준비한다.
- Harness ActiveScenario 입력 인터페이스, SLDV 입력 선택과 이후 Scenario 검증은
  그대로 유지한다. 엄격 차단으로 복귀할 때는 설정을 `false`로 바꾸면 된다.
- 해당 설정을 SLDV 증분 실행 signature에 포함했다. 현재 PC에는 MATLAB이 없어
  정적 계약 검사만 수행했으며 실제 라이브러리 링크 CUT 재사용은 R2025b에서 확인해야 한다.

### 기존 통합 검증

1. R2025b PC에서 최신 활성 브랜치를 fast-forward하고 실제 PER_CUT 실행을 수행한다.
2. 18비트 전체 코드, CUT별 6비트 코드와 상세 산출물을 분석해 필요한 수정만 새
   커밋으로 반영한다.
3. CERTIFY + BOTH와 수동 GUI 증거가 끝난 뒤에만 PR과 main 통합을 결정한다.

### 2026-09-14 Standalone Harness Coverage Action pipeline

- 구현 커밋은 `debff6a`(controller/prepare-only), `5f935d9`(결과 CVF 사후 등록),
  마지막 `feat(report): CUT별 산출물과 Coverage Excel 정리` 순서다.
- 이전 단계형 공개 API는 제거했다. `st_run_standalone_coverage_pipeline`은
  `EXECUTE`, `PACKAGE`, `SUMMARY`, `ALL` Action을 지원하고 기본값은 `ALL`이다.
  Harness/Test Case/Expected 준비는 `st_run_from_harness`에만 둔다.
- `EXECUTE`는 재현 번들의 standalone Harness 작업 사본과 재연결된 Test File을
  사용한다. 모든 활성 대상은 ALL_CONTENT+CUT_ONLY+EXCLUDE와 rationale이
  필수다. 일반 PER_CUT 기본은 DURING_RUN을 유지하고 pipeline만
  POST_RUN_REQUIRED를 사용한다.
- 결과 필터 helper는 cvdata, cv.cvdatagroup, cell 반환을 평탄화하고 filter 절대
  경로 readback과 decisioninfo/executioninfo를 검증한다. 생산 경로의 결과
  round-trip은 제거하고, `ALL`은 live Result, 별도 `PACKAGE`는 aggregate Result를
  한 번 import한다.
- pipeline manifest와 SHA-256은 원자적으로 갱신되며 latest.json으로 재개한다.
  `PACKAGE`는 공유 Test Manager 사본, CUT별 standalone 모델·input·CVF·CVT와
  Test Manager Coverage Results의 REPORT 화살표가 여는 원본 `cvhtml` root
  TC 이름 `.html`을 만들고 `SUMMARY`는 정확한 11열 CoverageSummary.xlsx를 원자적으로
  교체한다. PDF, TestSummary.xlsx와 coverage-metrics.mat는 만들지 않는다.
- bundle 실행 후 copied Test File과 copied Top Model을 닫고 caller의 MATLAB path와
  현재 폴더를 복원한다. 이 상태와 외부 Harness/Input 파일 checksum도 manifest와
  one-screen checker에서 확인한다.
- 현재 PC에는 MATLAB과 MISS_HIT 실행 환경이 없어 `git diff --check`와 정적 계약
  검사만 수행할 수 있다. `tests/integration/test_standalone_coverage_pipeline_runtime.m`
  및 위 20번 R2025b/GUI 증거 전에는 main에 통합하지 않는다.
- PACKAGE의 남은 `cvsave`는 닫힌 execution model을 참조하는 Coverage 객체를
  직렬화하므로, 실행 model이 열린 `capture_package_evidence`로 이동했다. PACKAGE는
  CVT/HTML/metric evidence의 SHA-256을 검증해 복사만 한다. R2025b에서는 ALL 및
  EXECUTE→PACKAGE→SUMMARY 모두 `Package=OK`, CUT별 TC 이름 `.html`/`.cvt` 생성과
  `st_check_standalone_coverage = 1111111111`을 확인해야 한다. PACKAGE 예외는
  `PackageFailure.Stack`에 최초 호출 파일·라인을 보존한다. 실행 명령은
  `docs/manual/standalone-coverage-runtime.md`에 있다.
- R2025b Test Manager CoverageSettings readback의 `MetricSettings='d'`는 Decision이
  Block Execution을 포함하는 legacy 표기이므로 정상이다. 이 값에 `e`가 없다는 이유로
  EXECUTE를 중단하면 안 된다. matched CUT에서 CVF가 모든 objective를 제외하면
  Decision/Execution 모두 `0/0`, `N/A` (`Percentage=NaN`)와 `MetricStatus=OK`가
  정상이며, unmatched coverage object와 혼동하지 않도록 summary 수집 단계에서만
  zero-denominator row를 만든다.
- `e8346c6` 이후 실제 `ALL`에서 1·4번 CUT은 EXECUTE/PACKAGE가 통과했지만 2·3번
  CUT의 package evidence 캡처가 `The current directory is read only`로 실패했다.
  PACKAGE의 `st_package_standalone_coverage_artifacts:37`은 이미 실패한 EXECUTE
  lifecycle을 전달한 위치다. CVSAVE와 CVHTML은 모두 writable scratch 격리가 적용된
  상태이므로, 실패 CUT의 남은 CVT/report/ZIP/evidence 파일과 ExecutionLog event로
  실제 실패 API를 먼저 구분해야 한다. 진단 명령은
  `docs/manual/standalone-coverage-runtime.md` 3절에 있다.
- 진단 결과 실패 CUT 모두 `CoverageResult.cvt`는 있고 Coverage report/ZIP은 없어
  `cvhtml` 실패로 확정됐다. 실패한 두 report.html 절대 경로는 262자, 통과 target은
  235·257·259자로 Windows legacy 260자 경계와 일치했다. 기존 격리는 MATLAB `pwd`만
  짧게 바꾸고 `cvhtml`에는 긴 절대 출력 경로를 전달한 것이 결함이었다. 이제 report
  tree와 ZIP을 writable scratch 내부에서 완성하고, 260자 미만인 단일 ZIP만 evidence
  경로로 복사한다. R2025b 새 `ALL` 재검증이 필요하다.
- 실제 새 `ALL`은 끝까지 성공했지만 packaged MLDATX를 Test Manager UI에서 직접
  열면 `..._Harness1` standalone model을 찾지 못했다. MLDATX의 Model SUT는 Harness가
  아니라 CUT별 package folder의 standalone `.slx`이고, 직접 load는 그 folder들을
  MATLAB path에 추가하지 않는다. PACKAGE는 launcher를 TestManager folder에 함께
  제공해 model path/load와 packaged CVF Test Case readback 후 GUI를 열도록 보강했다.
  실행 때 Result coverage object에 CVF를 사후 연결하는 방식은 공식 `cvdata.filter`
  API의 지원 범위다. 다만 R2025b 실제 실행에서 Result hierarchy를 다시 조회하면
  새 `cvdata` 객체가 materialize되어 앞서 등록한 filter readback이 비어 보였다.
  이전 객체가 비었다는 이유만으로 EXECUTE를 실패시키는 검증은 제거했다. capture는
  CVSAVE/CVHTML/metric에 실제로 넘길 새 객체에 CVF를 다시 bind하고 그 즉시 readback한
  뒤 진행한다. 새 `ALL`에서 `Standalone original Coverage report CVF binding complete`
  로그와 CVF의 Excluded/Justified HTML 표시를 확인해야 한다.
- packaged Test Manager launcher의 `CoverageFilterFilename` readback은 R2025b에서
  canonical absolute path 대신 CVF basename을 반환할 수 있다. 빈 readback은 계속
  실패로 처리하되 동일 basename은 성공으로 인정한다. 이미 PACKAGE가 완료된 결과는
  새 template을 `m.TestManagerLauncher`로 복사한 뒤 다시 실행해 재패키징 없이 연다.
- Test Manager Model SUT 속성은 model file path가 아니라 model name만 직렬화한다.
  그러므로 `.mldatx`를 다른 사용자에게 전달해도 standalone Harness 결과 folder가
  MATLAB path에 없으면 UI의 folder picker 뒤 Refresh/All에서 model-not-found가
  재발할 수 있다. 수동 UI 경로는 folder를 Add to Path 한 뒤 같은 Harness를 선택하는
  것이며 launcher는 그 반복 작업의 편의 수단일 뿐 portable path를 저장하는 해법은
  아니다. CVF 표시 metadata는 filter name=`TestCaseName`, description=`none`, 모든
  rule rationale=`none`으로 고정했다. PACKAGE target folder, packaged CVF/CVT와
  공식 report HTML은 `TestCaseName`을 안전화하고 `UT_REQ_` 접두사를 붙인
  `UT_REQ_{TC}.cvf`/`.cvt`/`.html` 이름을 사용하고 report tree는 별도
  `_CoverageReport` 폴더 없이 target root에 배치한다. 이 stem은
  `st_artifact_stem`이 유일하게 만들며 생산자 4곳과 checker가 모두 그 함수를
  호출해야 한다. 접두사 부여는 멱등이고 80자 상한 안에서 계산한다. HTML의 companion asset은 report render를 위해 같은 root에 유지한다.
  `cvhtml`에는 같은 폴더에 놓일 짧은 표시용 CVF 이름을 bind하고, scratch 폴더가
  제거된 뒤 최종 metric 추출이 같은 coverage 객체를 재사용하므로 보고서 생성
  직후 검증된 절대 경로 CVF 바인딩을 복원한다. 이 bind/복원 helper는
  `capture_package_evidence`의 nested function이면 보고서 subfunction에서 호출할
  수 없으므로 file-level subfunction으로 유지해야 한다. R2025b 재검증이 필요하다.
- Test Case 실행 예외(예: simulation overflow)는 `ExecutionStatus=EXCEPT`로 기록한다.
  해당 상태여도
  PACKAGE는 standalone Harness, 존재하는 Signal Editor input, target manifest를 먼저
  대상 folder에 보존한다. 이후 CVF/CVT/HTML만 `FAIL`로 남긴다. 모델/input 보존 자체가
  실패한 경우에는 그 실패가 PackageStatus에 기록된다. `ContinueOnFailure=true`에서는
  다음 target도 계속 처리한다. R2025b 재검증이 필요하다.
- 실제 R2025b에서 사용자가 Top Model을 열지 않았는데도 target 입력 수집 후
  `StandaloneModelStillLoadedBeforeRun`이 발생했다. export 중간 상태가 아니라
  `st_export_test_bundle` 진입 전 load 상태를 기준으로 dependency/Harness API가
  내부 로드한 clean 모델을 정리하도록 수정했다. exporter의 runner 전용 guard는
  pipeline의 export 전·runner 전 격리 검사로 이동했다. Dirty 모델은 자동 저장이나
  폐기하지 않는다. 수정 후 R2025b 재검증은 아직 미수행이다.
- 후속 재현에서 실제 최초 로더는 pipeline 진입 시 호출한
  `st_require_runtime_target()`임을 확인했다. 이 함수가 모델을 무조건 로드하던 기존
  기본 동작은 유지하되 `LoadModel=false` 옵션을 추가하고, standalone pipeline과
  bundle exporter는 이 옵션으로 saved target만 검증한다. exporter가
  최초 상태를 캡처하기 전에 같은 함수로 모델을 로드하지 않도록 함께 변경했다.
  프로젝트와 모델을 열지 않은 실제 사용자 경로에서 R2025b 재검증이 필요하다.
- 이 수정 적용 후 pipeline은 입력 수집까지 진행했지만, 닫힌 Top Model 아래의
  subsystem CUTPath를 `sltest.harness.load`에 바로 전달하여 "유효하지 않은 Simulink
  객체 이름"으로 실패했다. `collect_target_inputs`가 원본 모델을 해당 범위 안에서
  명시적으로 로드하고 기존 export-entry cleanup으로 다시 unload하도록 보강했다.
  이전처럼 모델을 전역적으로 미리 로드하는 동작으로 되돌린 것은 아니다.
- 후속 실행은 standalone TC readback과 PER_CUT 진입까지 성공했다. 모든 CUT의 CVF
  저장에서 `Slvnv:simcoverage:ioerrors:ReadOnlyDirectory`가 발생했는데,
  `slcoverage.Filter.save`가 절대 파일 경로와 별도로 현재 MATLAB 폴더의 쓰기 가능
  여부를 검사하는 경로였다. save 호출 동안만 `tempdir`로 이동하고 즉시 원래 폴더로
  복원하도록 보강했다. 이후 실패 target을 pipeline manifest로 변환할 때 발생한
  `MATLAB:heterogeneousStructAssignment`는 `empty_target_state`에 빠져 있던
  `CoverageFilterMode` 필드를 추가해 수정했다. 두 변경 모두 R2025b 재검증이 필요하다.
- 다음 실행에서는 CVF 생성과 Test Case 실행까지 성공했지만 결과에 model coverage
  객체가 없어 `ResultCoverageDataMissing`으로 사후 필터 등록이 실패했다. Harness
  SUT를 standalone Model SUT로 바꾼 뒤 작업용 Test File/Suite/Case의
  `RecordCoverage`, file metric과 referenced-model 설정을 다시 적용하고 저장 후
  readback하도록 보강했다. 원본 무결성 검사에서 Harness inventory cell이 scalar
  snapshot struct를 1x4로 확장해 발생한 intermediate indexing 오류는 struct field를
  cell wrapper로 넣어 수정했다. runner 종료 시 이미 제거된 standalone path에 대한
  반복 `rmpath` 경고는 실행 전 전체 path snapshot 복원으로 대체했다.
- 후속 실행은 4개 Test Case 모두 끝까지 실행했지만 ResultSet 최상위의
  `getCoverageResults`가 빈 결과를 반환하여 모든 CUT가
  `ResultCoverageDataMissing`으로 실패했다. 직접 `run(testCase)` 결과에서 Coverage가
  TestCaseResult/TestIterationResult에만 노출되는 구성도 처리하도록 aggregate가
  비었을 때 결과 계층을 내려가는 collector를 추가했다. 이전 실행 단계가 실패하면
  후속 패키징이 CUT 폴더의 model/input 복사까지 생략하던 문제를 확인했으므로,
  이제 standalone 모델·존재하는 입력·target manifest는 필터 결과와 무관하게 먼저
  보존하고 CVF/CVT/report만 검증 성공 시 생성한다. R2025b 재검증이 필요하다.
- 캡처 한 장으로 상태를 전달하는 기존 출력기는
  `st_check_standalone_coverage`로 교체했다. manifest v2, lifecycle event, 실제 파일,
  Excel schema와 원본 checksum을 교차 검사하며 최대 20줄과 10비트 code를 출력한다.
  전체 통과는 `1111111111`뿐이며 Result import나 model load/save를 수행하지 않는다.
- 첫 실제 이전 STATUS 캡처에서 모든 CUT의 RF/restore와 root/hierarchy Coverage가 1로
  성공했지만 실행 대상 상태는 Initial report incomplete로 FAIL이었다. compact
  진단이 원인을 숨기지 않도록 PER_CUT manifest의 FAIL artifact를 type/message별로
  묶어 최대 6개 `AF` 행으로 출력하도록 보강했다.
- 첫 AF 상세 출력은 main/helper가 `lines(end+1)` 선형 인덱싱으로 서로 다른 모양의
  string row를 만든 뒤 결합되어 R2025b의 ambiguous dimension 오류가 발생했다. 모든
  행 추가를 명시적인 `lines(end+1,1)` column append로 수정했다.
- 수정된 AF 캡처에서 모든 CUT의 ResultFilter/restore와 Coverage 객체는 성공했고,
  당시 실행 실패는 `COVERAGE_DATA` 4건, `RESULT_INTEGRITY` 4건, read-only cwd의 CVT/HTML
  각 3건과 후속 Excel 3건이었다. standalone model-root metadata를 CUT path와 매칭하고,
  cvdata의 불안정한 ID 대신 root/checksum/정규화 CVF로 무결성을 비교한다. CVSAVE와
  CVHTML은 짧은 writable scratch에서 호출하며, bundle PER_CUT 출력 루트도 execution
  바로 아래 `r`로 줄였다. 이 내용은 Action 단순화 전 실패 분석 기록이다.
- Action 단순화 후 실제 `ALL` 실행은 4개 CUT 모두 model/input/CVF/CVT까지 생성했지만
  공식 Test Manager HTML 생성에서 `Slvnv:simcoverage:cvhtml:ModelNotOpen`으로
  실패했다. PACKAGE에서 execution standalone 모델을 다시 여는 첫 수정도 같은
  오류가 재현되어, 단순 load state가 아니라 실행 때의 Coverage report context가
  모델 종료와 함께 소실되는 것으로 판단했다. 이제 PER_CUT 실행 직후 모델이 열린
  동안 공식 ZIP과 metric JSON을 임시 증거로 캡처하고, 모델 정리 후 PACKAGE는 해시와
  대상을 검증해 최종 산출물로 승격한다. 실제 재실행에서 모든 CUT의
  `PackageEvidenceStatus=OK`인데도 이전 PACKAGE 구현의 `cvhtml:ModelNotOpen`이
  재현되어, 장기 MATLAB 세션이 디스크 갱신 전 helper를 메모리에 유지한 사실을
  확인했다. controller는 PACKAGE 직전에 helper를 clear/rehash하고 활성 프로젝트
  경로와 `CAPTURED_EVIDENCE_V1` 구현 표식을 검증한 뒤 호출한다. 이 cache 격리
  수정의 R2025b 재검증은 아직 미수행이다.
- cache 격리 적용 후 실제 `ALL`은 PACKAGE와 SUMMARY까지 완료했다. checker는
  `0111100111`로 B1/B6/B7만 실패했으며, 진단 중 `Bits` cell이 struct constructor에서
  펼쳐져 summary가 1x10 struct가 되는 오류를 확인했다. `Bits`를 cell wrapper로
  감싸 scalar summary를 복구했다. 남은 B1/B6/B7의 세부 원인은 추가 runtime 출력이
  필요하다. 기존 PACKAGE catch가 identifier/message만 보존하고 stack을 버려
  `cvhtml:ModelNotOpen`의 실제 호출 지점을 잃는 진단 결함도 확인했다. 이제 target
  manifest에 exception stack을 직렬화하고 checker details에 첫 frame을 표시한다.

정적 검증: 변경·추가 MATLAB 파일 중 37개가 MISS_HIT UTF-8 검사에 통과했다.
Signal Editor의 `import(reader)` 파서 오류는 Import 이전 기준 `7f0825e`에서도
동일하게 재현되는 기존 도구 제한이다. MATLAB 단위·통합 테스트 실행 결과와 구분한다.
