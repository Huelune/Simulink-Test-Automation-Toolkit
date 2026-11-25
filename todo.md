# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 점검 함수 `st_todo_check` 하나만 부른다. pull한 뒤에는 명령 기록에서 블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 6. 결함 TC의 Custom Criteria 판정과 저장 Coverage 보고서 확인하기

왜: 1단계 결과 정리는 세 대상 모두 CUT 결정 20/22, 실행 45/45로 standalone 저장 Coverage와 같아졌다. standalone 모델의 끊긴
입력선도 고쳐졌다. 남은 것은 결함 Iteration의 FAIL이 설계대로 `실행 횟수` 검증이 실패한 것인지(판정 스크립트 오류가 아닌지)와, 저장
Coverage 보고서·모델 표시에 CVF가 반영됐는지다. 앞의 것은 이 블록이 결과를 읽어 숫자로 찍는다. 블록은 Test Manager를 비우고 최근
standalone 결과와 1단계 결과를 가져온다. 대상마다 저장 Coverage 보고서를 브라우저에 열고 standalone 모델에 Coverage 색을 칠한다.
시뮬레이션은 하지 않는다.

순서: 클론에서 main을 pull한다. 열려 있는 모델 중 저장 안 한 것이 없을 때, 지난번 두 줄(`st_todo_check`를 부르는 것)을 명령
기록에서 다시 부르거나 아래에서 복사해 붙여 넣는다. 화면 첫 줄 끝에 `결함 TC Custom Criteria`가 있어야 이 절의 점검이다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

화면: `단위 테스트`, `standalone 결과`, `1단계 결과 가져옴` 줄이 나온다. 이어서 대상(Excel 행 번호 `No`)마다 세 줄(결함 TC 수와 저장
Coverage, standalone 판정, 1단계 판정)이 나오고, 끝에 합계 줄이 나온다. 판정 줄은 결함 Iteration을 Custom Criteria 결과로 센다.
`verify 실패`는 `실행 횟수` 검증이 실패한 것(설계대로)이고, `오류`는 판정 스크립트가 오류를 낸 것이다. 그 밖의 종류가 있으면 이름과
수가 붙고, 오류 식별자나 검증 이벤트 이름도 같은 줄에 붙는다.

확인할 것:

- `단위 테스트 | 16`이고 실패·미완료가 0인가.
- `standalone 결과 IMPORTED`, `저장 Coverage 보고서 OK 3 실패 0`, `1단계 결과 가져옴 3 / 대상 3`인가.
- 대상마다 `결함 TC 2 | 저장 Coverage CUT 결정 20/22 실행 45/45`인가(다시 만든 결과물이 예전 숫자와 같은지).
- 대상마다 standalone과 1단계 줄이 `verify 실패 2 | 오류 0`이고 다른 종류가 붙지 않았는가.
- 눈으로: 브라우저에 열린 보고서의 Filter 항목에 뺀 것이 나오는가. standalone 모델에 Coverage 색이 칠해지고 하위 Subsystem이
  빠졌는가. 이 두 화면은 블록 이름이 보이므로 캡처하지 않는다.

돌려줄 것: 화면 캡처 한 장과 한 줄("보고서에 필터 항목 나옴/안 나옴, 모델 색 표시 됨/안 됨"). 보고서와 모델 화면, 오류 전문 파일은
사용자 PC에서만 보고 밖으로 보내지 않는다.
