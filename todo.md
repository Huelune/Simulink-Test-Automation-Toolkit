# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 실행할 때 CVF를 거는 것이 커버리지를 바꾸는지 확인

왜: 같은 CUT 기준으로 세어도 파이프라인 원본은 결정 20/22·실행 45/45이고, 재실행은 11/22·41/45다. 재실행이 실제로
다르게 돈 것이다. 모델 파일, 입력 MAT, CVF, Iteration 수는 같다. 남은 차이 가운데 가장 큰 것은 CVF를 거는 때다.
파이프라인은 CVF 없이 실행하고 결과에 나중에 CVF를 건다. `RunPerTestCase`는 실행 전에 Test Case 설정에 CVF를 넣는다.
이번에는 CVF를 빼고 실행한 뒤 결과에 CVF를 걸어 센다. 20/22가 나오면 실행 때 건 CVF가 원인이다.
`RunPerTestCase`로 연 MATLAB을 닫지 않은 상태에서 붙여 넣는다. CUT 수만큼 다시 시뮬레이션한다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
testFiles = sltest.testmanager.getTestFiles; allCases = getAllTestCases(testFiles(1));
runFolder = fullfile(tempdir, 'st_open_standalone_run'); if ~isfolder(runFolder), mkdir(runFolder); end
previousFolder = cd(runFolder);
for t = 1:numel(pipeline.Targets)
    target = pipeline.Targets(t); cutPath = char(string(target.StandaloneCUTPath));
    addpath(char(string(target.OutputDirectory)), '-begin');
    caseIndex = find(string({allCases.Name}) == string(target.TestCaseName), 1);
    try
        coverage = getCoverageSettings(allCases(caseIndex)); coverage.CoverageFilterFilename = '';
        evalc('noFilterRun = run(allCases(caseIndex));');
        pending = {getCoverageResults(noFilterRun)}; covObjects = {};
        while ~isempty(pending)
            item = pending{1}; pending(1) = [];
            if iscell(item), pending = [pending, item(:)']; %#ok<AGROW>
            elseif isa(item, 'cv.cvdatagroup'), pending = [pending, getAll(item)']; %#ok<AGROW>
            elseif isa(item, 'cvdata'), covObjects = [covObjects, num2cell(item(:)')]; end %#ok<AGROW>
        end
        for j = 1:numel(covObjects)
            cvd = covObjects{j}; cvd.filter = char(string(target.PackagedCVF));
            decision = decisioninfo(cvd, cutPath); executed = executioninfo(cvd, cutPath);
            fprintf('대상 %d | CVF 없이 실행 후 CVF 적용 | 통과 %d | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, ...
                noFilterRun.NumPassed, decision(1), decision(2), executed(1), executed(2));
        end
    catch runError
        fprintf('대상 %d | 실패 | 식별자 %s\n', t, runError.identifier);
    end
end
cd(previousFolder); warning(warnState);
```

확인할 것: 대상마다 CUT 결정이 20/22인지(파이프라인과 같은지), 11/22인지(재실행과 같은지).

돌려줄 것: 화면 캡처 한 장.
