# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 고른 클론을 먼저 pull하고(`git pull --ff-only`, 이어서 `rehash`) 점검 함수 `st_todo_check` 하나만 부른다. 명령 기록에서
블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
블록은 고른 툴킷 폴더에 머문다. 모델마다 클론이 있고, 툴킷은 현재 폴더의 `st_setup.m`을 먼저 보고 어느 클론인지 정한다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 24. 대상 1의 Test Assessment가 Tmax에 실행되는지 보기

왜: 23절 결과, 대상 1은 1단계와 standalone 모두 SLDV 시나리오의 verify 결과가 하나도 없었다(`verify 결과 없음(Tmax=0.04)`).
툴킷은 SLDV 입력을 쓸 때 Harness의 StopTime을 Tmax로 두고, Test Assessment가 step1에서 `after(Tmax, sec)`로 step2(verify)로
넘어가게 만든다. 그래서 verify는 마지막 시각 t=Tmax에 한 번만 돈다. Test Assessment가 그 시각에 실행되지 않으면(예: 실행 주기가
Tmax보다 길거나 Tmax가 주기의 배수가 아님) step2에 들어가지 못해 verify 결과가 아예 남지 않는다. 대상 1의 Tmax는 0.04초로
짧다. 이것이 맞는지 Harness를 컴파일해 숫자로 본다. 모델과 Harness는 저장하지 않고 닫는다.

순서: 저장할 모델은 저장한다. 같은 블록을 명령 기록에서 다시 불러 두 번째 모델의 클론을 고른다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); [pullStatus, ~] = system('set GIT_TERMINAL_PROMPT=0&& git pull --ff-only -q'); rehash; clear st_setup st_todo_check; if pullStatus, disp('git pull 실패 | cmd에서 이 클론 폴더로 가서 git pull을 해 보세요'); else, evalc('st_setup'); st_todo_check; end, end
```

확인할 것:

- 화면 첫 줄 끝이 `verify 시점 보기`인가.
- `대상 1 | SLDV ... | 시나리오 <수> | Tmax 0.04`
- `Harness | StopTime | 솔버 | FixedStep`, `step1→step2 after(...)`, `step2 verify <수>개`
- `컴파일 샘플 시간 | Test Assessment [주기 오프셋]`과 `Test Assessment가 t=Tmax에 실행됨 | 예/아니오`

돌려줄 것: 화면 캡처 한 장.
