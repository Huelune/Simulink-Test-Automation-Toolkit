function [cells, details, notes] = st_read_specification_assessment( ...
        block, scenario, target, cfg, mode, reader)
%ST_READ_SPECIFICATION_ASSESSMENT Read step2 independently of other step failures.
% Reader injection supports non-simulation regression tests of API failures.
if nargin < 6
    reader = struct('FindSteps', @sltest.testsequence.findStep, ...
        'ReadStep', @sltest.testsequence.readStep, ...
        'ReadTransition', @sltest.testsequence.readTransition);
end
scenario = string(scenario);
step2 = scenario + ".step2";
notes = "";
cells = strings(1,0);
details = strings(0,10);
st_log(cfg, 'DEBUG', 'Specification verify start | Mode=%s | Block=%s | Scenario=%s', ...
    mode, block, scenario);
cached = [];
step2Error = "";
% Do not let findStep, a parent step, or step1 prevent reading the exact step2.
if strcmp(mode, 'STEP2')
    try
        cached = read_info(reader, block, step2, cfg, mode);
    catch ME
        step2Error = string(ME.message);
    end
end
enumerated = true;
try
    paths = string(reader.FindSteps(block));
    paths = unique(paths(:), 'stable');
    paths = paths(startsWith(paths, scenario + ".") | paths == scenario);
catch ME
    enumerated = false;
    paths = strings(0,1);
    notes = append_note(notes, "Step enumeration failed: " + string(ME.message));
    st_log(cfg, 'WARN', 'Specification findStep failed | Scenario=%s | %s', scenario, ME.message);
end
hasStep2 = any(paths == step2);
if strcmp(mode, 'STEP2') && ~hasStep2
    if ~isempty(cached) || ~enumerated
        paths(end+1,1) = step2;
    end
end
records = repmat(struct('Path', "", 'Index', NaN, 'Action', "", ...
    'Summary', "", 'Transitions', "", 'Note', "", 'Readable', false), numel(paths), 1);
for k = 1:numel(paths)
    record = records(k);
    record.Path = paths(k);
    try
        if strcmp(mode, 'STEP2') && paths(k) == step2
            if isempty(cached)
                error('simtest:SpecificationStepRead', '%s', step2Error);
            end
            info = cached;
        else
            info = read_info(reader, block, paths(k), cfg, mode);
        end
        record.Action = string(info.Action);
        record.Readable = true;
        [record.Summary, record.Note, count] = st_specification_verify_lines(info.Action);
        if isfield(info, 'Index') && isnumeric(info.Index) && ...
                isscalar(info.Index) && isfinite(info.Index)
            record.Index = double(info.Index);
        else
            record.Note = append_note(record.Note, 'Step Index unavailable; discovery order used.');
        end
        st_log(cfg, 'DEBUG', 'Specification verify read | Mode=%s | Scenario=%s | Step=%s | VerifyCount=%d', ...
            mode, scenario, paths(k), count);
        % Transition failures must never discard a successfully read Action.
        try
            transitions = strings(0,1);
            for t = 1:double(info.TransitionCount)
                try
                    transition = reader.ReadTransition(block, char(paths(k)), t);
                    transitions(end+1,1) = string(transition.Condition) + ...
                        " -> " + string(transition.NextStep); %#ok<AGROW>
                catch ME
                    record.Note = append_note(record.Note, sprintf('Transition %d: %s', t, ME.message));
                    transitions(end+1,1) = sprintf('<전이 %d 읽기 실패>', t); %#ok<AGROW>
                end
            end
            record.Transitions = strjoin(transitions, newline);
        catch ME
            record.Note = append_note(record.Note, "Transitions: " + string(ME.message));
        end
    catch ME
        record.Note = append_note(record.Note, string(ME.message));
        st_log(cfg, 'ERROR', 'Specification step failed | Mode=%s | Scenario=%s | Step=%s | %s', ...
            mode, scenario, paths(k), ME.message);
    end
    records(k) = record;
end
% Sort by sibling Index at each hierarchy level. Failed/missing indices retain
% discovery order after readable siblings; no extra parent API calls are needed.
keys = strings(numel(records),1);
for k = 1:numel(records)
    relative = erase_prefix(records(k).Path, scenario);
    if strlength(relative) == 0, continue; end
    parts = split(relative, '.');
    for depth = 1:numel(parts)
        ancestor = scenario + "." + strjoin(parts(1:depth), '.');
        a = find(paths == ancestor, 1);
        index = 1e9 + k;
        if ~isempty(a)
            index = records(a).Index;
            if isnan(index), index = 1e9 + a; end
        end
        keys(k) = keys(k) + sprintf('%012d/', index);
    end
end
[~, order] = sort(keys);
records = records(order);
for k = 1:numel(records)
    record = records(k);
    status = "OK";
    if ~record.Readable, status = "FAIL";
    elseif strlength(record.Note) > 0, status = "WARN"; end
    details(end+1,:) = [target.TestCaseName target.HarnessName string(block) ...
        scenario record.Path record.Action record.Transitions record.Summary status record.Note]; %#ok<AGROW>
    if strlength(record.Note) > 0
        notes = append_note(notes, record.Path + ": " + record.Note);
        st_log(cfg, 'WARN', 'Specification step detail | Scenario=%s | Step=%s | %s', ...
            scenario, record.Path, record.Note);
    end
    if strcmp(mode, 'ALL_STEPS_COLUMNS') && strlength(record.Summary) > 0
        label = erase_prefix(record.Path, scenario);
        if strlength(label) == 0, label = "<scenario>"; end
        cells(end+1) = "[" + label + "]" + newline + record.Summary; %#ok<AGROW>
    end
end
if strcmp(mode, 'STEP2')
    selected = find(string({records.Path}) == step2, 1);
    if isempty(selected) && enumerated
        cells = "step2 없음";
        notes = append_note(notes, "Direct step2 missing: " + step2);
    elseif isempty(selected) || ~records(selected).Readable
        cells = "<step2 읽기 실패>";
        notes = append_note(notes, "Cannot read direct step2: " + step2 + " | " + step2Error);
    elseif strlength(records(selected).Summary) == 0
        cells = "verify 없음";
        notes = append_note(notes, "No verify in direct step2: " + step2);
    else
        cells = records(selected).Summary;
    end
elseif isempty(cells)
    if ~enumerated || any(~[records.Readable])
        cells = "<verify 읽기 실패>";
    else
        cells = "verify 없음";
    end
    notes = append_note(notes, "No readable verify in scenario: " + scenario);
end
if strlength(notes) > 0
    st_log(cfg, 'WARN', 'Specification verify notes | Mode=%s | Scenario=%s | %s', mode, scenario, notes);
end
st_log(cfg, 'DEBUG', 'Specification verify end | Mode=%s | Scenario=%s | Cells=%d', mode, scenario, numel(cells));
end

function info = read_info(reader, block, step, cfg, mode)
st_log(cfg, 'DEBUG', 'Specification readStep start | Mode=%s | Step=%s', mode, step);
try
    info = reader.ReadStep(block, char(step));
    st_log(cfg, 'DEBUG', 'Specification readStep end | Mode=%s | Step=%s', mode, step);
catch ME
    st_log(cfg, 'ERROR', 'Specification readStep failed | Mode=%s | Step=%s | %s', mode, step, ME.message);
    rethrow(ME);
end
end

function relative = erase_prefix(path, scenario)
if path == scenario, relative = "";
else, relative = extractAfter(path, strlength(scenario) + 1); end
end

function text = append_note(a, b)
parts = [string(a); string(b)];
text = strjoin(parts(strlength(parts) > 0), ' | ');
end
