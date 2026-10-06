# 로그 체계 개편 설계

- 작성일: 2026-09-29
- 상태: 구현 중
- 대상 브랜치: develop

## 1. 배경

긴 명령(`st_run_from_harness`, `st_run_standalone_coverage_pipeline`)을 돌리면
콘솔만 보고서는 지금 어느 단계, 몇 번째 대상인지 알기 어렵다. 원인은 세 가지다.

1. `cfg.VerboseLogging`의 기본값이 `true`라서, 74개 파일에 있는 DEBUG 227개,
   INFO 173개, TRACE 32개 호출이 모두 콘솔에 찍힌다.
2. `st_log`와 별개로 `fprintf` 배너와 대상별 블록이 섞여 있다. 대상 하나에
   8줄 안팎이 찍히며, `st_export_test_bundle` 한 파일에만 `fprintf`가 60개 있다.
3. MATLAB·Simulink가 직접 내는 출력은 `st_log`를 거치지 않는다. 경고, SLDV 진행
   표시, `### Building ...`, Harness 생성, Test Manager 실행, `cvhtml` 출력이
   여기에 해당한다. 그래서 끌 수도, 파일에 남길 수도 없다.

## 2. 목표

- **콘솔:** 단계 시작·끝, 대상별 한 줄, WARN·ERROR만 보인다. 콘솔만 보고
  "몇 단계, 몇 번째 대상, 실패가 있는가"를 알 수 있다.
- **파일:** 실행 한 번마다 모든 레벨의 로그와 콘솔 원본이 남는다. 원인을
  추적하는 데 필요한 내용이 빠지지 않는다.
- **호환:** 기존 `st_log(cfg, level, format, ...)` 호출 형식은 그대로 둔다.
- **안전:** 로그를 기록하다 실패해도 실행은 멈추지 않는다.

### 범위 밖

- 번들 실행 로그 `execution.log`와 그 형식. 파이프라인이 이 파일을 증거로 복사하고
  checker가 참조한다. 번들 실행기가 찍는 콘솔 출력은 아래 5.1의 `diary`에 담긴다.
- 번들 안에 복사된 툴킷 사본의 로그 동작. 번들 폴더가 path 앞에 오므로 그 안에서는
  번들의 `st_log`가 호출된다. 이번 변경은 다음 번들 export부터 사본에도 들어가지만,
  바깥 실행의 로그 파일에 합쳐지지는 않는다.
- Simulink Diagnostic Viewer 창에만 뜨는 메시지.

## 3. 레벨과 콘솔

| 레벨 | 용도 | 콘솔 기본 | 파일 |
| --- | --- | --- | --- |
| `STEP` | 명령·단계 시작·끝, 대상별 진행 한 줄 | 표시 | 기록 |
| `WARN` | 저하된 경로, 시스템 경고 요약 | 표시 | 기록 |
| `ERROR` | 실패 대상, 예외 | 표시 | 기록 |
| `INFO` | 기존 체크포인트 | 숨김 | 기록 |
| `DEBUG` | 기존 세부 정보, 시스템 출력 원문 | 숨김 | 기록 |
| `TRACE` | 기존 추적 | 숨김 | 기록 |

- 새 설정 `cfg.ConsoleLogLevel`: `'STEP'`(기본), `'INFO'`, `'DEBUG'`, `'TRACE'`.
  지정한 레벨과, 위 표에서 그보다 위에 있는 레벨이 콘솔에 찍힌다. 따라서 STEP·WARN·
  ERROR는 어느 값에서도 항상 찍힌다. 네 값 밖의 값은 `'STEP'`으로 취급한다.
- `cfg.VerboseLogging`은 없앤다. `st_config.m`에서 이 필드를 지우므로 사용자 설정에
  남을 수가 없어서, 바꾸라고 알리는 WARN은 넣지 않는다. `ConsoleLogLevel`이 없는
  struct cfg(테스트나 예제)에서만 `true`는 `'DEBUG'`로, `false`는 `'STEP'`로
  취급한다.
- 이 설정을 참조하는 곳은 함께 고친다.
  - `st_create_example.m:3`
  - `st_check_standalone_coverage.m:24`
  - 주석: `st_configure_harnesses.m`, `st_configure_signal_editors.m`
- 콘솔 줄 형식: `[HH:mm:ss] <메시지>`. STEP 줄에는 레벨 표시를 붙이지 않는다.
  WARN·ERROR 줄에는 `WARN `·`ERROR` 접두를 붙인다.
