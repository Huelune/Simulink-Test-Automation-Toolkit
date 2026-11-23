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

## 2. st_config.m에서 바꾼 SldvCoverageFilter 되돌리고 pull

왜: 비교하려고 클론의 `src\config\st_config.m`에서 `cfg.SldvCoverageFilter`를 `false`로 직접 바꿨다. 이제 main에서 기본값이
`false`가 되었다. 직접 바꾼 줄이 남아 있으면 pull할 때 같은 줄이 충돌한다. 그래서 그 파일의 직접 바꾼 내용을 버리고 pull한다.
툴킷 클론 폴더에서 명령 프롬프트로 실행한다.

```cmd
git checkout -- src/config/st_config.m && git pull
```

확인할 것: 오류 없이 끝나는지. pull 뒤 `st_config.m`에 `cfg.SldvCoverageFilter = false;`가 있는지.

돌려줄 것: 오류가 나면 그 화면. 정상이면 "됨" 한 줄.

## 3. 파이프라인이 실제로 돌린 작업 공간 파일로 다시 돌려 보기

왜: Iteration에서 파라미터 덮어쓰기는 보이지 않았다(모두 0). 그래서 그 가설로는 설명이 안 된다. 이번에는 범위를 반으로 나눈다.
파이프라인은 실행 작업 공간에 있는 Test File과 standalone 모델로 돌렸고, 패키지 단계는 그것을 복사한 뒤 Signal Editor를 바꿔
저장했다. 작업 공간 원본으로 똑같이 돌린다. 그때 PASSED·20/22가 나오면 패키지 단계에서 무언가 바뀐 것이다. 그때도 Iteration 2가
실패하면 파이프라인 실행기만 하는 무언가가 있는 것이다.
Test Manager의 Test File과 결과를 닫는다. 저장 안 한 모델이 없을 때만 모든 모델을 닫고 시작한다. CUT 수만큼 시뮬레이션한다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
workFile = char(string(pipeline.TestManagerWorkFile));
fprintf('작업 공간 Test File 있음 %d\n', isfile(workFile));
if ~isfile(workFile), warning(warnState); return; end
loadedNames = find_system('type', 'block_diagram');
if any(strcmp(get_param(loadedNames, 'Dirty'), 'on')), fprintf('저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요\n'); warning(warnState); return; end
bdclose('all'); sltest.testmanager.clearResults; sltest.testmanager.clear;
workTestFile = sltest.testmanager.load(workFile); allCases = getAllTestCases(workTestFile);
oldGen = Simulink.fileGenControl('getConfig');
for t = 1:numel(pipeline.Targets)
    target = pipeline.Targets(t); cutPath = char(string(target.StandaloneCUTPath));
    workModel = char(string(target.StandaloneModelFile)); [~, modelName] = fileparts(workModel);
    fprintf('대상 %d 파이프라인 | 판정 %s | CUT 결정 %d/%d | CUT 실행 %d/%d | 작업 공간 모델 있음 %d\n', t, ...
        char(string(target.InitialOutcome)), target.DecisionCovered, target.DecisionTotal, target.ExecutionCovered, ...
        target.ExecutionTotal, isfile(workModel));
    freshFolder = tempname; mkdir(freshFolder); previousFolder = cd(freshFolder);
    try
        Simulink.fileGenControl('set', 'CacheFolder', freshFolder, 'CodeGenFolder', freshFolder, 'keepPreviousPath', true);
        addpath(fileparts(workModel), '-begin');
        caseIndex = find(string({allCases.Name}) == string(target.TestCaseName), 1);
        if isempty(caseIndex), fprintf('대상 %d | 작업 공간 Test File에 같은 이름의 Test Case 없음 (Test Case %d개)\n', t, numel(allCases)); error('stt:skip', 'skip'); end
        coverage = getCoverageSettings(allCases(caseIndex)); coverage.CoverageFilterFilename = char(string(target.PackagedCVF));
        evalc('workRun = run(allCases(caseIndex));');
        caseResults = getTestCaseResults(workRun); iterationOutcomes = '';
        for c = 1:numel(caseResults)
            iterationResults = getIterationResults(caseResults(c));
            for i = 1:numel(iterationResults), iterationOutcomes = [iterationOutcomes ' ' char(string(iterationResults(i).Outcome))]; end %#ok<AGROW>
        end
        fprintf('대상 %d 작업 공간 재실행 | 통과 %d | 실패 %d | 미완료 %d | Iteration:%s\n', t, ...
            workRun.NumPassed, workRun.NumFailed, workRun.NumIncomplete, iterationOutcomes);
        pending = {getCoverageResults(workRun)}; covObjects = {};
        while ~isempty(pending)
            item = pending{1}; pending(1) = [];
            if iscell(item), pending = [pending, item(:)']; %#ok<AGROW>
            elseif isa(item, 'cv.cvdatagroup'), pending = [pending, getAll(item)']; %#ok<AGROW>
            elseif isa(item, 'cvdata'), covObjects = [covObjects, num2cell(item(:)')]; end %#ok<AGROW>
        end
        if isempty(covObjects), fprintf('대상 %d 작업 공간 재실행 | Coverage 결과 없음\n', t); error('stt:skip', 'skip'); end
        cvd = covObjects{1}; cvd.filter = char(string(target.PackagedCVF));
        decision = decisioninfo(cvd, cutPath); executed = executioninfo(cvd, cutPath);
        fprintf('대상 %d 작업 공간 Coverage | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, decision(1), decision(2), executed(1), executed(2));
    catch workError
        if ~strcmp(workError.identifier, 'stt:skip'), fprintf('대상 %d | 실패 | 식별자 %s\n', t, workError.identifier); end
    end
    Simulink.fileGenControl('setConfig', 'config', oldGen); cd(previousFolder);
    if bdIsLoaded(modelName), close_system(modelName, 0); end
    rmpath(fileparts(workModel));
end
warning(warnState);
```

확인할 것: "작업 공간 재실행" 줄이 "파이프라인" 줄과 같은지(실패 0, 20/22, 45/45). 작업 공간 파일이 이미 지워졌으면 "있음 0"으로 나온다.

돌려줄 것: 화면 캡처 한 장.
