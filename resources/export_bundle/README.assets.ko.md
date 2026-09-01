# Simulink 테스트 자산 통합 관리 번들

이 폴더는 사용자가 선택한 Test Manager 결과와 그 결과에 대응하는 테스트
자산을 한 위치에서 확인하고 보관하기 위한 모음입니다.

- 번들 ID: `{{BUNDLE_ID}}`
- 대상 모델: `{{TOP_MODEL}}`
- 생성 MATLAB 릴리스: `{{MATLAB_RELEASE}}`
- 선택 결과: `{{RESULT_NAME}}`

## 포함된 파일

| 위치 | 내용 |
|---|---|
| `TestManagement.xlsx` | Test Case와 자산 매핑의 원본 관리 파일 |
| `models/{{TOP_MODEL}}.slx` | 내부 Harness가 유지된 저장 모델 사본 |
| `test-manager/{{TOP_MODEL}}.mldatx` | Test Case와 Iteration 정의가 포함된 Test Manager 파일 |
| `harnesses/{target}/*.slx` | 선택 결과와 매핑된 독립 standalone Harness 모델 |
| `inputs/signal_editor/{target}/` | 대상별 Harness Signal Editor 입력 |
| `inputs/sldv/{target}/` | 대상별 source/effective SLDV 입력 |
| `results/{selected-result}/` | 선택 결과의 Excel/PDF/HTML/MLDATX와 Coverage |
| `manifest.json` | 결과 선택, Target별 자산 경로, 상태와 파일 목록 |

현재 Test Manager ResultSet에서 직접 만든 `TestSummary.xlsx`의 Coverage sheet는
`OVERALL`과 `CUT` 수준 요약입니다. Test Case·Iteration별 상세 Coverage는
`raw/SelectedResults.mldatx`에 보존됩니다. `CoverageReportMode=SUMMARY`이면
`coverage/CoverageSummary.html`이, `FULL`이면 공식 상세 Coverage HTML이
생성됩니다. `manifest.json`의 `CoverageDetail`과 `CoverageReportMode`가 이
범위를 기록합니다.

standalone Harness는 원본 모델 사본에서 다시 복사한 임시 모델을 대상으로
생성했습니다. 따라서 원본 모델과 `models/`의 모델에는 내부 Harness가 그대로
남아 있습니다.

## 상태 확인

- `OK`: 선택 결과 보고서와 Coverage가 모두 생성 또는 복사되었습니다.
- `PARTIAL`: Test Manager/Harness/입력은 보존됐지만 Coverage 또는 일부 결과
  보고서가 없거나 생성에 실패했습니다. `manifest.json`의
  `ResultArtifacts`에서 사유를 확인하십시오.

## 중요한 제한

- 선택 결과에 포함된 Test Case와 정확히 매핑되는 Harness만 포함합니다.
- 참조 모델, Library, Data Dictionary 등의 전체 dependency는 수집하지 않습니다.
- standalone Harness는 원래 CUT와의 Harness 관리 연결이 없는 독립 모델입니다.
- `run_exported_tests`를 포함하지 않으며 다른 컴퓨터에서의 재실행을 보장하지
  않습니다.

완전한 재실행 번들이 필요하면 원본 프로젝트에서
`st_export_test_bundle`을 사용하십시오.
