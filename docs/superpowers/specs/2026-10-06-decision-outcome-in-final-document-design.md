# 최종 문서의 분기 결과 표기 설계

- 작성일: 2026-10-06
- 상태: 설계 검토 중
- 대상 브랜치: develop

## 1. 배경

최종 문서(`st_export_final_document`)의 Description 셀은 분기마다
`D1 [T/F]Switch (u2 >= 5)` 같은 줄을 적는다. 여기서 `[T/F]`는 "이 블록에 분기가
있다"는 정적 표기일 뿐이고, 그 행의 테스트가 실제로 어느 쪽을 탔는지는 알려 주지
않는다. 그래서 고객 문서를 보는 사람이 분기 결과를 확인하려면 Coverage 리포트를
따로 열어 대조해야 한다.

Simulink Coverage는 결정마다 결과별 실행 횟수를 이미 갖고 있다. For Iterator의
리포트를 예로 들면 `loop condition`의 `false 3/33`, `true 30/33`이 그 값이다.
툴킷은 리포트를 만들 때 `decisioninfo`로 블록별 objective 개수만 읽고
(`st_collect_decision_points`), 결과별 실행 횟수는 어디서도 읽지 않는다.

## 2. 목표

- 최종 문서의 각 행(Test Case × iteration)에서, 결과가 true/false 둘뿐인 분기의
  `[T/F]`를 **그 행의 테스트가 실제로 탄 결과**로 바꾼다.

  | 표기 | 뜻 |
  | --- | --- |
  | `[T]` | true만 탔다 |
  | `[F]` | false만 탔다 |
  | `[T/F]` | 둘 다 탔다 |
  | `[-]` | 둘 다 타지 않았다 (블록이 그 행에서 한 번도 평가되지 않음) |

- 결과를 구할 수 없으면 지금처럼 `[T/F]`로 두고, 그 사실을 행의 `확인 사유`에
  남긴다. 결과를 모르는 상태를 "둘 다 탔다"로 착각하지 않도록 사유 코드로
  구분한다.

### 범위 밖

- **명세서 export**(`st_export_test_specification`): 테스트 실행 전의 정적 문서이므로
  그대로 둔다.
- **T/F가 아닌 분기**: 결정이 둘인 블록(Saturate의 상한·하한, Discrete-Time
  Integrator의 reset과 한계)과 결과가 셋 이상인 블록(MinMax, MultiPortSwitch,
  SwitchCase, Sign, Combinatorial Logic)은 `[T/F]` 그대로 둔다. 사용자가 이 범위를
  골랐다.
- D번호 체계: 지금처럼 정적 scan이 정한 블록·조건 단위를 유지한다.
- Condition/MCDC 결과.

## 3. 접근

리포트를 만드는 동안에는 iteration 결과 객체와 로드된 모델이 모두 있다. 이때
iteration마다 cvdata를 얻어 분기 결과를 읽고, 결과 workbook에 새 시트
`DecisionOutcomes`로 남긴다. 최종 문서는 지금 `DecisionPoints` 시트를 읽는 것과 같은
방식으로 이 시트를 읽는다.

검토했지만 고르지 않은 방법은 다음과 같다.

- **iteration별 cvdata를 파일로 저장하고 최종 문서에서 계산**: 최종 문서 export에도
  모델 로드와 Coverage 라이선스가 필요해진다. 지금 최종 문서는 결과 파일만 읽는다.
- **기존 Coverage 시트의 `ITERATION` 행 사용**: covered/total 합계뿐이라 어느 결과를
  탔는지 알 수 없다.

## 4. 수집: `st_collect_decision_outcomes`

`src/reporting/st_collect_decision_outcomes.m` (새 함수)

```matlab
rows = st_collect_decision_outcomes(resultObj, cutName, root, cfg)
```

- **단위.** `st_collect_test_case_results(resultObj)`로 Test Case 결과를 얻고, 각
  결과의 `getIterationResults`를 돈다. iteration이 없으면 Test Case 결과 자체를 한
  단위로 본다. 각 단위의 cvdata는 `getCoverageResults`로 얻는다
  (`st_collect_coverage_summary.m`이 `ITERATION` 행을 만들 때 쓰는 방식과 같다).
- **iteration 이름.** 판정 시트와 키가 맞아야 하므로
  `st_collect_test_result_summary.m`의 `iteration_name`(Name → TestSequenceScenario →
  `Iteration N`)을 공용 함수 `st_result_iteration_name`으로 꺼내 둘이 같이 쓴다.
  iteration이 없는 단위의 IterationName은 판정 쪽과 같은 빈 값으로 둔다.