- 콘솔 표시 기호와 문구는 ASCII 영어로 쓴다. 기존 로그 문구가 모두 영어이고, `.m`
  파일 인코딩 문제를 피하려는 것이다. 한글이 필요한 곳(경고 접두 `경고`)은
  `char([0xACBD 0xACE0])`처럼 코드값으로 만든다.
- 파일 줄 형식: `[yyyy-MM-dd HH:mm:ss.SSS][LEVEL] <메시지>`.

## 4. 로그 파일과 실행 범위

### 4.1 `st_log_scope`

```matlab
guard = st_log_scope('enter', commandName)   % 최상위 명령 첫 줄에서
info  = st_log_scope('current')              % st_log가 조회
```

- 방식은 `st_config_scope`와 같다. persistent 상태를 두고, 반환된 `onCleanup`
  guard가 사라질 때 이전 상태로 되돌린다.
- **처음 들어갈 때(깊이 0 → 1):**
  - `result/logs/<yyyyMMdd_HHmmss>_<commandName>.log`를 정한다.
  - 같은 이름의 파일이 이미 있으면 `_2`, `_3`을 붙인다.
  - 시작 줄 `==> <commandName> start`를 STEP으로 찍고, 이어서 로그 파일 경로
    `    log: <경로>`를 찍는다.
- **안쪽 명령이 다시 들어갈 때(깊이 ≥ 1):** 새 파일을 만들지 않는다. 깊이만 올리고
  `commandName`은 파일에 INFO로 기록한다.
- **처음 들어간 범위가 끝날 때:**
  - `<== <commandName> done | <경과 시간>`을 STEP으로 찍는다. 오류로 끝났으면
    `<== <commandName> FAILED | <경과 시간> | <오류 식별자>: <메시지>`를 ERROR로
    찍는다.
  - 마지막 줄에 로그 파일 경로 `    log: <경로>`를 한 번 더 찍는다.
  - `onCleanup`만으로는 정상 종료와 예외를 구분할 수 없다. 그래서 명령 쪽에서
    `st_log_scope('fail', ME)`를 불러 실패를 표시한 뒤 rethrow한다.
  - 정상 종료도 명령 쪽에서 `st_log_scope('complete')`로 표시한다(깊이 1일 때만
    유효). Ctrl+C는 catch를 건너뛰고 `onCleanup`만 돌리므로, 둘 다 표시되지 않은 채
    닫히면 `<== <commandName> INTERRUPTED | <경과 시간>`을 ERROR로 찍는다. 닫는 줄을
    찍다가 오류가 나도 범위 상태는 반드시 초기화한다.
- **명령 본문 헬퍼 `st_log_run`:** 위 순서를 명령마다 되풀이하지 않도록 범위를 열고,
  명령 본문을 실행하고, 실패하면 `fail`을 표시한 뒤 rethrow하고, 정상으로 돌아오면
  `complete`를 표시하는 헬퍼를 둔다.

  ```matlab
  [varargout{1:nargout}] = st_log_run(mfilename, @() body(varargin{:}))
  ```
- **범위 밖에서 `st_log`를 부를 때:** `result/logs/session_<yyyyMMdd>.log`에
  이어 쓴다.
- `result/logs/`는 `.gitignore`에 들어 있는 `result/` 아래이므로 따로 처리하지 않는다.

### 4.2 범위를 여는 명령

[user-manual.md](../../user-manual.md)에 나오는 명령 가운데 사용자가 직접
부르는 것의 첫 줄에서 `st_log_run`(또는 `st_log_scope('enter', ...)`)으로 연다. 다음
12개다.

- `st_run_from_harness`, `st_run_after_harness`, `st_run_from_stage`: 각자 연다.
  이 명령들이 거치는 `st_run_workflow`는 따로 열지 않는다.
- `st_run_standalone_coverage_pipeline`, `st_check_standalone_coverage`,
  `st_open_standalone_test_manager`
- `st_collect_per_cut_results`, `st_generate_test_report`,
  `st_export_test_specification`, `st_export_final_document`
- `st_pre_validate_targets`, `st_select_target_model`
- 워크플로 단계 함수(`st_create_harnesses` 등)는 범위를 따로 열지 않는다. 워크플로
  안에서 불리면 바깥 명령의 파일에 이어 쓰고, 단독으로 부르면
  `session_<yyyyMMdd>.log`로 간다.
- 다른 명령 안에서 불린 명령은 안쪽 명령이므로 새 파일을 만들지 않는다. 예: 워크플로가
  부르는 `st_pre_validate_targets`, `st_collect_per_cut_results`,
  `st_generate_test_report`.

### 4.3 파일 쓰기

