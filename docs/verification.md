# 전체 기능 테스트 및 상태 검증

처음 설치하거나 실제 업무 모델을 인증하는 단계별 절차는
[종합 검증 사용자 매뉴얼](user-manual.md)을 먼저 참조하십시오. 이 문서는
공개 API, 판정 기준과 결과 형식을 설명하는 기술 사양입니다.

## 공개 진입점

검증은 정상 workflow와 별도인 `st_verify_all`에서 시작합니다. 기본 명령은
원본을 저장하지 않고 현재 상태만 확인합니다.

```matlab
st_setup
summary = st_verify_all( ...
    'Profile', 'QUICK', ...
    'Target', 'CURRENT', ...
    'ManualEvidence', '', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', true);
```

전체 인증 명령은 다음과 같습니다.

```matlab
summary = st_verify_all( ...
    'Profile', 'CERTIFY', ...
    'Target', 'BOTH', ...
    'ManualEvidence', 'manual-evidence.json', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', true);
```

`FailOnNonPass=true`여도 Excel, JSON, JUnit XML과 manifest를 모두 기록한
뒤 `FAIL` 또는 `BLOCKED`에서 오류를 발생시킵니다.

## 프로필과 예상 시간

아래 시간은 모델 크기, Harness 수, SLDV 탐색 공간과 라이선스 서버 상태에
따라 크게 달라질 수 있는 운영 예상치입니다.

| Profile | 동작 | 시뮬레이션 | 일반적인 예상 |
| --- | --- | --- | --- |
| `QUICK` | 단위 테스트, 제품·라이선스 존재, 설정, 저장 상태, Test File/Harness/Scenario, 최신 산출물 점검 | 안 함 | 수십 초~수 분 |
| `RUNTIME` | QUICK + 내보내기 수집기로 만든 실제 모델 격리 사본에서 기존 Test File 실행과 보고서 생성 | 함 | 수 분~수 시간 |
| `CERTIFY` | 자동 fixture 전체 workflow, SLDV GENERATE/FILE, 캐시, 손상 복구, 부분 실패, 보고서, 내보내기와 2회 재실행 | 함 | 수십 분~수 시간 |

`Target`은 `CURRENT`, `FIXTURE`, `BOTH`입니다. 바이너리 fixture는 Git에
저장하지 않으며 실행별 `workspace/fixture`에서 MATLAB builder가 만듭니다.
실제 업무 모델은 원본에서 직접 실행하지 않고 내보내기 수집기를 재사용한
snapshot과 새 실행 workspace에서만 변경합니다.

## 필수 제품과 판정

| 기능 | MATLAB | Simulink | Simulink Test | Simulink Coverage | SLDV |
| --- | --- | --- | --- | --- | --- |
| QUICK/CURRENT | 필수 | 필수 | 필수 | 필수 | 사용 대상에 따라 확인 |
| RUNTIME/CURRENT | 필수 | 필수 | 필수 | 필수 | 기존 입력만 쓰면 생성 라이선스 불필요 |
| CERTIFY/FIXTURE | 필수 | 필수 | 필수 | 필수 | 필수 |

`license('test', feature)` 결과는 라이선스 존재 여부로만 사용합니다. 실제
checkout 실패는 실행 시점에 `BLOCKED`로 분류합니다.

| 검사 상태 | 의미 |
| --- | --- |
| `PASS` | 요구 검사를 통과함 |
| `FAIL` | 기능 또는 무결성 오류가 확인됨 |
| `BLOCKED` | 필수 제품, 라이선스, 입력 또는 수동 증거가 없어 완료할 수 없음 |
| `SKIP` | 선택한 대상에 적용되지 않음 |
| `WARN` | Coverage 미달 등 비차단 관찰 사항 |

전체 상태 우선순위는 `FAIL > BLOCKED > PASS_WITH_WARNINGS > PASS`입니다.
fixture에서 분모가 있는 Decision·Execution coverage는 100%가 필수입니다.
실제 업무 모델 coverage는 보고 전용이며 미달만으로 실패시키지 않습니다.

## 결과 구조

```text
result/verification/
├── latest.json
└── runs/{timestamp}_{run-id}/
    ├── VerificationSummary.xlsx
    ├── verification.json
    ├── junit.xml
    ├── environment.json
    ├── manifest.json
    ├── logs/
    │   └── matlab-unit-junit.xml
    ├── evidence/
    └── workspace/
```

