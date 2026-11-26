# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 점검 함수 `st_todo_check` 하나만 부른다. pull한 뒤에는 명령 기록에서 블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 9. standalone 결과 보기

왜: 가장 최근 standalone 제출물의 결과를 눈으로 본다. 사용 설명서 6단계와 같은 방법으로 연다. 콘솔에 찍히는 경로와 이름은
화면에 나오지 않게 했다. 이 블록이 여는 것:

- Test Manager: 먼저 열린 Test File과 Result를 모두 닫고, 파이프라인이 저장한 standalone Result를 가져온다. 이 Result의
  Coverage 값에는 CVF가 걸려 있지 않다(8절 결과).
- 브라우저: CUT마다 저장 커버리지에 CVF를 건 Coverage 보고서를 띄운다.
- 모델: standalone 모델을 열고 커버리지 색을 칠한다.

순서: 저장할 모델은 저장한다. 저장 안 한 모델이 있으면 아무것도 열지 않고 멈춘다. 지금 Test Manager에 손으로 넣은 필터는
닫히면서 없어진다. 클론에서 main을 pull한 뒤 지난번 두 줄(`st_todo_check`를 부르는 것)을 명령 기록에서 다시 부르거나 아래에서
복사해 붙여 넣는다. 화면 첫 줄 끝에 `standalone 결과 보기`가 있어야 이 절의 점검이다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

화면: 대상마다 한 줄로 Iteration 통과·실패 수와 CVF를 건 CUT 결정·실행 값을 찍는다. 열기에 실패하면 실패 이유의 식별자를
찍고, 오류 전문은 임시 폴더의 `st_todo_check.txt`에 쓴다.

확인할 것: Test Manager의 Result, 브라우저 보고서, 모델 색 표시를 눈으로 본다. 7절과 같다면 대상마다 Iteration 5(통과 3,
실패 2), CUT 결정 20/22, 실행 45/45다.

돌려줄 것: 화면 캡처 한 장. 눈으로 보다가 이상한 것이 있으면 이름 없이 말로 적어 준다.
