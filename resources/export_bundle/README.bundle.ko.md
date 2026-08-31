# 재실행 가능한 Simulink 테스트 번들

이 폴더는 다른 컴퓨터에서도 같은 테스트를 다시 실행할 수 있도록 만든 내보내기 결과입니다.

- 번들 ID: `{{BUNDLE_ID}}`
- 대상 모델: `{{TOP_MODEL}}`
- 생성 MATLAB 릴리스: `{{MATLAB_RELEASE}}`
- 비교용 기존 결과: `{{REFERENCE_RUN}}`

## 가장 빠른 실행 방법

1. ZIP 파일을 새 폴더에 압축 해제합니다.
2. MATLAB `{{MATLAB_RELEASE}}`와 필요한 MathWorks 제품을 준비합니다.
3. MATLAB의 Current Folder를 이 README가 있는 폴더로 설정합니다.
4. Command Window에서 다음 명령을 실행합니다.

```matlab
run_exported_tests
```

실행할 때마다 `executions/날짜_식별자/workspace/`가 새로 생깁니다. 테스트 중 변경되는 기대값, Harness 설정, Test File과 결과는 이 작업 사본에만 저장됩니다. `template/`과 원래 프로젝트는 바뀌지 않으므로 같은 시작 상태에서 다시 실행할 수 있습니다.

## 포함된 파일

| 위치 | 내용 |
|---|---|
| `template/workspace/` | 내부 Test Harness를 포함한 저장 모델과 분석된 모델 의존 파일 |
| `template/inputs/` | 대상별 Signal Editor 및 SLDV 테스트 입력 |
| `template/{{TOP_MODEL}}.mldatx` | Test Case와 Iteration을 포함한 Test File |
| `template/TestManagement.xlsx` | 실행 대상과 옵션 설정 |
| `reference-report/{{REFERENCE_RUN}}/` | 내보내기 시점의 비교용 Excel/PDF/HTML/MLDATX 결과 |
| `manifest.json` | 파일 경로, SHA-256 checksum, MATLAB 릴리스와 대상 정보 |
| `executions/` | 이 번들에서 새로 실행한 작업 사본과 결과 |

`reference-report/`는 과거 결과를 보는 용도입니다. Test Case 자체는 `template/*.mldatx`에 들어 있습니다. 결과 MLDATX만으로 Test Case를 복원하는 방식은 사용하지 않습니다.

## 재실행 결과 확인

성공하면 MATLAB에 새 실행 폴더와 새 보고서 폴더가 표시됩니다. 새 보고서는 실행 작업 사본 아래 `result/runs/`에 생성되고, 기존 비교 결과는 `reference-report/`에 그대로 남습니다.

기본 동작은 내보낼 때 사용한 MATLAB 릴리스와 정확히 같은 릴리스를 요구합니다. 다른 릴리스에서 시험해야 한다면 차이가 날 수 있음을 확인한 뒤 다음처럼 명시적으로 허용할 수 있습니다.

```matlab
run_exported_tests('AllowReleaseMismatch', true)
```

## 오류가 날 때 확인할 것

- `Bundle file was changed`: 번들 파일이 생성 이후 변경됐습니다. 원본 ZIP을 다시 압축 해제하십시오.
- `MATLAB release mismatch`: `{{MATLAB_RELEASE}}`를 사용하거나 위의 명시적 허용 옵션을 사용하십시오.
- 필요한 제품/라이선스 오류: `manifest.json`의 `RequiredProducts`와 실행 컴퓨터의 설치·라이선스를 비교하십시오.
- 같은 이름의 모델 오류: 다른 폴더에서 이미 연 모델을 저장하고 닫은 뒤 새 MATLAB 세션에서 다시 실행하십시오.

## 중요한 제한

- 이 번들은 준비 단계에서 Harness나 Test Case를 새로 생성하지 않습니다. 내보내기 당시 저장된 상태를 반복 실행합니다.
- 자동 수집 대상은 모델 dependency와 이 toolkit이 관리하는 Signal Editor·SLDV 입력입니다. Test File에 사용자가 직접 연결한 baseline 데이터, callback, 요구사항 또는 custom criteria 파일은 MATLAB Project로 dependency를 별도 확인해야 합니다.
- 외부 서버, 사내 데이터베이스, 환경 변수나 라이선스는 파일로 복사할 수 없습니다. 모델이 이런 자원에 의존하면 받는 사람이 별도로 준비해야 합니다.
- 같은 파일과 릴리스를 사용해도 운영체제, 라이선스, solver 또는 외부 코드 차이로 결과가 달라질 수 있습니다. `reference-report/`와 새 보고서를 함께 비교하십시오.
