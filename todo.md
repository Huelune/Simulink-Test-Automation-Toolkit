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

## 7. Harness 안 CUT의 입력선이 끊긴 이유 찾기

왜: 1단계 결과를 Test Manager에서 열어 들어간 Harness 안의 CUT에서, 한 블록으로 들어가는 입력선 여러 개가 끊어져(빨간 점선)
있었다. 원래 모델의 같은 CUT에서는 이어져 있다. DV(도달 불가 판정)는 원래 모델에서 돌아 영향이 없다. 하지만 시험 실행은 Harness에서
돌아서, 끊긴 입력은 0으로 들어갔다. 그래서 verify 결과, coverage(20/22, 45/45), 결함 Iteration의 Custom Criteria 판정이 원래
설계로 돌린 것과 다를 수 있다. 이 블록은 대상마다 원래 CUT과 Harness CUT에서 끊긴 선 끝을 세고, Harness에서만 끊긴 것을 종류별로
묶어 찍는다. Harness 동기화 설정도 찍는다. 모델은 저장하지 않는다.

순서: 클론에서 main을 pull한다. 지난번 두 줄(`st_todo_check`를 부르는 것)을 명령 기록에서 다시 불러도 되고, 아래에서 복사해도
된다. 열어 둔 모델과 Harness 화면은 닫힌다. 저장 안 한 모델이 있으면 멈춘다. 화면 첫 줄 끝에 `Harness CUT 비교`가 있어야 이 절의
점검이다. 6절의 눈 확인을 아직 안 했다면 이 블록 전에 한다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

화면: 대상(Excel 행 번호 `No`)마다 아래 줄들. 이름 대신 수, Simulink 블록 종류, 설정 값만 찍는다.

- `대상 n | 끊긴 선 끝 원래 CUT a | Harness CUT b | Harness에만 c`: 포트에 닿지 않은 선 끝의 수.
- `대상 n Harness 설정 | synchronizationMode ... | rebuildOnOpen ... | saveExternally ...`: Harness의 동기화 설정.
- 들여 쓴 줄: Harness에서만 끊긴 것을 종류별로 묶은 수.
  - `끊긴 입력 | 받는 <블록 종류> | 원래 보내는 <블록 종류> | 출력 포트 원래→Harness | 링크 원래→Harness`: 원래 모델에서는 어느
    종류의 블록이 이 입력을 보냈는지, 그 블록의 출력 포트 수와 라이브러리 링크 상태가 Harness에서 어떻게 다른지.
  - `받는 쪽 없음 | 보내는 <블록 종류>`: 보내는 쪽만 이어지고 받는 쪽이 끊긴 선.

확인할 것:

- `Harness에만`이 0보다 큰가. 0이면 지금 불러온 Harness는 원래와 같다. 그때는 화면에서 본 Harness가 어느 대상의 것이었는지 알려 달라.
- `출력 포트`가 원래와 Harness에서 다르면, Harness를 만들 때 보내는 블록의 포트 수가 바뀌어 선이 떨어진 것이다.
- 포트 수가 같은데 끊겼으면, Harness가 원래 모델보다 오래된 것일 수 있다. 설정 줄의 synchronizationMode를 본다.
- `링크`가 원래와 다르면(예: `resolved→inactive`), 라이브러리 링크 처리가 다른 것이다.
- `실패` 줄이 나오면 식별자를 본다. 진단 파일은 사용자 PC에서만 본다.

돌려줄 것: 화면 캡처 한 장.
