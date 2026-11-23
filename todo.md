# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. standalone 열기 명령과 제출물 launcher 단위 테스트

왜: `st_open_standalone_test_manager`에 `RunPerTestCase`를 넣었고, 제출물의 launcher
(`open_standalone_coverage_test_manager.m`)도 Test Case마다 자기 CVF를 건 직후 실행하게 바꿨다. MATLAB이 없어
단위 테스트를 못 돌렸다. 먼저 클론에서 main을 pull한다. 실행하면 툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다.
이미 만든 제출물 폴더의 launcher는 PACKAGE 때 복사한 옛 것이다. 바뀐 launcher는 다음 PACKAGE부터 들어간다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
testFiles = fullfile(st_project_root(), 'tests', 'unit', ...
    {'test_open_standalone_test_manager.m', 'test_standalone_coverage_pipeline.m', 'test_classify_standalone_results.m'});
evalc('testResults = runtests(testFiles);');
fprintf('MATLAB %s | 테스트 %d | 통과 %d | 실패 %d | 미완료 %d\n', version('-release'), numel(testResults), ...
    sum([testResults.Passed]), sum([testResults.Failed]), sum([testResults.Incomplete]));
failedTests = testResults([testResults.Failed] | [testResults.Incomplete]);
for k = 1:numel(failedTests), fprintf('실패 | %s\n', failedTests(k).Name); end
warning(warnState);
```

확인할 것: 실패 0. 실패하면 줄에 테스트 이름이 찍힌다(툴킷 테스트 이름이라 내부 정보가 아니다).

돌려줄 것: 화면 캡처 한 장.

## 2. Test Manager 재실행 결정 커버리지가 파이프라인보다 낮은 이유 확인

왜: CVF를 적용한 결정 커버리지가 파이프라인의 `CoverageSummary.xlsx`에서는 CUT마다 20/22인데, `RunPerTestCase`로
다시 돌리면 11/22다. 분모가 같으니 CVF는 똑같이 걸렸다. 그런데 덜 충족됐으므로 입력이 달랐다고 의심한다.
파이프라인은 CUT마다 그 CUT 폴더만 path에 올리고 돌린다. 열기 명령은 모든 CUT 폴더를 한꺼번에 올린다. 그런데 입력
MAT는 파일 이름으로만 찾는다. 그래서 여러 CUT 폴더에 이름이 같은 MAT가 있으면 엉뚱한 MAT를 읽을 수 있다.
반복(iteration) 수가 다른지도 본다. `st_open_standalone_test_manager(..., 'RunPerTestCase', true)`로 열고 실행한
MATLAB을 닫지 않은 상태에서 붙여 넣는다. 닫았다면 그 명령을 먼저 다시 돌린다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
cfg = st_config();
pipeline = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir, 'LATEST');
targetCount = numel(pipeline.Targets); inputNames = strings(1, targetCount);
for t = 1:targetCount
    [~, inputName, inputExt] = fileparts(char(string(pipeline.Targets(t).PackagedInput))); inputNames(t) = lower(string([inputName inputExt]));
end
testFiles = sltest.testmanager.getTestFiles; allCases = getAllTestCases(testFiles(1));
for t = 1:targetCount
    ownInput = char(string(pipeline.Targets(t).PackagedInput));
    if isempty(ownInput), fprintf('대상 %d | 입력 MAT 없음\n', t); continue; end
    found = which(char(inputNames(t)), '-all'); if ischar(found), found = {found}; end
    resolvesOwn = ~isempty(found) && strcmpi(found{1}, ownInput);
    caseIndex = find(string({allCases.Name}) == string(pipeline.Targets(t).TestCaseName), 1);
    iterationCount = 0; if ~isempty(caseIndex), iterationCount = numel(getIterations(allCases(caseIndex))); end
    fprintf('대상 %d | 같은 이름 입력 MAT를 쓰는 대상 %d | path에서 찾은 같은 이름 MAT %d개 | 맨 앞이 자기 것 %d | Iteration %d\n', ...
        t, sum(inputNames == inputNames(t)), numel(found), resolvesOwn, iterationCount);
end
resultSets = sltest.testmanager.getResultSets;
for k = 1:numel(resultSets)
    fprintf('결과 %d | 통과 %d | 실패 %d | 미완료 %d\n', k, resultSets(k).NumPassed, resultSets(k).NumFailed, resultSets(k).NumIncomplete);
end
warning(warnState);
```

확인할 것: "맨 앞이 자기 것"이 0인 대상이 있으면 다른 CUT의 입력 MAT로 돌린 것이다. 대상마다 Iteration 수와
결과의 통과+실패+미완료 수가 다르면 반복이 일부만 돌았다.

돌려줄 것: 화면 캡처 한 장. 파이프라인 실행 때 CUT마다 Iteration이 몇 개였는지 알면 한 줄 적어 주세요.
