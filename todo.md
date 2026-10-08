# MATLAB 실행 요청

작성: 2026-10-07. 결과를 붙여 주면 해당 절은 지운다.

## 1. 분기 결과 표기와 결정 단위 D 단위 테스트 (develop의 새 기능)

develop에만 있는 기능이다. 모델 프로젝트 안의 클론에서 develop을 받은 뒤
`st_setup`을 하고 실행한다.

```matlab
runtests({'test_decision_outcomes','test_export_final_document', ...
    'test_export_test_specification','test_specification_decision_blocks', ...
    'test_coverage_filters'})
```

실패한 테스트가 있으면 출력 전체를 붙인다.

### 1-1. "테스트 스위트를 만들 수 없습니다"로 멈출 때

2026-10-08 실행에서 `test_decision_outcomes`가 이 메시지로 멈췄다. 이 메시지는 진짜
원인을 감춘다. 아래를 돌려 원인 전체와 클론의 커밋을 찍는다. 저장소는 바꾸지 않는다.

```matlab
%% 1-1. 스위트 생성 실패 원인 찍기
system(sprintf('git -C "%s" log -1 --oneline', st_project_root()));
f = which('test_decision_outcomes');
disp("file=" + f);
try
    s = matlab.unittest.TestSuite.fromFile(f);
    disp("OK: " + numel(s) + " tests");
catch e
    disp(getReport(e, 'extended', 'hyperlinks', 'off'));
end
checkcode(f)
```

돌려줄 것: 출력 전체(커밋 한 줄, `file=` 경로, 오류 보고, `checkcode` 결과).

이번 변경과 무관하게 **이미 실패하던 테스트 두 개**가 있다. 이 둘이 실패해도 회귀가
아니며, 따로 고친다.

- `test_specification_decision_blocks/testScanReportsTheSubsystemNotThePortBlock`:
  지금 코드에 없는 `conditional_subsystems` 함수를 찾는다.
- `test_specification_decision_blocks/testCatalogHidesOnlySwitchCaseExpressionInTheMainCell`:
  `HIDE`가 SwitchCase 하나라고 가정하지만 catalog에는 CombinatorialLogic과
  Enable/Trigger/Reset도 `HIDE`다.

결과가 나오면 실제 모델로 최종 문서를 한 번 뽑아, Saturation이나 Discrete-Time
Integrator가 있는 CUT에서 결정마다 D가 나뉘고 `[T]`/`[F]`/`[T/F]`/`[-]`가 적히는지
본다. Discrete FIR Filter나 Discrete Transfer Fcn이 있으면 그 블록 줄도 함께 본다
(결정 이름을 실기로 확인하지 못한 블록이다).
