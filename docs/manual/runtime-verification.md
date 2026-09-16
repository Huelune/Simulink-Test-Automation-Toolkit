# R2025b 배포 전 확인

배포 전에 MATLAB R2025b 실기에서 확인할 항목을 모은 **검증 계획**입니다. 통과
기록이 아닙니다.

- 업무 모델 대신 폐기 가능한 예제나 복사본으로 먼저 실행하십시오.
- 새 MATLAB 세션에서 저장소를 Current Folder로 선택하십시오.
- 테스트는 자체 임시 checkout을 쓰지만 모델 callback 같은 외부 부작용까지 격리하지는
  않습니다. **다른 작업과 동시에 실행하지 마십시오.**

## 자동 테스트

```matlab
st_setup
assert(strcmp(version('-release'),'2025b'), 'Run this acceptance on R2025b.');
repo = st_project_root();
testFiles = { ...
    fullfile(repo,'tests','unit','test_artifact_stem.m'), ...
    fullfile(repo,'tests','unit','test_file_signature.m'), ...
    fullfile(repo,'tests','unit','test_warning_suppression.m'), ...
    fullfile(repo,'tests','unit','test_stage_restart.m'), ...
    fullfile(repo,'tests','unit','test_result_regeneration.m'), ...
    fullfile(repo,'tests','unit','test_standalone_coverage_pipeline.m'), ...
    fullfile(repo,'tests','unit','test_standalone_coverage_screen_status.m'), ...
    fullfile(repo,'tests','unit','test_export_bundle.m'), ...
    fullfile(repo,'tests','unit','test_standalone_harness_bundle.m'), ...
    fullfile(repo,'tests','unit','test_per_cut_execution.m'), ...
    fullfile(repo,'tests','unit','test_coverage_filters.m'), ...
    fullfile(repo,'tests','integration','test_stage_restart_runtime.m'), ...
    fullfile(repo,'tests','integration','test_standalone_coverage_pipeline_runtime.m')};
results = runtests(testFiles);
disp(table(results))
assert(all([results.Passed]), 'Some tests failed or were incomplete; preserve the full output.');
```

선행 단계 고정, readiness 무저장, 입력 변경 시 SLDV 안내, 유효 증거 재생성,
파일 훼손/구버전 증거 누락 차단, N/A/EXCEPT 보존, 재생성 provenance·latest 보존,
제출물 이름 stem, 파일 해시, 경고 억제 범위를 검사합니다. 기존 전체 unit suite도
별도로 실행하십시오.

## 실제 사용 흐름

1. [예제](example.md) 생성 → 대상 지정 → 일반 준비/실행.
2. readiness 전후 원본 model/Excel/Test File SHA-256, `pwd`, `path`, 열린 모델을 비교.
3. ASSESSMENT부터 재시작: HARNESS/SLDV/입력 준비가 다시 실행되지 않는지 로그 확인.
4. 입력 MAT 변경 후 늦은 단계 재시작: BLOCKED와 SLDV 권고 확인. 원본을 복구한 뒤 재검사.
5. [Standalone](standalone-run.md) EXECUTE → PACKAGE → SUMMARY와 ALL 경로 확인.
6. [재생성](restart.md) PACKAGE → SUMMARY, SUMMARY만 실행. 새 id, 원본 불변,
   `LocalExecutionCount=0`, PACKAGE import 1회 / SUMMARY import 0회 확인.
7. 두 실행 경로와 정상 파생 결과에서 `1111111111 PASS`, TC별 HTML 생성,
   열린 standalone 모델 없음, CVF 적용/복원 상태를 확인.
8. [결과 열기](open-results.md): launcher 없이 MLDATX와 Model 폴더 버튼으로 각
   standalone 모델 연결. 다른 경로로 옮긴 제출 폴더에서도 Input/CVF 수동 연결 확인.
9. 원본 Coverage HTML Details와 Excel의 Decision/Execution Executed·Total을 대조.
   유효 N/A는 0/0로, 실제 미수집은 없는 값으로 구분. CVF 이름과 rationale `none` 확인.
10. 의도적으로 예외가 나는 TC를 넣어 EXCEPT, 가능한 Harness/Input 보존,
    후속 TC 실행을 확인. 필터 복원 실패와 일반 결함 예외를 구분해 기록.

## 2026-09-16 변경분에서 추가로 확인할 것

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

실패 시 재시도를 반복하기 전에 full stack, source/new PipelineId,
pipeline manifest, execution log, readiness table을 보존하십시오. 업무 경로가 포함된
증거는 저장소에 커밋하지 말고 승인된 위치에 보관합니다.
