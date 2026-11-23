# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 파이프라인이 저장한 Coverage를 CVF 적용 상태로 보기

왜: 다시 실행하면 파이프라인보다 덜 충족되는데, 원인을 아직 못 찾았다. 그래서 다시 실행하지 않는 방법을 넣었다.
`st_open_standalone_test_manager('ShowSavedCoverage', true)`는 파이프라인이 CUT마다 저장한 Coverage 원본(CVT)에 CVF를
걸어 보고서를 열고 모델에 Coverage를 색으로 표시한다. 시뮬레이션은 하지 않는다. 단위 테스트도 함께 돌린다.

순서: 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다. 열려 있는 모델 중 저장 안 한 것이 없을 때 아래 블록을 붙여
넣는다. 툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
evalc('testResults = runtests(fullfile(st_project_root(), ''tests'', ''unit'', ''test_open_standalone_test_manager.m''));');
fprintf('단위 테스트 %d | 통과 %d | 실패 %d\n', numel(testResults), sum([testResults.Passed]), sum([testResults.Failed]));
failedTests = testResults([testResults.Failed] | [testResults.Incomplete]);
for k = 1:numel(failedTests), fprintf('실패 | %s\n', failedTests(k).Name); end
loadedNames = find_system('type', 'block_diagram');
if any(strcmp(get_param(loadedNames, 'Dirty'), 'on')), fprintf('저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요\n'); warning(warnState); return; end
bdclose('all');
try
    evalc('openInfo = st_open_standalone_test_manager(''ClearTestManager'', true, ''ShowSavedCoverage'', true, ''View'', false);');
    saved = openInfo.SavedCoverage;
    fprintf('MATLAB %s | 대상 %d | 보고서 연 것 %d | 실패 %d\n', version('-release'), height(saved), sum(saved.Status == "OK"), sum(saved.Status ~= "OK"));
    for t = 1:height(saved)
        if saved.Status(t) == "OK"
            fprintf('대상 %d | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, saved.DecisionCovered(t), saved.DecisionTotal(t), saved.ExecutionCovered(t), saved.ExecutionTotal(t));
        else
            fprintf('대상 %d | 실패 | 식별자 %s\n', t, saved.ErrorId(t));
        end
    end
catch openError
    fprintf('열기 실패 | 식별자 %s\n', openError.identifier);
end
warning(warnState);
```

확인할 것: 단위 테스트 실패 0. 대상마다 CUT 결정 20/22, 실행 45/45(`CoverageSummary.xlsx`와 같은 값). 보고서가 브라우저에
열리고 Filter 항목에 뺀 것이 나오는지, 모델에 Coverage 색이 칠해지고 하위 Subsystem이 빠졌는지.

돌려줄 것: 화면 캡처 한 장과 "보고서에 필터 항목 나옴/안 나옴, 모델 색 표시 됨/안 됨" 한 줄. 보고서와 모델 화면은 블록
이름이 보이므로 캡처하지 마세요.

## 2. SLDV가 MaxProcessTime을 넘겨 멈추는 것이 커버리지 필터 때문인지 확인

왜: 처음부터 다시 돌린 워크플로가 SLDV 단계 첫 대상의 `sldvrun`에서 30분 넘게 끝나지 않았다(`MaxProcessTime=300 s`).
이 실행부터 SLDV에도 커버리지 필터(CovFilter)를 넘긴다. 이 필터를 실제 모델에서 쓴 것은 이번이 처음이다. 그래서 새
스위치 `cfg.SldvCoverageFilter = false`로 필터를 끄고 같은 단계를 돌려, 몇 분 안에 끝나는지 비교한다.

순서:

1. 돌고 있는 워크플로를 Ctrl+C로 멈춘다. 멈출 때까지 시간이 걸릴 수 있다. 멈추지 않으면 MATLAB을 끈다.
2. MATLAB을 다시 켜고 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다.
3. 툴킷 폴더의 `src\config\st_config.m`에서 `cfg.SldvCoverageFilter = true;`를 `false;`로 바꿔 저장한다.
4. 평소처럼 워크플로를 다시 실행한다. 이번에 멈췄던 명령을 그대로 쓴다.
5. SLDV 단계의 진행 줄(`[1/3] START` → `[1/3] OK` 또는 `FAIL`)에 찍히는 시각을 본다.

확인할 것: 필터를 끄고 대상마다 SLDV가 5~6분(300초 + 컴파일) 안에 끝나면, 필터가 원인이다. 필터를 꺼도 30분 넘게
걸리면 필터와 관계없는 다른 원인이다(그 모델이 원래 오래 걸리는 경우).

돌려줄 것: SLDV 단계의 진행 줄 화면 캡처 한 장(시각과 `[n/3] OK/FAIL`만 보이게). 끝나면 `st_config.m`의 값을 `true`로
되돌리지 말고 그대로 둔 채 알려 달라.