- 호출할 때마다 `fopen(path, 'a', 'n', 'UTF-8')`로 열어 쓰고 닫는다. 오류나
  Ctrl+C로 끊겨도 핸들이 남지 않게 하려는 것이다. 호출 수가 실행당 수천 건
  수준이라 비용은 문제가 되지 않는다고 본다.
- 쓰기가 실패하면 처음 한 번만 콘솔에 WARN을 찍고, 그 범위 안에서는 더 시도하지
  않는다. 예외를 올리지 않는다. 최상위 명령이 새로 시작하면 실패 기록을 비워, 한 번의
  일시적 실패가 MATLAB 세션 내내 그 경로를 조용하게 만들지 않게 한다.
- `st_config`를 읽지 못해 로그 폴더를 정할 수 없으면, 범위에 들어갈 때 콘솔에
  `st_config failed; this run has no log file` WARN을 한 번 찍는다.
- `st_log_stage_result`가 쓰던 `result/reports/WorkflowStageLog.log`는 이 파일로
  흡수하고 없앤다.

## 5. 시스템 출력

### 5.1 콘솔 원본: `diary`

- `st_log_scope`가 처음 들어갈 때 `diary`를 켜서
  `result/logs/<같은 이름>.console.log`에 콘솔 출력을 그대로 받는다. 나갈 때 끈다.
- 사용자가 이미 `diary`를 켜 두었으면(`get(0, 'Diary')`가 `'on'`) 건드리지 않고
  WARN 한 줄만 남긴다.
- `diary`는 전역 상태이므로 켜고 끄는 일은 깊이 0 → 1, 1 → 0일 때만 한다.
- `evalc`로 받은 출력은 콘솔에 나오지 않으므로 `diary`에도 담기지 않는다. 그런
  출력은 `.log`에 DEBUG로 남긴다(5.2).

### 5.2 출력이 많은 API: `st_call_quiet`

```matlab
varargout = st_call_quiet(cfg, label, fn)
```

- `fn`을 `evalc`로 실행한다. 받은 텍스트는 줄마다 `[SYS <label>] ...` 형태로
  DEBUG로 남긴다.
- 예외가 나기 직전까지의 출력도 잃지 않도록, `evalc` **안에서** try/catch로 예외를
  받는다. 먼저 텍스트를 기록하고, 그다음 원래 예외를 그대로 rethrow한다.
  `st_is_user_interrupt`에 해당하는 사용자 중단도 같은 방식으로 기록한 뒤 올린다.
  이때 DEBUG 끝 줄 `[SYS <label>] end | lines=N | <경과 시간>`에
  `| FAILED <오류 식별자>`를 붙여, 끝 줄만 보고도 실패한 호출을 알 수 있게 한다.
- 받은 텍스트에 `Warning:`(한국어 MATLAB은 `경고:`)으로 시작하는 줄이 있으면 콘솔에
  WARN 한 줄로 요약한다. 형식은 `<label> system warnings: N (K distinct) - see log`
  이다(표시 문구는 ASCII 영어). 경고 원문은 모두 DEBUG로 파일에 있다.
- 감싼 API는 끝날 때까지 콘솔에 아무것도 찍지 않는다. 앞뒤에 STEP 줄이 있으므로
  무엇을 기다리는지는 보인다.
- 적용 위치: 시끄러운 곳을 아직 모르므로, 다음 14곳을 모두 감싼다. 다음 실행에서
  `console.log`와 `.log`를 보고 조정한다.

| 파일 | 줄 | 호출 |
| --- | --- | --- |
| `src/harness/st_create_harnesses.m` | 170 | `sltest.harness.create` |
| `src/sldv/st_prepare_sldv_targets.m` | 779 | `sldvrun` |
| `src/execution/st_run_generated_tests.m` | 145, 262 | `run(tf)` |
| `src/execution/st_run_tests_per_cut.m` | 266, 342 | `run(tc)` |
| `src/execution/st_run_tests_per_cut.m` | 1001, 1028 | `cvsave`, `cvhtml` |
| `src/reporting/st_generate_test_report.m` | 229, 263 | `sltest.testmanager.report`, `cvhtml` |
| `src/reporting/st_export_result_set_report.m` | 120, 266, 378 | report, `cvsave`, `cvhtml` |
| `src/exporting/st_export_standalone_harnesses.m` | 148 | `sltest.harness.export` |

  이미 `evalc`를 쓰는 `st_validate_sldv_target.m`의 사전검사 3곳은 받은 텍스트를
  `check.Details`로 쓰고 있으므로 그대로 둔다.

### 5.3 반복 경고

- 지금은 standalone export 한 곳에서만 쓰는 `st_suppress_warnings`를 워크플로 각
  단계와 파이프라인 전체 범위로 넓힌다.