- **블록.** `st_collect_decision_points`와 같은 규칙을 쓴다. CUT의 직계 자식만 보고,
  CUT이 Enabled/Triggered/Resettable Subsystem이면 port 블록에 묻고, 비면
  subsystem 자신에게 descendants 없이 묻는다. 이 분류 함수(`classify_block`,
  `conditional_port`)를 공용 함수 `st_decision_object_path`로 꺼내 두 수집기가 같이
  쓴다.
- **결정.** `[~, description] = decisioninfo(cvd, objectPath)`의
  `description.decision(k)`마다 결과가 정확히 둘이고 그 텍스트가 `true`와 `false`
  (대소문자 무시)이면 한 행을 남긴다. 그 밖의 결정은 남기지 않는다. 블록의 결정 중
  하나라도 이 조건에 맞지 않으면 그 블록의 행을 하나도 남기지 않는다. 일부만 남기면
  최종 문서가 결정 순서를 잘못 맞출 수 있기 때문이다.
- **행 형식.**

  | 열 | 내용 |
  | --- | --- |
  | `Run` | `INITIAL` 또는 `FINAL` (호출자가 넘긴다) |
  | `CUTName`, `CUTPath` | 대상 |
  | `TestCaseName`, `IterationName` | 판정 시트와 같은 키 |
  | `BlockPath` | 블록 전체 경로. 최종 문서가 CUT 기준 상대 경로로 바꾼다 |
  | `DecisionIndex` | 블록 안 결정 순서 (1부터) |
  | `DecisionText` | `description.decision(k).text`. 사람이 대조할 때 쓴다 |
  | `TrueCount`, `FalseCount` | 결과별 `executionCount` |

- **로그.** 시작과 끝에 `st_log` INFO
  (`Decision outcome scan start/end | CUT=... | Units=... | Rows=... | elapsed=...`).
  cvdata가 없는 단위와 `decisioninfo` 실패는 WARN에 단위 이름과 블록 경로를 붙인다.
  T/F가 아니라서 건너뛴 블록은 DEBUG로 남긴다.
- **실패.** 이 수집이 실패해도 리포트 생성은 계속한다. 시트는 빈 표로 쓴다.

## 5. 기록 위치

| 실행 방식 | 쓰는 곳 | 비고 |
| --- | --- | --- |
| PER_CUT | `st_export_result_set_report`가 `DecisionPoints` 옆에 `DecisionOutcomes` 시트를 쓴다 | 대상 하나, run 하나의 workbook |
| BATCH | `st_generate_test_report`가 `TestSummary.xlsx`에 `DecisionOutcomes` 시트를 쓴다 | INITIAL과 FINAL 행이 한 workbook에 함께 들어간다 |

- coverage를 수집하지 않는 `Scope='VERDICT'`(LEAN)에서는 수집하지 않고 시트도 쓰지
  않는다.
- BATCH에는 지금 `DecisionPoints` 시트가 없다. 이번 범위는 `DecisionOutcomes`만
  더한다. 블록 목록은 지금처럼 정적 scan이 정한다.
- BATCH에서 Test Case별 CUT 경로는 `st_generate_test_report`가 이미 갖고 있는 대상
  정보(관리 Excel)에서 Test Case 이름으로 찾는다. 찾지 못한 Test Case는 WARN을 남기고
  건너뛴다.

## 6. 읽기: `st_final_document_decision_outcomes`

`src/exporting/st_final_document_decision_outcomes.m` (새 함수)

- 입력은 `st_final_document_run_source`가 고른 `source.Workbooks`다. 판정을 읽는 것과
  같은 파일이라 run(BATCH/PER_CUT, INITIAL/FINAL)이 자동으로 맞는다.
- BATCH workbook에 INITIAL과 FINAL이 함께 있으면, 판정 reader와 같은 규칙으로
  FINAL을 우선한다.
- 결과는 `(CUTName, TestCaseName, IterationName, RelativePath)`로 찾는
  `containers.Map`이다. 값은 `DecisionIndex` 순서의 `[TrueCount FalseCount]` 행렬이다.
- 행의 `Iteration명`이 실제 iteration이 아니면(빈 값, `<기본 설정>`, `(단일 실행)`,
  `연결 없음`) IterationName이 빈 Test Case 단위 결과로 찾는다. 판정 lookup
  (`st_final_document_table.m`의 `lookup_verdict`)과 같은 규칙이며, 같은 판별
  함수를 쓴다.
- 시트가 없는 workbook(이 기능 이전 결과)은 빈 결과로 본다. 오류가 아니다.
- 같은 키가 서로 다른 값으로 두 번 나오면 그 키를 버리고 Notes에
  `DECISION_OUTCOME_AMBIGUOUS`를 남긴다.

## 7. 표시

`st_format_specification_decision_blocks`가 행마다 D 줄을 만들 때 결과를 받는다.

