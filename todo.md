# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 6. 1단계 결과 정리의 Coverage에 CVF가 걸리는지 확인하고, 결함 TC 남은 눈 확인 마치기

왜: 1단계(PER_CUT) 결과 정리의 CUT 결정 커버리지가 27/30이었고, 같은 CUT의 standalone 저장 Coverage는 20/22였다. 결과 정리는
저장한 ResultSet에서 coverage 객체를 꺼내 CVF를 붙인 뒤 보고서를 쓴다. 그런데 보고서는 Coverage 표, CVT·HTML, CVF 복사,
결정 목록을 만들 때마다 coverage를 다시 꺼냈다. Test Manager는 꺼낼 때마다 새 객체를 줄 수 있어서, CVF가 빠진 객체로
계산됐다. 지난번 이 절의 `전` 로그에서 CVF 복사가 6번 모두 0개였던 것이 그 증거다. 첫 수정은 결과 정리를 다시 할 때
`ResultCoverageDecisionReadbackFailed`로 멈춰서, CVF를 붙인 객체를 보고서에 직접 넘기는 방식으로 다시 고쳤다. 그래도 같은
오류가 났는데, 원인은 따로 있었다. standalone 모델은 Harness와 이름이 같다. 결과 정리는 Harness를 열어 두고 coverage를
읽는데, CVF를 만드는 코드가 그 Harness를 닫았다. 그러면 coverage를 읽을 때 Simulink가 그 이름의 모델을 경로에서 찾아, 5절이
경로에 넣은 standalone 모델을 연다. 그래서 첫 대상은 끝나고 다음 대상에서 멈췄다(지난번 `전` 로그의 CVF 복사 2번이 첫 대상의
것이다). 지난번 `CollectHarnessNameInUse`는 Harness 이름으로 Harness가 아닌 모델이 열린 것을 결과 정리가 잡은 것이다. 이제
CVF 생성은 자기가 연 Harness만 닫는다. 이 블록은 시작할 때 열린 모델도 모두 닫는다. 이 블록은 시뮬레이션 없이 결과 정리만
다시 하고, 전후 숫자를 비교한다. 결과 정리가 중간에 멈춰도 `후` 로그의 CVF 복사 횟수로 어디까지 갔는지 보인다. 결정 목록(`DecisionPoints`)은 CVF가
빼는 블록을 빼고 고르므로, 그 수도 바뀔 수 있다.

5절(standalone과 최종 문서)은 숫자가 모두 기대대로였다. 남은 것은 눈으로 볼 세 가지뿐이라 이 절에 옮겼다.

순서:

1. 블록을 붙여 넣기 전에, 5절 실행 뒤 열려 있는 화면에서 두 가지를 본다(블록이 열린 모델을 닫으므로 먼저 본다). 이 화면들은
   블록 이름이 보이므로 캡처하지 않는다.
   - standalone 결과: Test Manager의 Results and Artifacts에서 가져온 결과 → 한 대상의 Test Case → 번호가 가장 큰
     Iteration(결함 Iteration) → Custom Criteria Results. `실행 횟수`가 든 검증이 실패로 나오면 `verify 실패`, 오류 메시지가
     나오면 `오류`. 결과가 이미 닫혀 있으면 `못 봄`.
   - 5절이 연 저장 Coverage 보고서(브라우저)의 Filter 항목에 뺀 것이 나오는지, standalone 모델에 Coverage 색이 칠해지고 하위
     Subsystem이 빠졌는지. 이미 닫았으면 `못 봄`.
2. 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다. 열려 있는 모델 중 저장 안 한 것이 없을 때 아래 블록을 붙여 넣는다.
   툴킷 폴더를 고르는 창이 뜬다. 결과 정리만 다시 하므로 평소 결과 정리만큼 걸린다.
