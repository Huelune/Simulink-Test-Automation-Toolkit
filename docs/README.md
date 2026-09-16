# 문서 지도

## 기본 사용법

평소 쓰는 명령은 네 개입니다.

```matlab
st_setup
st_pre_validate_targets
st_run_from_harness

st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
```

| 순서 | 문서 | 내용 |
| --- | --- | --- |
| 1 | [처음 시작하기](getting-started.md) | 설치부터 제출물까지 전체 흐름. MATLAB을 모른다는 전제로 씁니다 |
| 2 | [용어집](glossary.md) | CUT, Harness, Assessment, CVF, SLDV가 각각 무엇인지 |
| 3 | [관리 Excel 열 사전](workbook-reference.md) | Excel에 무엇을 적어야 하는지 |
| 4 | [수동 실행 안내](manual/README.md) | 복사해서 바로 쓸 코드 |

## 파라미터를 찾을 때

| 문서 | 내용 |
| --- | --- |
| [관리 Excel 열 사전](workbook-reference.md) | `Targets` 시트 모든 열의 역할·기본값·오답 시 동작 |
| [설정 사전](config-reference.md) | `st_config.m`의 전역 설정 전체 |
| [실행 명령 사전](execution-commands.md) | 각 명령과 그 명령이 받는 옵션의 역할 |

## 작업할 때

| 하고 싶은 것 | 문서 |
| --- | --- |
| 준비와 테스트 실행 | [준비 및 실행](manual/prepare.md) |
| 단계별로 끊어서 실행하고 그 다음부터 이어가기 | [단계별로 끊어서 실행하기](manual/step-by-step.md) |
| standalone 제출물 생성 | [Standalone 실행](manual/standalone-run.md) |
| 제출물을 Test Manager에서 열기 | [결과 열기](manual/open-results.md) |
| 단계별 동작과 주의사항 전체 | [운영자 매뉴얼](operator-manual.md) |
| 오류가 났다 | [문제 해결](troubleshooting.md) |

## 선택 기능

필요해질 때만 보면 됩니다.

| 상황 | 문서 |
| --- | --- |
| 실행 없이 테스트 명세서 Excel 뽑기 | [테스트 명세서 추출](test-specification.md) |
| 실제 모델 없이 예제로 연습 | [익명 예제 생성](manual/example.md) |
| 중간 단계부터 재시작, 결과 재생성 | [재시작](manual/restart.md) |
| standalone pipeline의 경계와 결과 구조 | [Standalone Coverage 파이프라인](standalone-coverage-pipeline.md) |
| 다른 PC에서 재실행할 번들 만들기 | [내보내기 번들](export-bundle.md) |
| 기존 Harness를 본떠 새 Harness 만들기 | [Template Harness clone](harness-template-clone.md) |
| 도구 자체를 인증하기 | [종합 검증](verification.md) |
| 배포 전 R2025b에서 확인 | [R2025b 배포 전 확인](manual/runtime-verification.md) |

## 개발자용

| 문서 | 내용 |
| --- | --- |
| [저장소 구조](architecture.md) | 모듈 책임과 경계 규칙 |
| [TODO](TODO.md) | 아직 결정·검증되지 않은 작업 |
| [codex-handoff.md](codex-handoff.md) | **에이전트 전용** 작업 상태 기록. 사용자 매뉴얼이 아닙니다 |
| [archive/](archive/) | 과거 인수인계 기록. 현재 구현 지침이 아닙니다 |
