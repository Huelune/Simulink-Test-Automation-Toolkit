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

## 2. 워크플로가 "Library-link Harness protection failed"로 멈춘 이유 확인

왜: 하네스 생성부터 다시 돌리려고 워크플로를 실행했더니 3개 대상 모두 Library-link Harness 보호 단계에서 실패했다. 이 단계는
Harness가 열려 있으면 바꾸지 않고 멈춘다. standalone 모델은 Harness와 이름이 같다. 그래서 1절이나 앞선 확인에서 연
standalone 모델이 열린 채로 남아 있으면, 툴킷은 Harness가 열려 있다고 보고 멈춘다. 이름이 Harness와 같은 모델이 몇 개
열려 있는지 세고, 저장 안 한 것이 없으면 모두 닫는다. 워크플로를 돌린 MATLAB에서 붙여 넣는다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
cfg = st_config(); targetRows = st_load_targets(cfg.OnlyEnabled);
loadedNames = string(find_system('type', 'block_diagram'));
fprintf('대상 %d | 지금 열린 모델 %d | 그중 Harness 이름과 같은 것 %d\n', height(targetRows), ...
    numel(loadedNames), sum(ismember(loadedNames, string(targetRows.HarnessName))));
dirtyCount = sum(strcmp(get_param(cellstr(loadedNames), 'Dirty'), 'on'));
if dirtyCount > 0
    fprintf('저장 안 한 모델 %d개: 저장할 것은 저장하고 나머지는 닫은 뒤 워크플로를 다시 돌려 주세요\n', dirtyCount);
else
    bdclose('all'); fprintf('열린 모델을 모두 닫았습니다. 워크플로를 다시 돌려 주세요\n');
end
warning(warnState);
```

확인할 것: "Harness 이름과 같은 것"이 0보다 크면 원인은 열린 standalone 모델이다. 닫은 뒤 워크플로를 다시 돌린다. 0이면
다른 원인이니 아래 "돌려줄 것"을 보낸다.

돌려줄 것: 화면 캡처 한 장. 워크플로를 다시 돌려도 같은 오류가 나면 그 화면도.
