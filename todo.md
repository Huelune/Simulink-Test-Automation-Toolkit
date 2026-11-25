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

## 3. 결함 TC 작업의 단위 테스트 다시 돌리기와 4절 실패의 원인 자료 읽기 (모델 실행 없음)

왜: 지난번 이 절에서 이미 알던 실패 다섯 건은 고쳐서 모두 통과했고, 목록 밖의 실패 하나
(`test_project_layout/testUnitTestHelpersAreNotMistakenForTests`)가 나왔다. 저장소의 테스트 파일에는 이 검사에 걸리는 함수가
없어서, 클론에만 있는 파일을 의심한다. 4절은 준비·실행이 `WorkflowStageFailed`로 멈췄고, 대상마다 도달 불가 결과 3개가 모두
Stateflow로 빠져 결함 TC가 0이었다. 이 모델에는 Stateflow가 없으므로, SLDV가 보통 블록에도 `sfObjType`에 값을 넣는 것으로
보인다. 이 블록은 같은 23개 파일의 단위 테스트를 다시 돌린 뒤, 파일과 실행 로그, SLDV 데이터를 읽기만 한다. 모델이나
시뮬레이션이 필요한 테스트는 뺐다.

순서: 4절을 돌린 클론에서 main을 pull한다. 4절을 다시 돌리기 전에 아래 블록을 붙여 넣는다(가장 최근 준비·실행 로그를 읽는다).
툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다. 몇 분 걸릴 수 있다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
idOf = @(ex) char(strjoin([string(ex.identifier) repmat("(식별자 없음)", 1, double(isempty(ex.identifier)))], ''));
idPattern = '(?:simtest|MATLAB|Simulink|sltest|stm|sldv|Stateflow|SimulinkTest|SL_SERVICES|slvnv)(?::\w+)+';
diagFile = 'st_defect_unit_and_probe.txt';
fid = fopen(fullfile(tempdir, diagFile), 'w');
if fid < 0, fprintf('진단 파일을 만들지 못해 화면 정보만 보입니다\n'); fid = fopen('nul', 'w'); end
rootDir = st_project_root(); cfg = st_config();
fprintf('MATLAB %s\n', version('-release'));
% 가. 단위 테스트: 모두 통과한 파일은 개수로만, 실패·미완료만 한 줄씩
testNames = {'test_defect_settings', 'test_build_defect_iterations', 'test_expected_iteration_bindings', ...
    'test_find_iteration_result', 'test_final_document_defects', 'test_export_final_document', ...
    'test_expected_update_modes', 'test_probe_sldv_objectives', 'test_decision_outcomes', ...
    'test_no_output_verify_skip', 'test_partial_iteration_update', 'test_per_cut_execution', ...
    'test_sldv_naming_and_off_profile', 'test_harness_clone', 'test_cut_name_slash_escaping', ...
    'test_mat_file_mode', 'test_signal_editor_no_inport', 'test_incremental_workflow', ...
    'test_library_link_harness_protection', 'test_sldv_config', 'test_project_layout', ...
    'test_unreachable_objectives', 'test_defect_criteria'};
failLines = {}; totalPassed = 0; totalFailed = 0; totalIncomplete = 0; errorCount = 0; cleanFiles = 0;
for k = 1:numel(testNames)
    try
        evalc('fileResults = runtests(fullfile(st_project_root(), ''tests'', ''unit'', [testNames{k} ''.m'']));');
    catch runError
        errorCount = errorCount + 1;
        failLines{end+1} = sprintf('%s | 실행 오류 | %s', testNames{k}, idOf(runError)); %#ok<SAGROW>
        fprintf(fid, '[%s] 실행 오류: %s\n\n', testNames{k}, runError.message);
        continue
    end
    totalPassed = totalPassed + sum([fileResults.Passed]); totalFailed = totalFailed + sum([fileResults.Failed]);
    totalIncomplete = totalIncomplete + sum([fileResults.Incomplete]);
    if ~any([fileResults.Failed] | [fileResults.Incomplete]), cleanFiles = cleanFiles + 1; continue; end
    for j = find([fileResults.Failed] | [fileResults.Incomplete])
        label = '실패'; if fileResults(j).Incomplete && ~fileResults(j).Failed, label = '미완료'; end
        kindText = '종류 확인 못 함';
        try
            firstRecord = fileResults(j).Details.DiagnosticRecord(1);
            kindText = char(string(firstRecord.Event));
            if strcmp(kindText, 'ExceptionThrown')
                exceptionId = char(string(firstRecord.Exception.identifier));
                if isempty(exceptionId), exceptionId = '(식별자 없음)'; end
                kindText = [kindText ' ' exceptionId];
            end
        catch, kindText = '종류 확인 못 함';
        end
        failLines{end+1} = sprintf('%s | %s | %s', label, fileResults(j).Name, kindText); %#ok<SAGROW>
        fprintf(fid, '[%s]\n', fileResults(j).Name);
        try
            diagRecords = fileResults(j).Details.DiagnosticRecord;
            for r = 1:numel(diagRecords), fprintf(fid, '%s\n', char(strjoin(string(diagRecords(r).Report), newline))); end
        catch, fprintf(fid, '(진단을 읽지 못했습니다)\n');
        end
        fprintf(fid, '\n');
    end
end
fprintf('단위 테스트 | 파일 %d | 모두 통과한 파일 %d | 통과 %d | 실패 %d | 미완료 %d | 실행 오류 %d\n', numel(testNames), ...
    cleanFiles, totalPassed, totalFailed, totalIncomplete, errorCount);
