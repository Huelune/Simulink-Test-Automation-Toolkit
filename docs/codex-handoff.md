# Codex 전용 작업 인수인계

이 문서는 사용자용 매뉴얼이 아니다. 다른 PC나 새 Codex 작업이 현재 브랜치와
검증 경계를 잘못 해석하지 않도록 유지하는 작업 상태 문서다. AGENTS.md의 지시에
따라 브랜치 변경, 병합, MATLAB 런타임 작업 전에 반드시 읽는다.

## 현재 기준

- 기준일: 2026-09-03
- 활성 개발 브랜치: feat/per-cut-filtered-execution
- 원격에서 가져온 기준: def658e
- 최신 로컬 기능 커밋: d109472
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

## 브랜치 지도

| 브랜치 | 기준 커밋 | 역할과 처리 방침 |
| --- | --- | --- |
| main | 0a0ace5 | 파일 구조 정리까지만 반영된 안정 기준. R2025b 검증 전 기능을 임의 backport하지 않는다. |
| integration/comprehensive | 34cf49f | 증분 실행, 보고서, 내보내기, 종합 검증을 모은 공통 기반. PER_CUT 최신 수정은 없음. |
| feature/api-per-testcase-coverage-filters | e27ffbb | Test Case별 필터 API 실험 기준. 현재 PER_CUT 브랜치가 후속 구현이다. |
| feat/per-cut-filtered-execution | d109472 이후 | 현재 활성 통합 브랜치. 다른 작업은 이 브랜치 최신 원격을 fetch한 뒤 이어간다. |
| fix/rebuild-coverage-filter-from-687aa78 | baadd60 | 결과 단계 필터 적용 실험 위에서 하위 Subsystem 선택을 복구한 비교 브랜치. 통째로 병합하지 않는다. |
| fix/rebuild-coverage-filter-from-9165bc9 | a5469f7 | 이전 실행 중 필터 적용 기준의 비교 브랜치. 통째로 병합하지 않는다. |

두 fix 브랜치는 서로 다른 과거 기준에서 만들어졌고 최신 def658e의 후속 오류
수정을 모두 포함하지 않는다. 하위 Subsystem 선택 의도는 d109472에 선별 반영됐다.
R2025b 검증 전에는 두 브랜치를 삭제하거나 현재 브랜치에 전체 병합하지 않는다.

## 실제 시스템 CVF 점검

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
3. st_check_per_cut_cvf 출력과 details 표를 보관한다.
4. 생성 CVF에서 CUT 자신이 없고 직계 하위 Subsystem만 있는지 확인한다.
5. SUBSYSTEM이 내부 일반 블록 전체를 필터링하지 않는지 Coverage HTML로 확인한다.
6. ALL_CONTENT만 선택된 하위 Subsystem 내부 전체를 처리하는지 확인한다.
7. 실행 전후 Test File, Suite, Test Case의 기존 필터 목록이 동일한지 확인한다.
8. Test Manager Coverage 화면에서 점 인덱싱 오류가 재발하지 않는지 확인한다.
9. 각 CUT의 MLDATX, CVT, CVF, Excel, HTML과 선택적 PDF를 확인한다.
10. 모델, Test File, Excel과 입력 파일의 원본 checksum 불변을 확인한다.

실패 시 최소 전달 자료:

- CVF-CHECK-v1로 시작하는 모든 출력 줄
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
5. st_setup 후 which st_check_per_cut_cvf -all 및 주요 st 함수의 중복을 확인한다.
6. 기존 원격 fix 브랜치를 전체 병합하지 않는다.
7. R2025b 결과가 없으면 정적 검증과 런타임 검증을 명확히 분리한다.
8. 새 런타임 결과와 결정이 생기면 이 문서의 기준일, 커밋, 검증 상태를 갱신한다.

## 다음 작업 순서

1. 현재 로컬 d109472와 이 handoff 문서를 원격 활성 브랜치에 push한다.
2. R2025b PC에서 최신 브랜치를 fast-forward하고 실제 PER_CUT 실행을 수행한다.
3. 6비트 코드와 상세 산출물을 분석해 필요한 수정만 새 커밋으로 반영한다.
4. 검증 통과 후 두 비교 fix 브랜치의 보존 또는 삭제를 결정한다.
5. CERTIFY + BOTH와 수동 GUI 증거가 끝난 뒤에만 PR과 main 통합을 결정한다.
