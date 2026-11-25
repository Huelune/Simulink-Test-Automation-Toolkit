# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 5. standalone 제출물·최종 문서의 결함 TC와 파이프라인이 저장한 Coverage 확인하기

왜: 2026-11-25 실제 모델의 1단계(PER_CUT) 실행에서 대상마다 결함 TC 2건(Switch, MinMax)이 생기고 FINAL 판정이 FAIL이었다.
보통 Iteration 판정은 그대로였고, 셋째 도달 불가 결과는 CVF가 빼는 하위 블록 안의 것이었다. 결함 판정 콜백은
standalone 번들에서도 돌아야 하는데, 번들은 Test Case를 내보낸 모델로 다시 가리켜서 콜백이 CUT 블록을 찾는 길이
달라진다. 그래서 사용 설명서의 평소 3단계와
5단계 명령(`st_run_standalone_coverage_pipeline('SaveTestResult', true)`, `st_export_final_document('CoveragePipelineId', ...)`)을
그대로 돌리고, standalone 결과에서 결함 Iteration이 FAIL인지, 최종 문서에 결함 행이 제대로 적히는지 숫자로만 본다.

같은 블록에서 파이프라인이 CUT마다 저장한 Coverage 원본(CVT)에 CVF를 걸어 보고서를 열고 모델에 Coverage를 색으로
표시한다(`ShowSavedCoverage`, 시뮬레이션 없음). 다시 실행하면 파이프라인보다 덜 충족되는데 원인을 아직 못 찾아서, 다시
실행하지 않고 보는 방법이다. 1단계 결과 정리의 결정 커버리지는 27/30이었다. SLDV 결정 목표 30개에서 도달 불가 3개만 뺀
값이라, CVF가 빼는 하위 블록의 결정이 그대로 들어 있는 것으로 보인다. 저장 Coverage 값과 나란히 본다.

순서:

1. 블록을 붙여 넣기 전에, 지난 1단계 실행의 결함 FAIL이 진짜 FAIL인지 본다. 이 블록은 실행 중에 Test Manager를 비우므로
   먼저 봐야 한다. 판정 콜백은 커버리지나 블록을 읽지 못하면 검증 대신 오류를 던지는데, Test Manager가 이것도 Failed로 적을
   수 있다. Test Manager의 Results and Artifacts에서 마지막 PER_CUT 실행 결과 → 한 대상의 Test Case → 번호가 가장 큰
   Iteration(결함 Iteration) → Custom Criteria Results를 연다. `실행 횟수`가 든 검증이 실패로 나오면 `verify 실패`, 오류
   메시지가 나오면 `오류`다. 결과가 이미 닫혀 있으면 `못 봄`으로 적는다. 이 화면에는 블록 이름이 보이므로 캡처하지 않는다.
2. 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다. 열려 있는 모델 중 저장 안 한 것이 없을 때 아래 블록을 붙여 넣는다.
   툴킷 폴더를 고르는 창이 뜬다. standalone 파이프라인은 원본 모델·Harness·Test File을 저장하고 닫으며 평소 3단계만큼
   걸린다. 끝나면 Test Manager가 열려 standalone 결과가 들어와 있고, 대상마다 저장 Coverage 보고서가 브라우저에 열리며
   standalone 모델에 Coverage 색이 칠해진다. 실행 중 콘솔 줄은 끝에 지워지고 숫자만 남는다.

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
try
    evalc('testResults = runtests(fullfile(st_project_root(), ''tests'', ''unit'', ''test_open_standalone_test_manager.m''));');
    screenLines{end+1} = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d | 미완료 %d', numel(testResults), sum([testResults.Passed]), ...
        sum([testResults.Failed]), sum([testResults.Incomplete]));
    failedTests = testResults([testResults.Failed] | [testResults.Incomplete]);
    for k = 1:numel(failedTests), screenLines{end+1} = sprintf('  실패 | %s', failedTests(k).Name); end %#ok<SAGROW>
catch testError
    screenLines{end+1} = sprintf('단위 테스트 | 실행 오류 | %s', idOf(testError));
