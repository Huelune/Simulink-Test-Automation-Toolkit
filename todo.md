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

## 3. 재실행에서 Iteration 2가 왜 Failed인지 보기

왜: Top Model을 먼저 열어도 재실행은 Iteration 2만 Failed이고 CUT 결정 11/22다. 파이프라인은 PASSED·20/22다. Iteration 2가 기대값
비교에서 졌는지, 아니면 시뮬레이션 자체가 오류로 끝났는지에 따라 볼 곳이 다르다. 시뮬레이션이 오류로 끝났다면 그 시나리오의
Coverage가 통째로 빠지므로 11/22도 함께 설명된다. 대상 1을 한 번 다시 돌린다. Iteration 2 결과의 속성 이름과, 오류·메시지
속성의 개수를 찍는다. 메시지 원문은 `%TEMP%\st_iteration2_report.txt`에만 쓴다. 그 파일은 보내지 말고, 종류만 말로 알려 달라.
6단계를 돌린 MATLAB에서 붙여 넣는다. 시뮬레이션 1회.

```matlab
clearvars; clc; warnState = warning('off', 'all');
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
testFiles = sltest.testmanager.getTestFiles; allCases = getAllTestCases(testFiles(1));
target = pipeline.Targets(1);
addpath(char(string(target.OutputDirectory)), '-begin');
caseIndex = find(string({allCases.Name}) == string(target.TestCaseName), 1);
freshFolder = tempname; mkdir(freshFolder); previousFolder = cd(freshFolder);
evalc('oneRun = run(allCases(caseIndex));');
cd(previousFolder);
caseResults = getTestCaseResults(oneRun); iterationResults = getIterationResults(caseResults(1));
reportFile = fullfile(tempdir, 'st_iteration2_report.txt'); fid = fopen(reportFile, 'w');
for i = 1:numel(iterationResults)
    names = properties(iterationResults(i));
    messageNames = names(contains(names, {'Error', 'Message', 'Reason', 'Fail', 'Log'}, 'IgnoreCase', true));
    counts = zeros(1, numel(messageNames));
    for m = 1:numel(messageNames)
        value = iterationResults(i).(messageNames{m});
        counts(m) = numel(value);
        fprintf(fid, '=== Iteration %d %s\n%s\n', i, messageNames{m}, evalc('disp(value)'));
    end
    fprintf('Iteration %d | %s | 메시지 속성 %s | 개수 %s\n', i, char(string(iterationResults(i).Outcome)), ...
        strjoin(messageNames, ','), mat2str(counts));
end
fclose(fid);
fprintf('속성 전체: %s\n', strjoin(properties(iterationResults(2)), ', '));
fprintf('%s\n', ['자세한 메시지: %TEMP%' filesep 'st_iteration2_report.txt']);
warning(warnState);
```

확인할 것: Iteration 2의 메시지 속성에 개수가 있는지. 그리고 `%TEMP%\st_iteration2_report.txt`의 Iteration 2 부분이 어떤 종류인지.
기대값 비교에서 졌다는 내용(verify 실패)인가, 시뮬레이션 오류(변수 없음, 입력 불일치 등)인가.

돌려줄 것: 화면 캡처 한 장과, 파일에 적힌 Iteration 2 오류의 종류를 이름·경로·값 없이 한 줄로.
