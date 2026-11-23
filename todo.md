# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. standalone 결과를 Test Case마다 자기 CVF로 실행해 보기

왜: 앞 확인에서 모델은 Test Case마다 제대로 돌았지만, 세 결과 모두에 3번 대상의 CVF가 걸려 있었다. Test Case들이
Coverage 설정 하나를 함께 써서, CVF를 차례로 걸면 마지막 것이 모두에게 남기 때문이다. 그래서 1·2번 결과는 아무것도
걸러지지 않았다. 새 옵션 `RunPerTestCase`는 Test Case마다 자기 CVF를 건 직후 따로 실행한다.

먼저 클론에서 main을 pull한다. 실행하면 툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다. 열려 있는 모델 중
저장 안 한 것이 없을 때만 모두 닫고, Test Manager의 Test File과 결과도 닫은 뒤 가장 최근 standalone 실행을 연다.
CUT 수만큼 시뮬레이션한다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
loadedNames = find_system('type', 'block_diagram');
dirtyCount = sum(strcmp(get_param(loadedNames, 'Dirty'), 'on'));
if dirtyCount > 0, fprintf('저장 안 한 모델 %d개: 저장하거나 닫은 뒤 다시 돌려 주세요\n', dirtyCount); warning(warnState); return; end
bdclose('all');
try
    evalc('openInfo = st_open_standalone_test_manager(''ClearTestManager'', true, ''LoadModels'', true, ''RunPerTestCase'', true);');
    runSummary = openInfo.RunSummary;
    fprintf('MATLAB %s | 대상 %d | 모델 %d | 실행 OK %d | CVF 없음 %d | 오류 %d | 통과 %d | 실패 %d\n', version('-release'), ...
        height(runSummary), numel(openInfo.LoadedModels), sum(runSummary.Status == "OK"), sum(runSummary.Status == "NO_CVF"), ...
        sum(runSummary.Status == "ERROR"), sum(runSummary.Passed), sum(runSummary.Failed));
catch openError
    fprintf('실패 | 식별자 %s\n', openError.identifier);
end
resultSets = sltest.testmanager.getResultSets;
for k = 1:numel(resultSets)
    pending = {getCoverageResults(resultSets(k))}; covObjects = {};
    while ~isempty(pending)
        item = pending{1}; pending(1) = [];
        if iscell(item), pending = [pending, item(:)']; %#ok<AGROW>
        elseif isa(item, 'cv.cvdatagroup'), pending = [pending, getAll(item)']; %#ok<AGROW>
        elseif isa(item, 'cvdata'), covObjects = [covObjects, num2cell(item(:)')]; end %#ok<AGROW>
    end
    for j = 1:numel(covObjects)
        cvd = covObjects{j}; root = char(string(cvd.modelinfo.analyzedModel)); savedFilter = cvd.filter;
        try
            withFilter = decisioninfo(cvd, root);
            cvd.filter = ''; withoutFilter = decisioninfo(cvd, root); cvd.filter = savedFilter;
            fprintf('결과 %d-%d | 결정: CVF 있음 %d/%d, CVF 없음 %d/%d\n', k, j, withFilter(1), withFilter(2), withoutFilter(1), withoutFilter(2));
        catch infoError
            cvd.filter = savedFilter;
            fprintf('결과 %d-%d | 지표 읽기 실패 | 식별자 %s\n', k, j, infoError.identifier);
        end
    end
end
sltest.testmanager.view; warning(warnState);
```

확인할 것: 결과가 대상 수만큼 따로 있고, 결과마다 "CVF 있음" 숫자가 "CVF 없음"과 다른지. Test Manager에서
결과마다 맨 위 Results 항목의 보고서에 필터로 뺀 항목이 나오고, 모델의 하위 Subsystem이 Coverage에서 빠졌는지.

돌려줄 것: 화면 캡처 한 장과 "보고서에 필터 항목 나옴/안 나옴" 한 줄. 블록 이름이 보이는 화면은 캡처하지 마세요.