- 새 선택 인자 `outcomeLookup`. 행의 `(CUTName, 테스트 케이스명, Iteration명)`과 블록
  경로를 주면 결과 행렬을 돌려주는 함수 핸들이다. 명세서 export는 이 인자를 넘기지
  않으므로 출력이 바뀌지 않는다.
- 블록의 D 줄 수와 결과 행렬의 행 수가 같을 때만 k번째 D에 k번째 결정을 대응시킨다.
  If 블록의 if/elseif가 여기에 해당한다. 다르면 그 블록의 D는 모두 `[T/F]`로 둔다.
- 표기 규칙: `TrueCount > 0`이면 T, `FalseCount > 0`이면 F. 둘 다면 `T/F`, 둘 다
  0이면 `-`.
- 결과를 붙이지 못한 경우는 행의 `확인 사유`에 아래 코드를 남긴다. `확인 필요`
  판정은 바꾸지 않는다. 결과 표기는 참고 정보이지 판정 기준이 아니기 때문이다.

  | 코드 | 언제 |
  | --- | --- |
  | `DECISION_OUTCOME_UNAVAILABLE` | 그 행의 run workbook에 `DecisionOutcomes` 시트가 없거나 그 행의 결과가 없다 |
  | `DECISION_OUTCOME_MISMATCH` | 블록의 D 줄 수와 기록된 결정 수가 다르다 |

  T/F가 아니라서 기록이 없는 블록(Saturate 등)은 사유를 남기지 않는다. 처음부터
  범위 밖이기 때문이다.

- Metadata 시트에 `DecisionOutcomeRows`(결과를 하나라도 붙인 행 수)와
  `DecisionOutcomeUnavailableRows`를 더한다.
- 시작과 끝에 `st_log` INFO, 키를 못 찾은 행은 DEBUG, 불일치는 WARN.

## 8. 테스트

MATLAB 없이 이 환경에서 돌릴 수는 없지만, 아래는 모델 없이 도는 단위 테스트로 쓴다.

- 집계 규칙: 가짜 `description`으로 T만, F만, 둘 다, 둘 다 0, 결과 셋, 텍스트가
  true/false가 아닌 경우, 결정 일부만 T/F인 블록.
- iteration 이름 공용 함수: 판정 쪽과 같은 이름을 돌려주는지.
- 읽기: 시트 없음, FINAL 우선, 중복 키.
- 표시: `[T]`/`[F]`/`[T/F]`/`[-]` 치환, If의 다중 D 대응, 개수 불일치 시 `[T/F]`
  유지와 사유 코드, `outcomeLookup`이 없으면 출력이 그대로인지.
- 실제 cvdata에서 나오는 값은 MATLAB 실기 실행으로만 확인한다(아래 10).

## 9. 커밋 순서

1. `refactor(reporting)`: `st_result_iteration_name`과 `st_decision_object_path`를
   꺼낸다. 동작은 바뀌지 않는다.
2. `feat(reporting)`: `st_collect_decision_outcomes`를 더하고 PER_CUT·BATCH 리포트에
   `DecisionOutcomes` 시트를 쓴다.
3. `feat(export)`: 최종 문서가 시트를 읽어 `[T]`/`[F]`/`[T/F]`/`[-]`를 적는다.
4. `docs`: `docs/reference/final-document.md`, 결과 workbook 시트 설명, CHANGELOG,
   `docs/ai/codex-handoff.md`의 실기 확인 항목.

## 10. 확인하지 못한 가정

실기 MATLAB 실행으로 확인할 항목이다. 인수인계 문서에 그대로 옮긴다.

1. iteration 단위 cvdata(`getCoverageResults(iterResult)`)가 결과를 담고 있다. 일부
   릴리스는 ResultSet 단위에만 coverage를 둔다. 그 경우 모든 행이
   `DECISION_OUTCOME_UNAVAILABLE`이 되며, 그 사실이 Metadata 숫자로 보여야 한다.
2. Enable/Trigger/Reset, Switch, If의 outcome 텍스트가 `true`/`false`다. For
   Iterator는 사용자 리포트 캡처로 확인했다.
3. If 블록의 `description.decision` 순서가 if, elseif 순서와 같다.
4. iteration 단위 cvdata에도 coverage filter(CVF)가 적용되는지. 이번 표기는 실행
   횟수만 보므로 filter와 무관하지만, 결과가 filter로 가려진 블록이 `[-]`로 보일 수
   있는지 확인한다.
5. PER_CUT 리포트에 iteration 단위 수집을 더했을 때 리포트 시간이 얼마나 느는지.
   지금 PER_CUT은 속도 때문에 `IncludeTestDetails=false`로 돈다.
