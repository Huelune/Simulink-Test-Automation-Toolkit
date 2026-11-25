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

## 7. 입력선이 끊겨 보인 모델 찾기

왜: Test Manager에서 들어간 모델의 CUT 안에서 한 블록으로 들어가는 입력선 여러 개가 끊어져(빨간 점선) 보였다. 원래 모델의 같은
CUT에서는 이어져 있다. 지난 화면에서는 세 대상 모두 원래 CUT과 Harness CUT에 끊긴 선이 하나도 없었다. 그러니 그 화면은 Harness의 CUT
안이 아니었을 수 있다. 후보는 Harness의 CUT 바깥(입력을 CUT으로 넘기는 부분), 그리고 standalone 모델이다. standalone 모델은
Harness와 이름이 같아서, standalone 결과에서 들어가면 Harness처럼 보인다. 이 블록은 대상마다 원래 CUT, Harness 전체, standalone 모델
전체를 보고, 끊긴 선 끝을 CUT 안과 밖으로 나눠 센다. 모델은 저장하지 않는다.

순서: 클론에서 main을 pull한다. 지난번 두 줄(`st_todo_check`를 부르는 것)을 명령 기록에서 다시 불러도 되고, 아래에서 복사해도
된다. 열어 둔 모델과 Harness 화면은 닫힌다. 저장 안 한 모델이 있으면 멈춘다. 화면 첫 줄 끝에 `Harness CUT 비교`가 있어야 이 절의
점검이다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

화면: 대상(Excel 행 번호 `No`)마다 아래 줄들. 이름 대신 수, Simulink 블록 종류, 설정 값만 찍는다.

- `대상 n | 끊긴 선 끝 | 원래 CUT a | Harness CUT 안 b 밖 c | standalone CUT 안 d 밖 e`: 포트에 닿지 않은 선 끝의 수.
- `대상 n Harness 설정 | ...`: Harness의 동기화 설정(값 그대로).
- 들여 쓴 줄: 끊긴 것을 어디서(`Harness CUT 안/밖`, `standalone CUT 안/밖`) 무엇이 끊겼는지로 묶은 수.
  - `끊긴 입력 | 받는 <블록 종류> | 원래 보내는 <블록 종류> | 출력 포트 원래→복사본 | 링크 원래→복사본`: CUT 안에서 원래 모델과 다르게
    끊긴 입력.
  - `끊긴 입력 | 받는 <블록 종류>`: CUT 밖에서 끊긴 입력. 받는 쪽이 `CUT`이면 CUT의 입력 포트 자체가 비어 있는 것이다.
  - `받는 쪽 없음 | 보내는 <블록 종류>`: 보내는 쪽만 이어진 선.

확인할 것:

- 어느 칸이 0보다 큰가. 그곳이 끊긴 선을 본 모델이다.
- CUT 안에서 `출력 포트` 수가 원래와 다르면, 모델을 만들 때 보내는 블록의 포트 수가 바뀌어 선이 떨어진 것이다.
- 모두 0이면, 화면에서 본 모델이 어느 것이었는지(Test Manager의 어느 결과에서 어떻게 들어갔는지) 알려 달라.
- `실패` 줄이 나오면 식별자를 본다. 진단 파일은 사용자 PC에서만 본다.

돌려줄 것: 화면 캡처 한 장.