for k = 1:min(8, numel(failLines)), fprintf('  %s\n', failLines{k}); end
if numel(failLines) > 8, fprintf('  실패 %d개 더 있음. 이름은 진단 파일에서 봅니다\n', numel(failLines) - 8); end
% 나. layout 검사에 걸리는 함수: 저장소가 추적하는 파일이면 이름을, 아니면 개수만 찍는다
[gitState, ~] = system(sprintf('git -C "%s" rev-parse --is-inside-work-tree', rootDir));
unitFiles = dir(fullfile(rootDir, 'tests', 'unit', '*.m'));
trackedHits = strings(0, 1); untrackedHits = 0; untrackedFiles = 0;
for k = 1:numel(unitFiles)
    isTracked = false;
    if gitState == 0
        [trackState, ~] = system(sprintf('git -C "%s" ls-files --error-unmatch "tests/unit/%s"', rootDir, unitFiles(k).name));
        isTracked = trackState == 0; untrackedFiles = untrackedFiles + double(~isTracked);
    end
    source = fileread(fullfile(unitFiles(k).folder, unitFiles(k).name));
    tokens = regexp(source, '^\s*function\s+(?:\[[^\]]*\]\s*=\s*|\w+\s*=\s*)?(\w+)\s*(?:\(([^)]*)\))?', 'tokens', 'lineanchors');
    for t = 2:numel(tokens)
        if isempty(regexpi(tokens{t}{1}, '^test|test$', 'once')), continue; end
        args = ''; if numel(tokens{t}) >= 2, args = strtrim(tokens{t}{2}); end
        if ~isempty(args) && numel(strsplit(args, ',')) == 1, continue; end
        fprintf(fid, '[layout] %s:%s (%s)\n', unitFiles(k).name, tokens{t}{1}, args);
        if isTracked
            trackedHits(end+1, 1) = sprintf('%s:%s | 인자 %d개', unitFiles(k).name, tokens{t}{1}, ...
                numel(strsplit(args, ',')) * double(~isempty(args))); %#ok<SAGROW>
        else
            untrackedHits = untrackedHits + 1;
        end
    end
end
gitText = 'OK'; if gitState ~= 0, gitText = '확인 못 함'; end
fprintf('layout | 파일 %d | git %s | 저장소에 없는 파일 %d | 걸린 함수: 저장소 파일 %d, 저장소에 없는 파일 %d\n', ...
    numel(unitFiles), gitText, untrackedFiles, numel(trackedHits), untrackedHits);
for k = 1:numel(trackedHits), fprintf('  저장소 파일 | %s\n', trackedHits(k)); end
% 다. 가장 최근 준비·실행 로그에서 FAIL이 난 단계와 행의 오류 식별자
logFiles = dir(fullfile(char(cfg.ResultDir), 'logs', '*_st_run_from_harness*.log'));
if ~isempty(logFiles), logFiles = logFiles(~endsWith({logFiles.name}, '.console.log')); end
if isempty(logFiles)
    fprintf('실행 로그 | 없음\n');
else
    [~, newest] = max([logFiles.datenum]);
    fprintf('실행 로그 | %s\n', logFiles(newest).name);
    logLines = splitlines(string(fileread(fullfile(logFiles(newest).folder, logFiles(newest).name))));
    stageNames = ["Protect Library-Linked CUT Harnesses", "Disable Library Links For SLDV Targets", ...
        "Pre-Validate CUT Paths", "Create Harnesses", "Validate CUT / Harness Mapping", "Prepare SLDV Data", ...
        "Configure Harnesses", "Configure Signal Editor", "Configure Test Assessment", "Create Test Manager", ...
        "Validate Scenario Alignment"];
    inFailedStage = false; rowLines = 0;
    for k = 1:numel(logLines)
        lineText = char(logLines(k));
        stageTok = regexp(lineText, '<-- (?:\[\d+\] )?(.+?) \| (.*)$', 'tokens', 'once');
        if ~isempty(stageTok)
            inFailedStage = contains(stageTok{2}, 'FAIL');
            if ~inFailedStage, continue; end
            label = '다른 단계'; if ismember(string(stageTok{1}), stageNames), label = stageTok{1}; end
            countText = regexp(stageTok{2}, '^[A-Z_]+=\d+(?:, [A-Z_]+=\d+)*', 'match', 'once');
            if isempty(countText), countText = 'FAILED'; end
            ids = unique(string(regexp(stageTok{2}, idPattern, 'match')));
            idText = '없음'; if ~isempty(ids), idText = char(strjoin(ids, ', ')); end
            fprintf('로그 단계 | %s | %s | 식별자 %s\n', label, countText, idText);
            fprintf(fid, '[log] %s\n', lineText);
        elseif inFailedStage && contains(lineText, '[ERROR]') && contains(lineText, 'No=')
            rowNo = regexp(lineText, '\<No=(\d+)', 'tokens', 'once');
            ids = unique(string(regexp(lineText, idPattern, 'match')));
            idText = '식별자 없음'; if ~isempty(ids), idText = char(strjoin(ids, ', ')); end
            rowLines = rowLines + 1;
            if rowLines <= 6 && ~isempty(rowNo), fprintf('  행 No=%s | %s\n', rowNo{1}, idText); end
            fprintf(fid, '[log] %s\n', lineText);
        else
            inFailedStage = false;
        end
    end
