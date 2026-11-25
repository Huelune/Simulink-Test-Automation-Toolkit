# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 점검 함수 `st_todo_check` 하나만 부른다. pull한 뒤에는 명령 기록에서 블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 7. standalone 파이프라인과 최종 문서를 결함 시나리오까지 다시 만들기

왜: 1단계는 결함 시나리오까지 다시 만들었고, 대상마다 시나리오·verify·Iteration이 5개다. 결함 Iteration 6개는 모두 Custom
Criteria가 결함 판정대로 실패시켰다(`verify 실패`). 그러나 standalone 파이프라인과 최종 문서는 시나리오가 3개이던 때 만든
것이다. 이 블록은 결함 판정 단위 테스트를 돌린 뒤 standalone 파이프라인(결과 저장)과 최종 문서를 다시 만든다. 이어서 standalone
결과를 Test Manager에 열고 저장된 Coverage 보고서를 브라우저에 띄운다. 그다음 두 실행의 결함 Iteration 판정을 센다. 시간이 걸린다.

순서: 저장 안 한 모델이 없게 한 뒤, 클론에서 main을 pull한다. 지난번 두 줄(`st_todo_check`를 부르는 것)을 명령 기록에서 다시
부르거나 아래에서 복사해 붙여 넣는다. 화면 첫 줄 끝에 `standalone·최종 문서 다시 만들기`가 있어야 이 절의 점검이다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

확인할 것:

- 단위 테스트가 모두 통과하고, `standalone 파이프라인 OK`, `최종 문서 OK`가 나온다.
- 대상마다 `standalone | Iteration 5 통과 3 실패 2 | verify 실패 2`가 나온다. `1단계` 줄도 같다.
- 마지막 줄 `합계 | 결함 TC 6 | verify 실패 standalone 6, 1단계 6`
- 열린 Test Manager에서 standalone 결과의 결함 Iteration을 열어 Custom Criteria Results에 실행 횟수 verify가 실패로 나오는지,
  Coverage 보고서의 Filter 항목과 standalone 모델 색 표시를 눈으로 본다.

돌려줄 것: 화면 캡처 한 장. 눈으로 본 것이 이상하면 어디가 이상했는지 말로 적어 준다(이름 없이).
