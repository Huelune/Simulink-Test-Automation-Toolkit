# Simulink 테스트 확인용 보관 번들

이 폴더는 저장된 Harness, Test File과 기존 테스트 결과를 빠르게 확인하기
위한 보관본입니다.

- 번들 ID: `{{BUNDLE_ID}}`
- 대상 모델: `{{TOP_MODEL}}`
- 생성 MATLAB 릴리스: `{{MATLAB_RELEASE}}`
- 포함 결과: `{{REFERENCE_RUN}}`

## 포함된 파일

| 위치 | 내용 |
|---|---|
| `template/workspace/` | 내부 Test Harness를 포함한 저장된 최상위 모델 |
| `template/{{TOP_MODEL}}.mldatx` | Test Case와 Iteration을 포함한 Test File |
| `template/TestManagement.xlsx` | 대상과 옵션을 기록한 관리 파일 |
| `reference-report/` | 선택한 기존 Excel/PDF/HTML/MLDATX 결과 |
| `manifest.json` | 보관 파일 목록, 크기와 대상 메타데이터 |

## 중요한 제한

이 보관본은 빠른 확인용이며 재실행 가능한 완전한 테스트 번들이 아닙니다.

- 참조 모델, Library, Data Dictionary 등의 dependency를 수집하지 않습니다.
- Harness의 외부 Signal Editor 및 SLDV 입력을 다시 수집하지 않습니다.
- 필요한 MathWorks 제품을 분석하지 않습니다.
- 파일 SHA-256을 계산하지 않습니다.
- `run_exported_tests`를 포함하지 않습니다.

다른 컴퓨터에서 동일 테스트를 재실행해야 한다면 원본 프로젝트에서
`st_export_test_bundle`을 사용해 재현 가능한 번들을 만드십시오.
