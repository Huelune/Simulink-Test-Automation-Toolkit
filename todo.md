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

## 3. Unsatisfiable Switch의 제어 신호를 거꾸로 따라가 보기

왜: CUT 자체에서 닿을 수 없다고 증명된 결정의 사유를 정확히 알아야 한다. 그 Switch의 제어 신호는 출력을 되먹임해서 다시 쓰는
구조라서 손으로 따라가기 어렵다. 되먹임 고리에는 반드시 상태 블록(Unit Delay, Memory, Delay, Integrator 등)이 있다. 그 블록의
초기값과, 고리 안에서 값이 어떻게만 바뀌는지(늘기만 하는지, 범위가 막혀 있는지)가 보통 사유다. 모델에서 Switch 하나를 클릭해
선택한 뒤 이 블록을 돌리면, 제어 입력에서 거꾸로 올라가며 지나는 블록의 **종류**와 숫자 설정만 찍는다. 그 숫자 설정은 Switch의
Threshold, 상태 블록의 초기값, Saturation 한계, 상수 값이다. 블록 이름은 찍지 않는다. 같은 블록을 다시 만나면 고리로 표시하고 멈춘다.
모델 프로젝트를 열고 `st_setup`을 돌린 MATLAB에서 Top Model을 연 뒤, 목록 파일에 있던 Switch를 클릭해 선택하고 붙여 넣는다.
MinMax를 볼 때는 MinMax를 선택하고 `startPort = 2;`로 바꾼다.
선택 블록을 감싼 Enabled Subsystem이 언제 켜지는지 보려면 같은 블록을 선택한 채 `startPort = 'enable';`로 바꾼다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
startPort = 2;   % Switch는 2(제어 입력), MinMax는 살펴볼 입력 번호
startBlock = gcb;
if ischar(startPort) && strcmp(startPort, 'enable')
    % 선택 블록을 감싼 가장 가까운 Enabled Subsystem의 Enable 입력부터 따라간다.
    while ~strcmp(get_param(startBlock, 'Parent'), bdroot(startBlock))
        startBlock = get_param(startBlock, 'Parent');
        startHandles = get_param(startBlock, 'PortHandles');
        if ~isempty(startHandles.Enable), break; end
    end
