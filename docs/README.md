# 문서 지도

> **처음이라면 [사용자 매뉴얼](user-manual.md) 하나만 읽으면 됩니다.**
> 준비부터 고객 제출용 최종 문서까지, 단계마다 코드·확인 방법·옵션을 적었습니다.

```text
docs/
├── user-manual.md    메인 매뉴얼. 처음부터 끝까지 따라가는 문서
├── reference/        자세히 볼 때. 입력·설정·옵션 전체, 내부 동작, 선택 기능
├── design/           설계. 저장소 구조와 보류된 결정
├── ai/               AI 에이전트 작업용. 인수인계와 커밋 규칙
├── superpowers/      AI 에이전트가 만든 설계안과 구현 계획
└── archive/          과거 기록. 현재 지침이 아닙니다
```

## reference — 자세히 볼 때

**입력과 설정**

| 문서 | 내용 |
| --- | --- |
| [관리 Excel 열 사전](reference/workbook-reference.md) | `Targets` 시트 모든 열의 역할·기본값·잘못 적었을 때의 동작 |
| [설정 사전](reference/config-reference.md) | `st_config.m`의 전역 설정 전체 |
| [실행 명령 사전](reference/execution-commands.md) | 모든 명령과 그 명령이 받는 옵션 |
| [용어집](reference/glossary.md) | CUT, Harness, Assessment, CVF, SLDV가 각각 무엇인지 |

**동작과 문제 해결**

| 문서 | 내용 |
| --- | --- |
| [운영자 매뉴얼](reference/operator-manual.md) | 단계마다 내부에서 일어나는 일, SLDV 모드별 처리, CVF 규칙, 결과 구조 |
| [단계별로 끊어서 실행하기](reference/step-by-step.md) | 단계 명령을 하나씩 부르고 그 다음부터 이어가기 |
| [문제 해결](reference/troubleshooting.md) | 오류 식별자별 원인과 대처 |

**선택 기능**

| 문서 | 내용 |
| --- | --- |
| [테스트 명세서 추출](reference/test-specification.md) | 실행 없이 명세서 Excel 뽑기 |
| [최종 문서 추출](reference/final-document.md) | 고객 제출용 최종 문서의 시트 구성과 판정 출처 |
| [Standalone Coverage 파이프라인](reference/standalone-coverage-pipeline.md) | 파이프라인의 경계, 산출물 구조, 예외 처리, PREPARE, 제출물 열기 |
| [재시작](reference/restart.md) | 앞 단계를 보존한 채 중간부터 재시작, 결과 재생성 |
| [내보내기 번들](reference/export-bundle.md) | 다른 PC에서 재실행할 번들 만들기 |
| [Template Harness clone](reference/harness-template-clone.md) | 기존 Harness를 본떠 새 Harness 만들기 |
| [익명 예제 생성](reference/example.md) | 실제 모델 없이 예제로 연습 |
| [종합 검증](reference/verification.md) | 도구 자체를 인증하기, R2025b 배포 전 실기 확인 |

**주제별 원본 문서** — 같은 내용은 한 곳에만 적고 나머지는 링크합니다.

| 주제 | 원본 |
| --- | --- |
| 절차, 기본 옵션, 상황별 조합 | [사용자 매뉴얼](user-manual.md) |
| 모든 명령의 옵션 전체 | [실행 명령 사전](reference/execution-commands.md) |
| Excel 열 / 설정값 | [관리 Excel 열 사전](reference/workbook-reference.md) / [설정 사전](reference/config-reference.md) |
| 단계 내부 동작 | [운영자 매뉴얼](reference/operator-manual.md) |
| 재시작, 결과 재생성 | [재시작](reference/restart.md) |
| standalone 경계·산출물·검사 비트·제출물 열기 | [Standalone Coverage 파이프라인](reference/standalone-coverage-pipeline.md) |
| 오류 대처, 상태 초기화 | [문제 해결](reference/troubleshooting.md) |

## design — 설계

| 문서 | 내용 |
| --- | --- |
| [저장소 구조](design/architecture.md) | 모듈 책임과 경계 규칙 |
| [TODO](design/TODO.md) | 아직 결정·검증되지 않은 작업 |

## ai — AI 에이전트 작업용

| 문서 | 내용 |
| --- | --- |
| [codex-handoff.md](ai/codex-handoff.md) | **에이전트 전용** 작업 상태 기록. 사용자 매뉴얼이 아닙니다 |
| [커밋 규칙](ai/commit-convention.md) | 커밋 단위와 메시지 형식. 사람이 커밋할 때도 따릅니다 |

`superpowers/`는 AI 에이전트의 설계·계획 도구가 파일을 만드는 위치라서 이름을
바꾸지 않았습니다. [archive/](archive/)에는 codex-handoff에서 옮긴 날짜별 [작업 기록](archive/codex-handoff-history.md)만 있습니다.