end
% 라. SLDV 데이터의 sfObjType 값과 도달 불가 결정 결과
T = table();
try
    evalc('T = st_load_targets(cfg.OnlyEnabled);');
catch loadError
    fprintf('대상 목록 읽기 실패 | %s\n', idOf(loadError));
end
knownTypes = ["subsystem"; "min"; "max"; "minmax"; "state"; "transition"; "chart"; "junction"];
try
    evalc('typeCatalog = st_specification_decision_catalog(''ALL'');');
    knownTypes = [knownTypes; lower(string(typeCatalog.BlockType(:))); lower(string(typeCatalog.DisplayType(:)))];
catch
end
for rowIndex = 1:height(T)
    rowNo = double(T.No(rowIndex));
    try
        evalc('sldvProfile = st_get_sldv_profile(T(rowIndex,:), cfg);');
        loaded = load(sldvProfile.EffectiveDataFile, 'sldvData');
        objects = loaded.sldvData.ModelObjects; objectives = loaded.sldvData.Objectives;
    catch readError
        fprintf('대상 %d | SLDV 데이터 읽기 실패 | %s\n', rowNo, idOf(readError));
        continue
    end
    if isempty(objects), fprintf('대상 %d | ModelObjects 0\n', rowNo); continue; end
    shapes = repmat("필드 없음", numel(objects), 1);
    for m = 1:numel(objects)
        if ~isfield(objects, 'sfObjType'), break; end
        value = objects(m).sfObjType;
        if ischar(value) || isstring(value)
            typeWord = strtrim(string(reshape(char(value), 1, [])));
            if typeWord == ""
                shapes(m) = "빈 글자";
            elseif ~isempty(regexp(typeWord, '^[A-Za-z][A-Za-z/ _-]{0,19}$', 'once'))
                shapes(m) = "'" + typeWord + "'";
            else
                shapes(m) = "다른 글자";
            end
        elseif isnumeric(value) || islogical(value)
            if isempty(value), shapes(m) = "빈 숫자";
            elseif isscalar(value), shapes(m) = "숫자 " + string(double(value));
            else, shapes(m) = "숫자 배열";
            end
        else
            shapes(m) = "형식 " + string(class(value));
        end
    end
    [shapeNames, ~, shapeIndex] = unique(shapes);
    shapeCounts = accumarray(shapeIndex(:), 1);
    fprintf('대상 %d | ModelObjects %d | sfObjType %s\n', rowNo, numel(objects), ...
        char(strjoin(shapeNames(:).' + " " + string(shapeCounts(:).'), ', ')));
    for q = 1:numel(objectives)
        objective = objectives(q);
        if ~strcmpi(strtrim(char(objective.type)), 'Decision'), continue; end
        if ~startsWith(strtrim(string(objective.status)), "Unsatisfiable", 'IgnoreCase', true), continue; end
        objectIndex = objective.modelObjectIdx; modelObject = objects(objectIndex);
        typeText = '기타 블록';
        if ismember(lower(strtrim(string(modelObject.typeDesc))), knownTypes), typeText = char(modelObject.typeDesc); end
        pathParts = numel(regexp(char(modelObject.slPath), '(?<!/)/(?!/)', 'split'));
        numText = '필드 없음';
        if isfield(modelObject, 'sfObjNum')
            sfNum = modelObject.sfObjNum;
            if isnumeric(sfNum) && isscalar(sfNum), numText = num2str(double(sfNum));
            elseif isempty(sfNum), numText = '빈 값';
            else, numText = ['형식 ' class(sfNum)];
            end
        end
        fprintf('  대상 %d | %s | slPath 요소 %d | sfObjType %s | sfObjNum %s\n', rowNo, typeText, pathParts, ...
            char(shapes(objectIndex)), numText);
        fprintf(fid, '[대상 %d 결과] typeDesc=%s\n', rowNo, char(string(modelObject.typeDesc)));
    end
