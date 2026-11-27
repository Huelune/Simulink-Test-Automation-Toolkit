# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 고른 클론을 먼저 pull하고(`git pull --ff-only`, 이어서 `rehash`) 점검 함수 `st_todo_check` 하나만 부른다. 명령 기록에서
블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
블록은 고른 툴킷 폴더에 머문다. 모델마다 클론이 있고, 툴킷은 현재 폴더의 `st_setup.m`을 먼저 보고 어느 클론인지 정한다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 29. 최종 문서와 팀 제출 트리만 다시 만들기

왜: 28절 결과에서 D 줄 표시 두 가지를 고쳤다. MinMax의 `[input 1]`은 이제 `[u1]`(MinMax가 고른 입력)로 나온다. If·Switch 같은
블록에서 참·거짓 어느 쪽도 지나지 않은 줄(`[-]`)은 D 목록에서 빠지고 D 번호가 다시 매겨진다. 필요한 기록은 28절 실행에
이미 있으므로 1단계는 다시 돌리지 않는다. 가장 최근 standalone 실행으로 5단계 최종 문서와 4단계 팀 제출 트리만 다시 만든다.

순서:
1. 최종 문서 Excel을 열어 두었으면 닫는다.
2. 아래 블록을 붙여 넣고, 툴킷 폴더 창에서 28절을 돌린 클론을 고른다. 블록이 그 클론을 먼저 pull한다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); [pullStatus, ~] = system('set GIT_TERMINAL_PROMPT=0&& git pull --ff-only -q'); rehash; clear st_setup st_todo_check; if pullStatus, disp('git pull 실패 | cmd에서 이 클론 폴더로 가서 git pull을 해 보세요'); else, evalc('st_setup'); st_todo_check(29); end, end
```

확인할 것:

- 단위 테스트 실패가 0이고 `5단계 최종 문서 OK`, `4단계 분류 OK`인가.
- 새 최종 문서에서 MinMax 줄이 `[u1]`처럼 나오고, `[-]`가 붙은 줄이 하나도 없으며, 각 행의 D 번호가 D1부터 빠짐없이 이어지는가.

돌려줄 것: 화면 캡처 한 장과, 위 두 가지가 맞는지 말로.
