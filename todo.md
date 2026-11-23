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

## 3. Signal Editor 입력을 절대 경로로 바꾸면 재실행이 파이프라인과 같아지는지 확인

왜: 새 파이프라인은 대상 1이 PASSED·CUT 결정 20/22·실행 45/45인데, 6단계 재실행은 실패 1·11/22·41/45다. 재실행이 다르게 돈다.
파이프라인은 Signal Editor가 입력 MAT를 절대 경로로 가리킨 채 실행했다. 패키지할 때는 모델 사본의 Signal Editor를 파일 이름만으로
바꿔 저장한다. 파일 이름만 있으면 Test Manager가 Iteration마다 시나리오를 바꿀 때 파일을 못 찾고, 기본 시나리오 하나만 재생할 수
있다. 그러면 기대값 FAIL과 낮은 커버리지가 함께 설명된다. 이번에는 메모리에서만 Signal Editor를 패키지 입력의 절대 경로로 바꾸고
돌린다. 모델은 저장하지 않고, 끝나면 원래 값으로 되돌린다.
6단계를 돌린 MATLAB(standalone 모델과 Test File이 열려 있는 상태)에서 이어서 붙여 넣는다. CUT 수만큼 다시 시뮬레이션한다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
testFiles = sltest.testmanager.getTestFiles; allCases = getAllTestCases(testFiles(1));
runFolder = fullfile(tempdir, 'st_open_standalone_run'); if ~isfolder(runFolder), mkdir(runFolder); end
previousFolder = cd(runFolder);
for t = 1:numel(pipeline.Targets)
    target = pipeline.Targets(t); cutPath = char(string(target.StandaloneCUTPath));
    [~, modelName] = fileparts(char(string(target.PackagedStandaloneModel)));
    fprintf('대상 %d 파이프라인 | 판정 %s | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, char(string(target.InitialOutcome)), ...
        target.DecisionCovered, target.DecisionTotal, target.ExecutionCovered, target.ExecutionTotal);
    try
        editorBlock = st_find_signal_editor_block(modelName);
        oldFile = get_param(editorBlock, 'Filename'); wasDirty = get_param(modelName, 'Dirty');
        set_param(editorBlock, 'Filename', char(string(target.PackagedInput)));
        caseIndex = find(string({allCases.Name}) == string(target.TestCaseName), 1);
        coverage = getCoverageSettings(allCases(caseIndex)); coverage.CoverageFilterFilename = char(string(target.PackagedCVF));
        evalc('absRun = run(allCases(caseIndex));');
        set_param(editorBlock, 'Filename', oldFile); set_param(modelName, 'Dirty', wasDirty);
        pending = {getCoverageResults(absRun)}; covObjects = {};
        while ~isempty(pending)
            item = pending{1}; pending(1) = [];
            if iscell(item), pending = [pending, item(:)']; %#ok<AGROW>
            elseif isa(item, 'cv.cvdatagroup'), pending = [pending, getAll(item)']; %#ok<AGROW>
            elseif isa(item, 'cvdata'), covObjects = [covObjects, num2cell(item(:)')]; end %#ok<AGROW>
        end
        cvd = covObjects{1}; cvd.filter = char(string(target.PackagedCVF));
        decision = decisioninfo(cvd, cutPath); executed = executioninfo(cvd, cutPath);
        fprintf('대상 %d 절대 경로 재실행 | 통과 %d | 실패 %d | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, ...
            absRun.NumPassed, absRun.NumFailed, decision(1), decision(2), executed(1), executed(2));
    catch absError
        fprintf('대상 %d | 실패 | 식별자 %s\n', t, absError.identifier);
    end
end
cd(previousFolder); warning(warnState);
```

확인할 것: 대상마다 "절대 경로 재실행" 줄이 "파이프라인" 줄과 같아지는지(실패 0, CUT 결정 20/22, 실행 45/45).

돌려줄 것: 화면 캡처 한 장.
