# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).



## 1. PER_CUT 결과를 CVF 적용해 Test Manager에서 보기

왜: `result/per_cut_runs`의 `Results.mldatx`에는 CVF가 들어 있지 않다(바로 앞 확인에서 Coverage 6개 모두
CVF 없음). 그래서 파일만 열면 필터가 적용되지 않은 Coverage가 보인다. 새로 넣은
`st_collect_per_cut_results('Mode', 'VIEW')`는 CUT마다 결과를 가져와 `filter/`의 CVF를 메모리에서만
걸고 Test Manager를 연다. 보고서나 manifest는 쓰지 않는다.

먼저 클론에서 main을 pull한다. 실행하면 툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다.
가장 최근 PER_CUT 실행을 연다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
try
    evalc('viewInfo = st_collect_per_cut_results(''Mode'', ''VIEW'');');
    viewResult = viewInfo.Result;
    fprintf('MATLAB %s | CUT %d개 | 연 것 %d | 건너뛴 것 %d | CVF 없는 CUT %d\n', version('-release'), ...
        height(viewResult), viewInfo.CollectedCount, viewInfo.SkippedCount, sum(contains(viewResult.Message, 'no CVF')));
catch viewError
    fprintf('실패 | 식별자 %s\n', viewError.identifier);
end
warning(warnState);
```

확인할 것: Test Manager의 Results and Artifacts에 결과가 들어왔는지, 그 Coverage의 %가 CVF 없이 볼 때
(앞 절처럼 파일만 열었을 때)와 달라졌는지.

돌려줄 것: 화면 캡처 한 장과 Coverage %가 바뀌었는지 한 줄. Coverage 표는 블록 이름이 보이므로 캡처하지 마세요.
