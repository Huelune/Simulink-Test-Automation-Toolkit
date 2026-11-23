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

## 2. Justify 근거용 SLDV Dead Logic 보고서 만들기

왜: CUT 결정 22개 중 2개(Switch 하나, Max 하나)를 SLDV가 Unsatisfiable(어떤 입력으로도 닿을 수 없음)로 증명했다. 커버리지 보고서에서 이
둘을 CVF로 Justify하려면 근거 자료가 필요하다. SLDV의 Design Error Detection 모드에서 Dead Logic 검사를 하면, 실행될 수 없는 블록
결과를 정리한 공식 보고서(HTML)가 나온다. 그 보고서를 Justify 사유의 첨부로 쓴다. 보고서는 툴킷 폴더의 `result\sldv_dead_logic\`
아래 시각 폴더에 남긴다. 모델은 저장하지 않는다. 분석 시간은 툴킷 설정(`cfg.SldvMaxProcessTime`, 비어 있으면 모델 설정)을 따른다.

순서: 모델 프로젝트를 열고 툴킷 폴더에서 `st_setup`을 돌린다. Top Model을 열고 **CUT Subsystem을 클릭해 선택**한 뒤 붙여 넣는다.
CUT마다 따로 돌린다(대상 3개면 세 번). CUT 하나에 몇 분 걸린다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
cfg = st_config(); cutBlock = gcb; topName = bdroot(cutBlock);
fprintf('선택 블록 종류 %s | Atomic %s\n', get_param(cutBlock, 'BlockType'), get_param(cutBlock, 'TreatAsAtomicUnit'));
wasDirty = get_param(topName, 'Dirty');
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outputFolder = fullfile(st_project_root(), 'result', 'sldv_dead_logic', stamp); mkdir(outputFolder);
opts = sldvoptions;
opts.Mode = 'DesignErrorDetection';
opts.DetectDeadLogic = 'on';
opts.DetectActiveLogic = 'off';
opts.DetectOutOfBounds = 'off'; opts.DetectDivisionByZero = 'off'; opts.DetectIntegerOverflow = 'off';
opts.OutputDir = outputFolder; opts.MakeOutputFilesUnique = 'on';
opts.SaveReport = 'on'; opts.ReportIncludeGraphics = 'on'; opts.DisplayReport = 'off';
if ~isempty(cfg.SldvMaxProcessTime), opts.MaxProcessTime = cfg.SldvMaxProcessTime; end
try
    evalc('[status, files] = sldvrun(cutBlock, opts, false);');
    fprintf('Dead Logic 분석 | 상태 %d (1 완료, -1 시간 초과, 0 실패)\n', status);
    if isfield(files, 'DataFile') && isfile(files.DataFile)
        data = load(files.DataFile, 'sldvData'); data = data.sldvData;
        statuses = string({data.Objectives.status});
        fprintf('검사 목표 %d개 | Dead Logic %d | Active Logic %d | Undecided %d\n', numel(statuses), ...
            sum(contains(statuses, 'Dead Logic')), sum(contains(statuses, 'Active Logic')), sum(contains(statuses, 'Undecided')));
        deadIndex = find(contains(statuses, 'Dead Logic'));
        for k = deadIndex
            try, blockType = get_param(Simulink.ID.getFullName(data.ModelObjects(data.Objectives(k).modelObjectIdx).designSid), 'BlockType'); catch, blockType = '?'; end
            fprintf('   Dead Logic | 블록 종류 %s | 목표 종류 %s\n', blockType, data.Objectives(k).type);
        end
    end
    if isfield(files, 'Report') && isfile(files.Report)
        [~, reportName, reportExt] = fileparts(files.Report);
        fprintf('%s\n', ['보고서: ' fullfile('result', 'sldv_dead_logic', stamp, [reportName reportExt])]);
        winopen(files.Report);
    else
        fprintf('보고서가 만들어지지 않았습니다\n');
    end
catch deadError
    fprintf('Dead Logic 분석 실패 | 식별자 %s\n', deadError.identifier);
end
if strcmp(wasDirty, 'off') && strcmp(get_param(topName, 'Dirty'), 'on'), set_param(topName, 'Dirty', 'off'); end
warning(warnState);
```

