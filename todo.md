# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 재실행의 Iteration이 서로 다른 시나리오를 돌았는지 확인

왜: sldd 내용은 파이프라인 사본과 같았다. 그런데도 재실행은 CUT 결정 11/22이고 파이프라인은 20/22다. 패키지 단계는
standalone 모델 사본의 Signal Editor 입력 파일 이름을 바꿔 저장한다. 이때 시나리오 선택이 초기화되었다면, 세 Iteration이
모두 같은 시나리오만 돌아 덜 충족될 수 있다. Iteration마다 지정된 시나리오가 몇 가지인지 센다. 그리고 Iteration마다
CUT 결정 충족 수가 서로 다른지 본다. 이름은 찍지 않는다.
앞 절처럼 프로젝트를 열고 `RunPerTestCase`로 돌린 MATLAB에서 이어서 붙여 넣는다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
testFiles = sltest.testmanager.getTestFiles; allCases = getAllTestCases(testFiles(1));
resultSets = sltest.testmanager.getResultSets;
for t = 1:numel(pipeline.Targets)
    target = pipeline.Targets(t); cutPath = char(string(target.StandaloneCUTPath));
    caseIndex = find(string({allCases.Name}) == string(target.TestCaseName), 1);
    useScenarios = getProperty(allCases(caseIndex), 'UseSignalEditorScenarios');
    iterations = getIterations(allCases(caseIndex)); scenarioNames = strings(0, 1);
    for i = 1:numel(iterations)
        try, scenarioNames(end+1, 1) = string(getTestParam(iterations(i), 'SignalEditorScenario')); catch, end %#ok<SAGROW>
    end
    fprintf('대상 %d | 시나리오 사용 %d | Iteration %d | 시나리오 지정 %d개, 서로 다른 것 %d\n', t, useScenarios, ...
        numel(iterations), numel(scenarioNames), numel(unique(scenarioNames)));
    for k = 1:numel(resultSets)
        fileResults = getTestFileResults(resultSets(k));
        for f = 1:numel(fileResults)
            caseResults = getTestCaseResults(fileResults(f));
            suiteResults = getTestSuiteResults(fileResults(f));
            for s = 1:numel(suiteResults), caseResults = [caseResults, getTestCaseResults(suiteResults(s))]; end %#ok<AGROW>
            for c = 1:numel(caseResults)
                if string(caseResults(c).Name) ~= string(target.TestCaseName), continue; end
                iterationResults = getIterationResults(caseResults(c)); covered = nan(1, numel(iterationResults));
                for i = 1:numel(iterationResults)
                    try
                        cov = getCoverageResults(iterationResults(i));
                        if isa(cov, 'cv.cvdatagroup'), cov = getAll(cov); end
                        if iscell(cov), cov = cov{1}; end
                        cov.filter = char(string(target.PackagedCVF));
                        decision = decisioninfo(cov, cutPath); covered(i) = decision(1);
                    catch
                    end
                end
                fprintf('대상 %d 결과 %d | Iteration별 CUT 결정 충족 %s\n', t, k, mat2str(covered));
            end
        end
    end
end
warning(warnState);
```

확인할 것: "서로 다른 것"이 1이거나 Iteration별 충족 수가 모두 같으면, 세 Iteration이 같은 시나리오를 돈 것이다.
NaN이면 그 Iteration 결과에 Coverage가 따로 없는 것이다.

돌려줄 것: 화면 캡처 한 장.
