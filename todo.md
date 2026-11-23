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

## 3. Top Model을 먼저 열어 두면 재실행이 파이프라인과 같아지는지 확인

왜: 작업 공간 파일은 파이프라인 실행기 밖에서는 아예 돌지 않았다(모두 Failed, Coverage 없음). 그래서 이 비교로는 범위를 나눌 수
없었다. 다른 차이를 본다. 파이프라인은 같은 MATLAB 세션에서 Top Model을 열었다가 진행한다. Top Model의 콜백(PreLoadFcn 등)은
열릴 때 base workspace에 변수를 만들 수 있다. standalone 모델이 그 변수를 쓰면 파이프라인에서는 그 값으로 돈다. 반면 재실행은
Top Model을 열지 않는다. 게다가 todo.md 블록이 모두 `clearvars`로 시작하므로 base workspace가 비어 있다. 그러면 standalone은 다른 값(sldd나
모델 기본값)으로 돌 수 있다. 이번에는 Top Model을 먼저 열고(콜백 실행), base workspace를 비우지 않은 채 재실행한다.
**이 블록은 `clearvars`로 시작하지 않는다.** 6단계를 돌린 MATLAB에서 붙여 넣는다. 저장 안 한 모델이 있으면 멈춘다.

```matlab
clc; diagWarn = warning('off', 'all');
diagCfg = st_config(); diagPipe = st_load_standalone_pipeline_manifest(diagCfg.StandaloneCoverageRootDir, 'LATEST');
diagLoaded = find_system('type', 'block_diagram');
if any(strcmp(get_param(diagLoaded, 'Dirty'), 'on')), fprintf('저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요\n'); warning(diagWarn); return; end
bdclose('all'); diagBaseBefore = numel(evalin('base', 'who'));
load_system(diagCfg.ModelFile);
diagCallbacks = ~isempty(get_param(diagCfg.TopModel, 'PreLoadFcn')) + ~isempty(get_param(diagCfg.TopModel, 'PostLoadFcn')) + ~isempty(get_param(diagCfg.TopModel, 'InitFcn'));
fprintf('Top Model 콜백 %d개 | base workspace 변수: 열기 전 %d, 연 뒤 %d | sldd 연결 %d\n', diagCallbacks, diagBaseBefore, ...
    numel(evalin('base', 'who')), ~isempty(get_param(diagCfg.TopModel, 'DataDictionary')));
diagFiles = sltest.testmanager.getTestFiles; diagCases = getAllTestCases(diagFiles(1));
diagGen = Simulink.fileGenControl('getConfig');
for diagT = 1:numel(diagPipe.Targets)
    diagTarget = diagPipe.Targets(diagT); diagCut = char(string(diagTarget.StandaloneCUTPath));
    fprintf('대상 %d 파이프라인 | 판정 %s | CUT 결정 %d/%d | CUT 실행 %d/%d\n', diagT, char(string(diagTarget.InitialOutcome)), ...
        diagTarget.DecisionCovered, diagTarget.DecisionTotal, diagTarget.ExecutionCovered, diagTarget.ExecutionTotal);
    diagFolder = tempname; mkdir(diagFolder); diagPrev = cd(diagFolder);
    try
        Simulink.fileGenControl('set', 'CacheFolder', diagFolder, 'CodeGenFolder', diagFolder, 'keepPreviousPath', true);
        addpath(char(string(diagTarget.OutputDirectory)), '-begin');
        diagIdx = find(string({diagCases.Name}) == string(diagTarget.TestCaseName), 1);
        diagCov = getCoverageSettings(diagCases(diagIdx)); diagCov.CoverageFilterFilename = char(string(diagTarget.PackagedCVF));
        evalc('diagRun = run(diagCases(diagIdx));');
        diagOut = ''; diagCR = getTestCaseResults(diagRun);
        for c = 1:numel(diagCR), diagIR = getIterationResults(diagCR(c)); for i = 1:numel(diagIR), diagOut = [diagOut ' ' char(string(diagIR(i).Outcome))]; end, end %#ok<AGROW>
        fprintf('대상 %d Top Model 연 뒤 재실행 | 통과 %d | 실패 %d | Iteration:%s\n', diagT, diagRun.NumPassed, diagRun.NumFailed, diagOut);
        diagPending = {getCoverageResults(diagRun)}; diagObjs = {};
        while ~isempty(diagPending)
            diagItem = diagPending{1}; diagPending(1) = [];
            if iscell(diagItem), diagPending = [diagPending, diagItem(:)']; %#ok<AGROW>
            elseif isa(diagItem, 'cv.cvdatagroup'), diagPending = [diagPending, getAll(diagItem)']; %#ok<AGROW>
            elseif isa(diagItem, 'cvdata'), diagObjs = [diagObjs, num2cell(diagItem(:)')]; end %#ok<AGROW>
        end
        if ~isempty(diagObjs)
            diagCvd = diagObjs{1}; diagCvd.filter = char(string(diagTarget.PackagedCVF));
            d = decisioninfo(diagCvd, diagCut); e = executioninfo(diagCvd, diagCut);
            fprintf('대상 %d Top Model 연 뒤 Coverage | CUT 결정 %d/%d | CUT 실행 %d/%d\n', diagT, d(1), d(2), e(1), e(2));
        end
    catch diagError
        fprintf('대상 %d | 실패 | 식별자 %s\n', diagT, diagError.identifier);
    end
    Simulink.fileGenControl('setConfig', 'config', diagGen); cd(diagPrev);
end
warning(diagWarn);
```

확인할 것: Top Model 콜백이 있거나 열고 나서 base workspace 변수가 늘었는지. 그리고 "Top Model 연 뒤 재실행"이 파이프라인과 같아졌는지
(실패 0, CUT 결정 20/22, 실행 45/45).

돌려줄 것: 화면 캡처 한 장.
