# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 6. 1단계 결과 정리의 CVF가 CUT 전체를 빼는 규칙 찾기, 결함 TC 남은 눈 확인 마치기

왜: Harness 이름 문제는 풀렸다. 지난 화면에서 결과 정리가 끝까지 돌았고, 결과 정리가 연 Harness도 Harness로 판정됐다. CVF도
보고서의 coverage 객체 6개에 모두 붙었다. 그런데 CUT 결정과 실행이 모두 0/0, 결정 목록이 0이 됐다. CVF 없이 읽으면 27/30,
66/66이므로 CVF가 CUT 전체를 빼고 있다. 결과 정리의 CVF는 Harness에서 만들어, 규칙을 Harness 블록의 SID로 적는다. coverage는
Top Model의 CUT 경로로 읽는다. standalone은 모델 하나뿐이라 이 차이가 없고, 20/22가 나왔다. 짐작은 이렇다. 규칙이 Top Model에서
같은 SID 번호의 블록으로 풀리고, 그 블록이 CUT을 품고 있으면 CUT 전체가 빠진다. 아직 짐작이라, 이 블록은 한 대상의 저장 결과와
CVF로 규칙을 하나씩 걸어 보고 CUT을 비우는 규칙을 찾는다. 시뮬레이션도 결과 정리도 하지 않아 금방 끝난다.

지난 화면의 `대상 시작 후 39개`는 보고서 단계 줄까지 센 것이라 대상 줄만 세게 고쳤다. 단위 테스트 실패 1개는 CVF 수정 때 바뀐
인자 이름을 테스트가 따라가지 못한 것이라 고쳤다. 둘 다 다음 결과 정리 점검 때 확인된다.

5절(standalone과 최종 문서)은 숫자가 모두 기대대로였다. 남은 것은 눈으로 볼 세 가지뿐이라 이 절에 옮겼다(아직 받지 못했다).

순서:

1. 블록을 붙여 넣기 전에, 열려 있는 화면에서 두 가지를 본다. 블록이 열린 모델을 닫으므로 먼저 본다. 이 화면들은 블록 이름이
   보이므로 캡처하지 않는다.
   - standalone 결과: Test Manager의 Results and Artifacts에서 가져온 standalone 결과 → 한 대상의 Test Case → 번호가 가장 큰
     Iteration(결함 Iteration) → Custom Criteria Results. `실행 횟수`가 든 검증이 실패로 나오면 `verify 실패`, 오류 메시지가
     나오면 `오류`. 결과가 없으면 `못 봄`.
   - 같은 순서로 1단계 결과(지난번 결과 정리가 가져온 것)의 결함 Iteration을 본다. 결과가 없으면 `못 봄`.
   - 5절이 연 저장 Coverage 보고서(브라우저)의 Filter 항목에 뺀 것이 나오는지, standalone 모델에 Coverage 색이 칠해지고 하위
     Subsystem이 빠졌는지. 이미 닫았으면 `못 봄`.
2. 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다. 아래 두 줄을 이 파일에서 복사해 붙여 넣는다. 열려 있는 모델 중 저장
   안 한 것이 없을 때 붙여 넣는다. 툴킷 폴더를 고르는 창이 뜬다.

```matlab
clearvars; toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if ~isequal(toolkitDir, 0), oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir); st_probe_collect_cvf_rules; end
```

화면: 마지막 결과 정리의 첫 대상 하나를 본다. 이름 대신 개수, 종류, Simulink 블록 종류만 찍는다.

- `대상 n | coverage 객체 | CUT에 답하는 것`: Excel 행 번호(`No`)와, 저장 결과에서 꺼낸 coverage 객체 수.
- `coverage 객체 | analyzedModel | ownerModel | 이미 걸린 CVF`: CUT에 답하는 객체가 어느 모델 기준인지(Harness, Top Model, 기타,
  없음)와, 가져올 때 이미 걸려 있던 CVF 수.
- `CVF 없이`, `CVF 전체`: CUT 결정과 실행의 covered/total.
- `규칙 하나씩`: 규칙 하나만 건 CVF로 읽었을 때 CUT을 비운(0/0) 규칙, 줄인 규칙, 그대로인 규칙의 수.
- `규칙 SID의 모델`, `규칙 위치(Harness)`, `같은 번호의 Top Model 블록 위치`: 규칙 블록이 CUT 자신, CUT 안, CUT 위(CUT을 품음),
  CUT 밖, 없음 중 어디인지의 개수.
- `규칙 n | ...`: CUT을 비운 규칙마다 한 줄(없으면 줄인 규칙마다). 선택자 종류, 블록 종류, Harness에서의 위치, 같은 SID 번호의
  Top Model 블록 위치, 그 규칙만 걸었을 때의 숫자.

확인할 것:

- `CVF 없이`가 27/30, 66/66이고 `CVF 전체`가 0/0인가. 지난 화면과 같은 상황인지 보는 것이다.
- CUT을 비운 규칙이 있는가. 있으면 그 줄의 `Top 같은 번호:`가 `CUT 위`나 `CUT 자신`인지 본다. 그렇다면 짐작이 맞다.
- CUT을 비운 규칙이 없는데 `CVF 전체`가 0/0이면, 규칙이 함께 걸릴 때만 비는 것이다. 화면 그대로 보내 주면 된다.
- `실패` 줄이 나오면 단계와 식별자를 본다. 진단 파일은 사용자 PC에서만 본다.

돌려줄 것: 화면 캡처 한 장과 다음 세 줄. standalone Custom Criteria 결과 한 단어(`verify 실패`, `오류`, `못 봄`), 1단계 Custom
Criteria 결과 한 단어, "보고서에 필터 항목 나옴/안 나옴/못 봄, 모델 색 표시 됨/안 됨/못 봄". Test Manager 결과 화면, 보고서와
모델 화면은 사용자 PC에서만 보고 밖으로 보내지 않는다.
