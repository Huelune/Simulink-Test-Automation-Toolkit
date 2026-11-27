# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 고른 클론을 먼저 pull하고(`git pull --ff-only`, 이어서 `rehash`) 점검 함수 `st_todo_check` 하나만 부른다. 명령 기록에서
블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
블록은 고른 툴킷 폴더에 머문다. 모델마다 클론이 있고, 툴킷은 현재 폴더의 `st_setup.m`을 먼저 보고 어느 클론인지 정한다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 23. 두 번째 모델의 대상 1이 실패한 이유 보기

왜: 22절(두 번째 모델) 결과는 이렇다.
- Excel 검사 대상 3개 OK, 1단계 OK, 시나리오 맞춤 3/3이었다.
- standalone은 `PARTIAL`이었다. 대상 1은 1단계 결과가 없고, standalone Iteration 1개가 실패했고, 저장 Coverage도 없다.
- 대상 2의 Coverage 0/0은 그 CUT에 Coverage를 세는 블록이 없어서 맞다(확인함).
- 대상 3은 정상이다.

첫 화면: 대상 1은 1단계 `EXCEPT`(처음·끝 `FAILED`, 실행 1번)였다. 오류 식별자는 1단계와 standalone 번들 모두
`simtest:PerCutVerifyTimingFailed`였다. SLDV 시나리오의 verify 결과가 시점 검사를 하나도 통과하지 못해, 기대값을 갱신하기 전에
그 대상을 멈춘 것이다. 같은 시각에 식별자 없는 ERROR가 3번 있었다. 이번에는 그 줄들이 어떤 종류인지(verify가 Untested로 남음,
verify 결과 없음, Iteration 결과 없음 등)와 그 수, Tmax도 같이 찍는다.

대상 1의 이유를 1단계 실행 기록과 로그에서 본다. 아무것도 돌리거나 바꾸지 않고 읽기만 한다. 로그의 메시지에는 모델·CUT
이름과 경로가 들어 있으므로, 화면에는 대상마다의 상태와 시각, PER_CUT 순번, 오류 식별자만 찍는다.

순서: 22절과 같은 블록을 명령 기록에서 다시 부르거나 아래에서 복사해 붙여 넣고, 툴킷 폴더 창에서 두 번째 모델의 클론을
고른다. 블록이 pull까지 한다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); [pullStatus, ~] = system('set GIT_TERMINAL_PROMPT=0&& git pull --ff-only -q'); rehash; clear st_setup st_todo_check; if pullStatus, disp('git pull 실패 | cmd에서 이 클론 폴더로 가서 git pull을 해 보세요'); else, evalc('st_setup'); st_todo_check; end, end
```

확인할 것:

- 화면 첫 줄 끝이 `대상 실패 이유 보기`인가.
- `대상 1` 줄의 1단계 상태(예: `EXCEPT`)와 처음·끝 결과.
- `1단계 로그 ERROR`, `3단계 로그 ERROR`, `standalone 번들 로그 ERROR` 아래 줄의 식별자와, `식별자 없음` 줄 뒤에 붙는 종류.

돌려줄 것: 화면 캡처 한 장. 고친 뒤 처음부터 다시 돌릴 때는 블록 끝의 `st_todo_check`를 `st_todo_check(22)`로 바꿔 쓴다
(그때 다시 적어 둔다).
