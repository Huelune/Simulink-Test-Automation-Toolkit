# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 점검 함수 `st_todo_check` 하나만 부른다. pull한 뒤에는 명령 기록에서 블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 6. 결함 TC 남은 눈 확인(MATLAB 블록 없음)

왜: 1단계 결과 정리는 세 대상 모두 CUT 결정 20/22, 실행 45/45로 standalone 저장 Coverage와 같아졌다. standalone 모델의 끊긴
입력선도 고쳐져 다시 만든 결과물에서 0이었고, 번들 단위 테스트 51개도 모두 통과했다. 5절에서 옮겨 온 눈 확인 세 가지만 남았다.
돌릴 블록은 없다.

순서: 열려 있는 화면에서 본다. 이 화면들은 블록 이름이 보이므로 캡처하지 않는다.

- standalone 결과: Test Manager의 Results and Artifacts에서 가져온 standalone 결과 → 한 대상의 Test Case → 번호가 가장 큰
  Iteration(결함 Iteration) → Custom Criteria Results. `실행 횟수`가 든 검증이 실패로 나오면 `verify 실패`, 오류 메시지가
  나오면 `오류`. 결과가 없으면 `못 봄`.
- 같은 순서로 1단계 결과(지난번 결과 정리가 가져온 것)의 결함 Iteration을 본다. 결과가 없으면 `못 봄`.
- 저장 Coverage 보고서(브라우저)의 Filter 항목에 뺀 것이 나오는지, standalone 모델에 Coverage 색이 칠해지고 하위 Subsystem이
  빠졌는지. 이미 닫았으면 `못 봄`.

돌려줄 것: 다음 세 줄. standalone Custom Criteria 결과 한 단어(`verify 실패`, `오류`, `못 봄`), 1단계 Custom Criteria 결과 한
단어, "보고서에 필터 항목 나옴/안 나옴/못 봄, 모델 색 표시 됨/안 됨/못 봄". 화면은 사용자 PC에서만 보고 밖으로 보내지 않는다.
