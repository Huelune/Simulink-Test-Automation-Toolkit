function st_inspect_verify_timing()
%ST_INSPECT_VERIFY_TIMING When the Test Assessment of a failed target runs, against Tmax.
%
% For todo.md; it changes nothing (the Harness is compiled and closed
% unsaved). For each target the latest PER_CUT run marked EXCEPT:
%   - SLDV: scenario count and Tmax. Step 1 sets the Harness StopTime to
%     Tmax and moves the Test Assessment from step1 to step2 (the verify)
%     after(Tmax, sec), so the verify runs only at the last time step.
%   - Harness: StopTime, solver type, fixed step.
%   - Compiled sample time [period offset] of the Test Assessment and the
%     Signal Editor, and whether the Test Assessment runs at t = Tmax. When it
%     does not, step2 is never reached and no verify result is recorded.
%   - The first scenario's step1 transition time and step2 verify count.
% Numbers, solver words and fixed messages only.
title = 'verify 시점 보기';
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
cfg = st_config();
st_log(cfg, 'INFO', 'Verify timing inspection start');
lines = {sprintf('MATLAB %s | %s', version('-release'), title)};
try
    latest = jsondecode(fileread(cfg.PerCutLatestPointer));
    manifest = jsondecode(fileread(char(string(latest.Manifest))));
    records = manifest.Targets;
    if iscell(records), records = [records{:}]; end
    failedNo = [records(string({records.Status}) == "EXCEPT").No];
    evalc('cfg = st_require_runtime_target();');
    targets = st_load_targets(cfg.OnlyEnabled);
catch ME
    show([lines, {sprintf('준비 실패 | %s', ME.identifier)}]);
    return;
end
if isempty(failedNo)
    show([lines, {'최근 1단계 실행에 EXCEPT 대상이 없습니다'}]);
    return;
end
loaded = find_system('type', 'block_diagram');
if ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
    show([lines, {'저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요'}]);
    return;
end
for no = reshape(failedNo, 1, [])
    row = targets(double(targets.No) == double(no), :);
    if height(row) ~= 1
        lines{end+1} = sprintf('대상 %g | Excel에서 찾지 못함', no); %#ok<AGROW>
        continue;
    end
    lines = [lines, inspect_target(cfg, row)]; %#ok<AGROW>
end
st_log(cfg, 'INFO', 'Verify timing inspection end | targets %d', numel(failedNo));
show(lines);
end


function lines = inspect_target(cfg, row)
no = double(row.No);
lines = {};
owner = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
harness = char(row.HarnessName);
try
    profile = st_get_sldv_profile(row, cfg);
    lines{end+1} = sprintf('대상 %g | SLDV %s | 시나리오 %d | Tmax %g', no, profile.Mode, ...
        numel(profile.ScenarioNames), profile.Tmax);
catch ME
    lines{end+1} = sprintf('대상 %g | SLDV 정보 읽기 실패 | %s', no, ME.identifier);
    return;
end
try
    sltest.harness.load(owner, harness);
    closeHarness = onCleanup(@() close_quiet(owner, harness)); %#ok<NASGU>
    lines{end+1} = sprintf('  Harness | StopTime %s | %s | FixedStep %s', ...
        number_text(get_param(harness, 'StopTime')), get_param(harness, 'SolverType'), ...
        number_text(get_param(harness, 'FixedStep')));
    assessment = st_find_assessment_block(harness);
catch ME
    lines{end+1} = sprintf('  Harness 열기 실패 | %s', ME.identifier);
    return;
end
lines{end+1} = ['  ' sequence_text(assessment, profile.ScenarioNames{1})];
editor = '';
try, editor = st_find_signal_editor_block(harness); catch, end
compiled = false;
% Compile where step 1 builds (tempdir/stt_build): from the clone folder the
% Stateflow build path can pass the Windows path limit (Simulink:cgxe:BuildError).
shortBuild = [];
try
    shortBuild = st_enter_short_build_directory(cfg, 'INSPECT'); %#ok<NASGU>
    feval(harness, [], [], [], 'compile');
    compiled = true;
    assessTime = get_param(assessment, 'CompiledSampleTime');
    text = sprintf('  컴파일 샘플 시간 | Test Assessment %s', rate_text(assessTime));
    if ~isempty(editor)
        text = [text sprintf(' | Signal Editor %s', rate_text(get_param(editor, 'CompiledSampleTime')))];
    end
    lines{end+1} = text;
    lines{end+1} = sprintf('  Test Assessment가 t=Tmax에 실행됨 | %s', runs_at(assessTime, profile.Tmax));
catch ME
    lines{end+1} = sprintf('  컴파일 실패 | %s', st_build_error_kind(ME));
    lines{end+1} = '  전문 st_todo_check.txt (임시 폴더, 밖으로 보내지 않음)';
    fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
    if fid >= 0
        fprintf(fid, '[verify 시점 보기 컴파일]\n%s\n\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        fclose(fid);
    end
end
% The compiled Harness must end before it closes (closeHarness on return),
% and the short build folder is left only after that.
if compiled
    try, feval(harness, [], [], [], 'term'); catch, end
end
clear shortBuild
end


function text = sequence_text(assessment, scenario)
text = 'Test Assessment';
try
    condition = sltest.testsequence.readTransition(assessment, [scenario '.step1'], 1);
    after = regexp(char(string(condition.Condition)), 'after\(\s*([-+.\deE]+)\s*,\s*sec\s*\)', ...
        'tokens', 'once');
    if isempty(after)
        text = [text ' | step1→step2 조건 after(Tmax) 아님'];
    else
        text = [text sprintf(' | step1→step2 after(%g, sec)', str2double(after{1}))];
    end
catch ME
    text = [text ' | step1 전이 읽기 실패 ' ME.identifier];
end
try
    action = char(string(sltest.testsequence.readStep(assessment, [scenario '.step2'], 'Action')));
    text = [text sprintf(' | step2 verify %d개', numel(strfind(action, 'verify(')))];
catch ME
    text = [text ' | step2 읽기 실패 ' ME.identifier];
end
end


function text = runs_at(sampleTime, tmax)
% A block with several rates (a cell) or a continuous/inherited rate is
% shown as is; a discrete [period offset] runs at offset + k*period.
if iscell(sampleTime) || numel(sampleTime) < 2 || sampleTime(1) <= 0
    text = '판정 못 함(이산 단일 샘플 시간 아님)';
    return;
end
steps = (tmax - sampleTime(2)) / sampleTime(1);
if steps >= 0 && abs(steps - round(steps)) < 1e-9
    text = '예';
else
    text = sprintf('아니오 | 실행 시각 %g, %g 사이', ...
        sampleTime(2) + floor(steps) * sampleTime(1), sampleTime(2) + ceil(steps) * sampleTime(1));
end
end


function text = rate_text(sampleTime)
if iscell(sampleTime)
    text = sprintf('여러 개 %d', numel(sampleTime));
else
    text = ['[' strjoin(arrayfun(@(v) sprintf('%g', v), sampleTime, 'UniformOutput', false), ' ') ']'];
end
end


function text = number_text(value)
% StopTime and FixedStep may be expressions; only a plain number is shown.
value = strtrim(char(string(value)));
if ~isnan(str2double(value)) || strcmpi(value, 'auto')
    text = value;
else
    text = '(식)';
end
end


function close_quiet(owner, harness)
try, sltest.harness.close(owner, harness); catch, end
end


function show(lines)
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end
