# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 고른 클론을 먼저 pull하고(`git pull --ff-only`, 이어서 `rehash`) 점검 함수 `st_todo_check` 하나만 부른다. 명령 기록에서
블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
블록은 고른 툴킷 폴더에 머문다. 모델마다 클론이 있고, 툴킷은 현재 폴더의 `st_setup.m`을 먼저 보고 어느 클론인지 정한다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 25. 대상 1의 C 코드(Custom Code) 설정 보기

왜: 24절 결과, 대상 1의 Harness는 1단계와 같은 짧은 빌드 폴더에서도 컴파일이 실패했다(`Simulink:cgxe:BuildError`,
`Simulink:cgxe:SymbolicLinkErrorCause`, 종류 `include 파일 없음`). 시뮬레이션을 빌드할 때 C 헤더(.h)를 찾지 못한다는 뜻이다.
그래서 Iteration이 verify 전에 실패하고, verify 결과가 하나도 남지 않았다. 대상 2와 3은 같은 모델에서 빌드가 되므로 대상 1의
CUT만 C 코드를 쓰는 것으로 보인다. Simulink는 Simulation Target의 상대 include 경로를 모델 폴더에서 찾고, 다음으로 include
폴더와 MATLAB 경로를 찾는다. 헤더를 못 찾는 이유를 숫자로 가린다. 모델은 저장하지 않고 닫는다.

화면에 찍는 것:
- 대상 1 CUT 안에서 C 빌드가 필요한 블록 수: C Caller, C Function, S-Function(MEX 있음), MATLAB Function, Stateflow 차트,
  Model 참조, 라이브러리 링크
- Top Model, Harness, (CUT가 라이브러리 링크면) 라이브러리의 Custom Code 설정: 헤더 코드·소스 코드가 있는지, include 폴더와
  소스와 라이브러리 수, 그중 없는 것 수
- Top Model과 Harness 사이에 다른 설정 이름(예: `SimUserIncludeDirs`)
- Top Model 헤더 코드가 `#include`하는 헤더 수와 찾은 수
- MATLAB 프로젝트가 열려 있는지, 모델 폴더와 그 위 .prj 수
- Top Model 자체가 짧은 폴더에서 컴파일되는지

순서: 저장할 모델은 저장한다. 같은 블록을 명령 기록에서 다시 불러 두 번째 모델의 클론을 고른다. Top Model 컴파일이 있어 몇 분
걸릴 수 있다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), cd(toolkitDir); [pullStatus, ~] = system('set GIT_TERMINAL_PROMPT=0&& git pull --ff-only -q'); rehash; clear st_setup st_todo_check; if pullStatus, disp('git pull 실패 | cmd에서 이 클론 폴더로 가서 git pull을 해 보세요'); else, evalc('st_setup'); st_todo_check; end, end
```

확인할 것: 화면 첫 줄 끝이 `C 코드 설정 보기`인가. 나머지는 숫자 그대로 보내 준다.

돌려줄 것: 화면 캡처 한 장. 팀에서 이 모델을 돌릴 때 따로 여는 프로젝트나 경로 설정이 있는지 알게 되면 말로 알려 준다.
