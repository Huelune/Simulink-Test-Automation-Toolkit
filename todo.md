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

## 3. 못 채운 결정 2개를 SLDV가 어떻게 판정했는지 세기

왜: CVF를 적용한 CUT 결정 커버리지가 대상마다 20/22다. SLDV에 필터를 넘기든 안 넘기든 같은 두 결정이 남는다. SLDV는 목표마다
판정을 남긴다. Satisfied(채움), Unsatisfiable(어떤 입력으로도 못 채운다고 증명), Undecided(시간 안에 결론 못 냄) 등이다.
Unsatisfiable이면 그 로직은 닿을 수 없으니 CVF로 Justify 처리하는 것이 맞다. Undecided이면 `cfg.SldvMaxProcessTime`을 늘리면
채워질 수 있다. 대상마다 Decision 목표를 CUT 자체에 있는 것과 하위 Subsystem 안에 있는 것으로 나눠 판정별로 센다.
이름은 찍지 않는다. 모델 프로젝트를 열고 `st_setup`을 돌린 MATLAB에서 붙여 넣는다. Top Model을 저장하지 않고 열기만 한다.
시뮬레이션은 하지 않는다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
cfg = st_config(); targetRows = st_load_targets(cfg.OnlyEnabled);
targetRows = targetRows(targetRows.SldvMode == "GENERATE", :);
if ~bdIsLoaded(cfg.TopModel), load_system(cfg.ModelFile); end
for t = 1:height(targetRows)
    row = targetRows(t, :);
    noText = regexprep(sprintf('%.17g', double(row.No)), '[^A-Za-z0-9_-]', '_');
    found = dir(fullfile(cfg.SldvDir, [noText '_*'], 'latest_sldvdata.mat'));
    if isempty(found), fprintf('대상 %d | SLDV 결과 파일 없음\n', t); continue; end
    try
        data = load(fullfile(found(1).folder, found(1).name), 'sldvData'); data = data.sldvData;
        cutPath = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
        children = find_system(cutPath, 'SearchDepth', 1, 'FollowLinks', 'on', 'LookUnderMasks', 'all', ...
            'MatchFilter', @Simulink.match.allVariants, 'BlockType', 'SubSystem');
        children = children(~strcmp(children, cutPath));
        own = containers.Map(); inChild = containers.Map(); unknown = 0;
        for k = 1:numel(data.Objectives)
            objective = data.Objectives(k);
            if ~contains(objective.type, 'Decision', 'IgnoreCase', true), continue; end
            status = char(string(objective.status));
            try
                objectPath = Simulink.ID.getFullName(data.ModelObjects(objective.modelObjectIdx).designSid);
            catch
                unknown = unknown + 1; continue;
            end
            if any(startsWith(objectPath, strcat(children, '/')) | strcmp(objectPath, children)), bucket = inChild; else, bucket = own; end
            if isKey(bucket, status), bucket(status) = bucket(status) + 1; else, bucket(status) = 1; end
        end
        ownText = strjoin(cellfun(@(s) sprintf('%s %d', s, own(s)), keys(own), 'UniformOutput', false), ', ');
        childText = strjoin(cellfun(@(s) sprintf('%s %d', s, inChild(s)), keys(inChild), 'UniformOutput', false), ', ');
        fprintf('대상 %d | CUT 자체 Decision 목표: %s\n', t, ownText);
        fprintf('대상 %d | 하위 Subsystem 안 Decision 목표: %s | 위치 모름 %d\n', t, childText, unknown);
    catch dataError
        fprintf('대상 %d | 읽기 실패 | 식별자 %s\n', t, dataError.identifier);
    end
end
warning(warnState);
```

확인할 것: "CUT 자체" 줄에 Satisfied가 아닌 판정이 몇 개이고 무엇인지. Unsatisfiable이면 닿을 수 없는 로직이다. Undecided면 시간이 부족한
것이다. CUT 자체 Decision 목표 수는 결정 커버리지 분모(22)와 단위가 달라 꼭 같지는 않다.

돌려줄 것: 화면 캡처 한 장.