end
fclose(fid);
fprintf('진단 전문 파일: %s (임시 폴더)\n', diagFile);
warning(warnState);
```

화면: 위에서부터 네 덩어리가 나온다.

- `단위 테스트` 한 줄과, 실패·미완료·실행 오류마다 `실패 | 테스트 이름 | 종류` 한 줄(최대 8줄).
- `layout` 한 줄. 저장소가 추적하는 파일에서 걸린 함수가 있으면 그 이름이 아래에 붙는다.
- `실행 로그` 이름 한 줄, FAIL이 난 단계마다 `로그 단계` 한 줄, FAIL 행마다 `행 No=` 한 줄.
- 대상마다 `sfObjType` 값 분포 한 줄과, 도달 불가 결정 결과마다 한 줄. `sfObjType`은 영어 낱말이면 그대로(`'State'` 같은)
  찍고, 다른 글자면 `다른 글자`로만 찍는다. 블록 종류는 툴킷이 아는 Simulink 블록 종류만 찍고, 모르는 종류는 `기타 블록`이다.

확인할 것:

- `단위 테스트`의 실행 오류가 0인가. 실패가 `test_project_layout/testUnitTestHelpersAreNotMistakenForTests` 한 건뿐인가. 다른
  실패가 있으면 새 실패다.
- `layout`의 `걸린 함수: 저장소에 없는 파일`이 1 이상인가. 그러면 클론의 `tests/unit`에 git이 추적하지 않는 파일이 있다(진단
  파일 `[layout]` 줄에 이름이 있다). 직접 만든 파일인지, 지워도 되는지 말로 알려 달라. 저장소 파일에서 걸린 함수가 찍혔으면
  화면 그대로 보내 달라(툴킷 테스트 이름이다).
- `실행 로그` 이름의 날짜·시각이 4절을 돌린 때인가.
- `로그 단계`가 어느 단계인가. `행 No=` 줄이 `식별자 없음`이면, 진단 파일의 `[log]` 줄에서 그 행 메시지를 CUT·블록 이름과
  경로를 뺀 말로 옮겨 달라.
- 대상마다 `sfObjType` 값 분포가 어떤가. 도달 불가 결과 줄(대상마다 3줄)의 `sfObjType`과 `sfObjNum`이 다른 ModelObjects와
  같은 값인가.

돌려줄 것: 화면 캡처 한 장과, 위에서 말로 옮겨 달라고 한 것이 있으면 그 한두 줄. 진단 파일은 사용자 PC에서만 보고 밖으로
보내지 않는다. 다른 실패가 있으면 진단 파일에서 그 테스트의 첫 진단 줄을 경로와 이름을 뺀 말로 바꿔 적어 달라.

## 4. 실제 모델에서 결함 TC 확인하기 (TEST_MANAGER부터 다시 준비하고 PER_CUT 실행)

왜: 계기가 된 모델에서 SLDV가 실행할 수 없다고 증명한 결정 결과가 결함 TC 2건(Switch, Max)이 되는지, 그 둘이 진짜
FAIL인지 본다. 기대값 갱신은 기본값(APPLY) 그대로 둔다. 갱신과 재실행 뒤에도 결함 TC가 FAIL로 남는지, 보통 TC의 판정과
결정 커버리지가 그대로인지도 같이 본다.

순서: 3절의 원인 자료로 결함 TC 0건과 준비·실행 실패를 고친 뒤에 돌린다. 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다. 열려 있는
모델 중 저장 안 한 것이 없을 때 아래 블록을 붙여 넣는다. 툴킷 폴더를 고르는 창이 뜬다. 블록은 사용 설명서의 재실행
명령 `st_run_from_harness('PreparationMode','FORCE','FromStage','TEST_MANAGER')`로 Test Case를 다시 만들고(결함
Iteration이 Test File에 붙는다) PER_CUT으로 실행한 뒤, `st_collect_per_cut_results`로 결과를 정리한다. 평소 1단계
재실행만큼 걸린다. 실행 중 콘솔 줄은 끝에 지워지고 숫자만 남는다. 결함 TC를 다시 없애려면 `src/config/st_config.m`의
`cfg.UnreachableDefectTests`를 `false`로 바꾸고 같은 명령으로 다시 준비한다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
idOf = @(ex) char(strjoin([string(ex.identifier) repmat("(식별자 없음)", 1, double(isempty(ex.identifier)))], ''));
diagFile = 'st_defect_real_model.txt';
fid = fopen(fullfile(tempdir, diagFile), 'w');
if fid < 0, fid = fopen('nul', 'w'); end
cfg = st_config();
screenLines = {sprintf('MATLAB %s', version('-release'))};
haveBefore = false; beforeText = '없음';
try
    evalc('beforeSource = st_final_document_run_source(cfg, ''PER_CUT'');');
    evalc('beforeOutcomes = st_final_document_outcomes(cfg, beforeSource);');
    beforeRows = beforeOutcomes.Iterations; haveBefore = height(beforeRows) > 0;
    beforeText = sprintf('%d행', height(beforeRows));
catch beforeError
    beforeText = ['읽기 실패 ' idOf(beforeError)];
    fprintf(fid, '[실행 전 판정]\n%s\n\n', getReport(beforeError, 'extended', 'hyperlinks', 'off'));
end
screenLines{end+1} = sprintf('실행 전 판정 %s', beforeText);
runText = 'OK'; collectText = '건너뜀';
try
    st_run_from_harness('PreparationMode', 'FORCE', 'FromStage', 'TEST_MANAGER', 'ExecutionMode', 'PER_CUT');
catch runError
    runText = ['실패 ' idOf(runError)];
    fprintf(fid, '[준비와 실행]\n%s\n\n', getReport(runError, 'extended', 'hyperlinks', 'off'));
end
if strcmp(runText, 'OK')
    try
        st_collect_per_cut_results();
        collectText = 'OK';
    catch collectError
        collectText = ['실패 ' idOf(collectError)];
        fprintf(fid, '[결과 정리]\n%s\n\n', getReport(collectError, 'extended', 'hyperlinks', 'off'));
    end
end
haveAfter = false;
if strcmp(collectText, 'OK')
    try
        evalc('afterSource = st_final_document_run_source(cfg, ''PER_CUT'');');
        evalc('afterOutcomes = st_final_document_outcomes(cfg, afterSource);');
        afterRows = afterOutcomes.Iterations; haveAfter = true;
    catch afterError
        collectText = ['OK, 판정 읽기 실패 ' idOf(afterError)];
        fprintf(fid, '[실행 후 판정]\n%s\n\n', getReport(afterError, 'extended', 'hyperlinks', 'off'));
    end
end
screenLines{end+1} = sprintf('준비·실행 %s | 결과 정리 %s', runText, collectText);
try
    evalc('T = st_load_targets(cfg.OnlyEnabled);');
catch loadError
    T = table();
    screenLines{end+1} = sprintf('대상 목록 읽기 실패 | %s', idOf(loadError));
    fprintf(fid, '[대상 목록]\n%s\n\n', getReport(loadError, 'extended', 'hyperlinks', 'off'));
end
knownTypes = "subsystem";
try
    evalc('typeCatalog = st_specification_decision_catalog(''ALL'');');
    knownTypes = lower([typeCatalog.BlockType; typeCatalog.DisplayType; "SubSystem"; "Min"; "Max"]);
catch catalogError
    screenLines{end+1} = sprintf('블록 종류 목록 읽기 실패 | %s', idOf(catalogError));
    fprintf(fid, '[블록 종류 목록]\n%s\n\n', getReport(catalogError, 'extended', 'hyperlinks', 'off'));
end
for rowIndex = 1:height(T)
    rowNo = double(T.No(rowIndex));
    try
        evalc('sldvProfile = st_get_sldv_profile(T(rowIndex,:), cfg);');
    catch profileError
        screenLines{end+1} = sprintf('대상 %d | SLDV profile 읽기 실패 | %s', rowNo, idOf(profileError));
        fprintf(fid, '[대상 %d SLDV profile]\n%s\n\n', rowNo, getReport(profileError, 'extended', 'hyperlinks', 'off'));
        continue
    end
    defectCounts = sldvProfile.DefectCounts; defects = sldvProfile.DefectIterations;
    screenLines{end+1} = sprintf('대상 %d | DefectStatus %s | Decision %d | Unsatisfiable %d | Approximate %d | Undecided %d', ...
        rowNo, sldvProfile.DefectStatus, defectCounts.Decision, defectCounts.Unsatisfiable, defectCounts.Approximate, ...
        defectCounts.Undecided);
    coverageText = '-';
    if haveAfter
        workbookFiles = afterSource.Workbooks.File(afterSource.Workbooks.No == rowNo);
        if isempty(workbookFiles)
            coverageText = '정리 파일 없음';
        else
            try
                coverageRows = readtable(workbookFiles(end), 'Sheet', 'Coverage', 'TextType', 'string', ...
                    'VariableNamingRule', 'preserve');
                coverageRows = coverageRows(coverageRows.Level == "CUT" & coverageRows.Metric == "Decision", :);
                coverageText = 'Decision 행 없음';
                if height(coverageRows) > 0, coverageText = sprintf('%g/%g', coverageRows.Covered(1), coverageRows.Total(1)); end
            catch coverageError
                coverageText = ['읽기 실패 ' idOf(coverageError)];
                fprintf(fid, '[대상 %d 커버리지]\n%s\n\n', rowNo, getReport(coverageError, 'extended', 'hyperlinks', 'off'));
            end
        end
    end
    screenLines{end+1} = sprintf('대상 %d | 뺌 FilteredByCvf %d | CutItself %d | Stateflow %d | 결함 TC %d | 결정 커버리지 %s', ...
        rowNo, defectCounts.FilteredByCvf, defectCounts.CutItself, defectCounts.Stateflow, numel(defects), coverageText);
    defectNames = string({defects.Name});
    if haveAfter
        caseRows = afterRows(afterRows.TestCaseName == string(T.TestCaseName(rowIndex)), :);
        isDefect = ismember(caseRows.IterationName, defectNames);
        defectVerdicts = caseRows.Verdict(isDefect); normalRows = caseRows(~isDefect, :);
        compareText = '이전 판정 없음';
        if haveBefore
            priorRows = beforeRows(beforeRows.TestCaseName == string(T.TestCaseName(rowIndex)), :);
            changedCount = 0; missingCount = 0;
            for r = 1:height(normalRows)
                priorVerdict = priorRows.Verdict(priorRows.IterationName == normalRows.IterationName(r));
                if isempty(priorVerdict)
                    missingCount = missingCount + 1;
                elseif priorVerdict(end) ~= normalRows.Verdict(r)
                    changedCount = changedCount + 1;
                end
            end
            compareText = sprintf('이전과 다름 %d, 이전 없음 %d', changedCount, missingCount);
        end
        stageText = '-'; if height(caseRows) > 0, stageText = char(caseRows.Stage(1)); end
        screenLines{end+1} = sprintf('대상 %d | 판정 %s | 결함 FAIL %d PASS %d 기타 %d | 보통 PASS %d FAIL %d 기타 %d | %s', ...
            rowNo, stageText, sum(defectVerdicts == "FAIL"), sum(defectVerdicts == "PASS"), ...
            sum(~ismember(defectVerdicts, ["FAIL" "PASS"])), sum(normalRows.Verdict == "PASS"), ...
            sum(normalRows.Verdict == "FAIL"), sum(~ismember(normalRows.Verdict, ["FAIL" "PASS"])), compareText);
    end
    for k = 1:numel(defects)
        blockDepth = numel(regexp(defects(k).RelativePath, '(?<!/)/(?!/)')) + 1;
        approxText = '아니오'; if any([defects(k).Outcomes.Approximate]), approxText = '예'; end
        verdictText = '-';
        if haveAfter
            hitVerdicts = caseRows.Verdict(caseRows.IterationName == string(defects(k).Name));
            if ~isempty(hitVerdicts), verdictText = char(hitVerdicts(end)); end
        end
        typeText = '기타 블록';
        if ismember(lower(strtrim(string(defects(k).BlockType))), knownTypes), typeText = defects(k).BlockType; end
        fprintf(fid, '[대상 %d 결함 %d 블록 종류] %s\n', rowNo, k, defects(k).BlockType);
        screenLines{end+1} = sprintf('  결함 %d | %s | 깊이 %d | 결과 %d | 근사 %s | 판정 %s', k, typeText, ...
            blockDepth, numel(defects(k).Outcomes), approxText, verdictText);
    end
end
fprintf(fid, '[화면 전체]\n'); fprintf(fid, '%s\n', screenLines{:}); fclose(fid);
clc;
for k = 1:min(38, numel(screenLines)), fprintf('%s\n', screenLines{k}); end
if numel(screenLines) > 38, fprintf('%d줄 더 있음. 진단 파일 끝에 모두 있습니다\n', numel(screenLines) - 38); end
fprintf('진단 전문 파일: %s (임시 폴더)\n', diagFile);
warning(warnState);
```

