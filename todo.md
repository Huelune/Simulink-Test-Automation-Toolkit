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

## 31. 팀 제출 트리를 골라 Test Manager에서 결과 보기

왜: 옮긴 팀 제출 트리(테스트 케이스·테스트 보고서·프로젝트)에서 마지막 단계인 Test Manager 결과를 보려고 한다. 지금까지 4단계
분류는 standalone 실행이 저장한 Test Manager 결과 파일(`StandaloneCoverageResults.mldatx`)을 트리에 넣지 않았다. 이제
`테스트 보고서` 안에 넣는다. 트리를 고르면 그 결과를 Test Manager로 가져와 보여 주고, CUT마다 `프로젝트`의 standalone 모델을
열어 CVF를 건 Coverage 보고서를 브라우저에 띄우고 모델에 색을 칠한다. 모두 트리 안의 파일만 쓰므로, 트리를 어디로 옮겨도 같다.
트리 안의 파일은 바꾸지 않는다.

이 절의 점검은:
1. 단위 테스트를 돌린다.
2. 가장 최근 standalone 실행의 트리를 다시 만든다. 결과 파일과 `result` 폴더의 가장 최근 최종 문서가 함께 들어간다. 실행은
   다시 하지 않는다.
3. 폴더 고르기 창을 띄운다. 2에서 만든 트리(결과 루트 안, 모델 이름 폴더)나 그 복사본을 고른다. 이미 다른 곳으로 옮겨 둔 예전
   트리에는 결과 파일이 없으니, 2에서 새로 만든 트리를 다시 복사해 쓴다.

순서:
1. 저장할 모델은 저장한다. 열린 모델과 Test Manager는 모두 닫힌다.
2. 아래 블록을 붙여 넣는다. 끝이 `st_todo_check(31)`이다. 툴킷 폴더 창에서 결과를 볼 모델의 클론을 고르고, 다음 창에서 트리를
   고른다. 두 모델 모두 보려면 클론마다 한 번씩 돌린다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); [pullStatus, ~] = system('set GIT_TERMINAL_PROMPT=0&& git pull --ff-only -q'); rehash; clear st_setup st_todo_check; if pullStatus, disp('git pull 실패 | cmd에서 이 클론 폴더로 가서 git pull을 해 보세요'); else, evalc('st_setup'); st_todo_check(31); end, end
```

확인할 것:

- 화면 첫 줄 끝이 `팀 제출 트리 결과 보기`이고, `4단계 분류 다시 | CUT <수> | Test Manager 결과 넣음 예`인가.
- `고른 폴더 | 팀 제출 트리 | CUT 폴더 <수> | Test Manager 결과 파일 있음`, `Test Manager 결과 가져옴 | Test Case <수>`
- Test Case마다 Iteration 통과·실패 수가 standalone 결과와 같은가.
- `CVF 적용 보고서 | OK <수> | 실패 0`, 그리고 Test Manager 창과 브라우저 보고서가 뜨는가.

돌려줄 것: 화면 캡처 한 장.

다음부터 직접 쓸 때는 `st_setup` 뒤에 `st_show_team_tree_results`만 부르면 된다. 인자 없이 부르면 트리를 고르는 창이 뜬다.
