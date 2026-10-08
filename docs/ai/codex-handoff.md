# Codex 전용 작업 인수인계

이 문서는 사용자용 매뉴얼이 아니다. 다른 PC나 새 Codex 작업이 현재 브랜치와
검증 경계를 잘못 해석하지 않도록 유지하는 작업 상태 문서다. AGENTS.md의 지시에
따라 브랜치 변경, 병합, MATLAB 런타임 작업 전에 반드시 읽는다.

**지금 유효한 것만 둔다.** 날짜별 작업 기록(무엇을 왜 바꿨는지, 접은 실험, 과거
브랜치)은 [작업 기록 보관](../archive/codex-handoff-history.md)으로 옮겼다. 과거 결정의
이유를 찾을 때만 그쪽을 본다. 새 기록도 그 파일 끝에 날짜 절로 붙이고, 여기에는
결과로 바뀐 "현재 기준"과 "실물 미검증 목록"만 고친다.

## 현재 기준

- 기준일: 2026-10-08
- 브랜치: 작업은 `develop`, `main`은 `develop`의 fast-forward만 받는다. 사용자의
  MATLAB 클론은 `main`을 `git pull`한다. 자세한 역할은 아래 브랜치 지도.
- R2025b 실물 확인 범위: 2026-09-15에 실제 업무 모델(대상 26개)로 standalone
  export → EXECUTE → PACKAGE → SUMMARY → checker 경로를 처음 통과했다. 그 뒤에
  들어온 기능은 `main`에 있어도 **실물 미검증**이다. `main`에 있다는 것이 검증됐다는
  뜻이 아니다. 미검증 항목은 아래 목록에 모은다.
- 에이전트 PC: MATLAB 실행 파일과 실제 `result` 폴더가 없다. 실행 증거는 사용자
  PC에서만 나온다.
- 완료 표현: 정적 구현 완료까지만 쓰고, 인증 완료나 PR 준비 완료로 표현하지 않는다.
- 사용자 문서의 원본: 절차와 기본 옵션은 `docs/user-manual.md`, 옵션 전체는
  `docs/reference/execution-commands.md`, Excel 열은 `docs/reference/workbook-reference.md`,
  설정은 `docs/reference/config-reference.md`. 같은 내용을 여러 문서에 나눠 적지 않는다.
- 로그 체계: 2026-10-06에 로그 체계 개편(옛 `feat/logging`)이 `develop`에 들어왔고 그 뒤
  `main`에도 들어갔다.
  콘솔은 `cfg.ConsoleLogLevel`(기본 `'STEP'`)로 거르고 모든 레벨은
  `result/logs/<yyyyMMdd_HHmmss>_<명령>.log`에 남긴다. 설계는
  `docs/superpowers/specs/2026-09-29-logging-design.md`, 계획은
  `docs/superpowers/plans/2026-09-29-logging.md`. 2026-10-08 사용자 MATLAB에서
  `tests/unit` 전체(59개 파일)가 실패·미완료 없이 통과했다. **실제 모델 실행 검증은
  아직이다.** 남은 미검증 항목은 아래 "로그 체계 개편" 절에 있다. 실행 로그를 여는
  명령은 13개이며 목록은 `docs/user-manual.md`의 "콘솔에 보이는 줄과 실행 로그"에
  있다(13번째가 `st_classify_standalone_results`). `st_rename_test_file_models`는 로그
  범위를 열지 않고 `disp`/`fprintf` 출력도 그대로다.

## 실물 미검증 목록

정적 구현과 단위 테스트만 거친 것이다. 사용자 실행 결과가 나오면 해당 줄을 지우고
결과를 작업 기록에 남긴다.

- PER_CUT 결과 정리(`st_collect_per_cut_results`), 최종 문서 추출,
  `CloseSourceModel` 자동 저장·닫기 (2026-09-15 확인 범위 밖).
- `release_source_model`이 외부 저장 Harness를 `sltest.harness.set(...,
  'SaveExternally', false)`로 모델 안에 옮기는 동작. `.slx`가 없는 외부 Harness에도
  통하는지.