end
visited = {}; queue = {startBlock, startPort, 0};
fprintf('시작 | 종류 %s', get_param(startBlock, 'BlockType'));
try, fprintf(' | Criteria %s | Threshold %s', get_param(startBlock, 'Criteria'), get_param(startBlock, 'Threshold')); catch, end
fprintf('\n');
while ~isempty(queue) && numel(visited) < 60
    block = queue{1, 1}; port = queue{1, 2}; depth = queue{1, 3}; queue(1, :) = [];
    handles = get_param(block, 'PortHandles');
    if ischar(port), portHandle = handles.Enable; else, if port > numel(handles.Inport), continue; end, portHandle = handles.Inport(port); end
    if isempty(portHandle), continue; end
    line = get_param(portHandle, 'Line'); if line < 0, continue; end
    source = get_param(line, 'SrcBlockHandle'); if source < 0, continue; end
    sourcePath = getfullname(source); sourceType = get_param(source, 'BlockType');
    indent = repmat('  ', 1, depth + 1);
    if any(strcmp(visited, sourcePath)), fprintf('%s%s (이미 지난 블록, 되먹임 고리)\n', indent, sourceType); continue; end
    visited{end + 1} = sourcePath; %#ok<SAGROW>
    detail = '';
    for name = {'InitialCondition', 'X0', 'UpperLimit', 'LowerLimit', 'Value', 'Threshold', 'Criteria', 'Operator', 'Inputs', 'Function', 'OutDataTypeStr'}
        try
            settingText = char(string(get_param(source, name{1})));
            % 변수 이름은 내부 정보다. 숫자로 읽히지 않는 값 설정은 그 값을 sldd·워크스페이스에서 찾아 숫자로 바꾼다.
            if any(strcmp(name{1}, {'InitialCondition', 'X0', 'UpperLimit', 'LowerLimit', 'Value', 'Threshold'})) && isempty(str2num(settingText)) %#ok<ST2NM>
                try, settingText = ['변수=' mat2str(slResolve(settingText, source))]; catch, settingText = '변수(값 못 읽음)'; end
            end
            detail = [detail ' | ' name{1} ' ' settingText]; %#ok<AGROW>
        catch
        end
    end
    fprintf('%s%s%s\n', indent, sourceType, detail);
    switch sourceType
        case 'Constant'
            continue;
        case 'From'
            % 같은 태그의 Goto로 건너가 그 입력을 계속 따라간다(태그 이름은 찍지 않는다).
            gotoBlocks = find_system(bdroot(sourcePath), 'FollowLinks', 'on', 'LookUnderMasks', 'all', ...
                'BlockType', 'Goto', 'GotoTag', get_param(source, 'GotoTag'));
            sameLevel = gotoBlocks(strcmp(get_param(gotoBlocks, 'Parent'), get_param(source, 'Parent')));
            if ~isempty(sameLevel), gotoBlocks = sameLevel; end
            fprintf('%s  → 같은 태그의 Goto %d개 중 1번째로 이어 감\n', indent, numel(gotoBlocks));
            if ~isempty(gotoBlocks), queue(end + 1, :) = {gotoBlocks{1}, 1, depth + 1}; end %#ok<SAGROW>
        case 'Inport'
            % Subsystem 안의 입력 포트면 바깥 Subsystem의 같은 번호 입력으로 올라간다.
            parentBlock = get_param(sourcePath, 'Parent');
            if ~strcmp(parentBlock, bdroot(sourcePath))
                fprintf('%s  → 바깥 Subsystem 입력 %s번으로 올라감\n', indent, get_param(source, 'Port'));
                queue(end + 1, :) = {parentBlock, str2double(get_param(source, 'Port')), depth + 1}; %#ok<SAGROW>
            end
        case 'SubSystem'
            % Subsystem 출력이면 안쪽의 같은 번호 Outport로 들어간다.
            portNumber = get_param(get_param(line, 'SrcPortHandle'), 'PortNumber');
            outportBlock = find_system(sourcePath, 'SearchDepth', 1, 'FollowLinks', 'on', 'LookUnderMasks', 'all', ...
                'BlockType', 'Outport', 'Port', num2str(portNumber));
            fprintf('%s  → Subsystem 안 출력 %d번으로 들어감\n', indent, portNumber);
            if ~isempty(outportBlock), queue(end + 1, :) = {outportBlock{1}, 1, depth + 1}; end %#ok<SAGROW>
        otherwise
            sourceHandles = get_param(source, 'PortHandles');
            for p = 1:numel(sourceHandles.Inport), queue(end + 1, :) = {sourcePath, p, depth + 1}; end %#ok<SAGROW>
    end