3. 블록이 끝나면 결과 정리가 다시 가져온 1단계 결과가 Test Manager에 들어와 있다. 1번과 같은 순서로 1단계 결함 Iteration의
   Custom Criteria Results를 본다. 결과가 없으면 `못 봄`.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
loadedNames = find_system('type', 'block_diagram');
if any(strcmp(get_param(loadedNames, 'Dirty'), 'on')), fprintf('저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요\n'); warning(warnState); return; end
bdclose('all');
idOf = @(ex) char(strjoin([string(ex.identifier) repmat("(식별자 없음)", 1, double(isempty(ex.identifier)))], ''));
dashText = @(value) strrep(value, 'NaN', '-');
diagFile = 'st_cvf_collect_check.txt';
fid = fopen(fullfile(tempdir, diagFile), 'w');
if fid < 0, fid = fopen('nul', 'w'); end
cfg = st_config();
screenLines = {sprintf('MATLAB %s', version('-release'))};
% 가. 단위 테스트
try
    evalc(['testResults = runtests({fullfile(st_project_root(), ''tests'', ''unit'', ''test_coverage_filters.m''), ' ...
        'fullfile(st_project_root(), ''tests'', ''unit'', ''test_per_cut_execution.m'')});']);
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
end
% 나. 결과 정리 전(1)과 후(2): 결과 정리 로그의 CVF 복사 횟수, 대상별 CUT 결정·실행 커버리지와 결정 목록 수
numbers = nan(height(T), 5, 2); copyCounts = nan(2, 2); logNames = {'-', '-'}; collectText = '건너뜀';
for phase = 1:2
    if phase == 2
        try
            evalc('st_collect_per_cut_results();');
            collectText = 'OK';
        catch collectError
            collectText = ['실패 ' idOf(collectError)];
            fprintf(fid, '[결과 정리]\n%s\n\n', getReport(collectError, 'extended', 'hyperlinks', 'off'));
        end
    end
    logFiles = dir(fullfile(char(cfg.ResultDir), 'logs', '*_st_collect_per_cut_results*.log'));
    if ~isempty(logFiles), logFiles = logFiles(~endsWith({logFiles.name}, '.console.log')); end
    if ~isempty(logFiles)
        [~, newest] = max([logFiles.datenum]);
        logNames{phase} = logFiles(newest).name;
        logLines = splitlines(string(fileread(fullfile(logFiles(newest).folder, logFiles(newest).name))));
        copyLines = logLines(contains(logLines, "Portable coverage filter copy complete"));
        copyCounts(phase, :) = [sum(contains(copyLines, "files=0")), sum(~contains(copyLines, "files=0"))];
    end
    if phase == 2 && ~strcmp(collectText, 'OK'), break; end
    try
        evalc('runSource = st_final_document_run_source(cfg, ''PER_CUT'');');
    catch sourceError
        screenLines{end+1} = sprintf('결과 정리 파일 찾기 실패 %d | %s', phase, idOf(sourceError));
        fprintf(fid, '[결과 정리 파일 %d]\n%s\n\n', phase, getReport(sourceError, 'extended', 'hyperlinks', 'off'));
        continue
    end
    for rowIndex = 1:height(T)
        workbookFiles = runSource.Workbooks.File(runSource.Workbooks.No == double(T.No(rowIndex)));
        if isempty(workbookFiles), continue; end
        try
            coverageRows = readtable(workbookFiles(end), 'Sheet', 'Coverage', 'TextType', 'string', 'VariableNamingRule', 'preserve');
            cutRows = coverageRows(coverageRows.Level == "CUT", :);
            decisionRows = cutRows(cutRows.Metric == "Decision", :); executionRows = cutRows(cutRows.Metric == "Execution", :);
            if height(decisionRows) > 0, numbers(rowIndex, 1:2, phase) = [decisionRows.Covered(1), decisionRows.Total(1)]; end
            if height(executionRows) > 0, numbers(rowIndex, 3:4, phase) = [executionRows.Covered(1), executionRows.Total(1)]; end
            pointRows = readtable(workbookFiles(end), 'Sheet', 'DecisionPoints', 'TextType', 'string', 'VariableNamingRule', 'preserve');
            numbers(rowIndex, 5, phase) = height(pointRows);
        catch readError
            fprintf(fid, '[대상 %d 읽기 %d]\n%s\n\n', double(T.No(rowIndex)), phase, getReport(readError, 'extended', 'hyperlinks', 'off'));
        end
    end
