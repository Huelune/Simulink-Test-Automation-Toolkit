# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).


## 1. 자산 번들 결과에 CVF를 다시 걸어 Test Manager에서 보기

왜: 번들의 `raw/` 결과를 가져오면 열리지만 Coverage에 CVF가 적용되지 않는다. 결과의 Coverage는 CVF를
원래 프로젝트 경로나 이름으로 가리키는데, 번들을 만들 때 CVF는 `coverage/filters/`로 복사된다. 결과의
Coverage가 가리키는 CVF 이름과 같은 번들 CVF를 찾아 다시 걸면 Test Manager에도 적용되는지 확인한다.
툴킷 함수를 쓰지 않으므로 `st_setup` 없이 붙여 넣어도 된다. 실행하면 번들 폴더를 고르는 창이 뜬다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
bundleDir = uigetdir(pwd, '자산 번들 폴더(manifest.json이 있는 폴더)를 고르세요');
if isequal(bundleDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
rawFiles = dir(fullfile(bundleDir, '**', '*.mldatx')); % 결과 폴더 모양이 번들마다 달라 Test File만 뺀다
rawFiles = rawFiles(~contains({rawFiles.folder}, [filesep 'test-manager']));
cvfFiles = dir(fullfile(bundleDir, '**', '*.cvf'));
cvfNames = lower(string({cvfFiles.name}));
fprintf('MATLAB %s | manifest.json %d | 결과 파일 %d개 | 번들 CVF %d개\n', version('-release'), isfile(fullfile(bundleDir, 'manifest.json')), numel(rawFiles), numel(cvfFiles));
for k = 1:numel(rawFiles)
    resultSet = sltest.testmanager.importResults(fullfile(rawFiles(k).folder, rawFiles(k).name));
    pending = {getCoverageResults(resultSet)}; covObjects = {};
    if isempty(pending{1}) % 어떤 릴리스는 Coverage를 Test Case 결과에만 둔다
        nodes = num2cell(getTestFileResults(resultSet)); pending = {};
        while ~isempty(nodes)
            node = nodes{1}; nodes(1) = [];
            if isa(node, 'sltest.testmanager.TestCaseResult'), pending{end+1} = getCoverageResults(node); continue; end %#ok<SAGROW>
            nodes = [nodes, num2cell(getTestSuiteResults(node)), num2cell(getTestCaseResults(node))]; %#ok<AGROW>
        end
    end
    while ~isempty(pending)
        item = pending{1}; pending(1) = [];
        if iscell(item), pending = [pending, item(:)']; %#ok<AGROW>
        elseif isa(item, 'cv.cvdatagroup'), pending = [pending, getAll(item)']; %#ok<AGROW>
        elseif isa(item, 'cvdata'), covObjects = [covObjects, num2cell(item(:)')]; end %#ok<AGROW>
    end
    noFilter = 0; bound = 0; missing = 0; readbackFail = 0;
    for j = 1:numel(covObjects)
        refs = string(covObjects{j}.filter); refs = refs(strlength(refs) > 0 & ~ismissing(refs));
        if isempty(refs), noFilter = noFilter + 1; continue; end
        newRefs = strings(size(refs));
        for r = 1:numel(refs)
            [~, refName, refExt] = fileparts(char(refs(r))); if isempty(refExt), refExt = '.cvf'; end
            hit = find(cvfNames == lower(string([refName refExt])), 1);
            if isempty(hit), newRefs = strings(0); break; end
            newRefs(r) = string(fullfile(cvfFiles(hit).folder, cvfFiles(hit).name));
        end
        if isempty(newRefs), missing = missing + 1; continue; end
        covObjects{j}.filter = cellstr(newRefs);
        if numel(string(covObjects{j}.filter)) == numel(newRefs), bound = bound + 1; else, readbackFail = readbackFail + 1; end
    end
    fprintf('결과 %d | Coverage %d개 | CVF 다시 걸음 %d | CVF 없던 것 %d | 번들에 CVF 없음 %d | 걸고 확인 실패 %d\n', ...
        k, numel(covObjects), bound, noFilter, missing, readbackFail);
end
sltest.testmanager.view; warning(warnState);
```

확인할 것: 화면의 개수, 그리고 Test Manager의 Results and Artifacts에서 가져온 결과의 Coverage에
CVF로 뺀 항목이 빠지거나 justified로 보이는지(CVF 없이 볼 때와 % 값이 달라지는지).

돌려줄 것: 화면 캡처 한 장과 Test Manager Coverage가 바뀌었는지 한 줄. Coverage 표 캡처는 블록 이름이
보이므로 보내지 말고 % 값이 바뀌었는지만 적어 주세요.
