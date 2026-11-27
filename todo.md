# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 고른 클론을 먼저 pull하고(`git pull --ff-only`, 이어서 `rehash`) 점검 함수 `st_todo_check` 하나만 부른다. 명령 기록에서
블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
블록은 고른 툴킷 폴더에 머문다. 모델마다 클론이 있고, 툴킷은 현재 폴더의 `st_setup.m`을 먼저 보고 어느 클론인지 정한다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 28. 결과물을 모두 지우고 처음부터 다시 만들기

왜: 최종 문서가 MinMax 같은 참/거짓이 아닌 블록도 그 행이 실제로 지난 결과만 적게 바뀌었다(지나지 않은 블록은 D 목록에서
빠짐). 이 기록은 1단계 결과를 만들 때 모이므로 예전 결과로는 보이지 않는다. 그래서 만든 것을 모두 지우고 다시 만든다.

이 절의 점검(`st_rebuild_all`)은:
1. 단위 테스트를 돌린다. 실패가 있으면 아무것도 지우지 않고 멈춘다.
2. 열린 모델과 Test Manager를 닫고 이전 실행의 결과를 지운다(`result/` 아래 생성물, 최종 문서·시험 사양서 Excel,
   standalone 실행 폴더와 팀 제출 트리).
3. Excel 대상의 Harness를 지우고 Top Model을 저장한 뒤, 그 Harness들의 입력(`<Harness 이름>_HarnessInputs*.mat`)과
   Test File을 지운다. Harness 입력은 클론 폴더와 모델 폴더에서 찾는다. 다른 이름의 파일과 Excel에 적은 데이터 파일은
   지우지 않는다.
4. 1단계(Harness 생성 → SLDV → 실행 → 결과 정리, PER_CUT)를 돌리고 3단계 standalone, 5단계 최종 문서, 4단계 팀 제출
   트리를 만든다.

남기는 것: 모델 자체(입력 Min/Max 포함), `TestManagement.xlsx`, `result/logs`, 모델 고르기와 C 헤더 폴더
(`runtime_target.mat`). 지운 것은 되돌릴 수 없으니 남겨 둘 결과는 먼저 다른 폴더로 복사한다. 오래 걸린다.

순서:
1. 저장할 모델은 저장한다.
2. 아래 블록을 붙여 넣고, 툴킷 폴더 창에서 다시 만들 모델의 클론을 고른다. 블록이 그 클론을 먼저 pull한다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); [pullStatus, ~] = system('set GIT_TERMINAL_PROMPT=0&& git pull --ff-only -q'); rehash; clear st_setup st_todo_check; if pullStatus, disp('git pull 실패 | cmd에서 이 클론 폴더로 가서 git pull을 해 보세요'); else, evalc('st_setup'); st_todo_check(28); end, end
```

확인할 것:

- 단위 테스트 실패가 0이고, `Harness 지움 <수> / 대상 <수> | Harness 입력 지움 <수> | Test File 지움 예`에서 앞의 두 수가
  같은가. Harness 입력 지움 수는 대상 수 이상이어야 한다(0이면 예전 입력이 다른 폴더에 있었다는 뜻이니 알려 준다).
- `1단계(FORCE, 결과 정리 포함) OK`, `시나리오 맞춤 OK <수> / 대상 <수>`의 두 수가 같은가.
- `standalone 파이프라인 OK`, `5단계 최종 문서 OK`, `4단계 분류 OK`인가.
- 최종 문서에서 정상 TC의 MinMax 줄이 `[T/F]`가 아니라 `[u1 max]`처럼 나오고, 결함 TC의 줄이 `[u2 max]`처럼 나오는가.
- 멈추면 마지막 줄의 안내를 따른다. 오류 전문은 임시 폴더의 `st_todo_check.txt`에 있다.

돌려줄 것: 화면 캡처 한 장과, 최종 문서의 MinMax 줄이 어떻게 나왔는지 말로(대괄호 안 글자만).
