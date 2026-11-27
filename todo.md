# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 고른 클론을 먼저 pull하고(`git pull --ff-only`, 이어서 `rehash`) 점검 함수 `st_todo_check` 하나만 부른다. 명령 기록에서
블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
블록은 고른 툴킷 폴더에 머문다. 모델마다 클론이 있고, 툴킷은 현재 폴더의 `st_setup.m`을 먼저 보고 어느 클론인지 정한다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 22. 모델마다 처음부터 끝까지 다시 돌리기

왜: 21절로 standalone부터 팀 제출 트리까지 잘 되는 것을 확인했다. 이제 모델마다 처음부터 다시 돌린다. 블록에서 고른 클론의
모델과 `TestManagement.xlsx`로 돈다. 클론마다 한 번씩, 두 번 돌린다. 하는 일은 이렇다.

1. 단위 테스트를 돌린다. 실패가 있으면 아무것도 지우지 않고 멈춘다.
2. 열린 모델과 Test Manager를 닫고, 그 클론의 예전 결과를 지운다. `result/` 아래 생성물, 최종 문서·시험 사양서 Excel,
   standalone 실행 폴더, 팀 제출 트리가 대상이다. `result/logs`와 모델 고르기(`runtime_target.mat`)는 남긴다.
3. Excel 대상의 Harness와 Test File을 지우고 1단계(Harness 생성 → SLDV → 실행 → 결과 정리, PER_CUT)를 돌린다.
4. 3단계 standalone, 5단계 최종 문서, 4단계 팀 제출 트리를 만든다.

모델 자체(넣어 둔 Min/Max 포함)는 지우지 않는다. 지운 결과와 Harness는 되돌릴 수 없으니, 남겨 둘 결과는 먼저 다른 폴더로
복사한다. 오래 걸리므로 시간이 있을 때 돌린다.

**블록이 바뀌었다.** 이제 블록이 고른 클론에서 직접 `git pull`을 하고, MATLAB이 먼저 읽어 둔 예전 함수를 버리고 새로
읽게(`rehash`) 한 뒤 점검을 부른다. 지난번에 pull을 했는데도 클론 만들기 창이 뜬 것은 pull이 그 클론에 닿지 않았거나,
MATLAB이 같은 세션에서 먼저 읽어 둔 예전 점검 함수를 그대로 썼기 때문이다. pull이 실패하면 `git pull 실패`만 찍고 아무것도
돌리지 않는다. 이번에는 명령 기록의 예전 블록이 아니라 아래 블록을 복사해 붙여 넣는다. 다음부터는 이 블록을 명령 기록에서
다시 불러도 된다.

지난번(두 번째 모델의 클론)은 Harness를 지우다가 멈췄다. `HarnessName` 칸이 빈 대상이 있었기 때문이다. 그때는 예전 결과를
이미 지운 뒤였다. 이제는 아무것도 지우기 전에 Excel을 먼저 검사한다. `CUTName`, `HarnessName`, `TestCaseName`이 빈 대상과
`CUTPath`가 Subsystem이 아닌 대상을 종류별로 대상 번호와 함께 찍고 멈춘다. 그러면 그 클론의 `TestManagement.xlsx`에서 빈
칸을 채운다. 첫 번째 모델의 Excel처럼 대상마다 겹치지 않는 이름을 적으면 된다(설명서 2.4절). 고친 뒤 같은 블록을 다시
돌린다.

모델마다 이 순서로 한다.
1. 저장할 모델은 저장한다.
2. 아래 블록을 붙여 넣고, 툴킷 폴더 창에서 그 모델의 클론을 고른다. cmd에서 따로 pull하지 않아도 된다.
3. 화면 첫 줄 끝이 `처음부터 분류까지 다시 만들기`인지 본다. 다른 제목이면 그 화면을 캡처해 보낸다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); [pullStatus, ~] = system('set GIT_TERMINAL_PROMPT=0&& git pull --ff-only -q'); rehash; clear st_setup st_todo_check; if pullStatus, disp('git pull 실패 | cmd에서 이 클론 폴더로 가서 git pull을 해 보세요'); else, evalc('st_setup'); st_todo_check; end, end
```

확인할 것:

- 단위 테스트 실패가 0이고, `Excel 검사 | 대상 <수> | OK <수> | 실패 0`인가.
- `예전 결과 지움` 줄 아래에 `지우지 못함`이 없는가.
- `Harness 지움 <수> / 대상 <수>`, `1단계(FORCE, 결과 정리 포함) OK`, `시나리오 맞춤 OK <수> / 대상 <수>`에서 두 수가 같은가.
- `standalone 파이프라인 OK`, `standalone 점검 코드`가 모두 1인가, `5단계 최종 문서 OK`, `4단계 분류 OK`인가.
- 대상마다 `standalone` 줄과 `1단계` 줄이 하나씩 있는가.
- 멈추면 실패 줄의 식별자와 위치(툴킷 함수와 줄 번호)를 본다.

돌려줄 것: 모델마다 화면 캡처 한 장씩. 화면 끝에 `<수>줄 더 있음`이 나오면 그대로 캡처해 보내 준다.
