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

## 4. Enable, 카운터(Unit Delay), 리셋 Switch를 모델에서 찾아 색칠하기

왜: 사유를 확정하려면 모델에서 세 곳을 직접 봐야 한다. 안쪽 Switch를 감싼 Enabled Subsystem과 그 Enable 블록, 두 카운터의 Unit Delay,
그리고 각 카운터를 0으로 되돌리는 리셋 Switch다. 되먹임과 Goto/From 때문에 손으로 찾기 어렵다. 그래서 선택한 Switch에서 거꾸로 따라가며
이 블록들을 모으고, 모델에서 색으로 표시한 뒤 해당 화면을 연다. 색은 이렇게 칠한다.
- 노란색: Enabled Subsystem
- 초록색: 두 카운터의 Unit Delay
- 빨간색: 각 Unit Delay 바로 앞의 리셋 Switch
- 하늘색: 처음 선택한 Switch
화면에는 개수만 찍고, 블록 경로는 `%TEMP%\st_counter_blocks.txt`에 쓴다. 그 파일은 보내지 말고 직접 연다. 모델은 저장하지 않는다.
다 보면 `hilite_system(gcb, 'none')` 대신 모델을 닫았다 열거나 그대로 두면 된다(색은 저장되지 않는다).
3절에서 쓴 **같은 안쪽 Switch를 선택한 채로** 붙여 넣는다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
startBlock = gcb; found = struct('enabled', {{}}, 'delays', {{}}, 'resets', {{}});
current = startBlock;
while ~strcmp(get_param(current, 'Parent'), bdroot(current))
    current = get_param(current, 'Parent'); currentHandles = get_param(current, 'PortHandles');
    if ~isempty(currentHandles.Enable), found.enabled{end + 1} = current; break; end
end
starts = {startBlock, 2};
if ~isempty(found.enabled), starts(end + 1, :) = {found.enabled{1}, 'enable'}; end
visited = {};
for s = 1:size(starts, 1)
    queue = {starts{s, 1}, starts{s, 2}};
    while ~isempty(queue) && numel(visited) < 200
        block = queue{1, 1}; port = queue{1, 2}; queue(1, :) = [];
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
            otherwise
                if any(strcmp(sourceType, {'UnitDelay', 'Delay', 'Memory'}))
                    found.delays{end + 1} = sourcePath;
                    delayHandles = get_param(source, 'PortHandles'); delayLine = get_param(delayHandles.Inport(1), 'Line');
                    if delayLine > 0
                        feeder = get_param(delayLine, 'SrcBlockHandle');
                        if feeder > 0 && strcmp(get_param(feeder, 'BlockType'), 'Switch'), found.resets{end + 1} = getfullname(feeder); end
                    end
                end
                sourceHandles = get_param(source, 'PortHandles');
                for p = 1:numel(sourceHandles.Inport), queue(end + 1, :) = {sourcePath, p}; end %#ok<SAGROW>
        end
    end
end
fid = fopen(fullfile(tempdir, 'st_counter_blocks.txt'), 'w');
groups = {'enabled', '노란색 Enabled Subsystem', 'yellow'; 'delays', '초록색 Unit Delay', 'green'; 'resets', '빨간색 리셋 Switch', 'red'};
for g = 1:size(groups, 1)
    items = unique(found.(groups{g, 1}), 'stable');
    fprintf('%s %d개\n', groups{g, 2}, numel(items));
    for k = 1:numel(items)
        fprintf(fid, '%s | %s\n', groups{g, 2}, items{k});
        hilite_system(items{k}, groups{g, 3});
    end
end
hilite_system(startBlock, 'lightBlue'); fprintf(fid, '하늘색 처음 선택한 Switch | %s\n', startBlock); fclose(fid);
if ~isempty(found.enabled), open_system(get_param(found.enabled{1}, 'Parent')); end
fprintf('%s\n', ['블록 경로: %TEMP%' filesep 'st_counter_blocks.txt']);
warning(warnState);
```

확인할 것: 노란색 Enabled Subsystem의 Enable이 어느 카운터에서 오는지, 초록색 Unit Delay 두 개가 각각 어느 빨간색 Switch로 리셋되는지, 두
리셋 Switch의 조건 입력이 같은 신호에서 오는지.

돌려줄 것: 화면 캡처 한 장(개수만 찍힌다). 그리고 "두 리셋 조건이 같은 신호/다른 신호" 한 줄.