- `cfg.SuppressedWarnings`의 기본값은 빈 목록 그대로 둔다. 무엇을 끌지는 다음
  실행의 경고 요약을 보고 정한다.
- 끈 ID 목록은 단계 시작 때 INFO로 남긴다. 기존 동작과 같다.

## 6. 진행 표시

### 6.1 `st_log_stage`

```matlab
st_log_stage(cfg, 'start', label)
st_log_stage(cfg, 'end',   label, 'Result', T, 'Elapsed', sec)
st_log_stage(cfg, 'fail',  label, 'Exception', ME, 'Elapsed', sec)
```

- 콘솔 예:
  - `--> [2] Create Harnesses`
  - `<-- [2] Create Harnesses | OK=24, SKIP=1, FAIL=1 | 12m38s`
  - 단계가 예외로 멈추면 `<-- [2] Create Harnesses | FAILED | 12m38s | <오류 식별자>: <메시지>`를
    ERROR로 찍는다.
- 단계 번호 `[k]`는 그 명령의 범위 안에서 몇 번째로 시작한 단계인지이다. 재시작이나
  plan에 따라 실행할 단계 수가 달라지므로 전체 개수(`2/5`)는 붙이지 않는다. 시작 줄에
  대상 수도 붙이지 않는다. 대상 수는 진행 줄의 `[i/n]`으로 보인다.
- `Result` 표에 `Status` 열이 있으면 상태별 개수를 처음 나온 순서대로 붙인다.
  FAIL·EXCEPT가 있으면 끝 줄을 WARN으로 찍고, 그 대상마다
  `No=.. | CUTName=.. | HarnessName=.. | TestCaseName=.. | <Message>`를 ERROR로 한
  줄씩 남긴다. `st_log_stage_result`의 집계 코드를 옮겨 온다.
- `st_log_stage_result`와 `st_run_workflow`의 `execute_timed_step` 배너는 이것으로
  바꾼다.

### 6.2 `st_log_progress`

```matlab
st_log_progress(cfg, i, n, status, label, 'Elapsed', sec, 'Message', msg, 'Detail', detail, ...
    'Eta', st_progress_eta(toc(loopTimer), i, n))
```

- 콘솔 예: `    [ 3/26] FAIL   OBC_DIAG_..._Harness     30.9s  Port mismatch ...  elapsed=1m33s eta=11m53s`
- 대상 하나가 오래 걸리는 곳에는 시작 줄 `    [ 3/26] START  <label>`을 먼저 찍는다.
  Harness 생성, SLDV, PER_CUT 실행, PER_CUT 결과 정리가 해당하며, 그곳에서는 대상
  하나에 콘솔 줄이 최대 두 줄이 된다.
- `Eta`(문자열, 기본 `''`)는 main `42544a5`의 경과·남은 시간이다. 콘솔 줄 맨 끝, 잘린
  메시지 뒤에 공백 두 칸을 두고 자르지 않고 붙이며, DEBUG detail 줄에도 붙인다. main이
  손댄 긴 대상 반복(Harness 생성, SLDV 준비, Harness 설정, Signal Editor, Assessment,
  Test Manager, PER_CUT 실행·결과 정리, standalone Harness export, PACKAGE)이
  `loopTimer = tic`(Test Manager와 PER_CUT 결과 정리는 반복 직전의 `totalTimer`)으로
  START 줄에는 `st_progress_eta(toc(loopTimer), i - 1, n)`, 결과 줄에는
  `st_progress_eta(toc(loopTimer), i, n)`을 넘긴다. START 줄이 없는 반복은 결과 줄에만
  붙는다.
- `status`가 FAIL·EXCEPT이면 ERROR, WARN·PARTIAL이면 WARN, 그 밖에는 STEP으로 찍는다.
- 콘솔에서는 `label`을 40자, `Message`를 60자로 자르고 줄바꿈을 없앤다. 파일에는
  `Detail`(CUT 경로 등)과 전체 메시지를 그대로 남긴다.
- `cfg`를 받지 않던 `st_collect_output_specs`는 선택 세 번째 인자 `cfg`(기본 `[]`)를
  받아 이 진행 줄을 찍는다.

## 7. 기존 출력 정리 규칙

- 대상마다 찍는 `fprintf` 블록(`START`, `Time`, `CUT`, `-> OK` 등)은 없애고
  `st_log_progress` 한 줄로 바꾼다. 그 안의 세부 정보는 DEBUG로 옮긴다.
- 명령 시작 배너(`====`, `Model`, `Count`, `Start`)는 `st_log_stage` 시작 줄과,
  파일에 남는 INFO 한 줄로 바꾼다.