화면: 대상 행마다 숫자 세 줄과 결함마다 한 줄이 나온다. 대상은 Excel 행 번호(`No`)로만 적는다. 결함 줄의 종류 칸에는
툴킷이 아는 Simulink 블록 종류만 찍고, 모르는 종류는 `기타 블록`으로 찍는다(원래 종류는 진단 파일에만 쓴다). `깊이`는
CUT 바로 아래 블록이 1이다.

확인할 것:

- `준비·실행 OK | 결과 정리 OK` 줄이 나왔는가. 아니면 식별자를 보고, 진단 파일에서 그 절의 첫 줄을 경로·이름 없이
  말로 옮겨 달라.
- 대상마다 `DefectStatus OK`, `결함 TC 2`이고, 결함 줄의 블록 종류가 Switch와 Max(SLDV가 `MinMax`로 적을 수 있다)인가.
  `기타 블록`이 있으면 진단 파일의 `블록 종류` 줄에서 그 종류를 보고, Switch인지 Max인지 아니면 다른 것인지 말로 알려
  달라(종류 이름은 적지 않는다).
- `판정 -`이면 그 대상의 결과 정리 파일(판정)을 읽지 못한 것이다. 결과 정리 줄과 진단 파일을 본다.
- SLDV는 대상마다 도달 불가 결과 3개를 냈다. `Unsatisfiable + Approximate`(3) = 결함 줄 `결과`의 합 + `FilteredByCvf` +
  `CutItself` + `Stateflow`여야 한다. 셋째 결과가 CVF가 빼는 곳(`FilteredByCvf 1`), CUT 자신(`CutItself 1`), Stateflow,
  같은 블록의 두 번째 결과(어느 결함 줄이 `결과 2`) 중 무엇으로 설명되는가.