- 짧은 빌드 폴더: standalone 러너가 `%TEMP%\stt_build\<id>_ws`에서 돌고 기록
  위치로 복사하는 것, SLDV·Harness 생성·PER_CUT 루프의 `st_enter_short_build_directory`.
  Harness 입력 MAT이 짧은 폴더와 함께 지워지지 않는지(create/save를 호출 폴더에서
  돌림), `keepPreviousPath=true`로 입력 MAT이 path에 남는지. `9b491f2` 이후 만든
  Harness는 다시 만들어야 한다.
- 이름이 공백으로 끝나는 CUT: `st_normalize_cut_path`가 `getfullname`을 돌려주는
  경로가 Test Manager·PER_CUT·standalone 커버리지·최종 문서에서 맞는지. 끝 `/`를 붙인
  경로가 R2025b에서 해석되는지는 단위 테스트가 assume으로만 다룬다.
- 함수 호출 CUT의 SLDV 입력 `FcnTriggerPort` 자동 제외: SLDV가 항상 이 이름을 쓰는지
  (관측 1건), `Simulink.io.SLDVMatFile` import 결과도 같은 이름인지.
- `st_classify_standalone_results`(팀 제출 트리 MATLAB 판). Python 판과 같은 결과를
  내는지.
- `st_set_standalone_coverage_root` 기본 루트 `D:\model_result\<Top Model>`.
- `DisableLibraryLinkForSldvTargets` 실물 동작.
- 최종 문서 분기 결과(`DecisionOutcomes`): iteration 단위 `getCoverageResults`가
  결과를 담는지(비면 모든 행이 `DECISION_OUTCOME_UNAVAILABLE`, Metadata
  `DecisionOutcomeUnits=0`), Switch·If·Abs·While Iterator·Enable·Trigger·Reset의
  outcome 텍스트가 `true`/`false`로 시작하는지(For Iterator만 사용자 캡처로 확인.
  아니면 그 블록이 모든 행에서 `DECISION_OUTCOME_UNAVAILABLE`), If의
  `description.decision` 순서가 if→elseif인지, PER_CUT 결과 정리 시간이 얼마나
  늘었는지, `detectImportOptions`가 첫 데이터 행(UNIT 행)에 빈 칸이 여럿 있어도
  `DecisionOutcomes` 시트의 1행을 머리글로 읽는지(못 읽으면 모든 행이
  `DECISION_OUTCOME_UNAVAILABLE`).
- 결정 단위 D(2026-10-08 설계): DiscreteFir의 결정 이름이 Delay와 같은 `Enable`,
  `Reset`이고 DiscreteTransferFcn이 DiscreteFilter와 같은 `Reset`인지(실기 스크립트에
  넣지 않음), 결정 이름이 MATLAB 릴리스·언어 설정에 따라 바뀌지 않는지, 벡터 입력
  블록의 결정 이름이 원소마다 같은지(다르면 MISMATCH로 보인다). 벡터 입력이
  원소마다 결정 하나씩이면 MISMATCH지만, 결과가 셋 이상인 결정 하나로 나오면
  그 블록은 기록되지 않아 `DECISION_OUTCOME_UNAVAILABLE`로 보인다.

### 로그 체계 개편

바뀐 내용과 합치기 기록은 작업 기록의 2026-09-29, 2026-10-06 절에 있다.

- `sltest.harness.create`, `sldvrun`, `run(testCase)`, `run(testFile)`를 `evalc`
  안에서 불러도 동작과 속도가 같은지. 특히 GUI를 띄우는 경로를 본다.
- `evalc` 안의 Ctrl+C 중단이 `st_is_user_interrupt`로 알아볼 수 있는 예외로 다시
  올라오는지. `st_call_quiet`는 받은 예외를 그대로 다시 던진다.
- 번들 실행 중 번들 사본의 `st_log`가 번들 폴더의 session 로그로 가는지, 바깥 실행
  로그와 섞이지 않는지.
