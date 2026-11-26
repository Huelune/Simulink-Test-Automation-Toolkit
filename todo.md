# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 점검 함수 `st_todo_check` 하나만 부른다. pull한 뒤에는 명령 기록에서 블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 8. Test Manager에서 CVF를 넣어도 값이 안 바뀌는 이유 찾기

왜: 가져온 standalone 결과의 Results에서 Coverage Filters에 CUT별 CVF를 Add했는데 Aggregated Coverage Results 값이
바뀌지 않았다. 원인은 셋 중 하나로 본다. (1) CVF가 모델 단위 값에 들어가는 목표를 빼지 않는다. (2) Test Manager가 결과에 CVF를
붙이지 않았다. (3) CVF 규칙이 열린 standalone 모델의 블록을 찾지 못한다. 이 블록은 대상마다 다음을 찍는다. 파일은 바꾸지 않고,
Test Manager도 그대로 둔다.

- CVF 규칙 수와 종류, 모델에서 블록을 찾은 규칙 수
- 파이프라인이 저장한 커버리지(CVT)의 모델·CUT 값을 CVF 없이와 CVF를 걸고 각각
- Test Manager에 열린 결과의 같은 값과, 그 결과에 걸린 필터 가운데 이 CVF가 있는지

순서: CVF를 넣어 둔 Test Manager를 닫지 말고 그대로 둔다. 클론에서 main을 pull한 뒤 지난번 두 줄(`st_todo_check`를 부르는 것)을
명령 기록에서 다시 부르거나 아래에서 복사해 붙여 넣는다. 화면 첫 줄 끝에 `standalone CVF 효과 보기`가 있어야 이 절의 점검이다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

화면: 대상마다 `CVF`, `저장 CVT`, `Test Manager` 세 줄이 나온다. 값은 덮인 수/전체 수이고, 화살표 왼쪽이 CVF 없이, 오른쪽이 CVF를
건 값이다.

확인할 것: 특별히 맞춰 볼 값은 없다. 화면 그대로 돌려주면 된다.

돌려줄 것: 화면 캡처 한 장.