- `Stateflow 0`인가. 이 모델에는 Stateflow가 없다. 0이 아니고 Unsatisfiable과 비슷하게 크면 Stateflow를 가려내는
  판단(`sfObjType`이 있으면 Stateflow로 봄)이 틀린 것이다.
- `결함 FAIL`이 결함 TC 수와 같고 `PASS 0 기타 0`인가. 결함 줄의 판정이 모두 `FAIL`인가. `판정 FINAL`이면 기대값 갱신 뒤
  재실행한 결과이고, `INITIAL`이면 재실행이 없었던 것이다.
- 그 FAIL이 진짜 FAIL인가. 판정 콜백은 커버리지나 블록을 읽지 못하면 검증 대신 오류를 던지는데, Test Manager가 이것도
  Failed로 적을 수 있다. Test Manager의 Results and Artifacts에서 이번 실행 결과 → 한 대상의 Test Case → 번호가 가장 큰
  Iteration(결함 Iteration) → Custom Criteria Results를 연다. `실행 횟수`가 든 검증이 실패로 나오면 `verify 실패`,
  오류 메시지가 나오면 `오류`다. 이 화면에는 블록 이름이 보이므로 캡처하지 않는다.
- 보통 Iteration의 PASS·FAIL 수가 전에 알던 값과 같고 `이전과 다름 0`인가. `이전 판정 없음`이면 직전 실행이 정리되지
  않았던 것이니 수만 비교한다.
- `결정 커버리지`가 이전과 같은가(1절에서 대상마다 20/22). 이 값은 결과 정리가 CVF를 붙여 쓴 CUT별 `TestSummary.xlsx`의
  `Coverage` 시트(CUT·Decision 행)에서 읽는다. 1절 값은 standalone의 `CoverageSummary.xlsx`라 출처가 다르다. 다르면
  두 값을 함께 적어 달라.

돌려줄 것: 화면 캡처 한 장과 Custom Criteria 결과 한 단어(`verify 실패` 또는 `오류`). `기타 블록`이 있었으면 그 종류가
Switch/Max/다른 것 중 무엇인지 한 줄. 진단 파일과 Test Manager 결과 화면은 사용자 PC에서만 보고 밖으로 보내지 않는다.

## 5. standalone 제출물과 최종 문서에서 결함 TC 확인하기

왜: 4절은 1단계(PER_CUT) 실행에서 결함 TC가 FAIL인지 봤다. 결함 판정 콜백은 standalone 번들에서도 돌아야 하는데,
번들은 Test Case를 내보낸 모델로 다시 가리켜서 콜백이 CUT 블록을 찾는 길이 달라진다. 그래서 사용 설명서의 평소 3단계와
5단계 명령(`st_run_standalone_coverage_pipeline('SaveTestResult', true)`, `st_export_final_document('CoveragePipelineId', ...)`)을
그대로 돌리고, standalone 결과에서 결함 Iteration이 FAIL인지, 최종 문서에 결함 행이 제대로 적히는지 숫자로만 본다.