end
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
haveStandalone = false; importText = '건너뜀'; saved = table(); savedText = '건너뜀';
if ~isempty(pipelineInfo)
    try
        if ~any(strcmp(get_param(find_system('type', 'block_diagram'), 'Dirty'), 'on')), bdclose('all'); end
        evalc(['openInfo = st_open_standalone_test_manager(''PipelineId'', pipelineInfo.PipelineId, ''ClearTestManager'', true, ' ...
            '''ImportResults'', true, ''ShowSavedCoverage'', true);']);
        importText = openInfo.ResultStatus; saved = openInfo.SavedCoverage;
        savedText = sprintf('OK %d 실패 %d', sum(saved.Status == "OK"), sum(saved.Status ~= "OK"));
        if strcmp(openInfo.ResultStatus, 'IMPORTED')
            evalc('[~, standaloneRows] = st_collect_test_result_summary(sltest.testmanager.getResultSets, T, "STANDALONE");');
            haveStandalone = true;
        end
    catch importError
        importText = ['실패 ' idOf(importError)];
        fprintf(fid, '[standalone 결과]\n%s\n\n', getReport(importError, 'extended', 'hyperlinks', 'off'));
    end
end
screenLines{end+1} = sprintf('standalone 결과 가져오기 %s | 저장 Coverage 보고서 %s', importText, savedText);
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
    savedRow = [];
    if height(saved) > 0, savedRow = find(saved.TestCaseName == caseName, 1); end
    if isempty(savedRow)
        screenLines{end+1} = sprintf('대상 %d | 저장 Coverage 없음', rowNo);
    elseif saved.Status(savedRow) == "OK"
        screenLines{end+1} = sprintf('대상 %d | 저장 Coverage CUT 결정 %d/%d | CUT 실행 %d/%d', rowNo, saved.DecisionCovered(savedRow), ...
            saved.DecisionTotal(savedRow), saved.ExecutionCovered(savedRow), saved.ExecutionTotal(savedRow));
    else
        screenLines{end+1} = sprintf('대상 %d | 저장 Coverage 실패 | 식별자 %s', rowNo, saved.ErrorId(savedRow));
    end
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

화면: 맨 위에 `단위 테스트` 한 줄, 이어서 파이프라인·최종 문서·결과 가져오기 줄, 대상 행마다 세 줄, 끝에 합계 한 줄이
나온다. 대상은 Excel 행 번호(`No`)로만 적는다. `standalone 결함`은 standalone 결과에서
결함 Iteration의 판정 수다. `최종 문서 결함`은 최종 문서의 결함 행 수와, 그중 `Description`이 D 줄(`D3 [F]Switch ...`)인 행과 경로
표기(`Switch [false] (...)`)인 행의 수다. `사유` 줄은 결함 행의 `확인 사유`에 그 코드가 든 행 수이고,
`DUPLICATE_TEST_CASE_ID`만 그 Test Case의 모든 행에서 센다. `저장 Coverage`는 파이프라인이 저장한 CVT에 CVF를 건 CUT의 결정·실행
커버리지다(`CoverageSummary.xlsx`와 같은 값).

확인할 것:

- `단위 테스트`의 실패·미완료가 0인가.
- `standalone 파이프라인 OK`, `최종 문서 OK`, `standalone 결과 가져오기 IMPORTED`인가. 아니면 식별자를 보고, 진단 파일에서 그 절의
  첫 줄을 경로·이름 없이 말로 옮겨 달라. `NOT_SAVED`·`MISSING`은 파이프라인이 결과 파일을 남기지 않은 것이다.
- 대상마다 `결함 TC 2`이고 `standalone 결함 2개 FAIL 2 PASS 0 기타 0`인가.
- 대상마다 `최종 문서 결함 2행 D 줄 2 경로 0`인가. 계기가 된 두 블록은 CUT 바로 아래에 있으므로 둘 다 D 줄이어야 한다.
- `사유` 줄이 `UNREACHABLE_DEFECT 2`이고 나머지 코드(`_APPROXIMATE`, `_PASSED`, `FAILED`)가 0인가. `DUPLICATE_TEST_CASE_ID 0`인가.
- standalone의 FAIL이 진짜 FAIL인가. 열린 Test Manager의 Results and Artifacts에서 가져온 결과 → 한 대상의 Test Case → 번호가 가장
  큰 Iteration(결함 Iteration) → Custom Criteria Results를 연다. `실행 횟수`가 든 검증이 실패로 나오면 `verify 실패`, 오류 메시지가
  나오면 `오류`다. 이 화면에는 블록 이름이 보이므로 캡처하지 않는다.
- 대상마다 `저장 Coverage CUT 결정 20/22 | CUT 실행 45/45`인가. 결정이 20/22이면, 1단계 결과 정리의 27/30은 CVF가 반영되지
  않은 값이다(결함 TC와는 별개로 따로 고친다). 브라우저에 열린 보고서의 Filter 항목에 뺀 것이 나오는가. standalone 모델에
  Coverage 색이 칠해지고 하위 Subsystem이 빠졌는가. 보고서와 모델 화면은 블록 이름이 보이므로 캡처하지 않는다.

돌려줄 것: 화면 캡처 한 장과 다음 세 줄. 1단계 Custom Criteria 결과 한 단어(`verify 실패`, `오류`, `못 봄`), standalone Custom
Criteria 결과 한 단어, "보고서에 필터 항목 나옴/안 나옴, 모델 색 표시 됨/안 됨". 진단 파일, 최종 문서, Test Manager
결과 화면은 사용자 PC에서만 보고 밖으로 보내지 않는다.
