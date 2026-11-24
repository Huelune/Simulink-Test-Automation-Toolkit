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

## 3. 결함 TC 작업의 단위 테스트와 회귀 테스트 돌리기

왜: 도달 불가 결과를 결함 TC로 남기는 작업(설정, 결함 Iteration 만들기, 기대값 연결, 결과 찾기, 최종 문서 결함 행)에서
새로 만든 단위 테스트와, 그 작업이 바꾼 함수를 쓰는 기존 단위 테스트를 한 번에 돌린다. 모델이나 시뮬레이션이 필요한
테스트는 뺐다.

순서: 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다. 아래 블록을 붙여 넣는다. 툴킷 폴더(`st_setup.m`이 있는
폴더)를 고르는 창이 뜬다. 파일이 21개라 몇 분 걸릴 수 있다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
testNames = {'test_defect_settings', 'test_build_defect_iterations', 'test_expected_iteration_bindings', ...
    'test_find_iteration_result', 'test_final_document_defects', 'test_export_final_document', ...
    'test_expected_update_modes', 'test_probe_sldv_objectives', 'test_decision_outcomes', ...
    'test_no_output_verify_skip', 'test_partial_iteration_update', 'test_per_cut_execution', ...
    'test_sldv_naming_and_off_profile', 'test_harness_clone', 'test_cut_name_slash_escaping', ...
    'test_mat_file_mode', 'test_signal_editor_no_inport', 'test_incremental_workflow', ...
    'test_library_link_harness_protection', 'test_sldv_config', 'test_project_layout'};
diagFile = 'st_defect_unit_tests.txt';
fid = fopen(fullfile(tempdir, diagFile), 'w');
if fid < 0, fprintf('진단 파일을 만들지 못해 화면 정보만 보입니다\n'); fid = fopen('nul', 'w'); end
failLines = {}; totalPassed = 0; totalFailed = 0; totalIncomplete = 0; errorCount = 0;
fprintf('MATLAB %s\n', version('-release'));
for k = 1:numel(testNames)
    try
        evalc('fileResults = runtests(fullfile(st_project_root(), ''tests'', ''unit'', [testNames{k} ''.m'']));');
    catch runError
        errorCount = errorCount + 1;
        errorId = runError.identifier; if isempty(errorId), errorId = '(식별자 없음)'; end
        fprintf('%s | 실행 오류 | %s\n', testNames{k}, errorId);
        fprintf(fid, '[%s] 실행 오류: %s\n\n', testNames{k}, runError.message);
        continue
    end
    passedCount = sum([fileResults.Passed]); failedCount = sum([fileResults.Failed]); incompleteCount = sum([fileResults.Incomplete]);
    totalPassed = totalPassed + passedCount; totalFailed = totalFailed + failedCount; totalIncomplete = totalIncomplete + incompleteCount;
    fprintf('%s | 통과 %d | 실패 %d | 미완료 %d\n', testNames{k}, passedCount, failedCount, incompleteCount);
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
fclose(fid);
fprintf('합계 | 통과 %d | 실패 %d | 미완료 %d | 실행 오류 %d\n', totalPassed, totalFailed, totalIncomplete, errorCount);
for k = 1:min(15, numel(failLines)), fprintf('%s\n', failLines{k}); end
if numel(failLines) > 15, fprintf('실패 %d개 더 있음. 이름은 진단 파일에서 봅니다\n', numel(failLines) - 15); end
fprintf('진단 전문 파일: %s (임시 폴더)\n', diagFile);
warning(warnState);
```

확인할 것: 합계의 실패, 미완료, 실행 오류가 모두 0인가. 0이 아니면 파일 줄과 `실패`/`미완료 | 테스트 이름 | 종류` 줄을 본다.

돌려줄 것: 화면 캡처 한 장. 진단 파일은 사용자 PC에서만 보고 밖으로 보내지 않는다. 실패한 테스트가 있으면, 파일에서
찾은 진단의 첫 줄을 경로와 이름을 뺀 말로 바꿔 적어 달라.
