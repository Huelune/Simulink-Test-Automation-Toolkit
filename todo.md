# MATLAB 실행 요청

작성: 2026-10-07. 결과를 붙여 주면 해당 절은 지운다.

## 1. 분기 결정 텍스트와 순서 확인

최종 문서에서 Saturation 같은 블록을 결정마다 D로 나누려면(상한 D 하나, 하한 D
하나), Simulink Coverage가 각 결정을 **어떤 텍스트로, 어떤 순서로** 내보내는지
알아야 한다. D 줄과 결정을 텍스트로 짝지어야 상한·하한 결과가 뒤바뀌지 않는다.

아래 스크립트는 툴킷과 무관하다. 임시 모델을 새로 만들고 `tempdir`에만 저장한 뒤
닫으므로, 저장소와 기존 모델은 건드리지 않는다. Command Window에 그대로 붙여
넣거나 `.m` 파일로 저장해 실행한다.

```matlab
%% 분기 결정 텍스트와 순서 확인용 (임시 모델, 저장소와 무관)
mdl = 'cov_probe';
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
set_param(mdl, 'Solver', 'FixedStepDiscrete', 'FixedStep', '0.01', 'StopTime', '5');

% 입력: -50~50 사인파, 부가 입력(reset/enable/제어)은 펄스
add_block('simulink/Sources/Sine Wave', [mdl '/Src'], 'Amplitude', '50', ...
    'Frequency', '2', 'SampleTime', '0.01');
add_block('simulink/Sources/Pulse Generator', [mdl '/Pulse'], ...
    'Period', '1', 'PulseWidth', '30');

blocks = {
  'simulink/Discontinuities/Saturation',       'Sat',    {'UpperLimit','32','LowerLimit','-32'}
  'simulink/Discontinuities/Dead Zone',        'DZ',     {'LowerValue','-10','UpperValue','10'}
  'simulink/Discontinuities/Rate Limiter',     'RL',     {'RisingSlewLimit','20','FallingSlewLimit','-20'}
  'simulink/Discontinuities/Relay',            'Relay',  {'OnSwitchValue','10','OffSwitchValue','-10'}
  'simulink/Discrete/Discrete-Time Integrator','DTI',    {'LimitOutput','on','UpperSaturationLimit','5', ...
                                                          'LowerSaturationLimit','-5','ExternalReset','rising'}
  'simulink/Discrete/Delay',                   'Delay',  {'ExternalReset','Rising','ShowEnablePort','on'}
  'simulink/Discrete/Discrete Filter',         'DFilt',  {'ExternalReset','Rising'}
  'simulink/Signal Routing/Switch',            'Sw',     {}
  'simulink/Math Operations/Abs',              'Abs',    {}
  'simulink/Ports & Subsystems/If',            'If',     {'NumInputs','1','IfExpression','u1 > 0', ...
                                                          'ElseIfExpressions','u1 < -20'}
  'simulink/Ports & Subsystems/Enabled Subsystem','EnSS',{}
};
src = get_param([mdl '/Src'], 'PortHandles');
pulse = get_param([mdl '/Pulse'], 'PortHandles');
for i = 1:size(blocks, 1)
    path = [mdl '/' blocks{i,2}];
    add_block(blocks{i,1}, path, blocks{i,3}{:});
    ph = get_param(path, 'PortHandles');
    inputs = [ph.Inport, ph.Enable, ph.Reset];
    for k = 1:numel(inputs)
        if k == 1, add_line(mdl, src.Outport(1), inputs(k));
        else,      add_line(mdl, pulse.Outport(1), inputs(k)); end
    end
end
save_system(mdl, fullfile(tempdir, [mdl '.slx']));

% Decision coverage로 한 번 시뮬레이션
test = cvtest(mdl);
test.settings.decision = 1;
cvd = cvsim(test);

% 블록마다 결정 텍스트, 순서, 결과별 실행 횟수 출력
diary(fullfile(tempdir, 'cov_probe.txt'));
found = find_system(mdl, 'SearchDepth', 1, 'Type', 'Block');
for i = 1:numel(found)
    try
        [v, d] = decisioninfo(cvd, found{i});
    catch
        continue;
    end
    if isempty(v), continue; end
    fprintf('\n== %s (%s)  covered %d/%d\n', found{i}, ...
        get_param(found{i}, 'BlockType'), v(1), v(2));
    for k = 1:numel(d.decision)
        fprintf('  decision %d: %s\n', k, d.decision(k).text);
        for j = 1:numel(d.decision(k).outcome)
            o = d.decision(k).outcome(j);
            fprintf('      %-45s %d\n', o.text, o.executionCount);
        end
    end
end
diary off;
close_system(mdl, 0);
fprintf('\n결과: %s\n', fullfile(tempdir, 'cov_probe.txt'));
```

### 확인할 것

- Saturation, Dead Zone, Rate Limiter, Relay, Discrete-Time Integrator, Delay의
  `decision 1/2/3` 텍스트와 순서. 상한이 먼저인지, reset이 먼저인지.
- 결과 텍스트가 `true`/`false`로 시작하는지. Switch, If, Abs, Enabled Subsystem 포함.
- If의 `u1 > 0`과 `u1 < -20` 결정 순서.

### 돌려줄 것

콘솔 출력 전체, 또는 마지막 줄에 나오는 `cov_probe.txt` 내용.

블록 경로나 파라미터 이름 때문에 에러가 나면 그 메시지를 함께 붙인다. 해당 블록
줄만 지우고 다시 돌려도 된다. 이 스크립트는 아직 한 번도 실행해 보지 않았다.

## 2. 분기 결과 표기 단위 테스트 (develop의 새 기능)

develop에만 있는 기능이다. 모델 프로젝트 안의 클론에서 develop을 받은 뒤
`st_setup`을 하고 실행한다.

```matlab
runtests({'test_decision_outcomes','test_export_final_document', ...
    'test_export_test_specification','test_specification_decision_blocks', ...
    'test_coverage_filters'})
```

실패한 테스트가 있으면 출력 전체를 붙인다.