end
screenLines{end+1} = sprintf('결과 정리 다시 하기 %s', collectText);
screenLines{end+1} = sprintf('결과 정리 로그 | 전 %s | 후 %s', logNames{1}, logNames{2});
screenLines{end+1} = dashText(sprintf('CVF 복사 0개/1개 이상 | 전 %g/%g | 후 %g/%g', copyCounts(1, :), copyCounts(2, :)));
for rowIndex = 1:height(T)
    before = numbers(rowIndex, :, 1); after = numbers(rowIndex, :, 2);
    screenLines{end+1} = dashText(sprintf('대상 %d | CUT 결정 전 %g/%g 후 %g/%g | CUT 실행 전 %g/%g 후 %g/%g | 결정 목록 전 %g 후 %g', ...
        double(T.No(rowIndex)), before(1:2), after(1:2), before(3:4), after(3:4), before(5), after(5))); %#ok<SAGROW>
end
fprintf(fid, '[화면 전체]\n'); fprintf(fid, '%s\n', screenLines{:}); fclose(fid);
clc;
for k = 1:min(38, numel(screenLines)), fprintf('%s\n', screenLines{k}); end
if numel(screenLines) > 38, fprintf('%d줄 더 있음. 진단 파일 끝에 모두 있습니다\n', numel(screenLines) - 38); end
fprintf('진단 전문 파일: %s (임시 폴더)\n', diagFile);
warning(warnState);
```

화면: `단위 테스트` 한 줄, `결과 정리 다시 하기` 한 줄, 결과 정리 로그 이름 한 줄, `CVF 복사` 한 줄, 대상 행마다 한 줄. 대상은 Excel 행 번호
(`No`)로만 적는다. `전`은 지난 결과 정리가 남긴 것, `후`는 이번에 다시 한 결과 정리다. `CVF 복사 0개/1개 이상`은
결과 정리 로그에서 보고서가 coverage에 붙은 CVF를 찾지 못한 횟수와 찾아 복사한 횟수다.

확인할 것:

- `단위 테스트`의 실패·미완료가 0이고 `결과 정리 다시 하기 OK`인가. 아니면 식별자를 보고, 진단 파일에서 그 절의 첫 줄을
  경로·이름 없이 말로 옮겨 달라.
- `CVF 복사`의 `후`가 1개 이상 쪽만 있는가(0개가 0). `전`은 지난번 중간에 멈춘 결과 정리라 참고만 한다.
- 대상마다 `CUT 결정 후 20/22`, `CUT 실행 후 45/45`인가(standalone 저장 Coverage와 같은 값). `전`은 지난 결과 정리가 남긴
  파일 값이다. 지난번 화면에서는 27/30, 66/66이었다.
- `결정 목록 전 n 후 m`이 바뀌었는가. 바뀌었으면 CVF가 빼는 블록이 결정 목록에서 빠진 것이다. 최종 문서의 D 줄 수도 그만큼
  바뀐다.

돌려줄 것: 화면 캡처 한 장과 다음 세 줄. standalone Custom Criteria 결과 한 단어(`verify 실패`, `오류`, `못 봄`), 1단계 Custom
Criteria 결과 한 단어, "보고서에 필터 항목 나옴/안 나옴/못 봄, 모델 색 표시 됨/안 됨/못 봄". 진단 파일, Test Manager 결과
화면, 보고서와 모델 화면은 사용자 PC에서만 보고 밖으로 보내지 않는다.