순서: 4절이 `준비·실행 OK | 결과 정리 OK`로 끝난 뒤에 돌린다(최종 문서는 4절의 PER_CUT 판정을 읽는다). 모델 프로젝트(.prj)를
연다. 클론에서 main을 pull한다. 열려 있는 모델 중 저장 안 한 것이 없을 때 아래 블록을 붙여 넣는다. 툴킷 폴더를 고르는 창이
뜬다. standalone 파이프라인은 원본 모델·Harness·Test File을 저장하고 닫으며 평소 3단계만큼 걸린다. 끝나면 Test Manager가
열리고 standalone 결과가 들어와 있다. 실행 중 콘솔 줄은 끝에 지워지고 숫자만 남는다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
loadedNames = find_system('type', 'block_diagram');
if any(strcmp(get_param(loadedNames, 'Dirty'), 'on')), fprintf('저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요\n'); warning(warnState); return; end
idOf = @(ex) char(strjoin([string(ex.identifier) repmat("(식별자 없음)", 1, double(isempty(ex.identifier)))], ''));
diagFile = 'st_defect_standalone_final.txt';
fid = fopen(fullfile(tempdir, diagFile), 'w');
if fid < 0, fid = fopen('nul', 'w'); end
cfg = st_config();
screenLines = {sprintf('MATLAB %s', version('-release'))};
T = table();
try
    evalc('T = st_load_targets(cfg.OnlyEnabled);');
catch loadError
    screenLines{end+1} = sprintf('대상 목록 읽기 실패 | %s', idOf(loadError));
    fprintf(fid, '[대상 목록]\n%s\n\n', getReport(loadError, 'extended', 'hyperlinks', 'off'));
end
defectNames = cell(height(T), 1);
for rowIndex = 1:height(T)
    defectNames{rowIndex} = strings(0, 1);
    try
        evalc('sldvProfile = st_get_sldv_profile(T(rowIndex,:), cfg);');
        defectNames{rowIndex} = reshape(string({sldvProfile.DefectIterations.Name}), [], 1);
    catch profileError
        screenLines{end+1} = sprintf('대상 %d | SLDV profile 읽기 실패 | %s', double(T.No(rowIndex)), idOf(profileError));
        fprintf(fid, '[대상 %d SLDV profile]\n%s\n\n', double(T.No(rowIndex)), getReport(profileError, 'extended', 'hyperlinks', 'off'));
    end
end
pipelineInfo = []; pipelineText = '건너뜀';
if height(T) > 0
    try
        pipelineInfo = st_run_standalone_coverage_pipeline('SaveTestResult', true);
        pipelineText = ['OK | 상태 ' pipelineInfo.Status];
    catch pipelineError
        pipelineText = ['실패 ' idOf(pipelineError)];
        fprintf(fid, '[standalone 파이프라인]\n%s\n\n', getReport(pipelineError, 'extended', 'hyperlinks', 'off'));
    end
end
screenLines{end+1} = sprintf('대상 %d | standalone 파이프라인 %s', height(T), pipelineText);
haveFinal = false; finalText = '건너뜀';
if ~isempty(pipelineInfo)
    try
        evalc('[finalSheet, finalFile] = st_export_final_document(''CoveragePipelineId'', pipelineInfo.PipelineId);');
        resultCells = readcell(finalFile, 'Sheet', 'TestResults');
        resultCells(cellfun(@(x) all(ismissing(x)), resultCells)) = {''};
        headerText = string(cellfun(@(x) char(string(x)), resultCells(1, :), 'UniformOutput', false));
        rowCount = min(height(finalSheet), size(resultCells, 1) - 1);
        textColumn = @(name) string(cellfun(@(x) char(string(x)), ...
            resultCells(2:rowCount + 1, find(headerText == name, 1)), 'UniformOutput', false));
        caseColumn = textColumn("TestCaseName"); iterationColumn = textColumn("Iteration명"); reasonColumn = textColumn("확인 사유");
        isDLine = ~cellfun(@isempty, regexp(cellstr(finalSheet.Description(1:rowCount)), '^D\d+ \[', 'once'));
        [~, finalName, finalExt] = fileparts(finalFile);
        finalText = ['OK | ' finalName finalExt]; haveFinal = true;
    catch finalError
        finalText = ['실패 ' idOf(finalError)];
        fprintf(fid, '[최종 문서]\n%s\n\n', getReport(finalError, 'extended', 'hyperlinks', 'off'));
    end
end
screenLines{end+1} = sprintf('최종 문서 %s', finalText);
haveStandalone = false; importText = '건너뜀';
if ~isempty(pipelineInfo)
    try
        if ~any(strcmp(get_param(find_system('type', 'block_diagram'), 'Dirty'), 'on')), bdclose('all'); end
        evalc('openInfo = st_open_standalone_test_manager(''PipelineId'', pipelineInfo.PipelineId, ''ClearTestManager'', true, ''ImportResults'', true);');
        importText = openInfo.ResultStatus;
        if strcmp(openInfo.ResultStatus, 'IMPORTED')
            evalc('[~, standaloneRows] = st_collect_test_result_summary(sltest.testmanager.getResultSets, T, "STANDALONE");');
            haveStandalone = true;
        end
    catch importError
        importText = ['실패 ' idOf(importError)];
        fprintf(fid, '[standalone 결과]\n%s\n\n', getReport(importError, 'extended', 'hyperlinks', 'off'));
    end
