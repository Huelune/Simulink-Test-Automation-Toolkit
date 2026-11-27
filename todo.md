# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 고른 클론을 먼저 pull하고(`git pull --ff-only`, 이어서 `rehash`) 점검 함수 `st_todo_check` 하나만 부른다. 명령 기록에서
블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
블록은 고른 툴킷 폴더에 머문다. 모델마다 클론이 있고, 툴킷은 현재 폴더의 `st_setup.m`을 먼저 보고 어느 클론인지 정한다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 30. 결함 블록이 도달 불가인 이유 보기

왜: 결함 TC의 Switch와 MinMax 결과가 왜 도달할 수 없는지 다시 확인한다. 이 점검은 결함 블록마다 그 블록으로 들어오는
신호를 식으로 풀어 찍는다. 상수는 숫자, Delay 상태는 `D1`, CUT 입력은 `In1`처럼 적고 CUT 입력의 자료형과 Min/Max를 붙인다.
블록·신호 이름은 찍지 않는다. 모델은 바꾸지 않고 저장하지 않는다. 같은 로직의 결함은 한 줄로 줄인다.

순서:
1. 아래 블록을 붙여 넣고, 툴킷 폴더 창에서 28절을 돌린 클론을 고른다. 블록이 그 클론을 먼저 pull한다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); [pullStatus, ~] = system('set GIT_TERMINAL_PROMPT=0&& git pull --ff-only -q'); rehash; clear st_setup st_todo_check; if pullStatus, disp('git pull 실패 | cmd에서 이 클론 폴더로 가서 git pull을 해 보세요'); else, evalc('st_setup'); st_todo_check(30); end, end
```

확인할 것:

- `단위 테스트 실패`가 나오지 않고 `결함 <수>개 | 대상 <수>개`가 나오는가. 결함 수는 최종 문서의 FAIL 행 수(대상마다 2)와 같아야 한다.
- 결함마다 `선택 블록(...) = ...` 식과 `입력: In1=... ` 줄이 있는가. `읽기 실패`가 있으면 그 줄의 식별자를 본다.

돌려줄 것: 화면 캡처 한 장.
