# Codex 전용 작업 인수인계

이 문서는 사용자용 매뉴얼이 아니다. 다른 PC나 새 Codex 작업이 현재 브랜치와
검증 경계를 잘못 해석하지 않도록 유지하는 작업 상태 문서다. AGENTS.md의 지시에
따라 브랜치 변경, 병합, MATLAB 런타임 작업 전에 반드시 읽는다.

## 현재 기준

- 기준일: 2026-09-03
- 활성 개발 브랜치: feat/per-cut-filtered-execution
- 필수 기능 기준: d109472
- 필수 handoff 기준: 2b3ba09 이후
- 필수 진단 기준: 현재 브랜치 최신 커밋의 st_check_actual_system 포함
- MATLAB R2025b 검증: 미수행
- 현재 PC: MATLAB 실행 파일과 실제 result 폴더 없음
- 완료 표현: 정적 구현 완료까지만 허용하며 인증 완료나 PR 준비 완료로 표현하지 않는다.

## 변경 불가 핵심 결정

CoverageFilterMode이 활성화된 CUT의 자동 CVF는 CUT 자기 자신을 rule로 선택하면
안 된다. CUT의 직계 하위 Subsystem만 선택해야 한다.

- SUBSYSTEM: 각 직계 하위 Subsystem을 BlockInstance로 선택한다. 내부 일반 블록은
  직접 포함하지 않는다.
- ALL_CONTENT: 각 직계 하위 Subsystem을 SubsystemAllContent로 선택한다.
- CUT 자신은 두 모드 모두 제외한다.
- 일반 블록은 직접 rule로 만들지 않는다.
- 직계 하위 Subsystem이 없으면 CVF는 생성될 수 있지만 실제 rule은 0개다. 실제
  필터 효과를 확인하는 6비트 진단에서는 B3을 0으로 표시한다.
- CVF는 CUT별 실행 폴더에 보존하고 실행 후 원래 Test File, Suite, Test Case 필터
  목록을 복원해야 한다.

이 기준은 d109472에서 최신 기능 브랜치 위에 다시 반영됐다. 이전 원격 커밋
f60601e는 CUT 자신을 선택하므로 현재 요구사항의 기준으로 사용하지 않는다.

## 활성 브랜치 지도

| 브랜치 | 기준 커밋 | 역할과 처리 방침 |
| --- | --- | --- |
| main | 0a0ace5 | 파일 구조 정리까지만 반영된 안정 기준. R2025b 검증 전 기능을 임의 backport하지 않는다. |
| feat/per-cut-filtered-execution | d109472 이후 | 현재 활성 통합 브랜치. 다른 작업은 이 브랜치 최신 원격을 fetch한 뒤 이어간다. |

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

과거 커밋 해시는 추적 근거로만 유지한다. 새 수정은 main이 아니라
feat/per-cut-filtered-execution의 최신 원격에서 시작한다.

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

출력되는 CVF-CHECK-v1 줄 전체를 사용자 또는 다른 Codex에 전달한다. 종합 코드가
111111일 때만 모든 활성 CVF CUT이 여섯 검사를 통과한 것이다.

| 비트 | 검사 |
| --- | --- |
| B1 | target manifest, CVF 파일, SHA-256 일치 |
| B2 | 생성, 적용, 복원 상태가 모두 OK |
| B3 | 실제 rule 수가 manifest와 같고 0보다 큼 |
| B4 | CUT 자신이 selector에 없음 |
| B5 | selector 집합이 직계 하위 Subsystem 집합과 정확히 같음 |
| B6 | SUBSYSTEM/ALL_CONTENT selector와 EXCLUDE/JUSTIFY action 일치 |

한 CUT이라도 특정 비트가 0이면 종합 코드의 같은 위치도 0이다. 진단 명령은
result와 CVF를 읽기만 하며, 점검을 위해 연 모델은 저장하지 않고 닫는다.

## R2025b에서 반드시 확인할 항목

1. MATLAB 경로 중복 여부를 which 함수명 -all 형태로 확인한다.
2. SUBSYSTEM, ALL_CONTENT, OFF 대상이 포함된 PER_CUT 실행을 수행한다.
3. st_check_actual_system과 st_check_per_cut_cvf 출력 및 상세 표를 보관한다.
4. 생성 CVF에서 CUT 자신이 없고 직계 하위 Subsystem만 있는지 확인한다.
5. SUBSYSTEM이 내부 일반 블록 전체를 필터링하지 않는지 Coverage HTML로 확인한다.
6. ALL_CONTENT만 선택된 하위 Subsystem 내부 전체를 처리하는지 확인한다.
7. 실행 전후 Test File, Suite, Test Case의 기존 필터 목록이 동일한지 확인한다.
8. Test Manager Coverage 화면에서 점 인덱싱 오류가 재발하지 않는지 확인한다.
9. 각 CUT의 MLDATX, CVT, CVF, Excel, HTML과 선택적 PDF를 확인한다.
10. 모델, Test File, Excel과 입력 파일의 원본 checksum 불변을 확인한다.

실패 시 최소 전달 자료:

- CVF-CHECK-v1로 시작하는 모든 출력 줄
- SYSTEM-CHECK-v1로 시작하는 모든 출력 줄과 summary 상세 표
- details 표
- result/per_cut_latest.json
- 해당 run의 manifest.json과 logs/execution.log
- 실패 CUT의 target-manifest.json과 filter 폴더
- MATLAB 오류의 getReport extended 출력과 dbstack completenames 출력

## 다른 Codex의 시작 절차

1. git fetch --prune origin을 실행한다.
2. 원격 feat/per-cut-filtered-execution의 최신 커밋을 확인한다.
3. 작업 트리가 깨끗할 때만 fast-forward한다.
4. 이 문서의 브랜치 지도와 변경 불가 핵심 결정을 읽는다.
5. st_setup 후 st_check_actual_system을 실행한다. E6이 주요 st 함수 중복을
   자동 확인하며 필요할 때만 which 함수명 -all로 상세 경로를 확인한다.
6. 정리된 과거 브랜치를 다시 만들거나 과거 tip을 전체 병합하지 않는다.
7. R2025b 결과가 없으면 정적 검증과 런타임 검증을 명확히 분리한다.
8. 새 런타임 결과와 결정이 생기면 이 문서의 기준일, 커밋, 검증 상태를 갱신한다.

## 다음 작업 순서

### 2026-09-04 테스트 명세서 추출 추가

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
