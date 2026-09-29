# 로그 체계 개편 설계

- 작성일: 2026-09-29
- 상태: 설계 합의, 구현 전
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
| `STEP` | 단계 시작·끝, 대상별 진행 한 줄 | 표시 | 기록 |
| `WARN` | 저하된 경로, 시스템 경고 요약 | 표시 | 기록 |
| `ERROR` | 실패 대상, 예외 | 표시 | 기록 |
| `INFO` | 기존 체크포인트 | 숨김 | 기록 |
| `DEBUG` | 기존 세부 정보, 시스템 출력 원문 | 숨김 | 기록 |
| `TRACE` | 기존 추적 | 숨김 | 기록 |

- 새 설정 `cfg.ConsoleLogLevel`: `'STEP'`(기본), `'INFO'`, `'DEBUG'`, `'TRACE'`.
  지정한 레벨과, 위 표에서 그보다 위에 있는 레벨이 콘솔에 찍힌다. 따라서 STEP·WARN·
  ERROR는 어느 값에서도 항상 찍힌다.
- `cfg.VerboseLogging`은 없앤다. 설정에 `true`가 남아 있으면 `'DEBUG'`로 취급하고,
  한 번만 WARN으로 `ConsoleLogLevel`로 바꾸라고 안내한다. `false`는 `'STEP'`로
  취급한다.
- 이 설정을 참조하는 곳은 함께 고친다.
  - `st_create_example.m:3`
  - `st_check_standalone_coverage.m:24`
  - 주석: `st_configure_harnesses.m`, `st_configure_signal_editors.m`
- 콘솔 줄 형식: `[HH:mm:ss] <메시지>`. STEP 줄에는 레벨 표시를 붙이지 않는다.
  WARN·ERROR 줄에는 `WARN `·`ERROR` 접두를 붙인다.
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
  - 시작 줄 `▶ <commandName>`을 STEP으로 찍는다.
- **안쪽 명령이 다시 들어갈 때(깊이 ≥ 1):** 새 파일을 만들지 않는다. 깊이만 올리고
  `commandName`은 파일에 INFO로 기록한다.
- **처음 들어간 범위가 끝날 때:**
  - `■ <commandName> | <경과 시간>`을 STEP으로 찍는다. 오류로 끝났으면
    `■ <commandName> | FAILED | <경과 시간>`을 ERROR로 찍는다.
  - 마지막 줄에 로그 파일 경로를 찍는다.
  - `onCleanup`만으로는 정상 종료와 예외를 구분할 수 없다. 그래서 명령 쪽에서
    `st_log_scope('fail', ME)`를 불러 실패를 표시한 뒤 rethrow한다.
- **범위 밖에서 `st_log`를 부를 때:** `result/logs/session_<yyyyMMdd>.log`에
  이어 쓴다.
- `result/logs/`는 `.gitignore`에 들어 있는 `result/` 아래이므로 따로 처리하지 않는다.

### 4.2 범위를 여는 명령

[team-commands.md](../../team-commands.md)에 나오는 공개 명령과, 단독으로도 불리는
단계 명령의 첫 줄에서 연다.

- `st_run_workflow`: `st_run_from_harness`, `st_run_after_harness`,
  `st_run_from_stage`가 이것을 거친다.
- `st_run_standalone_coverage_pipeline`, `st_check_standalone_coverage`
- `st_collect_per_cut_results`, `st_export_test_specification`,
  `st_export_final_document`
- `st_pre_validate_targets`, `st_select_target_model`
- 워크플로 단계 함수(`st_create_harnesses` 등): 단독 호출에 대비해 연다.
  워크플로 안에서 불리면 바깥 파일에 이어 쓴다.

### 4.3 파일 쓰기

- 호출할 때마다 `fopen(path, 'a', 'n', 'UTF-8')`로 열어 쓰고 닫는다. 오류나
  Ctrl+C로 끊겨도 핸들이 남지 않게 하려는 것이다. 호출 수가 실행당 수천 건
  수준이라 비용은 문제가 되지 않는다고 본다.
- 쓰기가 실패하면 처음 한 번만 콘솔에 WARN을 찍고, 그 범위 안에서는 더 시도하지
  않는다. 예외를 올리지 않는다.
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
- 받은 텍스트에 `Warning:`으로 시작하는 줄이 있으면 콘솔에 WARN 한 줄로 요약한다.
  형식은 `<label> 시스템 경고 N건(종류 K) — 로그 참조`이다. 경고 원문은 모두 DEBUG로
  파일에 있다.
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
st_log_stage(cfg, 'start', label, 'Index', k, 'Count', m, 'Targets', n)
st_log_stage(cfg, 'end',   label, 'Result', T, 'Elapsed', sec)
st_log_stage(cfg, 'fail',  label, 'Exception', ME, 'Elapsed', sec)
```

- 콘솔 예:
  - `▶ 2/5 Create Test Harnesses | 대상 26`
  - `■ 2/5 Create Test Harnesses | OK=24 SKIP=1 FAIL=1 | 12m38s`
- `Result` 표에 `Status` 열이 있으면 상태별 개수를 붙인다. FAIL·EXCEPT 대상마다
  `No | CUT | Harness | Message`를 ERROR로 한 줄씩 남긴다.
  `st_log_stage_result`의 집계 코드를 옮겨 온다.
- `st_log_stage_result`와 `st_run_workflow`의 `execute_timed_step` 배너는 이것으로
  바꾼다.

### 6.2 `st_log_progress`

```matlab
st_log_progress(cfg, i, n, status, label, 'Elapsed', sec, 'Message', msg, 'Detail', detail)
```

- 콘솔 예: `  [ 3/26] FAIL  OBC_DIAG_..._Harness     30.9s  Port mismatch ...`
- `status`가 FAIL·EXCEPT이면 ERROR, WARN이면 WARN, 그 밖에는 STEP으로 찍는다.
- 콘솔에서는 `label`을 40자, `Message`를 60자로 자르고 줄바꿈을 없앤다. 파일에는
  `Detail`(CUT 경로 등)과 전체 메시지를 그대로 남긴다.

## 7. 기존 출력 정리 규칙

- 대상마다 찍는 `fprintf` 블록(`START`, `Time`, `CUT`, `-> OK` 등)은 없애고
  `st_log_progress` 한 줄로 바꾼다. 그 안의 세부 정보는 DEBUG로 옮긴다.
- 명령 시작 배너(`====`, `Model`, `Count`, `Start`)는 `st_log_stage` 시작 줄과,
  파일에 남는 INFO 한 줄로 바꾼다.
- 사용자가 결과로 읽는 출력은 콘솔에 남긴다. 예: `st_pre_validate_targets` 결과 표,
  `st_check_standalone_coverage` 코드와 요약, `disp`로 돌려주는 반환값.
  그대로 `fprintf`/`disp`로 두어도 `diary`에 담긴다.
- 사용자 중단 배너(`terminated by user`)는 `st_log_stage(..., 'fail', ...)`로 바꾼다.

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

[commit-convention.md](../../commit-convention.md)에 따라 목적 하나당 커밋 하나로
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
