# Reproducible test bundle export

## 테스트 자산 통합 관리 번들과의 구분

선택한 Test Manager 결과, standalone Harness, Harness 입력과 Coverage 결과를
한 폴더에서 관리하려면 다음 명령을 사용합니다.

```matlab
st_export_test_asset_bundle('SelectResult', true)
```

선택창에는 Test Manager ResultSet과 기존 toolkit Run이 함께 표시됩니다.
자동화 스크립트에서는 기존처럼 `ResultSet` 객체나 `RunId`를 직접 지정할 수
있습니다.

대용량 ResultSet은 기본 `CoverageReportMode='SUMMARY'`로 처리합니다. CUT
Coverage Excel/HTML과 전체 결과 MLDATX를 보존하면서 Coverage 포함 PDF와
`cvhtml` 상세 보고서의 중복 생성을 피합니다. 상세 보고서가 반드시 필요하면
`st_export_test_asset_bundle('SelectResult',true,'CoverageReportMode','FULL')`을
사용합니다.

이 명령은 `result/exports/assets/`에 내부 Harness가 유지된 모델 사본,
선택 결과와 매핑되는 독립 Harness `.slx`, Test Manager 파일, 관리 Excel,
Signal Editor·SLDV 입력과 결과 보고서·Coverage를 복사합니다. 독립 Harness는
원본을 다시 복사한 임시 모델에서 생성하므로 원본 Harness 관계를 변경하지
않습니다. 전체 모델 dependency 분석, Toolbox 분석, 전체 파일 SHA-256과 ZIP
생성을 기본적으로 생략합니다.

`st_export_test_bundle`은 다른 컴퓨터에서의 재실행이 필요할 때 사용하는
완전한 번들이며 아래의 재현성 검사를 모두 수행합니다.

## 목적

`st_export_test_bundle`은 준비가 끝난 Simulink 테스트의 저장 상태와 결과를
다른 작업자에게 전달하는 독립 명령입니다. 정상 workflow 진입점에는
연결하지 않습니다. 시간이 오래 걸리는 Harness·SLDV·Test Case 준비 단계를
다시 만들지 않고, 내보낸 저장 상태에서 Test File을 반복 실행하는 것이
범위입니다.

## 안전 경계

- 원본 모델과 Test File이 저장된 상태일 때만 내보냅니다.
- 원본의 내부 Harness를 파일로 분리하거나 모델과의 연결을 제거하지 않습니다.
- 파일 복사 전후 모델과 Test File의 SHA-256을 비교합니다.
- 모델 dependency 분석에서 누락 파일이 발견되면 부분 번들을 만들지 않습니다.
- 번들 `template/`은 기준 상태이며 실행 중 직접 수정하지 않습니다.
- 각 재실행은 `executions/{timestamp}/workspace`에 새 작업 사본을 만듭니다.
- 받는 쪽에서 변경되는 Harness Filename, SLDV manifest, 기대값과 Test File은
  해당 작업 사본에만 저장됩니다.

`sltest.harness.export`는 기존 모델과 Harness 관계를 제거하는 용도의 API이므로
이 기능에서 사용하지 않습니다. 현재 내부 Harness는 저장된 모델 파일 복사로
보존합니다.

## 출력 구조

```text
result/exports/{timestamp}_{id}/
├── README.md
├── manifest.json
├── run_exported_tests.m
├── template/
│   ├── st_setup.m
│   ├── VERSION.txt
│   ├── src/
│   ├── TestManagement.xlsx
│   ├── {TopModel}.mldatx
│   ├── workspace/          # 모델과 분석된 모델 dependency
│   ├── inputs/
│   │   ├── signal_editor/{target}/
│   │   └── sldv/{target}/
│   └── result/sldv/sldv_manifest.mat
├── reference-report/{source-run-id}/
└── executions/            # 받는 사람이 실행하면 생성
```

결과 MLDATX는 Test Case 정의를 대체하지 않습니다. 따라서 비교용
`reference-report/raw/*.mldatx`와 별도로 실행 가능한 Test File
`template/{TopModel}.mldatx`를 반드시 포함합니다.

## Manifest와 재실행

`manifest.json`은 번들 ID, MATLAB 릴리스, 대상, 상대 경로, 필요한 제품,
모든 기준 파일의 SHA-256과 크기를 기록합니다. 로컬 절대 source path는
기록하지 않습니다.

`run_exported_tests`는 다음 순서로 동작합니다.

1. MATLAB 릴리스와 기준 파일 checksum을 검사합니다.
2. `template/`을 새 실행 작업 공간에 복사합니다.
3. 작업 사본에만 `runtime_target.mat`을 만들고 SLDV manifest 경로를 바꿉니다.
4. 작업 사본 모델의 Harness Signal Editor Filename을 복사된 입력으로 바꿉니다.
5. `st_run_generated_tests`로 Test File을 실행합니다.
6. `st_generate_test_report`로 새 Excel/PDF/HTML/MLDATX 결과를 만듭니다.

일반 사용자의 `st_export_test_bundle`은 기본적으로 reference report를
포함합니다. `st_verify_all`의 격리 snapshot은 아직 실행 결과가 없는 상태도
검증할 수 있도록 같은 수집기를 `IncludeReferenceReport=false`로 호출합니다.
이 내부 snapshot도 모델, Test File, Excel, dependency와 입력 checksum 검사를
동일하게 적용하지만 비교용 reference-report 폴더만 생략합니다.

기대값 `APPLY` 정책도 작업 사본에서 기존 실행 함수가 동일하게 처리합니다.
재실행은 준비 workflow를 실행하지 않습니다.

## 재현성의 범위와 검증

기본값은 내보낸 MATLAB 릴리스와 정확히 같은 릴리스를 요구합니다. 설치 제품,
라이선스, 운영체제, compiler, 환경 변수 또는 외부 데이터 서비스는 파일
번들만으로 복제할 수 없습니다. `RequiredProducts`는 안내 정보이며 받는
환경의 실제 설치·라이선스 확인이 필요합니다.

모델 dependency와 이 toolkit이 직접 관리하는 Signal Editor·SLDV 입력은
자동 수집합니다. Test File에 사용자가 별도로 연결한 baseline 데이터,
callback, 요구사항 또는 custom criteria 파일은 이 구현의 수집 범위가 아니므로
MATLAB Project의 Test File dependency 분석으로 추가 확인해야 합니다.

현재 정적·순수 함수 검증은 번들 경로 안전성, manifest/resource 존재,
workflow와의 분리, 금지 API 미사용을 다룹니다. 실제 모델 dependency 수집,
내부 Harness 보존, 입력 경로 재작성과 결과 동일성은 MATLAB R2025b가 있는
승인된 환경에서 end-to-end 검증해야 합니다.
