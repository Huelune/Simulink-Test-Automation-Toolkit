# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 점검 함수 `st_todo_check` 하나만 부른다. pull한 뒤에는 명령 기록에서 블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 6. 1단계 결과 정리가 CVF를 반영해 20/22를 내는지 확인하고, 결함 TC 남은 눈 확인 마치기

왜: 지난 진단으로 1단계 결과 정리의 0/0 원인 두 가지가 드러났다.

- 저장 결과의 coverage는 Harness가 열려 있으면 Harness의 CUT 경로에만 답한다(27/30). 결과 정리는 Top Model의 CUT 경로로 물어서
  아무 답도 받지 못했다. 결과 정리는 이제 Harness CUT 경로로 묻는다.
- CVF 규칙은 Harness 블록의 SID로 적혀 있어서, 16개 모두 아무것도 빼지 못했다. CUT 안 규칙을 Top Model CUT 블록의 SID로 다시 만들면
  standalone과 같은 20/22, 45/45가 나왔다. CVF 생성은 이제 CUT 안 규칙을 Top Model CUT의 블록으로 만든다.

이 블록은 결과 정리를 다시 하고 전후를 비교한다. 시뮬레이션은 하지 않고, 평소 결과 정리만큼 걸린다.

5절(standalone과 최종 문서)은 숫자가 모두 기대대로였다. 남은 것은 눈으로 볼 세 가지뿐이라 이 절에 옮겼다(아직 받지 못했다).

순서:

1. 블록을 붙여 넣기 전에, 열려 있는 화면에서 두 가지를 본다. 블록이 열린 모델을 닫으므로 먼저 본다. 이 화면들은 블록 이름이
   보이므로 캡처하지 않는다.
   - standalone 결과: Test Manager의 Results and Artifacts에서 가져온 standalone 결과 → 한 대상의 Test Case → 번호가 가장 큰
     Iteration(결함 Iteration) → Custom Criteria Results. `실행 횟수`가 든 검증이 실패로 나오면 `verify 실패`, 오류 메시지가
     나오면 `오류`. 결과가 없으면 `못 봄`.
   - 5절이 연 저장 Coverage 보고서(브라우저)의 Filter 항목에 뺀 것이 나오는지, standalone 모델에 Coverage 색이 칠해지고 하위
     Subsystem이 빠졌는지. 이미 닫았으면 `못 봄`.
2. 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다. 지난번 두 줄(`st_todo_check`를 부르는 것)을 명령 기록에서 다시 불러도
   되고, 아래에서 복사해도 된다. 열려 있는 모델 중 저장 안 한 것이 없을 때 붙여 넣는다. 툴킷 폴더를 고르는 창이 뜬다. 화면 첫
   줄 끝에 `결과 정리 다시 하기`가 있어야 이 절의 점검이다.
3. 블록이 끝나면 결과 정리가 다시 가져온 1단계 결과가 Test Manager에 들어와 있다. 1번과 같은 순서로 1단계 결함 Iteration의
   Custom Criteria Results를 본다. 결과가 없으면 `못 봄`.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

화면: 단위 테스트 한 줄, 결과 정리 다시 하기 한 줄, 결과 정리 로그 한 줄, Harness 이름 줄 여섯, CVF 복사 한 줄, 대상 행마다 한 줄.
대상은 Excel 행 번호(`No`)로만 적는다. `전`은 지난 결과 정리가 남긴 것(0/0), `후`는 이번에 다시 한 결과 정리다.

확인할 것:

- `단위 테스트 | 42`이고 실패·미완료가 0인가.
- `결과 정리 다시 하기 OK`인가. 아니면 식별자를 보고, 진단 파일에서 그 절의 첫 줄을 경로·이름 없이 말로 옮겨 달라.
- `CVF 복사`의 `후`가 0개 쪽 0인가.
- 대상마다 `CUT 결정 후 20/22`, `CUT 실행 후 45/45`인가(standalone 저장 Coverage와 같은 값).
- `결정 목록 후` 수가 0이 아닌가. CVF가 빼는 블록은 결정 목록에서도 빠진다.

돌려줄 것: 화면 캡처 한 장과 다음 세 줄. standalone Custom Criteria 결과 한 단어(`verify 실패`, `오류`, `못 봄`), 1단계 Custom
Criteria 결과 한 단어, "보고서에 필터 항목 나옴/안 나옴/못 봄, 모델 색 표시 됨/안 됨/못 봄". 진단 파일, Test Manager 결과
화면, 보고서와 모델 화면은 사용자 PC에서만 보고 밖으로 보내지 않는다.
