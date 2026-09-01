# Simulink 테스트 자산 통합 관리 번들

이 폴더는 Test Manager 파일, 내부 Harness, Harness 입력과 기존 Coverage
결과를 한 위치에서 확인하고 보관하기 위한 테스트 자산 모음입니다.

- 번들 ID: `{{BUNDLE_ID}}`
- 대상 모델: `{{TOP_MODEL}}`
- 생성 MATLAB 릴리스: `{{MATLAB_RELEASE}}`
- 포함 결과: `{{REFERENCE_RUN}}`

## 포함된 파일

| 위치 | 내용 |
|---|---|
| `template/workspace/` | 내부 Test Harness가 저장된 최상위 모델 |
| `template/{{TOP_MODEL}}.mldatx` | Test Case와 Iteration을 포함한 Test Manager 파일 |
| `template/inputs/signal_editor/` | 대상별 Harness Signal Editor 입력 |
| `template/inputs/sldv/` | 대상별 source/effective SLDV 입력 |
| `template/result/sldv/` | 수집 시점의 SLDV manifest |
| `template/TestManagement.xlsx` | 대상과 옵션을 기록한 관리 파일 |
| `reference-report/` | 선택한 Excel/PDF/HTML/MLDATX 및 Coverage 결과 |
| `manifest.json` | 대상별 자산 경로, 파일 목록과 크기 |

Harness는 생성 시 `SaveExternally=false`이므로 별도 Harness 파일이 아니라
`template/workspace/`의 최상위 모델 안에 저장되어 있습니다.

## 중요한 제한

이 번들은 테스트 자산과 결과의 통합 관리용이며 다른 컴퓨터에서 그대로
재실행 가능한 완전한 테스트 번들은 아닙니다.

- 참조 모델, Library, Data Dictionary 등의 전체 dependency를 수집하지 않습니다.
- 필요한 MathWorks 제품을 분석하지 않습니다.
- 파일 SHA-256을 계산하지 않습니다.
- `run_exported_tests`를 포함하지 않습니다.

다른 컴퓨터에서 동일 테스트를 재실행해야 한다면 원본 프로젝트에서
`st_export_test_bundle`을 사용해 재현 가능한 번들을 만드십시오.
