# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 점검 함수 `st_todo_check` 하나만 부른다. pull한 뒤에는 명령 기록에서 블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 6. Harness와 Test File을 지우고 결함 시나리오까지 처음부터 다시 만들기

왜: 결함 Iteration(004, 005)이 지금까지는 마지막 시나리오를 그대로 다시 써서, Signal Editor 시나리오와 Test Assessment
verify는 3개뿐이었다. 이제 결함마다 원본 시나리오를 복사한 같은 이름의 Signal Editor 시나리오와 Test Assessment 시나리오(verify)를
만든다. Iteration도 그 시나리오에 묶인다. 그래서 대상마다 시나리오와 verify가 5개씩 생겨야 한다. 확인을 위해 지금 있는 Harness와
Test File을 지우고 1단계를 처음부터 다시 돌린다.

이 블록이 하는 일:

1. 결함 시나리오 변경의 단위 테스트를 돌린다. 하나라도 실패하면 아무것도 지우지 않고 멈춘다.
2. Excel 대상 행이 가리키는 Harness만 지우고 모델을 저장한 뒤, Test File(.mldatx)을 닫고 지운다.
3. `st_run_from_harness('PreparationMode','FORCE','ExecutionMode','PER_CUT','AutoCollect',true)`로 1단계를 처음부터 돌린다
   (SLDV 분석, 실행, 결과 정리 포함). 평소 1단계를 처음부터 돌린 만큼 걸리고, 진행 줄이 보인다.
4. 끝나면 화면을 지우고 대상마다 시나리오 수와 판정을 숫자로 찍는다.

순서: 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다. 열려 있는 모델 중 저장 안 한 것이 없을 때, 지난번 두 줄
(`st_todo_check`를 부르는 것)을 명령 기록에서 다시 부르거나 아래에서 복사해 붙여 넣는다. 화면 첫 줄 끝에
`Harness·Test 처음부터 다시 만들기`가 있어야 이 절의 점검이다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

확인할 것:

- `단위 테스트 | 51`이고 실패·미완료가 0인가.
- `Harness 지움 3 / 대상 3 | Test File 지움 예`, `1단계(FORCE, 결과 정리 포함) OK`인가.
- 대상마다 `시나리오 SLDV+결함 5 | Signal Editor 5 | Test Assessment 5 | Iteration 5 | OK`인가.
- `1단계 결과 가져옴 3 / 대상 3`이고, 대상마다 `1단계 FINAL`(또는 `INITIAL`) 줄이 `결함 2: verify 실패 2 | 오류 0`인가.
  같은 줄의 `Iteration 5 통과 3 실패 2`는 보통 시나리오 3개가 통과하고 결함 2개가 실패한 것이다.
- 눈으로: Harness를 열어 Signal Editor의 시나리오 목록과 Test Assessment의 시나리오 목록에 004, 005가 있는지 본다. 이 화면은
  블록 이름이 보이므로 캡처하지 않는다.

돌려줄 것: 화면 캡처 한 장과 한 줄("Signal Editor·Test Assessment에 004, 005 있음/없음"). 오류 전문 파일은 사용자 PC에서만
보고 밖으로 보내지 않는다. standalone 제출물(3단계)과 저장 Coverage 보고서 확인은 이 결과를 본 뒤 다음 절로 한다.
