# 문서 지도

무엇을 하려는지에 따라 읽을 문서를 골라 주는 목차입니다.

## 처음이라면

| 순서 | 문서 | 내용 |
| --- | --- | --- |
| 1 | [처음 시작하기](getting-started.md) | 설치부터 첫 실행까지. MATLAB을 모른다는 전제로 씁니다 |
| 2 | [용어집](glossary.md) | CUT, Harness, Assessment, CVF, SLDV가 각각 무엇인지 |
| 3 | [관리 Excel 열 사전](workbook-reference.md) | Excel에 무엇을 적어야 하는지 |

## 파라미터를 찾을 때

| 문서 | 내용 |
| --- | --- |
| [관리 Excel 열 사전](workbook-reference.md) | `Targets` 시트 모든 열의 역할·기본값·오답 시 동작 |
| [설정 사전](config-reference.md) | `st_config.m`의 전역 설정 전체 |
| [실행 명령 사전](execution-commands.md) | 각 명령과 그 명령이 받는 옵션의 역할 |

## 작업할 때

| 하고 싶은 것 | 문서 |
| --- | --- |
| 복사해서 바로 쓸 코드 | [수동 실행 안내](manual/README.md) |
| 단계별 동작과 주의사항 전체 | [운영자 매뉴얼](operator-manual.md) |
| 오류가 났다 | [문제 해결](troubleshooting.md) |
| 원하는 단계부터 다시 실행 | [재시작](manual/restart.md) |
| 모델을 여러 개 다루기 | [모델 profile](manual/model-profiles.md) |

## 결과물을 만들 때

| 만들려는 것 | 문서 |
| --- | --- |
| 실행 없이 테스트 명세서 Excel | [테스트 명세서 추출](test-specification.md) |
| standalone Harness 커버리지 제출물 | [Standalone Coverage 파이프라인](standalone-coverage-pipeline.md) · [Standalone 실행](manual/standalone-run.md) |
| 다른 PC에서 재실행할 번들 | [내보내기 번들](export-bundle.md) |
| 제출된 결과를 Test Manager에서 열기 | [결과 열기](manual/open-results.md) |
| 기존 Harness를 본떠 새 Harness 만들기 | [Template Harness clone](harness-template-clone.md) |

## 검증할 때

| 문서 | 내용 |
| --- | --- |
| [종합 검증](verification.md) | `st_verify_all`의 QUICK/RUNTIME/CERTIFY 실행 절차와 판정 기준 |
| [R2025b 배포 전 확인](manual/runtime-verification.md) | 배포 전에 실기에서 돌려 볼 항목 |

## 개발자용

| 문서 | 내용 |
| --- | --- |
| [저장소 구조](architecture.md) | 모듈 책임과 경계 규칙 |
| [TODO](TODO.md) | 아직 결정·검증되지 않은 작업 |
| [codex-handoff.md](codex-handoff.md) | **에이전트 전용** 작업 상태 기록. 사용자 매뉴얼이 아닙니다 |
| [archive/](archive/) | 과거 인수인계 기록. 현재 구현 지침이 아닙니다 |
