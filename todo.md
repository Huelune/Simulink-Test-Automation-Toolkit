# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 고른 클론을 먼저 pull하고(`git pull --ff-only`, 이어서 `rehash`) 점검 함수 `st_todo_check` 하나만 부른다. 명령 기록에서
블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
블록은 고른 툴킷 폴더에 머문다. 모델마다 클론이 있고, 툴킷은 현재 폴더의 `st_setup.m`을 먼저 보고 어느 클론인지 정한다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 26. C 헤더 폴더를 고르고 두 번째 모델을 처음부터 다시 돌리기

왜: 대상 1의 CUT은 C 코드가 쓰는 헤더(.h)를 찾지 못해 시뮬레이션 빌드가 실패했다(24절, `include 파일 없음`). 헤더 파일은
있다. 툴킷은 Windows 경로 길이 제한 때문에 짧은 임시 폴더에서 빌드하므로, 현재 폴더나 모델 폴더에 기대던 헤더를 찾지 못한다.
이제 툴킷이 헤더 폴더를 Harness와 standalone 사본의 Simulation Target `Include directories`에 절대 경로로 넣는다. 팀의 Top
Model은 바꾸지 않는다. 고른 폴더는 이 클론의 `runtime_target.mat`에 저장되어 다음 실행에도 쓰인다.

이 절의 점검은:
1. 단위 테스트를 돌린다.
2. 폴더 고르기 창을 띄운다. 헤더(.h)가 있는 폴더를 고른다. 헤더가 여러 폴더에 있으면 이 절을 끝낸 뒤 블록을 다시 돌려 하나씩
   더한다(고른 폴더는 쌓인다).
3. 22절처럼 처음부터 다시 만든다(예전 결과·Harness·Test File 지우고 1단계 → 3·5·4단계). 새 Harness는 고른 폴더를 가진다.

순서:
1. 저장할 모델은 저장한다.
2. 아래 블록을 붙여 넣는다. 끝이 `st_todo_check(26)`이라 명령 기록의 블록과 다르다. 툴킷 폴더 창에서 두 번째 모델의 클론을
   고르고, 다음 창에서 헤더 폴더를 고른다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); [pullStatus, ~] = system('set GIT_TERMINAL_PROMPT=0&& git pull --ff-only -q'); rehash; clear st_setup st_todo_check; if pullStatus, disp('git pull 실패 | cmd에서 이 클론 폴더로 가서 git pull을 해 보세요'); else, evalc('st_setup'); st_todo_check(26); end, end
```

확인할 것:

- 화면 첫 줄 끝이 `처음부터 분류까지 다시 만들기`이고, 그 아래 `C 헤더 폴더 | 1개 | 없는 폴더 0개`가 있는가.
- `1단계(FORCE, 결과 정리 포함) OK`, `시나리오 맞춤 OK 3 / 대상 3`, `standalone 파이프라인 OK`(이번에는 `PARTIAL`이 아니어야 함)
- `대상 1 | standalone ...`과 `대상 1 | 1단계 ...` 줄에 Iteration이 있고, 저장 Coverage가 실패하지 않는가.

돌려줄 것: 화면 캡처 한 장. 대상 1이 또 실패하면, 블록을 명령 기록의 것(끝이 `st_todo_check`)으로 다시 돌려 25절 화면을 보내
준다.

## 27. 최종 문서 분기 결과 표시의 단위 테스트 돌리기

왜: 최종 문서가 MinMax처럼 참/거짓이 아닌 블록도 그 행이 실제로 지난 결과만 적도록 바꿨다(지난 결과 없음 → D 목록에서
빠짐, 결함 줄은 `[u2 max]` 같은 짧은 형식). 모델은 건드리지 않고 그 단위 테스트 두 파일만 돌린다. 26절과 따로 돌려도 된다.

순서:
1. 클론에서 main을 pull한다(cmd에서 그 클론 폴더로 가서 `git pull`).
2. 아래 블록을 붙여 넣고, 툴킷 폴더 창에서 그 클론을 고른다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); evalc('st_setup'); st_todo_check(27); end
```

확인할 것:

- 두 파일 모두 `실패 0 | 미완료 0`이고 마지막 줄이 `모두 통과`인가.
- 실패가 있으면 실패한 테스트 이름과 오류 식별자가 한 줄씩 나온다. 전문은 임시 폴더의 `st_unit_tests.txt`에 있다.

돌려줄 것: 화면 캡처 한 장.
