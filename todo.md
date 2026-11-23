# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 자기 입력 MAT로 다시 돌려 파이프라인 커버리지와 맞는지 확인

왜: 앞 확인에서 세 대상 모두, path 맨 앞에 있는 입력 MAT가 패키지에 든 자기 것이 아니었다. 이름이 같은 다른 MAT로
돌아서 결정 커버리지가 11/22로 나왔다(파이프라인은 20/22). 이제 `RunPerTestCase`는 실행 직전에 그 대상 폴더를
path 맨 앞에 둔다. 그래도 자기 MAT가 아니면 그 Test Case를 실행하지 않는다. 다시 돌려 20/22가 나오는지 보고, 단위
테스트도 함께 돌린다. 먼저 클론에서 main을 pull한다. 실행하면 툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다.

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
dirtyCount = sum(strcmp(get_param(loadedNames, 'Dirty'), 'on'));
if dirtyCount > 0, fprintf('저장 안 한 모델 %d개: 저장하거나 닫은 뒤 다시 돌려 주세요\n', dirtyCount); warning(warnState); return; end
bdclose('all');
try
    evalc('openInfo = st_open_standalone_test_manager(''ClearTestManager'', true, ''LoadModels'', true, ''RunPerTestCase'', true);');
    runSummary = openInfo.RunSummary;
    fprintf('MATLAB %s | 대상 %d | 실행 OK %d | 오류 %d | 통과 %d | 실패 %d\n', version('-release'), height(runSummary), ...
        sum(runSummary.Status == "OK"), sum(runSummary.Status == "ERROR"), sum(runSummary.Passed), sum(runSummary.Failed));
catch openError
    fprintf('열기 실패 | 식별자 %s\n', openError.identifier);
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
        cvd = covObjects{j}; root = char(string(cvd.modelinfo.analyzedModel));
        try
            decision = decisioninfo(cvd, root); executed = executioninfo(cvd, root);
            fprintf('결과 %d-%d | 결정 %d/%d | 실행 %d/%d\n', k, j, decision(1), decision(2), executed(1), executed(2));
        catch infoError
            fprintf('결과 %d-%d | 지표 읽기 실패 | 식별자 %s\n', k, j, infoError.identifier);
        end
    end
end
sltest.testmanager.view; warning(warnState);
```

확인할 것: 단위 테스트 실패 0. 오류 0이고, 결과마다 결정 20/22·실행 45/45(파이프라인 `CoverageSummary.xlsx`와
같은 값)인지. 오류가 있으면 현재 폴더에 이름이 같은 MAT가 있는 것이니, 현재 폴더를 옮기고 다시 돌린다.

돌려줄 것: 화면 캡처 한 장.
