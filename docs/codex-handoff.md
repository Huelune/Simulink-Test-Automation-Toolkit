# Codex 전용 작업 인수인계

이 문서는 사용자용 매뉴얼이 아니다. 다른 PC나 새 Codex 작업이 현재 브랜치와
검증 경계를 잘못 해석하지 않도록 유지하는 작업 상태 문서다. AGENTS.md의 지시에
따라 브랜치 변경, 병합, MATLAB 런타임 작업 전에 반드시 읽는다.

## 현재 기준

- 기준일: 2026-09-04
- 활성 개발 브랜치: feat/standalone-harness-model-execution
- 기반 브랜치/커밋: feat/per-cut-filtered-execution / a48ec9e
- 독립 모델 기능 기준: 1af915c
- 독립 모델 검증 기준: cc10729
- 필수 handoff 기준: 이 문서의 현재 커밋
- 필수 진단 기준: st_check_actual_system과 st_check_standalone_run 포함
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

독립 Harness 모델 실행은 다음 경계를 추가로 지킨다.

- `INTERNAL_HARNESS`가 기본이며 `EXPORTED_MODEL`은 실행 전체 옵션이다.
- EXPORTED_MODEL은 항상 PER_CUT이며 BATCH와 행별 혼합을 허용하지 않는다.
- 내부 Harness는 Assessment와 expected value의 원본이다. APPLY 변경 후 Final
  독립 모델을 다시 export하고 SID 기반 CVF도 다시 생성한다.
- `harness-scope.cvf`는 독립 모델의 CUT을 제외한 최상위 블록만 선택한다.
- `target-policy.cvf`는 활성 정책일 때 CUT의 직계 하위 Subsystem만 선택한다.
- 원본 Test File 계층의 수동 CVF만 실행용 Test File에 복사하며 기존 자동 관리
  CVF는 승계하지 않는다.
- 실행 모델, 입력 사본, 전용 Test File과 결과는 result/standalone_runs에 두며
  기존 per_cut_runs와 latest pointer를 변경하지 않는다.

위의 공통 CUT 직계 Subsystem 필터 기준은 d109472에서 최신 기능 브랜치 위에
다시 반영됐다. 이전 원격 커밋
f60601e는 CUT 자신을 선택하므로 현재 요구사항의 기준으로 사용하지 않는다.

## 활성 브랜치 지도

| 브랜치 | 기준 커밋 | 역할과 처리 방침 |
| --- | --- | --- |
| main | 0a0ace5 | 파일 구조 정리까지만 반영된 안정 기준. R2025b 검증 전 기능을 임의 backport하지 않는다. |
| feat/per-cut-filtered-execution | a48ec9e | 검증되지 않은 독립 모델 변경을 포함하지 않는 안정 부모 브랜치. |
| feat/standalone-harness-model-execution | 3b0d798 이후 | 현재 활성 원격 기능 브랜치. 내부 Harness를 독립 Model SUT로 실행하며 R2025b 결과 전에는 부모 브랜치를 대체하지 않는다. |

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

과거 커밋 해시는 추적 근거로만 유지한다. 일반 수정은 부모 브랜치 최신 원격에서,
독립 모델 실행 수정은 feat/standalone-harness-model-execution에서 이어간다.

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
10. Test File, Excel과 입력 파일 checksum은 불변인지 확인하고, 원본 모델은
    Harness logging 및 APPLY 기대값 갱신 외의 변경이 없는지 확인한다.
11. EXPORTED_MODEL로 같은 fixture를 실행하고 Test Case의 Model SUT,
    HarnessOwner/HarnessName 공백과 Assessment 경로를 확인한다.
12. Harness CVF가 CUT을 제외한 최상위 블록 전체와 일치하고 Target CVF가 CUT
    직계 Subsystem만 선택하는지 확인한다.
13. APPLY 뒤 Final 모델·CVF가 별도 이름과 SID로 생성되는지 확인한다.
14. st_check_standalone_run 결과 `111111`과 상세 표를 보관한다.

실패 시 최소 전달 자료:

- CVF-CHECK-v1로 시작하는 모든 출력 줄
- SYSTEM-CHECK-v1로 시작하는 모든 출력 줄과 summary 상세 표
- details 표
- result/per_cut_latest.json
- 해당 run의 manifest.json과 logs/execution.log
- 실패 CUT의 target-manifest.json과 filter 폴더
- EXPORTED_MODEL이면 STANDALONE-CHECK-v1 출력과 standalone run의 Initial/Final
  모델, 두 CVF 및 실행 전용 Test File
- MATLAB 오류의 getReport extended 출력과 dbstack completenames 출력

## 다른 Codex의 시작 절차

1. git fetch --prune origin을 실행한다.
2. 원격 feat/per-cut-filtered-execution의 최신 커밋을 확인한다.
   독립 모델 작업을 이어갈 때는 원격에 게시된
   feat/standalone-harness-model-execution의 최신 커밋을 확인한다.
3. 작업 트리가 깨끗할 때만 fast-forward한다.
4. 이 문서의 브랜치 지도와 변경 불가 핵심 결정을 읽는다.
5. st_setup 후 st_check_actual_system을 실행한다. E6이 주요 st 함수 중복을
   자동 확인하며 필요할 때만 which 함수명 -all로 상세 경로를 확인한다.
6. 정리된 과거 브랜치를 다시 만들거나 과거 tip을 전체 병합하지 않는다.
7. R2025b 결과가 없으면 정적 검증과 런타임 검증을 명확히 분리한다.
8. 새 런타임 결과와 결정이 생기면 이 문서의 기준일, 커밋, 검증 상태를 갱신한다.

## 다음 작업 순서

1. 현재 개발 PC의 독립 모델 브랜치는 구현·검증 코드를 커밋했으며 MATLAB
   R2025b 실행은 아직 수행하지 않았다.
2. R2025b PC에서 기존 PER_CUT과 EXPORTED_MODEL을 같은 fixture로 각각 실행한다.
3. 18비트, 기존 CVF 6비트, STANDALONE 6비트와 상세 산출물을 비교한다.
4. CERTIFY + BOTH와 수동 GUI 증거가 끝난 뒤에만 PR과 main 통합을 결정한다.