확인할 것: 상태 1(완료)이고, Dead Logic 목록에 Switch와 MinMax가 있는지. 커버리지에서 못 채운 2개와 같은 블록이어야 한다(SLDV 테스트 생성 때
하위 Subsystem 안에 있던 1개도 함께 나올 수 있다). 열린 보고서의 Dead Logic 항목을 그 블록의 Justify 근거로 쓴다.

돌려줄 것: 화면 캡처 한 장. 보고서는 블록 이름이 들어 있으니 보내지 말 것.

## 3. 이미 있는 SLDV 결과로 보고서 만들기 (2절이 안 될 때)

왜: GUI에서 CUT에 Dead Logic 검사를 돌리면 "not analyzable independently"로 막힌다. 2절(코드)도 같은 이유로 실패할 수 있다.
그런데 워크플로가 이미 CUT마다 SLDV 테스트 생성을 돌려 결과(`latest_sldvdata.mat`)를 남겼다. 거기에는 목표마다 판정이 있고, 못 채운
2개는 Unsatisfiable(도달 불가로 증명)로 들어 있다. 다시 분석하지 않고 그 결과로 SLDV 공식 보고서(HTML)를 만들어 Justify 근거로 쓴다.
보고서는 툴킷 폴더의 `result\sldv_report\{시각}\`에 남긴다. 모델 프로젝트를 열고 `st_setup`을 돌린 MATLAB에서 붙여 넣는다.
GENERATE 대상 전부의 보고서를 한 번에 만든다. 모델은 저장하지 않는다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
cfg = st_config(); targetRows = st_load_targets(cfg.OnlyEnabled);
targetRows = targetRows(targetRows.SldvMode == "GENERATE", :);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outputFolder = fullfile(st_project_root(), 'result', 'sldv_report', stamp); mkdir(outputFolder);
if ~bdIsLoaded(cfg.TopModel), load_system(cfg.ModelFile); end
for t = 1:height(targetRows)
    noText = regexprep(sprintf('%.17g', double(targetRows.No(t))), '[^A-Za-z0-9_-]', '_');
    found = dir(fullfile(cfg.SldvDir, [noText '_*'], 'latest_sldvdata.mat'));
    if isempty(found), fprintf('대상 %d | SLDV 결과 파일 없음\n', t); continue; end
    dataFile = fullfile(found(1).folder, found(1).name);
    data = load(dataFile, 'sldvData'); statuses = string({data.sldvData.Objectives.status});
    try
        reportOptions = sldvoptions; reportOptions.OutputDir = fullfile(outputFolder, sprintf('target_%d', t));
        reportOptions.ReportIncludeGraphics = 'on';
        [reportStatus, reportFile] = sldvreport(dataFile, reportOptions, false);
        [~, reportName, reportExt] = fileparts(char(string(reportFile)));
        fprintf('대상 %d | 보고서 %d | 목표 %d개 중 Unsatisfiable %d | %s\n', t, reportStatus, numel(statuses), ...
            sum(contains(statuses, 'Unsatisfiable')), fullfile('result', 'sldv_report', stamp, sprintf('target_%d', t), [reportName reportExt]));
    catch reportError
        fprintf('대상 %d | 보고서 실패 | 식별자 %s\n', t, reportError.identifier);
    end
end
winopen(outputFolder);
warning(warnState);
```

확인할 것: 대상마다 보고서가 1(성공)이고 Unsatisfiable 개수가 3(CUT 자체 2 + 하위 Subsystem 1)인지. 열린 폴더의 보고서에서 Objectives 표의
Unsatisfiable 항목이 그 Switch와 Max인지 보고, 그 항목을 Justify 근거로 쓴다.

돌려줄 것: 화면 캡처 한 장. 보고서는 보내지 말 것.
