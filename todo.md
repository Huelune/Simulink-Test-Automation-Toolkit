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

## 3. 파이프라인 결과를 저장해 Test Manager로 가져와 보기

왜: 재실행은 파이프라인과 다르게 돈다(원인 미확인). 그래서 매뉴얼 6단계를 재실행 대신, 파이프라인이 실제로 돌린 결과를 저장했다가
가져오는 방식으로 바꿨다. 3단계를 `'SaveTestResult', true`로 다시 돌리고, 그 결과를 가져와 CVF가 걸려 보이는지 확인한다.
가져온 결과에 따로 CVF를 다시 걸지 않는다. 결과에 저장된 그대로를 센다.

순서: 모델 프로젝트를 연다. 클론에서 main을 pull한다. 툴킷 폴더에서 `st_setup`을 돌린다. 아래 블록을 붙여 넣는다. 3단계
파이프라인 전체가 다시 돈다(평소 3단계만큼 걸린다). 다른 모델은 닫지 않는다. standalone 모델과 이름이 같은 모델만 저장하지 않고
닫는다(파이프라인이 연 사본이다).

앞서 돌린 파이프라인은 PACKAGE까지 끝나지 않아(결과 파일 저장 0) 가져올 결과가 없었다. 그래서 파이프라인부터 다시 돌린다.
파이프라인은 Top Model이나 Test File이 저장 안 된 상태면 시작하지 않는다. 그럴 때는 블록이 멈추고 그 사실을 한 줄로 찍는다.
오류는 종류(식별자)만 찍고, 원문은 `%TEMP%\st_saved_result_error.txt`에 쓴다.

```matlab
clearvars; clc; warnState = warning('off', 'all'); cfg = st_config(); stage = '';
try
    stage = '파이프라인';
    evalc('st_run_standalone_coverage_pipeline(''SaveTestResult'', true);');
    pipeline = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir, 'LATEST');
    fprintf('파이프라인 | 결과 파일 저장 %d\n', isfile(char(string(pipeline.ResultFile))));
    for t = 1:numel(pipeline.Targets)
        [~, standaloneName] = fileparts(char(string(pipeline.Targets(t).PackagedStandaloneModel)));
        if bdIsLoaded(standaloneName), close_system(standaloneName, 0); end
    end
    stage = '가져오기';
    evalc('openInfo = st_open_standalone_test_manager(''ClearTestManager'', true, ''LoadModels'', true, ''ImportResults'', true);');
catch stepError
    fid = fopen(fullfile(tempdir, 'st_saved_result_error.txt'), 'w'); fprintf(fid, '%s', stepError.getReport('extended', 'hyperlinks', 'off')); fclose(fid);
    fprintf('%s 실패 | 식별자 %s\n', stage, stepError.identifier);
    if contains(stepError.identifier, 'Dirty'), fprintf('Top Model이나 Test File을 저장한 뒤 다시 붙여 넣어 주세요\n'); end
    fprintf('%s\n', ['자세한 오류: %TEMP%' filesep 'st_saved_result_error.txt']); warning(warnState); return;
end
fprintf('가져오기 | 상태 %s | 결과 %d개\n', char(string(openInfo.ResultStatus)), openInfo.ResultRootCount);
resultSets = sltest.testmanager.getResultSets;
for t = 1:numel(pipeline.Targets)
    target = pipeline.Targets(t); cutPath = char(string(target.StandaloneCUTPath));
    fprintf('대상 %d 파이프라인 | 판정 %s | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, char(string(target.InitialOutcome)), ...
        target.DecisionCovered, target.DecisionTotal, target.ExecutionCovered, target.ExecutionTotal);
    for k = 1:numel(resultSets)
        pending = {getCoverageResults(resultSets(k))}; covObjects = {};
        while ~isempty(pending)
            item = pending{1}; pending(1) = [];
            if iscell(item), pending = [pending, item(:)']; %#ok<AGROW>
            elseif isa(item, 'cv.cvdatagroup'), pending = [pending, getAll(item)']; %#ok<AGROW>
            elseif isa(item, 'cvdata'), covObjects = [covObjects, num2cell(item(:)')]; end %#ok<AGROW>
        end
        for j = 1:numel(covObjects)
            try
                decision = decisioninfo(covObjects{j}, cutPath); executed = executioninfo(covObjects{j}, cutPath);
            catch
                continue; % 다른 대상의 Coverage
            end
            filters = string(covObjects{j}.filter); filters = filters(strlength(filters) > 0 & ~ismissing(filters));
            fprintf('대상 %d 가져온 결과 %d | 결과에 걸린 CVF %d | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, k, ...
                numel(filters), decision(1), decision(2), executed(1), executed(2));
        end
    end
end
warning(warnState);
```

확인할 것: 대상마다 "가져온 결과"의 CUT 결정·실행이 "파이프라인" 줄과 같은지, "결과에 걸린 CVF"가 1 이상인지. Test Manager에서
가져온 결과의 맨 위 Results 항목을 눌렀을 때 Coverage Filters 칸에 CVF가 있고 하위 Subsystem이 빠져 보이는지.

돌려줄 것: 화면 캡처 한 장과 "Coverage Filters에 CVF 있음/없음, 하위 Subsystem 빠짐/안 빠짐" 한 줄. Coverage 표는 캡처하지 마세요.
