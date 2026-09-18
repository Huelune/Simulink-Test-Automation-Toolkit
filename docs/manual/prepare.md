# 준비 및 실행

Harness·입력·Assessment·Test Case를 만들고 테스트를 실행합니다. **모델과 Test
File을 실제로 바꾸므로 실행 전에 원본을 백업하십시오.**

standalone 제출물은 이 단계가 끝난 뒤 별도로 만듭니다.
[Standalone 실행](standalone-run.md)을 보십시오.

## 1. 기본 실행

```matlab
st_setup
st_pre_validate_targets
st_run_from_harness
```

처음이거나 대상 모델을 바꿀 때만 `st_select_target_model`을 사이에 넣습니다.

```matlab
st_setup
st_select_target_model
st_pre_validate_targets
st_run_from_harness
```

## 2. Harness가 이미 전부 있을 때

생성 단계를 건너뛰고 기존 Harness 매핑을 검증한 뒤 SLDV부터 진행합니다.

```matlab
st_setup
st_run_after_harness
```

## 3. 진행 순서

```text
HARNESS → SLDV → HARNESS_CONFIG → SIGNAL_EDITOR → ASSESSMENT
→ TEST_MANAGER → ALIGNMENT → EXECUTE
```

`AFTER_HARNESS`는 `HARNESS`를 생성하지 않습니다. `SLDV`라는 단계 이름에는 `OFF`와
`FILE` 대상의 입력 준비도 포함됩니다.

**Coverage Filter는 준비 단계가 아닙니다.** CVF는 실행하는 쪽이 만듭니다.

| 실행 방식 | CVF를 만드는 곳 |
| --- | --- |
| `BATCH` | `st_run_generated_tests`가 실행 직전에 |
| `PER_CUT` | `st_run_tests_per_cut`이 CUT 폴더 안에서 대상마다 |
| Standalone | 내보낸 번들 안에서. 물려받은 CVF는 `REPLACE` 정책으로 버립니다 |

필터 설정(`CoverageFilterMode` 등)은 `PERSIST`일 때 Test File에 기록되므로
`TEST_MANAGER` 지문에 들어갑니다. 설정을 바꿨으면 `TEST_MANAGER`부터 다시
돌리십시오.

## 4. 다시 실행할 때

각 단계가 성공하면 입력 지문을 `result/state/`에 저장하고, 다음 실행에서 입력이
그대로면 그 단계를 건너뜁니다.

캐시를 무시하고 처음부터 다시:

```matlab
st_run_from_harness('PreparationMode','FORCE');
```

특정 단계부터 다시:

```matlab
st_run_from_harness('PreparationMode','FORCE', 'FromStage','SLDV');
```

| 무엇이 바뀌었나 | `FromStage` |
| --- | --- |
| 입력 MAT 또는 SLDV 설정 | `SLDV` |
| Harness StopTime 등 설정 | `HARNESS_CONFIG` |
| verify 대상 또는 Assessment 구성 | `ASSESSMENT` |
| Coverage 필터 설정 | `TEST_MANAGER` |
| Test Case 이름 또는 Iteration | `TEST_MANAGER` |

checkpoint만 지우고 다시 판단하게 하려면:

```matlab
st_cleanup_results('Scope','STATE','Apply',true)
```

> **`FromStage`는 앞 단계를 "건너뛰라"는 뜻이 아닙니다.** 지정한 단계부터 강제로
> 다시 하라는 뜻이고, 그보다 앞 단계는 여전히 fingerprint로 판정됩니다. checkpoint가
> 없거나 모델이 바뀌었으면 앞 단계도 함께 실행됩니다. 평소에는 이것으로 충분하지만,
> 앞 단계 재실행을 확실히 막아야 하면 [재시작](restart.md)의 `st_run_from_stage`를
> 쓰십시오.

단계를 하나씩 끊어서 실행하고 결과를 확인하며 진행하려면
[단계별로 끊어서 실행하기](step-by-step.md)를 보십시오.

## 5. 실행 옵션

필요할 때만 씁니다. 적지 않으면 기본값이 쓰입니다.

```matlab
st_run_from_harness( ...
    'ExecutionMode', 'PER_CUT', ...
    'ContinueOnFailure', true, ...
    'ReportMode', 'SUMMARY', ...
    'FailOnNonPass', false);
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `ExecutionMode` | `AUTO` | 활성 CVF가 있으면 `PER_CUT`, 없으면 `BATCH`. 보통 그대로 둡니다 |
| `ExecuteTests` | `cfg.RunGeneratedTests` | `false`면 준비까지만 하고 실행하지 않습니다 |
| `ContinueOnFailure` | `true` | 한 CUT이 실패해도 다음을 계속 처리합니다 |
| `ReportMode` | `SUMMARY` | `FULL`은 PDF와 전체 Coverage HTML을 추가합니다 |
| `FailOnNonPass` | `false` | `true`면 통과하지 못한 Test Case가 있을 때 MATLAB 오류 |

준비만 하고 실행은 나중에 Test Manager에서 직접 하고 싶을 때:

```matlab
st_run_from_harness('ExecuteTests', false);
```

## 6. 결과 보기

```matlab
cfg = st_config();
winopen(cfg.LatestSummaryFile)
```

실행별 상세 결과는 `result/runs/`(BATCH) 또는 `result/per_cut_runs/`(PER_CUT)
아래에 있습니다.

## 7. 실패하면

단계별 결과는 `result/reports/`의 INI 파일에 있습니다. 확인 순서와 오류별 대처는
[문제 해결](../troubleshooting.md)에 정리되어 있습니다.
