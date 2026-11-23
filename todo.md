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

## 3. Unsatisfiable 목표가 어느 블록의 어느 결과인지 보기

왜: CUT 자체 Decision 목표 22개 중 2개가 Unsatisfiable(어떤 입력으로도 닿을 수 없다고 SLDV가 증명)이다. SLDV는 "왜"를 문장으로
주지 않는다. 대신 어느 블록의 어느 결과(예: Switch의 두 번째 입력 선택, If의 else)인지 알려 준다. 그 블록으로 들어오는 신호를
보면 이유가 보인다(앞단에서 범위가 막힌 신호, 상수 조건 등). 화면에는 블록 종류와 결과 번호만 찍는다. 블록 이름이 들어간 자세한
목록은 `%TEMP%\st_unsat_objectives.txt`에 쓴다. 그리고 SLDV 결과로 Top Model에 색을 칠한다(빨간색이 Unsatisfiable). 그 파일과
모델 화면은 보내지 말고 직접 본다. 모델 프로젝트를 열고 `st_setup`을 돌린 MATLAB에서 붙여 넣는다. Top Model을 저장하지 않는다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
cfg = st_config(); targetRows = st_load_targets(cfg.OnlyEnabled);
targetRows = targetRows(targetRows.SldvMode == "GENERATE", :);
if ~bdIsLoaded(cfg.TopModel), load_system(cfg.ModelFile); end
fid = fopen(fullfile(tempdir, 'st_unsat_objectives.txt'), 'w');
for t = 1:height(targetRows)
    row = targetRows(t, :);
    noText = regexprep(sprintf('%.17g', double(row.No)), '[^A-Za-z0-9_-]', '_');
    found = dir(fullfile(cfg.SldvDir, [noText '_*'], 'latest_sldvdata.mat'));
    if isempty(found), fprintf('대상 %d | SLDV 결과 파일 없음\n', t); continue; end
    dataFile = fullfile(found(1).folder, found(1).name);
    data = load(dataFile, 'sldvData'); data = data.sldvData;
    for k = 1:numel(data.Objectives)
        objective = data.Objectives(k);
        if ~contains(objective.type, 'Decision', 'IgnoreCase', true) || ~contains(string(objective.status), 'Unsatisfiable'), continue; end
        try
            objectPath = Simulink.ID.getFullName(data.ModelObjects(objective.modelObjectIdx).designSid);
            blockType = get_param(objectPath, 'BlockType');
        catch
            objectPath = '?'; blockType = '?';
        end
        outcome = '?'; if isfield(objective, 'outcomeValue'), outcome = num2str(objective.outcomeValue); end
        fprintf('대상 %d | Unsatisfiable | 블록 종류 %s | 결과 번호 %s\n', t, blockType, outcome);
        fprintf(fid, '대상 %d | %s | %s | %s\n', t, objectPath, blockType, char(string(objective.descr)));
    end
    if t == 1
        try, sldvhighlight(dataFile); fprintf('대상 1 SLDV 결과를 모델에 칠했습니다(빨간색 = Unsatisfiable)\n'); catch, fprintf('모델 칠하기 실패\n'); end
    end
end
fclose(fid);
fprintf('%s\n', ['블록 이름이 든 목록: %TEMP%' filesep 'st_unsat_objectives.txt']);
warning(warnState);
```

확인할 것: 대상마다 Unsatisfiable 목표가 어떤 블록 종류인지. 그리고 목록 파일과 칠해진 모델에서 그 블록으로 들어오는 신호를 직접 본다.
그 신호가 앞단에서 어떤 값 범위로 막히는지 보면 된다.

돌려줄 것: 화면 캡처 한 장. 이유를 찾았으면 블록·신호 이름 없이 말로 한 줄(예: "앞단 Saturation 때문에 조건이 항상 참").
