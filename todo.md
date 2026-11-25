# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록은 점검 함수 `st_todo_check` 하나만 부른다. pull한 뒤에는 명령 기록에서 블록을 다시 불러도 그때 할 점검이 돈다.
블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 6. 결함 Iteration의 Custom Criteria 결과를 읽는 길 찾기

왜: Harness와 Test File을 지우고 1단계를 처음부터 다시 돌린 결과, 세 대상 모두 SLDV+결함, Signal Editor, Test Assessment,
Iteration이 5개씩이었다. 판정은 Iteration 5개 중 통과 3, 실패 2였다. 결함 시나리오 004, 005는 만들어졌다. 그러나 결함 Iteration의
Custom Criteria 결과를 `getCustomCriteriaResult`로 읽으면 세 대상 모두 `MATLAB:unassignedOutputs`(결과를 돌려주지 않음)로
실패했다. 그래서 실패 2가 Custom Criteria 판정 때문인지 아직 모른다. 이 블록은 아무것도 실행하거나 지우지 않는다. 다음을 한 번에
읽는다.

- Test File의 Test Case에 Custom Criteria가 켜져 있고 툴킷의 결함 판정 스크립트인지
- 저장된 1단계 결과의 결함 Iteration 판정과 그 verify 결과(실패·통과·미판정 수)
- `getCustomCriteriaResult`를 결함 Iteration, 보통 Iteration, Test Case 결과에 각각 부른 결과
- Iteration 결과 객체에서 criteria가 들어간 속성·메서드 이름

지난번에는 준비 단계에서 `stm:general:LicenseCheck`(Simulink Test 라이선스 확인 실패)로 멈췄다. 이번에는 둘째 줄에 라이선스를
받았는지가 먼저 나온다. 준비 단계가 실패하면 어느 단계인지도 함께 나온다. Test File을 열지 못해도 저장된 결과는 계속 읽는다.

순서: 클론에서 main을 pull한 뒤, 지난번 두 줄(`st_todo_check`를 부르는 것)을 명령 기록에서 다시 부르거나 아래에서 복사해 붙여
넣는다. 이번 블록은 Harness를 지우지 않는다. 화면 첫 줄 끝에 `결함 Custom Criteria 결과 읽는 길 찾기`가 있어야 이 절의 점검이다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_todo_check; end
```

화면: 둘째 줄에 `라이선스 받기 | SIMULINK 예, Simulink_Test 예, Simulink_Coverage 예`처럼 나온다. 하나라도 `아니오`면 거기서
멈춘다. 다른 사람이 그 라이선스를 쓰는 중이면 기다렸다가, 아니면 MATLAB을 다시 연 뒤 돌린다. 그다음 대상마다 세 줄이 나온다. 첫 줄에는 기준 켜짐·표지, 결함 Iteration 수와 Failed 수, 그 verify 결과 수가 있다. 둘째 줄에는
Iteration에서 읽은 기준 결과가, 셋째 줄에는 Test Case 결과에서 읽은 기준 결과와 criteria 이름이 있다.

확인할 것: 특별히 맞춰 볼 값은 없다. 화면 그대로 돌려주면 된다.

돌려줄 것: 화면 캡처 한 장.