`VerificationSummary.xlsx`에는 `Overview`, `Features`, `Checks`,
`Environment`, `ManualEvidence`, `Artifacts` 시트가 있습니다. 각 검사 행은
`CheckId`, `FeatureId`, `Profile`, `Target`, `Required`, `Status`,
`Message`, `EvidencePath`, `DurationSec`, `StartedAt`, `CompletedAt`을
기록합니다. JUnit의 `BLOCKED`와 `SKIP`은 skipped, 실제 `FAIL`은 failure로
표현합니다. MATLAB 단위 테스트 상세 JUnit은 공식
`XMLPlugin.producingJUnitFormat`으로 별도 생성합니다.

`KeepWorkspace=ON_FAILURE`는 `FAIL` 또는 `BLOCKED` 실행의 작업공간만
남깁니다. `ALWAYS`는 항상 보존하고 `NEVER`는 결과 writer가 끝난 후
삭제합니다. 실행별 결과와 `latest.json`은 삭제하지 않습니다.

## 수동 증거

다음 항목은 자동 판정과 별도로 사람이 확인합니다.

- 모델 선택 대화상자
- 중복 CUT 후보 선택과 highlight
- Excel native indentation 표시
- PDF/HTML/Excel 시각 확인
- Excel application 수준 접근 진단

형식은 [manual-evidence.example.json](../examples/manual-evidence.example.json)을
사용합니다. 각 항목에는 다음 값이 필요합니다.

```json
{
  "CheckId": "MANUAL.REPORT_VISUAL",
  "Status": "PASS",
  "VerifiedBy": "reviewer-id",
  "VerifiedAt": "2026-08-30T15:00:00+09:00",
  "TargetFingerprint": "current target fingerprint",
  "Notes": "PDF, HTML, Excel layout checked",
  "EvidencePaths": ["evidence/report.png"]
}
```

증거 파일이 없거나 fingerprint가 현재 모델·Test File·Excel과 다르면
`BLOCKED`입니다. fingerprint는 같은 MATLAB session에서 다음과 같이 확인할
수 있습니다.

```matlab
cfg = st_require_runtime_target();
fingerprint = st_verification_target_fingerprint(cfg)
```

## R2025b 최초 인증 절차

1. 원본 모델, Test File, Excel을 저장하고 `st_setup`을 실행합니다.
2. `QUICK + CURRENT`를 `FailOnNonPass=false`로 실행해 선행 `BLOCKED`를 정리합니다.
3. 수동 evidence JSON과 screenshot/log를 현재 fingerprint로 준비합니다.
4. `CERTIFY + BOTH`, `KeepWorkspace=ON_FAILURE`를 실행합니다.
5. `VerificationSummary.xlsx`의 모든 required 검사와 `junit.xml`을 확인합니다.
6. fixture Decision·Execution 100%, 최초/최종 결과 연결, FILE/GENERATE,
   두 번째 AUTO 캐시 재사용, 손상 상태 복구, 부분 실패 시 테스트 미실행,
   내보낸 template 불변과 두 번의 재실행을 확인합니다.
7. fixture의 `SUBSYSTEM+JUSTIFY`, `ALL_CONTENT+EXCLUDE`, `OFF` CUT이 Excel
   순서대로 독립 실행되고, 각 target manifest의 CVF 적용·복원 상태와 SHA-256,
   초기·최종 ResultSet 연결이 일치하는지 확인합니다.
8. 실제 모델 source inventory가 실행 전후 동일한지 확인합니다.
9. `PASS` 실행의 manifest와 R2025b 버전을 최초 인증 근거로 보관합니다.

`CERTIFY + FIXTURE`는 현재 활성 CVF 때문에 `AUTO → PER_CUT` 경로를 사용하고
`FULL` 보고서로 CUT별 MLDATX, Excel, Coverage HTML과 PDF를 확인합니다. CVF
복원 실패 시 이후 CUT이 실행되지 않는지도 별도 실패 fixture로 확인해야 합니다.

현재 개발 환경에서 MATLAB R2025b runtime 결과를 만들지 않았다면 코드와
문서가 존재해도 인증 완료로 기록하지 않습니다.
