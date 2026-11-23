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

## 2. CUT를 C 코드로 만들어 로직 읽기

왜: 되먹임과 Goto/From이 얽혀 블록을 손으로 따라가기 어렵다. Simulink Coder로 CUT를 C 코드로 만들면 카운터, 리셋 조건, Enable 조건이
한 함수 안에 위에서 아래로 풀려 나온다. 그러면 안쪽 Switch의 거짓 쪽에 닿을 수 없는 사유를 읽기 쉽다. 코드에는 블록·신호 이름이
그대로 들어 있으니 보내지 말고 직접 읽는다. 원본 모델의 코드 생성 설정은 바꿨다가 끝나면 되돌리고, 모델은 저장하지 않는다.
코드는 `tempdir` 아래 새 폴더에 만들고 컴파일은 하지 않는다(코드만 만든다).

순서: 모델 프로젝트를 열고 `st_setup`을 돌린다. Top Model을 열고 **CUT Subsystem을 클릭해 선택**한 뒤 붙여 넣는다. CUT가 크면 몇 분 걸린다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
fprintf('라이선스 | Simulink Coder %d | Embedded Coder %d\n', license('test', 'Real-Time_Workshop'), license('test', 'RTW_Embedded_Coder'));
if ~license('test', 'Real-Time_Workshop'), fprintf('Simulink Coder 라이선스가 없어 코드를 만들 수 없습니다\n'); warning(warnState); return; end
cutBlock = gcb; topName = bdroot(cutBlock);
fprintf('선택 블록 종류 %s\n', get_param(cutBlock, 'BlockType'));
if strcmp(get_param(topName, 'Dirty'), 'on'), fprintf('모델에 저장 안 한 변경이 있습니다. 저장하거나 되돌린 뒤 다시 돌려 주세요\n'); warning(warnState); return; end
codeFolder = tempname; mkdir(codeFolder);
oldGen = Simulink.fileGenControl('getConfig'); oldGenCodeOnly = get_param(topName, 'GenCodeOnly'); oldReport = get_param(topName, 'GenerateReport');
try
    Simulink.fileGenControl('set', 'CodeGenFolder', codeFolder, 'CacheFolder', codeFolder, 'keepPreviousPath', true);
    set_param(topName, 'GenCodeOnly', 'on', 'GenerateReport', 'on');
    evalc('slbuild(cutBlock);');
    sourceFiles = dir(fullfile(codeFolder, '**', '*.c'));
    fprintf('코드 생성 완료 | C 파일 %d개 | 가장 큰 파일 줄 수 %d\n', numel(sourceFiles), ...
        max([0, arrayfun(@(f) numel(splitlines(fileread(fullfile(f.folder, f.name)))), sourceFiles)']));
catch buildError
    fprintf('코드 생성 실패 | 식별자 %s\n', buildError.identifier);
end
set_param(topName, 'GenCodeOnly', oldGenCodeOnly, 'GenerateReport', oldReport); set_param(topName, 'Dirty', 'off');
Simulink.fileGenControl('setConfig', 'config', oldGen);
fprintf('코드 폴더를 탐색기로 엽니다(코드는 보내지 마세요)\n'); winopen(codeFolder);
warning(warnState);
```

확인할 것: 코드 생성 완료가 나오는지. 열린 폴더에서 CUT 이름의 `.c` 파일을 연다. 그 안의 `_step` 함수(또는 `_Outputs`, `_Update`)에서 다음을 찾는다.
- 50과 비교하는 줄(Enable 조건)
- `== 2`인 줄(카운터 1 리셋 조건)
- 안쪽 Switch의 `>= 1` 줄
`== 2`의 왼쪽 값이 어디서 대입되는지 위로 올라가 보면, Enable이 켜진 동안 그 값이 2가 될 수 없는 이유가 보인다.

돌려줄 것: 화면 캡처 한 장(개수만 찍힌다). 그리고 찾은 사유를 블록·변수 이름 없이 말로 한 줄.
