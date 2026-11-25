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

## 7. standalone 모델의 입력선이 끊기는 이유 확인

왜: 지난 화면에서 끊긴 선은 standalone 모델에만 있었다. 세 대상 모두 standalone 모델의 CUT 바깥에서 SubSystem으로 들어가는 입력 5개가
끊겼다. 원래 CUT과 Harness에는 하나도 없었다. standalone 모델의 입력은 Signal Editor 블록이 준다. Signal Editor는 입력 파일 안의
신호 수만큼 출력 포트를 만든다. 패키징은 그 파일 이름을 폴더 없이 파일 이름만 적어 저장한다. 그래서 모델을 연 폴더나 MATLAB 경로에
따라 파일을 못 찾으면, 포트가 줄고 선이 떨어질 수 있다. 짐작이라서, 이 블록은 대상마다 다음을 함께 본다.

- Harness와 standalone의 Signal Editor 출력 포트 수
- standalone의 파일 이름이 그대로, MATLAB 경로에서, 모델 폴더에서 찾아지는지
- 모델 폴더에서 다시 열면 끊긴 선이 사라지는지

모델은 저장하지 않는다.

순서: 클론에서 main을 pull한다. 지난번 두 줄(`st_todo_check`를 부르는 것)을 명령 기록에서 다시 불러도 되고, 아래에서 복사해도
된다. 열어 둔 모델과 Harness 화면은 닫힌다. 저장 안 한 모델이 있으면 멈춘다. 화면 첫 줄 끝에 `Harness CUT 비교`가 있어야 이 절의
점검이다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

화면: 대상(Excel 행 번호 `No`)마다 아래 줄들. 이름 대신 수, Simulink 블록 종류, 설정 값만 찍는다.

- `대상 n | 끊긴 선 끝 | 원래 CUT a | Harness CUT 안 b 밖 c | standalone CUT 안 d 밖 e`: 포트에 닿지 않은 선 끝의 수. 지금 폴더에서
  standalone 모델을 연 결과다.
- `대상 n Harness 설정 | ...`: Harness의 동기화 설정(값 그대로).
- `대상 n standalone Signal Editor | 출력 포트 Harness x→standalone y | 파일 이름 상대/절대 | 그대로 O/X 경로 O/X 모델 폴더 O/X`
- `대상 n standalone 모델 폴더에서 열면 | 끊긴 선 끝 CUT 안 f 밖 g | Signal Editor 출력 포트 z`
- 들여 쓴 줄: 끊긴 것을 어디서 무엇이 끊겼는지로 묶은 수. standalone CUT 밖의 끊긴 입력은 Harness에서 그 입력을 보내는 블록 종류와,
  그 블록의 출력 포트 수(Harness→standalone)도 찍는다.

확인할 것:

- `출력 포트 Harness x→standalone y`에서 y가 x보다 작고, `모델 폴더에서 열면`의 `밖`이 0이고 출력 포트가 x로 돌아오면 짐작이 맞다.
  파일을 못 찾아 Signal Editor 포트가 준 것이다.
- `그대로`와 `경로`가 모두 X이면, 지금 폴더와 MATLAB 경로로는 그 파일을 찾을 수 없는 것이다.
- `실패` 줄이 나오면 식별자를 본다. 진단 파일은 사용자 PC에서만 본다.

돌려줄 것: 화면 캡처 한 장.
