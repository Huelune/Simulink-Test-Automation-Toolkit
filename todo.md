# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. Test Manager 재실행 결정 커버리지가 파이프라인보다 낮은 이유 확인

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