end
warning(warnState);
```

확인할 것: 화면에서 상태 블록(UnitDelay, Memory, Delay, DiscreteIntegrator 등)의 초기값과, 고리 안의 Sum·Saturation·Constant 값을 본다.
그것으로 제어 신호가 시작값에서 어느 쪽으로만 움직이는지 본다. 예를 들어 초기값이 Threshold 이상이고 고리가 더하기만 하면,
제어 신호는 영영 Threshold 아래로 내려가지 않는다. 그것이 사유다. `변수=값`으로 나온 설정은 sldd나 워크스페이스의 값을 읽은 것이다.

돌려줄 것: 화면 캡처 한 장. 블록 종류와 숫자만 찍힌다. 변수로 된 설정은 이름 대신 `변수=값`으로 찍는다.

## 4. 두 카운터와 리셋만 골라 색칠하고 리셋 조건이 같은지 보기

왜: 앞 절은 거꾸로 끝까지 따라가는 바람에 Unit Delay 9개, Switch 5개를 다 칠해서 무엇이 무엇인지 알 수 없었다. 이번에는
따라가다 **처음 만나는 Unit Delay 하나에서 멈춘다.** 출발점은 안쪽 Switch의 제어 입력(카운터 1)과 Enabled Subsystem의 Enable
입력(카운터 2) 두 곳이다. 그래서 카운터는 딱 두 개만 칠한다. 각 카운터 바로 앞의 리셋 Switch도 칠한다. 그리고 두 리셋 Switch의
조건 입력이 Goto/From을 건너 **같은 블록에서 오는지** 직접 비교해 찍는다. 색은 이렇게 칠한다.
- 노란색: Enabled Subsystem
- 초록색: 카운터 1·2
- 빨간색: 각 카운터의 리셋 Switch
- 하늘색: 리셋 조건이 나오는 블록
블록 경로는 `%TEMP%\st_counter_blocks.txt`에 쓴다(보내지 말 것). 색은 저장되지 않는다. 같은 안쪽 Switch를 선택한 채로 붙여 넣는다.
블록이 먼저 모델을 닫았다가 다시 열어 앞서 칠한 색을 지운다(선택한 Switch는 기억해 둔다). 저장 안 한 변경이 있으면 닫지 않고 멈춘다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
startBlock = gcb; enabledBlock = ''; topName = bdroot(startBlock);
if ~strcmp(get_param(startBlock, 'BlockType'), 'Switch')
    fprintf('선택된 블록이 Switch가 아닙니다(종류 %s). 안쪽 Switch를 클릭해 선택한 뒤 다시 붙여 넣어 주세요\n', get_param(startBlock, 'BlockType')); warning(warnState); return;
end
% 앞서 칠한 색을 지우려고 모델을 닫았다가 다시 연다. 저장 안 한 변경이 있으면 닫지 않고 멈춘다.
if strcmp(get_param(topName, 'Dirty'), 'on')
    fprintf('모델에 저장 안 한 변경이 있어 닫지 않았습니다. 저장하거나 되돌린 뒤 다시 돌려 주세요\n'); warning(warnState); return;
end
close_system(topName, 0); open_system(topName);
current = startBlock;
while ~strcmp(get_param(current, 'Parent'), bdroot(current))
    current = get_param(current, 'Parent'); currentHandles = get_param(current, 'PortHandles');
    if ~isempty(currentHandles.Enable), enabledBlock = current; break; end
end
starts = {startBlock, 2, '카운터 1(Switch 제어 입력)'};
if ~isempty(enabledBlock), starts(end + 1, :) = {enabledBlock, 'enable', '카운터 2(Enable 입력)'}; end
schemes = {'user1', 'yellow'; 'user2', 'green'; 'user3', 'red'; 'user4', 'lightBlue'};
for c = 1:size(schemes, 1), set_param(0, 'HiliteAncestorsData', struct('HiliteType', schemes{c, 1}, 'ForegroundColor', 'black', 'BackgroundColor', schemes{c, 2})); end
fid = fopen(fullfile(tempdir, 'st_counter_blocks.txt'), 'w');
if ~isempty(enabledBlock), hilite_system(enabledBlock, 'user1'); fprintf(fid, '노란색 Enabled Subsystem | %s\n', enabledBlock); end
resetSources = {};
for s = 1:size(starts, 1)
    queue = {starts{s, 1}, starts{s, 2}}; visited = {}; delayFound = '';
    while ~isempty(queue) && isempty(delayFound) && numel(visited) < 200
        block = queue{1, 1}; port = queue{1, 2}; queue(1, :) = [];
        [sourcePath, sourceType, line] = deal('', '', -1);
        handles = get_param(block, 'PortHandles');
        if ischar(port), portHandle = handles.Enable; else, if port > numel(handles.Inport), continue; end, portHandle = handles.Inport(port); end
        if isempty(portHandle), continue; end
        line = get_param(portHandle, 'Line'); if line < 0, continue; end
        source = get_param(line, 'SrcBlockHandle'); if source < 0, continue; end
        sourcePath = getfullname(source); sourceType = get_param(source, 'BlockType');
        if any(strcmp(visited, sourcePath)), continue; end
        visited{end + 1} = sourcePath; %#ok<SAGROW>
        switch sourceType
            case 'Constant'
            case 'From'
                gotoBlocks = find_system(bdroot(sourcePath), 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'BlockType', 'Goto', 'GotoTag', get_param(source, 'GotoTag'));
                if ~isempty(gotoBlocks), queue(end + 1, :) = {gotoBlocks{1}, 1}; end %#ok<SAGROW>
            case 'Inport'
                parentBlock = get_param(sourcePath, 'Parent');
                if ~strcmp(parentBlock, bdroot(sourcePath)), queue(end + 1, :) = {parentBlock, str2double(get_param(source, 'Port'))}; end %#ok<SAGROW>
            case 'SubSystem'
                portNumber = get_param(get_param(line, 'SrcPortHandle'), 'PortNumber');
                outportBlock = find_system(sourcePath, 'SearchDepth', 1, 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'BlockType', 'Outport', 'Port', num2str(portNumber));
                if ~isempty(outportBlock), queue(end + 1, :) = {outportBlock{1}, 1}; end %#ok<SAGROW>
            case {'UnitDelay', 'Delay', 'Memory'}
                delayFound = sourcePath;
            otherwise
                sourceHandles = get_param(source, 'PortHandles');
                for p = 1:numel(sourceHandles.Inport), queue(end + 1, :) = {sourcePath, p}; end %#ok<SAGROW>
        end
    end
    if isempty(delayFound), fprintf('%s | Unit Delay를 찾지 못함\n', starts{s, 3}); resetSources{end + 1} = ''; continue; end %#ok<SAGROW>
    hilite_system(delayFound, 'user2'); fprintf(fid, '초록색 %s | %s\n', starts{s, 3}, delayFound);
    if ~exist('treeSeen', 'var'), treeSeen = {}; end
    if ~any(strcmp(treeSeen, delayFound)), treeSeen{end + 1} = delayFound; end %#ok<SAGROW>
    fprintf('%s = UnitDelay#%d\n', starts{s, 3}, find(strcmp(treeSeen, delayFound), 1));
    delayHandles = get_param(delayFound, 'PortHandles'); feeder = get_param(get_param(delayHandles.Inport(1), 'Line'), 'SrcBlockHandle');
    feederType = get_param(feeder, 'BlockType'); resetSource = '';
    if strcmp(feederType, 'Switch')
        hilite_system(feeder, 'user3'); fprintf(fid, '빨간색 %s의 리셋 Switch | %s\n', starts{s, 3}, getfullname(feeder));
        % 리셋 조건(Switch 가운데 입력)을 Goto/From·Subsystem 경계를 건너 처음 계산 블록까지 따라간다.
        cursor = {getfullname(feeder), 2};
        for hop = 1:30
            cursorHandles = get_param(cursor{1}, 'PortHandles'); if cursor{2} > numel(cursorHandles.Inport), break; end
            cursorLine = get_param(cursorHandles.Inport(cursor{2}), 'Line'); if cursorLine < 0, break; end
            cursorSource = get_param(cursorLine, 'SrcBlockHandle'); cursorType = get_param(cursorSource, 'BlockType'); cursorPath = getfullname(cursorSource);
            if strcmp(cursorType, 'From')
                gotoBlocks = find_system(bdroot(cursorPath), 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'BlockType', 'Goto', 'GotoTag', get_param(cursorSource, 'GotoTag'));
                if isempty(gotoBlocks), break; end, cursor = {gotoBlocks{1}, 1};
            elseif strcmp(cursorType, 'DataTypeConversion')
                % 형식만 바꾸는 블록이라 그 입력을 이어 따라간다.
                cursor = {cursorPath, 1};
            elseif strcmp(cursorType, 'Inport') && ~strcmp(get_param(cursorPath, 'Parent'), bdroot(cursorPath))
                cursor = {get_param(cursorPath, 'Parent'), str2double(get_param(cursorSource, 'Port'))};
            elseif strcmp(cursorType, 'SubSystem')
                portNumber = get_param(get_param(cursorLine, 'SrcPortHandle'), 'PortNumber');
                outportBlock = find_system(cursorPath, 'SearchDepth', 1, 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'BlockType', 'Outport', 'Port', num2str(portNumber));
                if isempty(outportBlock), break; end, cursor = {outportBlock{1}, 1};
            else
                resetSource = cursorPath; hilite_system(cursorSource, 'user4');
                fprintf(fid, '하늘색 %s의 리셋 조건 출처 | %s\n', starts{s, 3}, cursorPath);
                fprintf('%s | 카운터 초기값 %s | 리셋 Switch 조건 %s, Threshold %s | 리셋 조건 출처 종류 %s\n', starts{s, 3}, ...
                    get_param(delayFound, 'InitialCondition'), get_param(feeder, 'Criteria'), get_param(feeder, 'Threshold'), cursorType);
                % 리셋 조건 블록이 무엇과 무엇을 비교하는지(연산자와 각 입력의 종류, 상수면 값) 찍는다.
                operatorText = ''; try, operatorText = get_param(cursorSource, 'Operator'); catch, end
                inputHandles = get_param(cursorSource, 'PortHandles'); inputTexts = {};
                for q = 1:numel(inputHandles.Inport)
                    inputLine = get_param(inputHandles.Inport(q), 'Line'); if inputLine < 0, inputTexts{end + 1} = '연결 없음'; continue; end %#ok<SAGROW>
                    inputSource = get_param(inputLine, 'SrcBlockHandle'); inputType = get_param(inputSource, 'BlockType');
                    if strcmp(inputType, 'Constant'), inputType = ['Constant ' get_param(inputSource, 'Value')]; end
                    inputTexts{end + 1} = inputType; %#ok<SAGROW>
                end
                fprintf('   리셋 조건 블록 | 연산자 %s | 입력: %s\n', operatorText, strjoin(inputTexts, ', '));
                % 리셋 조건을 만드는 계산을 8단계 아래까지(최대 30줄) 나무 모양으로 찍는다. 상태 블록은 번호를 붙여 안으로도 한 번 따라간다(Goto/From·Subsystem 경계와 형식 변환은 건너간다).
                % 각 줄은 (블록 경로, 들어간 입력 포트 번호, 깊이). 꺼낼 때 찍고 그 블록의 입력을 다시 쌓아, 자식이 부모 바로 아래에 찍힌다.
                stack = {}; rootHandles = get_param(cursorPath, 'PortHandles'); treeLines = 0;
                if ~exist('treeSeen', 'var'), treeSeen = {}; end
                for q = numel(rootHandles.Inport):-1:1, stack(end + 1, :) = {cursorPath, q, 1}; end %#ok<SAGROW>
                while ~isempty(stack)
                    nodePath = stack{end, 1}; q = stack{end, 2}; nodeDepth = stack{end, 3}; stack(end, :) = [];
                    nodeHandles = get_param(nodePath, 'PortHandles');
                    childLine = get_param(nodeHandles.Inport(q), 'Line'); if childLine < 0, continue; end
                    child = get_param(childLine, 'SrcBlockHandle'); childType = get_param(child, 'BlockType'); childPath = getfullname(child); hops = 0;
                    while any(strcmp(childType, {'From', 'Inport', 'SubSystem', 'DataTypeConversion'})) && hops < 20
                        hops = hops + 1;
                        if strcmp(childType, 'From')
                            gotoBlocks = find_system(bdroot(childPath), 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'BlockType', 'Goto', 'GotoTag', get_param(child, 'GotoTag'));
                            if isempty(gotoBlocks), break; end, nextHandles = get_param(gotoBlocks{1}, 'PortHandles'); nextLine = get_param(nextHandles.Inport(1), 'Line');
                        elseif strcmp(childType, 'Inport')
                            parentPath = get_param(childPath, 'Parent'); if strcmp(parentPath, bdroot(childPath)), break; end
                            nextHandles = get_param(parentPath, 'PortHandles'); nextLine = get_param(nextHandles.Inport(str2double(get_param(child, 'Port'))), 'Line');
                        elseif strcmp(childType, 'SubSystem')
                            portNumber = get_param(get_param(childLine, 'SrcPortHandle'), 'PortNumber');
                            outportBlock = find_system(childPath, 'SearchDepth', 1, 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'BlockType', 'Outport', 'Port', num2str(portNumber));
                            if isempty(outportBlock), break; end, nextHandles = get_param(outportBlock{1}, 'PortHandles'); nextLine = get_param(nextHandles.Inport(1), 'Line');
                        else
                            nextHandles = get_param(child, 'PortHandles'); nextLine = get_param(nextHandles.Inport(1), 'Line');
                        end
                        if nextLine < 0, break; end
                        childLine = nextLine; child = get_param(childLine, 'SrcBlockHandle'); childType = get_param(child, 'BlockType'); childPath = getfullname(child);
                    end
                    settingText = '';
                    for name = {'Operator', 'Criteria', 'Threshold', 'Value', 'Function', 'InitialCondition'}
                        try
                            value = char(string(get_param(child, name{1})));
                            if any(strcmp(name{1}, {'Threshold', 'Value', 'InitialCondition'})) && isempty(str2num(value)) %#ok<ST2NM>
                                try, value = ['변수=' mat2str(slResolve(value, child))]; catch, value = '변수'; end
                            end
                            settingText = [settingText ' ' name{1} '=' value]; %#ok<AGROW>
                        catch
                        end
                    end
                    % 상태 블록은 번호를 붙여 같은 것이 다시 나오면 알아보게 하고, 한 번만 안으로 따라간다.
                    seenIndex = find(strcmp(treeSeen, childPath), 1); seenNote = '';
                    if any(strcmp(childType, {'UnitDelay', 'Delay', 'Memory'}))
                        if isempty(seenIndex), treeSeen{end + 1} = childPath; seenIndex = numel(treeSeen); else, seenNote = ' (앞에 나온 상태, 되먹임)'; end %#ok<SAGROW>
                        childType = sprintf('%s#%d', childType, seenIndex);
                    end
                    if strcmp(childType, 'Inport'), seenNote = ' (모델 바깥 입력)'; end
                    treeLines = treeLines + 1;
                    if treeLines > 30, fprintf('%s... 이하 생략\n', repmat('    ', 1, nodeDepth)); stack = {}; continue; end
                    fprintf('%s입력 %d: %s%s%s\n', repmat('    ', 1, nodeDepth), q, childType, settingText, seenNote);
                    if isempty(seenNote) && nodeDepth < 8 && ~any(strcmp(childType, {'Constant', 'Inport'}))
                        childHandles = get_param(childPath, 'PortHandles');
                        for p = numel(childHandles.Inport):-1:1, stack(end + 1, :) = {childPath, p, nodeDepth + 1}; end %#ok<SAGROW>
                    end
                end
                break;
            end
        end
    else
        fprintf('%s | 카운터 바로 앞이 Switch가 아님(종류 %s)\n', starts{s, 3}, feederType);
    end
    resetSources{end + 1} = resetSource; %#ok<SAGROW>
end
fclose(fid);
if numel(resetSources) == 2 && ~isempty(resetSources{1})
    fprintf('두 리셋 조건이 같은 블록에서 나옴: %d\n', strcmp(resetSources{1}, resetSources{2}));
end
if ~isempty(enabledBlock), open_system(get_param(enabledBlock, 'Parent')); end
fprintf('%s\n', ['블록 경로: %TEMP%' filesep 'st_counter_blocks.txt']);
warning(warnState);
```

확인할 것: "두 리셋 조건이 같은 블록에서 나옴: 1"이면 두 카운터가 같은 조건으로 함께 리셋된다. 그러면 사유가 확정된다. 0이면 리셋 조건이
다르니, 하늘색 두 블록이 어떤 관계인지 모델에서 본다.

돌려줄 것: 화면 캡처 한 장.
