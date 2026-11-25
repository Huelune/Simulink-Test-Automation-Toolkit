# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 점검 함수 `st_todo_check` 하나만 부른다. pull한 뒤에는 명령 기록에서 블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 6. 결함 TC 남은 눈 확인(MATLAB 블록 없음)

왜: 1단계 결과 정리는 세 대상 모두 CUT 결정 20/22, 실행 45/45로 standalone 저장 Coverage와 같아졌고, 단위 테스트 42개도 모두
통과했다. 5절에서 옮겨 온 눈 확인 세 가지만 남았다. 돌릴 블록은 없다.

순서: 열려 있는 화면에서 본다. 이 화면들은 블록 이름이 보이므로 캡처하지 않는다.

- standalone 결과: Test Manager의 Results and Artifacts에서 가져온 standalone 결과 → 한 대상의 Test Case → 번호가 가장 큰
  Iteration(결함 Iteration) → Custom Criteria Results. `실행 횟수`가 든 검증이 실패로 나오면 `verify 실패`, 오류 메시지가
  나오면 `오류`. 결과가 없으면 `못 봄`.
- 같은 순서로 1단계 결과(지난번 결과 정리가 가져온 것)의 결함 Iteration을 본다. 결과가 없으면 `못 봄`.
- 5절이 연 저장 Coverage 보고서(브라우저)의 Filter 항목에 뺀 것이 나오는지, standalone 모델에 Coverage 색이 칠해지고 하위
  Subsystem이 빠졌는지. 이미 닫았으면 `못 봄`.

돌려줄 것: 다음 세 줄. standalone Custom Criteria 결과 한 단어(`verify 실패`, `오류`, `못 봄`), 1단계 Custom Criteria 결과 한
단어, "보고서에 필터 항목 나옴/안 나옴/못 봄, 모델 색 표시 됨/안 됨/못 봄". 화면은 사용자 PC에서만 보고 밖으로 보내지 않는다.

## 7. 고친 standalone 파이프라인을 다시 돌려 입력선이 이어지는지 확인하기

왜: standalone 모델의 입력선이 끊긴 원인이 확정됐다. 실행 준비는 Signal Editor의 입력 파일 이름을 짧은 임시 작업 폴더의 경로로
저장하는데, 그 폴더는 실행이 끝나면 지워진다. 그래서 나중에 그 모델을 열면 Signal Editor가 파일을 못 찾아 포트가 1개로 줄고, 2~6번의
선이 떨어진다. 패키징은 그 상태에서 파일 이름만 바꿔 저장해, 제출용 패키징본에 끊긴 선이 남았다. 지난 화면의 재현 시험(파일을 지운
저장본을 열면 포트 1, 끊김 5)이 이를 확인했다. standalone 실행은 파일이 있을 때 돌았으므로 실행 결과(20/22 등)는 영향이 없다.

고친 것:

- 번들 실행기는 임시 폴더를 지우기 전에, standalone 모델의 입력 파일 이름을 기록 위치의 같은 파일로 바꿔 저장한다.
- 패키징은 입력 파일 이름을 바꾼 뒤 최상위에 출발점 없는 선이 있으면, 저장하지 않고 `StandalonePackageLinesDetached`로 멈춘다.

지금 있는 패키징본은 이미 끊긴 채 저장돼 있으므로 standalone 파이프라인을 다시 돌려야 한다. 이 블록은 번들·파이프라인 단위 테스트를
돌린다. 이어서 standalone 파이프라인과 최종 문서를 다시 만들고(5절과 같은 명령), 새 결과물의 끊긴 선을 센다. 평소 standalone
파이프라인만큼 걸린다.

순서: 클론에서 main을 pull한다. 열려 있는 모델 중 저장 안 한 것이 없을 때, 지난번 두 줄(`st_todo_check`를 부르는 것)을 명령
기록에서 다시 부르거나 아래에서 복사해 붙여 넣는다. 화면 첫 줄 끝에 `Harness CUT 비교`가 있고, 그 아래에 `단위 테스트`와
`standalone 파이프라인` 줄이 있어야 이 절의 점검이다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

화면: `단위 테스트`, `standalone 파이프라인`, `최종 문서` 줄이 나온 뒤, 대상(Excel 행 번호 `No`)마다 지난번과 같은 줄들이 나온다.

확인할 것:

- `단위 테스트 | 51`이고 실패·미완료가 0인가.
- `standalone 파이프라인 OK`와 `최종 문서 OK`인가. 파이프라인이 `StandalonePackageLinesDetached`로 멈췄다면 고친 것이 듣지 않은 것이다.
- 대상마다 `standalone CUT 안 0 밖 0`인가.
- `단계별` 줄이 `실행용 복사본 0(포트 6, 파일 O) | 패키징본 0`인가.

돌려줄 것: 화면 캡처 한 장. 다시 만든 결과물이 5절 때와 같은 숫자인지는 이 화면으로 보지 않는다. 필요하면 다음 절로 따로 본다.