- 쓸 수 없는 경로에서 `diary()`가 그 자리에서 던지는지(늦게 실패하지 않는지).
  던지면 WARN `Console copy could not start`로 넘어간다.
- `dbstop if error`를 켜 둔 세션에서 `evalc` 안(`st_call_quiet`)에서 오류가 나면
  디버거에서 멈추고 그 프롬프트가 `evalc`에 잡혀 콘솔에 안 보일 수 있다. 그러면
  멈춘 것처럼 보인다. 재현되면 `dbclear if error` 뒤 다시 돌리라고 안내한다.
- 호출마다 `fopen`/`fclose`하는 비용이 작은지. 다음 실행에서 실행 로그의 전체 줄
  수와 명령 경과 시간을 적어 이전 실행과 비교한다.
- 실제 Ctrl+C 뒤 실행 로그와 콘솔의 끝 줄이 `<== <명령> INTERRUPTED`인지(guard의
  `onCleanup`이 Ctrl+C에서도 돈다는 가정).
- `evalc`로 받은 경고 원문에 verbose 안내 `(Type "warning off <id>" ...)`가 콘솔과
  같이 들어가는지. `st_collect_warning_ids`는 이 안내로 실행 로그의 `[SYS ...]`
  줄에서 식별자를 찾는다.
- Harness 생성의 `run_in_folder`(`cd`와 `onCleanup`)가 이제 `st_call_quiet`의
  `evalc` 안에서 돈다: `st_call_quiet(cfg, 'sltest.harness.create', @() run_in_folder(
  callerDirectory, @() sltest.harness.create(...)))`. 생성 뒤 현재 폴더가 짧은 빌드
  폴더로 돌아오는지, 입력 MAT이 호출 폴더에 남는지 본다.
- 대상 줄 끝의 `elapsed=... eta=...`(main `42544a5`의 값을 `st_log_progress`의
  `'Eta'`로 옮김)가 메시지가 60자에서 잘린 줄에도 붙어 읽히는지.

**다음 실행 뒤에 할 일.** `.console.log`와 `[SYS ...]` 줄을 보고 `st_call_quiet`를
어디에 남길지와 `cfg.SuppressedWarnings`에 무엇을 넣을지 정한다. 지금
`SuppressedWarnings`는 빈 목록이다.

**단위 테스트.** 2026-10-08 사용자 MATLAB에서 `tests/unit` 전체가 통과했다. 이로써
`evalc`가 `warning` 출력을 받는 것, `diary`가 콘솔 출력을 받고 `DiaryFile`을 되돌리는
것, 한국어 로캘의 `경고:` 줄을 경고로 세는 것은 확인됐다. 위 목록은 실제 모델로
돌려야 알 수 있는 것만 남긴 것이다.

## 활성 브랜치 지도

| 브랜치 | 위치 | 역할과 처리 방침 |
| --- | --- | --- |
| `main` | 원격 | 사용자의 MATLAB 클론이 받는 브랜치. 직접 커밋하지 않고 `develop`을 fast-forward로 받는다 |
| `develop` | 원격 | 모든 개발의 활성 브랜치 |
| `exp/per-cut-parallel` | 원격 | 접은 PER_CUT 병렬 실험의 진단 두 개(`3fb563f`). 참고용이며 합치지 않는다. 이유는 작업 기록의 2026-10-01 절 |
정리된 과거 브랜치 목록은 작업 기록에 있다. 그 브랜치를 다시 만들거나 과거 tip을
전체 병합하지 않는다.

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
    Relay/DiscreteIntegrator/ForIterator/WhileIterator/Signum/CombinatorialLogic/
    Delay/DiscreteFilter/DiscreteFir/DiscreteTransferFcn과 Resettable Subsystem
    CUT의 명세서를 export하고, 블록 이름 다음
    줄의 D번호·저장 파라미터 표현과 DecisionBlockDetails의
    (elseif가 있는 If는 조건 개수만큼 D를 차지하고 이름 줄은 한 번만 나오는지,
    else는 목록에 없는지, SwitchCase는 조건식 없이 유형만 찍히는지 포함)
    Outcome/Expression/ReadStatus가 실제 블록 설정과 일치하는지 확인한다. 메인 시트가
    전부 `[T/F]`이고 세부 시트 `Outcome`만 종류별로 갈리는지 확인한다. 각 암시적
    블록의 `BlockType` 문자열과 파라미터 이름이 실제 `get_param` 결과와 일치하는지,
    철자가 틀려 조용히 0건으로 나오지 않는지 확인한다. `LimitOutput=off;
    ExternalReset=none`인 DiscreteIntegrator가 목록에서 빠지고, 둘 중 하나가 켜진
    블록은 남는지 확인한다.
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

