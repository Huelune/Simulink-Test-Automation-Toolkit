# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. Iteration에 Signal Editor 시나리오를 지정하면 파이프라인 커버리지가 나오는지 확인

왜: 재실행의 세 Iteration은 CUT 결정 충족 수가 모두 11로 같았다. 입력이 Iteration마다 바뀌지 않은 것이다. Iteration에는
Test Sequence 시나리오만 지정되어 있고 Signal Editor 시나리오는 지정되어 있지 않았다(0개). 그래서 Signal Editor는 모델에
저장된 한 시나리오만 재생한다. 툴킷은 원래 Iteration마다 두 시나리오에 같은 이름을 넣는다. 이번에는 메모리에서만 각
Iteration에 Test Sequence 시나리오와 같은 이름을 Signal Editor 시나리오로 넣고 다시 돌린다. 저장은 하지 않는다. 함께
Signal Editor 블록의 시나리오 수도 센다. 앞 절처럼 프로젝트를 열고 `RunPerTestCase`로 돌린 MATLAB에서 이어서 붙여 넣는다.
CUT 수만큼 다시 시뮬레이션한다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
testFiles = sltest.testmanager.getTestFiles; allCases = getAllTestCases(testFiles(1));
runFolder = fullfile(tempdir, 'st_open_standalone_run'); if ~isfolder(runFolder), mkdir(runFolder); end
previousFolder = cd(runFolder);
for t = 1:numel(pipeline.Targets)
    target = pipeline.Targets(t); cutPath = char(string(target.StandaloneCUTPath));
    [~, modelName] = fileparts(char(string(target.PackagedStandaloneModel)));
    try
        editorBlock = st_find_signal_editor_block(modelName);
        scenarioCount = numel(st_normalize_options(get_param(editorBlock, 'options@ActiveScenario')));
        addpath(char(string(target.OutputDirectory)), '-begin');
        caseIndex = find(string({allCases.Name}) == string(target.TestCaseName), 1);
        iterations = getIterations(allCases(caseIndex)); assigned = 0;
        for i = 1:numel(iterations)
            sequenceScenario = st_specification_parameter(iterations(i).TestParams, {'TestSequenceScenario'});
            if strlength(sequenceScenario) == 0, continue; end
            setTestParam(iterations(i), 'SignalEditorScenario', char(sequenceScenario)); assigned = assigned + 1;
        end
        coverage = getCoverageSettings(allCases(caseIndex)); coverage.CoverageFilterFilename = char(string(target.PackagedCVF));
        evalc('scenarioRun = run(allCases(caseIndex));');
        pending = {getCoverageResults(scenarioRun)}; covObjects = {};
        while ~isempty(pending)
            item = pending{1}; pending(1) = [];
            if iscell(item), pending = [pending, item(:)']; %#ok<AGROW>
            elseif isa(item, 'cv.cvdatagroup'), pending = [pending, getAll(item)']; %#ok<AGROW>
            elseif isa(item, 'cvdata'), covObjects = [covObjects, num2cell(item(:)')]; end %#ok<AGROW>
        end
        cvd = covObjects{1}; cvd.filter = char(string(target.PackagedCVF));
        decision = decisioninfo(cvd, cutPath); executed = executioninfo(cvd, cutPath);
        fprintf('대상 %d | Signal Editor 시나리오 %d개 | 지정한 Iteration %d | 통과 %d | 실패 %d | CUT 결정 %d/%d | CUT 실행 %d/%d\n', ...
            t, scenarioCount, assigned, scenarioRun.NumPassed, scenarioRun.NumFailed, decision(1), decision(2), executed(1), executed(2));
    catch scenarioError
        fprintf('대상 %d | 실패 | 식별자 %s\n', t, scenarioError.identifier);
    end
end
cd(previousFolder); warning(warnState);
```

확인할 것: CUT 결정이 20/22, 실행이 45/45로 나오면 원인은 Iteration에 Signal Editor 시나리오가 빠진 것이다.
"Signal Editor 시나리오" 수가 1이면 입력 파일에 시나리오가 하나뿐인 것이다.

돌려줄 것: 화면 캡처 한 장.
