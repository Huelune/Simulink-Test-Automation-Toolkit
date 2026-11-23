# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 새 MATLAB 세션에서 다시 돌려 파이프라인 커버리지와 비교

왜: 같은 CUT 기준으로 세어도 파이프라인 원본은 결정 20/22·실행 45/45이고, 재실행은 11/22·41/45다. 지금까지 한 세션에서
모델을 닫고 path와 workspace를 여러 번 바꿨기 때문에, 그 상태가 꼬였을 수 있다. 그래서 새 세션에서 처음부터 돌린다.
두 가지를 함께 본다. (가) 새 세션에서 `RunPerTestCase`로 돈 값. (나) 실행 전에 CVF를 빼고 돌린 뒤 결과에 CVF를 걸어
센 값. 파이프라인은 (나)처럼 CVF 없이 실행하고 나중에 CVF를 건다.

순서: MATLAB을 완전히 껐다 켠다. 평소처럼 모델 프로젝트(.prj)를 연다(Library 경로가 여기서 잡힌다). 클론에서 main을
pull한다. 아래 블록을 붙여 넣는다. 툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다. CUT 수의 두 배만큼
시뮬레이션한다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
try
    evalc('openInfo = st_open_standalone_test_manager(''ClearTestManager'', true, ''LoadModels'', true, ''RunPerTestCase'', true);');
    fprintf('MATLAB %s | 프로젝트 열림 %d | 대상 %d | 실행 OK %d | 오류 %d | 통과 %d | 실패 %d | 미완료 %d\n', version('-release'), ...
        ~isempty(matlab.project.rootProject), height(openInfo.RunSummary), sum(openInfo.RunSummary.Status == "OK"), ...
        sum(openInfo.RunSummary.Status == "ERROR"), sum(openInfo.RunSummary.Passed), sum(openInfo.RunSummary.Failed), ...
        sum(openInfo.RunSummary.Incomplete));
    if sum(openInfo.RunSummary.Passed) == 0
        fprintf('통과가 0이면 시뮬레이션이 돌지 않은 것입니다. 모델 프로젝트(.prj)를 먼저 열고 다시 돌려 주세요\n');
        warning(warnState); return;
    end
catch openError
    fprintf('열기 실패 | 식별자 %s\n', openError.identifier); warning(warnState); return;
end
allCases = getAllTestCases(openInfo.TestFile);
runFolder = fullfile(tempdir, 'st_open_standalone_run'); previousFolder = cd(runFolder);
for stage = 1:2
    if stage == 1, resultSets = sltest.testmanager.getResultSets; label = '(가) 실행 전 CVF'; else, resultSets = []; label = '(나) 실행 후 CVF'; end
    for t = 1:numel(pipeline.Targets)
        target = pipeline.Targets(t); cutPath = char(string(target.StandaloneCUTPath)); cvfFile = char(string(target.PackagedCVF));
        try
            if stage == 2
                addpath(char(string(target.OutputDirectory)), '-begin');
                caseIndex = find(string({allCases.Name}) == string(target.TestCaseName), 1);
                coverage = getCoverageSettings(allCases(caseIndex)); coverage.CoverageFilterFilename = '';
                evalc('resultSets = run(allCases(caseIndex));');
            end
            for k = 1:numel(resultSets)
                pending = {getCoverageResults(resultSets(k))}; covObjects = {};
                while ~isempty(pending)
                    item = pending{1}; pending(1) = [];
                    if iscell(item), pending = [pending, item(:)']; %#ok<AGROW>
                    elseif isa(item, 'cv.cvdatagroup'), pending = [pending, getAll(item)']; %#ok<AGROW>
                    elseif isa(item, 'cvdata'), covObjects = [covObjects, num2cell(item(:)')]; end %#ok<AGROW>
                end
                for j = 1:numel(covObjects)
                    cvd = covObjects{j};
                    if stage == 2, cvd.filter = cvfFile; end
                    try
                        decision = decisioninfo(cvd, cutPath); executed = executioninfo(cvd, cutPath);
                    catch
                        continue; % 다른 대상의 결과에는 이 CUT 경로가 없다
                    end
                    fprintf('%s | 대상 %d | CUT 결정 %d/%d | CUT 실행 %d/%d\n', label, t, decision(1), decision(2), executed(1), executed(2));
                end
            end
        catch stageError
            fprintf('%s | 대상 %d | 실패 | 식별자 %s\n', label, t, stageError.identifier);
        end
    end
end
cd(previousFolder); sltest.testmanager.view; warning(warnState);
```

확인할 것: 파이프라인은 대상마다 CUT 결정 20/22·CUT 실행 45/45다. (가)가 이와 같으면 앞의 차이는 세션 상태 때문이었다.
(나)만 같으면 실행 전에 CVF를 거는 것이 원인이다. 둘 다 11/22면 다른 원인이다.

돌려줄 것: 화면 캡처 한 장.