### 2026-09-16 변경분 1회 확인 (옛 runtime-verification.md에서 옮김)

이번 변경은 MATLAB이 없는 환경에서 만들었습니다. 아래는 **한 번 확인하면 끝나는**
항목이므로, 확인이 끝나면 이 절을 지웁니다.

- [ ] **옵션 자동완성 파일** — MATLAB 스키마 검사를 아직 돌려보지 않았습니다.

  ```matlab
  for folder = {'workflow','pipeline','verification','exporting','execution'}
      validateFunctionSignaturesJSON(fullfile(st_project_root(), ...
          'src', folder{1}, 'functionSignatures.json'));
  end
  ```

  이어서 명령창에 `st_run_standalone_coverage_pipeline('Action','` 까지 치고 Tab을
  눌러 값 목록이 뜨는지 봅니다.

- [ ] **제출물 이름 규칙** — 대상 폴더가 `{NUM}_UT_REQ_{TC}`인지, 각 폴더에
  `UT_REQ_{TC}.cvf`/`.cvt`/`.html`과 `{HarnessName}.slx`가 있는지, 생성된 HTML을
  열었을 때 표시되는 CVF 이름이 옆 파일명과 같은지.

- [ ] **해시 속도** — 직전 측정에서 체커가 226초였습니다. 얼마로 줄었는지 기록합니다.

  ```matlab
  slx = '여기에_standalone_slx_경로';
  tic; st_file_signature(slx); toc
  ```

- [ ] **경고 식별자 수집** — 무엇을 억제할지 정하려면 목록이 먼저 필요합니다.
  `lastwarn`은 마지막 하나만 주므로 아래를 씁니다.

  ```matlab
  ids = st_collect_warning_ids(@() st_export_test_bundle( ...
      'ExecutionModelMode','STANDALONE_HARNESS','AnalyzeProducts',false));
  ```

  파라미터화된 라이브러리 링크 경고처럼 의미 있는 것은 남겨 두는 편이 낫습니다.

- [ ] **(선택) toolbox 제품 분석 소요시간** — 배송 번들의 기본값을 끌지 판단할
  근거입니다. pipeline과 verification snapshot의 내부 번들은 이미 끕니다.

  ```matlab
  tic; dependencies.toolboxDependencyAnalysis({'여기에_standalone_slx_경로'}); toc
  ```

## 다른 Codex의 시작 절차

1. git fetch --prune origin을 실행한다.
2. 원격 develop의 최신 커밋을 확인한다. main은 develop을 ff 통합한 결과다.
3. 작업 트리가 깨끗할 때만 fast-forward한다.
4. 이 문서의 브랜치 지도와 변경 불가 핵심 결정을 읽는다.
5. st_setup 후 st_check_actual_system을 실행한다. E6이 주요 st 함수 중복을
   자동 확인하며 필요할 때만 which 함수명 -all로 상세 경로를 확인한다.
6. 작업 기록의 정리된 과거 브랜치를 다시 만들거나 과거 tip을 전체 병합하지 않는다.
7. R2025b 결과가 없으면 정적 검증과 런타임 검증을 명확히 분리한다.
8. 새 런타임 결과와 결정이 생기면 작업 기록 끝에 날짜 절을 붙이고, 이 문서의
   현재 기준과 실물 미검증 목록을 고친다.
