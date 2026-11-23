# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. standalone 제출물을 CVF 건 채로 열어 실행하고 결과 보기

왜: 결과를 가져온 뒤에는 Coverage Filters의 Add로도 CVF가 적용되지 않았다. 문서가 정한 방법은 실행 전에
Test Case의 Coverage 설정에 CVF를 넣고 돌리는 것이다. 이미 있는 `st_open_standalone_test_manager`가
standalone 제출물의 Test File을 열고, 모델을 로드하고, 대상마다 CVF를 Test Case에 넣는다. 그 상태로 실행해
결과에 CVF가 적용되는지 본다. 열려 있던 모델과 Test Manager의 Test File·결과는 먼저 닫는다(같은 이름 충돌 방지).
저장 안 한 모델이 있으면 닫지 않고 멈춘다.
가장 최근 standalone 실행을 쓴다. 실행하면 툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다.
CUT 수만큼 시뮬레이션하므로 시간이 걸린다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
% 같은 이름의 모델이 다른 폴더에서 열려 있으면 열기가 멈춘다. 저장 안 한 모델이 없을 때만 모두 닫는다.
loadedNames = find_system('type', 'block_diagram');
dirtyCount = sum(strcmp(get_param(loadedNames, 'Dirty'), 'on'));
if dirtyCount > 0, fprintf('저장 안 한 모델 %d개: 저장하거나 닫은 뒤 다시 돌려 주세요\n', dirtyCount); warning(warnState); return; end
bdclose('all'); fprintf('열려 있던 모델 %d개를 닫음\n', numel(loadedNames));
stage = '열기';
try
    evalc('openInfo = st_open_standalone_test_manager(''LoadModels'', true, ''ApplyFilters'', true, ''ClearTestManager'', true);');
    fprintf('MATLAB %s | 대상 폴더 %d | 모델 %d | CVF 넣음 %d\n', version('-release'), ...
        numel(openInfo.AddedFolders), numel(openInfo.LoadedModels), openInfo.AppliedFilterCount);
    stage = '실행';
    % Test Case마다 따로 돌려 CUT마다 결과가 하나씩 생기게 한다
    allCases = getAllTestCases(openInfo.TestFile);
    for k = 1:numel(allCases)
        evalc('caseResult = run(allCases(k));');
        fprintf('실행 %d/%d | 통과 %d | 실패 %d | 미완료 %d\n', k, numel(allCases), ...
            caseResult.NumPassed, caseResult.NumFailed, caseResult.NumIncomplete);
    end
catch stepError
    fprintf('%s 실패 | 식별자 %s\n', stage, stepError.identifier);
end
sltest.testmanager.view; warning(warnState);
```

확인할 것: Results and Artifacts에 결과가 CUT 수만큼 따로 들어왔는지. 각 결과의 맨 위 Results 항목을 눌렀을 때 Coverage Filters 칸에 CVF가 있는지,
Aggregated Coverage Results의 %가 CVF 없이 볼 때와 다른지.

돌려줄 것: 화면 캡처 한 장과 "Coverage Filters에 CVF 있음/없음, %가 바뀜/안 바뀜" 한 줄.
Coverage 표는 블록 이름이 보이므로 캡처하지 마세요.