end
screenLines{end+1} = sprintf('standalone 결과 가져오기 %s', importText);
codeNames = ["UNREACHABLE_DEFECT", "UNREACHABLE_DEFECT_APPROXIMATE", "UNREACHABLE_DEFECT_PASSED", "FAILED"];
totals = zeros(1, 7);
for rowIndex = 1:height(T)
    rowNo = double(T.No(rowIndex)); caseName = string(T.TestCaseName(rowIndex)); names = defectNames{rowIndex};
    standaloneCaseText = '-';
    if haveStandalone
        caseIterations = standaloneRows(standaloneRows.TestCaseName == caseName, :);
        defectOutcomes = upper(caseIterations.Outcome(ismember(caseIterations.IterationName, names)));
        outcomeCounts = [numel(defectOutcomes), sum(defectOutcomes == "FAILED"), sum(defectOutcomes == "PASSED")];
        totals(1:3) = totals(1:3) + outcomeCounts;
        standaloneCaseText = sprintf('%d개 FAIL %d PASS %d 기타 %d', outcomeCounts, outcomeCounts(1) - sum(outcomeCounts(2:3)));
    end
    finalRowText = '-'; codeText = '-';
    if haveFinal
        inCase = caseColumn == caseName; isDefectRow = inCase & ismember(iterationColumn, names);
        codeCounts = zeros(1, numel(codeNames)); duplicateCount = 0;
        for r = find(inCase)'
            tokens = strtrim(split(reasonColumn(r), "|"));
            if isDefectRow(r), codeCounts = codeCounts + ismember(codeNames, tokens); end
            duplicateCount = duplicateCount + any(tokens == "DUPLICATE_TEST_CASE_ID");
        end
        lineCounts = [sum(isDefectRow), sum(isDefectRow & isDLine), sum(isDefectRow & ~isDLine)];
        totals(4:7) = totals(4:7) + [lineCounts, duplicateCount];
        finalRowText = sprintf('%d행 D 줄 %d 경로 %d', lineCounts);
        codeText = sprintf('UNREACHABLE_DEFECT %d | _APPROXIMATE %d | _PASSED %d | FAILED %d | 전체 행 DUPLICATE_TEST_CASE_ID %d', ...
            codeCounts, duplicateCount);
    end
    screenLines{end+1} = sprintf('대상 %d | 결함 TC %d | standalone 결함 %s | 최종 문서 결함 %s', rowNo, numel(names), ...
        standaloneCaseText, finalRowText);
    screenLines{end+1} = sprintf('대상 %d | 사유 %s', rowNo, codeText);
end
screenLines{end+1} = sprintf('합계 | standalone 결함 %d개 FAIL %d PASS %d | 최종 문서 결함 %d행 D 줄 %d 경로 %d | DUPLICATE_TEST_CASE_ID %d', ...
    totals);
fprintf(fid, '[화면 전체]\n'); fprintf(fid, '%s\n', screenLines{:}); fclose(fid);
clc;
for k = 1:min(38, numel(screenLines)), fprintf('%s\n', screenLines{k}); end
if numel(screenLines) > 38, fprintf('%d줄 더 있음. 진단 파일 끝에 모두 있습니다\n', numel(screenLines) - 38); end
fprintf('진단 전문 파일: %s (임시 폴더)\n', diagFile);
warning(warnState);
```

화면: 대상 행마다 두 줄, 끝에 합계 한 줄이 나온다. 대상은 Excel 행 번호(`No`)로만 적는다. `standalone 결함`은 standalone 결과에서
결함 Iteration의 판정 수다. `최종 문서 결함`은 최종 문서의 결함 행 수와, 그중 `Description`이 D 줄(`D3 [F]Switch ...`)인 행과 경로
표기(`Switch [false] (...)`)인 행의 수다. `사유` 줄은 결함 행의 `확인 사유`에 그 코드가 든 행 수이고,
`DUPLICATE_TEST_CASE_ID`만 그 Test Case의 모든 행에서 센다.

확인할 것:

- `standalone 파이프라인 OK`, `최종 문서 OK`, `standalone 결과 가져오기 IMPORTED`인가. 아니면 식별자를 보고, 진단 파일에서 그 절의
  첫 줄을 경로·이름 없이 말로 옮겨 달라. `NOT_SAVED`·`MISSING`은 파이프라인이 결과 파일을 남기지 않은 것이다.
- 대상마다 `결함 TC 2`이고 `standalone 결함 2개 FAIL 2 PASS 0 기타 0`인가.
- 대상마다 `최종 문서 결함 2행 D 줄 2 경로 0`인가. 계기가 된 두 블록은 CUT 바로 아래에 있으므로 둘 다 D 줄이어야 한다.
- `사유` 줄이 `UNREACHABLE_DEFECT 2`이고 나머지 코드(`_APPROXIMATE`, `_PASSED`, `FAILED`)가 0인가. `DUPLICATE_TEST_CASE_ID 0`인가.
- standalone의 FAIL이 진짜 FAIL인가. 열린 Test Manager의 Results and Artifacts에서 가져온 결과 → 한 대상의 Test Case → 번호가 가장
  큰 Iteration(결함 Iteration) → Custom Criteria Results를 연다. `실행 횟수`가 든 검증이 실패로 나오면 `verify 실패`, 오류 메시지가
  나오면 `오류`다. 이 화면에는 블록 이름이 보이므로 캡처하지 않는다.

돌려줄 것: 화면 캡처 한 장과 standalone Custom Criteria 결과 한 단어(`verify 실패` 또는 `오류`). 진단 파일, 최종 문서, Test Manager
결과 화면은 사용자 PC에서만 보고 밖으로 보내지 않는다.