- 사용자가 결과로 읽는 출력은 콘솔에 남긴다. 예: `st_pre_validate_targets` 결과 표,
  `st_check_standalone_coverage` 코드와 요약, `disp`로 돌려주는 반환값.
  그대로 `fprintf`/`disp`로 두어도 `diary`에 담긴다.
- 사용자 중단 배너(`terminated by user`)는 `st_log_stage(..., 'fail', ...)`로 바꾼다.
- `st_check_standalone_coverage`의 한 화면 계약은 자기 블록 20줄 이내에, 직접 부를 때의
  실행 로그 틀 4줄(`==>`, `<==`, `log:` 두 줄)을 더한 24줄 이내다. 다른 명령 안에서
  부르면 틀이 없다.
- 테스트 실행 중에 불리는 도우미 `st_apply_run_test_case_scope`,
  `st_get_run_test_cases`도 같은 규칙을 따른다. 인자 없이 부른 `st_get_run_test_cases`가
  찍던 대상 목록은 DEBUG로 옮기고, 목록은 두 번째 출력 `R`로 본다.
- 번들 export의 오래 걸리는 작업(toolbox 분석, 번들 SHA-256, 원본 불변 검사, ZIP)은
  시작·끝 줄을 STEP으로 콘솔에 남기고, `Bundle usage | Run=run_exported_tests` 안내도
  STEP으로 찍는다. 콘솔이 길게 조용하면 멈춘 것으로 보이기 때문이다.

## 8. 테스트

MATLAB이 없는 편집 클론이므로 정적 계약 테스트와 순수 함수 단위 테스트를 둔다.
실행은 사용자 PC에서만 된다.

- `tests/unit/test_log_scope.m`
  - 중첩 범위에서 파일이 하나인지, 깊이가 복원되는지
  - 범위 밖이면 session 파일로 가는지
  - 쓰기 실패 시 WARN이 한 번만 나고 예외가 없는지
- `tests/unit/test_log_levels.m`
  - `ConsoleLogLevel`별로 콘솔 출력이 걸러지는지(`evalc`로 확인)
  - `VerboseLogging` 호환 변환
- `tests/unit/test_call_quiet.m`
  - 출력이 파일에만 가는지, 경고 요약 개수가 맞는지
  - 예외가 나도 출력이 기록되고 원래 예외가 올라오는지
- 기존 `test_stage_result_log.m`은 `st_log_stage`에 맞게 옮긴다.
- 5.2의 14곳과 4.2의 범위 진입점은 소스 문자열 계약으로 확인한다.

## 9. 커밋 순서

[commit-convention.md](../../ai/commit-convention.md)에 따라 목적 하나당 커밋 하나로
나눈다.

1. `feat(log)`: `st_log` 파일 기록, `st_log_scope`, `ConsoleLogLevel`,
   `VerboseLogging` 호환
2. `feat(log)`: `diary` 콘솔 원본, `st_call_quiet`
3. `feat(log)`: `st_log_stage`, `st_log_progress`, 워크플로 적용,
   `WorkflowStageLog.log` 제거
4. `refactor(harness,sldv,test_manager)`: 단계별 `fprintf` 정리, 시스템 호출 감싸기
5. `refactor(execution,reporting)`: 실행·결과 정리 단계 정리, 시스템 호출 감싸기
6. `refactor(pipeline,exporting)`: 파이프라인·export 정리, 범위 진입점
7. `docs`: config-reference, troubleshooting, team-commands, team-workflow,
   codex-handoff의 미검증 항목

## 10. 확인하지 못한 가정

다음 실행에서 확인해야 한다. 확인할 때까지 codex-handoff에 미검증으로 적어 둔다.

- `evalc`가 R2025b에서 `warning` 출력까지 받는지. 받지 못하면 경고가 콘솔로 새고
  요약 개수는 0이 된다. 그래도 콘솔 원본은 `diary`에 남는다.
- `sltest.harness.create`, `sldvrun`, `run(tc)`를 `evalc` 안에서 불러도 동작과 속도가
  같은지. 특히 GUI를 띄우는 경로에서 확인해야 한다.
- `evalc` 안의 try/catch가 Ctrl+C 중단을 `st_is_user_interrupt`로 알아볼 수 있는
  예외로 받는지.
- 번들 실행기가 `addpath(bundleDirectory, '-begin')`한 동안, 바깥의
  `st_log_scope` 상태를 번들 사본의 `st_log`가 보지 못하는 영향. 번들 쪽 structured
  log는 번들의 session 파일로 간다.
