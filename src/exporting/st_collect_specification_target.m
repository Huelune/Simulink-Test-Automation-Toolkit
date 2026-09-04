function [rows, details, inputFiles] = st_collect_specification_target(target, cfg, suite)
%ST_COLLECT_SPECIFICATION_TARGET Inspect a loaded Harness; never activate/edit.
% Columns are assigned public Korean headers by the export entry point.
rows = strings(0,13);
details = strings(0,8);
inputFiles = strings(0,1);
base = strings(1,13);
base([1 2 3 8 9 12]) = [target.TestCaseName target.CUTName ...
    target.HarnessName string(cfg.TopModel) ...
    string(st_normalize_cut_path(target.CUTPath, cfg.TopModel)) "OK"];
harness = char(target.HarnessName);
assessment = st_find_assessment_block(harness);
scenarios = string(sltest.testsequence.getAllScenarios(assessment));
scenarios = scenarios(:);
if isempty(scenarios)
    error('simtest:SpecificationNoScenarios', 'Assessment has no scenarios: %s', assessment);
end
st_log(cfg, 'INFO', 'Specification Assessment read start | Block=%s | Scenarios=%d', ...
    assessment, numel(scenarios));

bindingNotes = "";
bindings = struct('Name', {}, 'Scenario', {}, 'Input', {}, 'Note', {});
signalBlock = '';
signalNote = "";
ports = find_system(char(base(9)), 'SearchDepth', 1, ...
    'Type', 'Block', 'BlockType', 'Inport');
noInput = isempty(ports) && strcmpi(target.SldvMode, 'OFF');
try
    if noInput
        base(4) = "해당 없음";
    else
        signalBlock = st_find_signal_editor_block(harness);
        configuredFile = get_param(signalBlock, 'Filename');
        [~, stem, extension] = fileparts(configuredFile);
        base(4) = string([stem extension]);
    end
catch ME
    signalNote = string(ME.message);
end

% A broken Test Manager link must not hide Assessment-only scenarios.
try
    if isempty(suite), error('simtest:SpecificationSuite', 'Configured Test Suite is missing.'); end
    tc = getTestCaseByName(suite, char(target.TestCaseName));
    if numel(tc) ~= 1
        error('simtest:SpecificationCase', 'Expected one Test Case, found %d.', numel(tc));
    end
    model = string(getProperty(tc, 'Model'));
    owner = string(getProperty(tc, 'HarnessOwner'));
    linkedHarness = string(getProperty(tc, 'HarnessName'));
    if model ~= base(8) || owner ~= base(9) || linkedHarness ~= base(3)
        error('simtest:SpecificationMapping', ...
            'Test Case model/owner/harness differs from Targets; input binding not inferred.');
    end
    linkedBlock = string(getProperty(tc, 'TestSequenceBlock'));
    if linkedBlock ~= string(assessment)
        error('simtest:SpecificationMapping', ...
            'Test Case TestSequenceBlock differs from Assessment; input binding not inferred.');
    end
    script = string(getProperty(tc, 'IterationScript'));
    if strlength(strtrim(script)) > 0
        error('simtest:SpecificationScriptedIterations', ...
            'IterationScript is not executed; dynamic input bindings cannot be inspected.');
    end
    iterations = getIterations(tc);
    if isempty(iterations)
        seq = string(getProperty(tc, 'TestSequenceScenario'));
        if strlength(seq) == 0
            seq = string(sltest.testsequence.getActiveScenario(assessment));
        end
        inp = "";
        if ~isempty(signalBlock)
            if getProperty(tc, 'UseSignalEditorScenarios')
                inp = string(getProperty(tc, 'SignalEditorScenario'));
            else
                inp = string(get_param(signalBlock, 'ActiveScenario'));
            end
        end
        bindings(1) = struct('Name', "<기본 설정>", 'Scenario', seq, ...
            'Input', inp, 'Note', "");
    else
        for k = 1:numel(iterations)
            [seq, seqNote] = st_specification_parameter(iterations(k).TestParams, ...
                {'TestSequenceScenario'});
            [inp, inpNote] = st_specification_parameter(iterations(k).TestParams, ...
                {'SignalEditorScenario', 'SignalBuilderGroup'});
            bindings(end+1) = struct('Name', string(iterations(k).Name), ...
                'Scenario', seq, 'Input', inp, 'Note', join_notes(seqNote, inpNote)); %#ok<AGROW>
            if ~any(scenarios == seq)
                bindingNotes = join_notes(bindingNotes, sprintf( ...
                    'Iteration %s: Assessment scenario binding missing/unknown (%s). %s', ...
                    iterations(k).Name, seq, seqNote));
            end
        end
    end
catch ME
    bindingNotes = string(ME.message);
    bindings = struct('Name', {}, 'Scenario', {}, 'Input', {}, 'Note', {});
end

inputPath = '';
inputSignature = [];
inputCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isempty(signalBlock)
    try
        inputPath = st_resolve_data_file(get_param(signalBlock, 'Filename'), cfg.TopModel);
        inputSignature = st_file_signature(inputPath);
        inputFiles = string(inputPath);
    catch ME
        signalNote = join_notes(signalNote, string(ME.message));
    end
end

for s = 1:numel(scenarios)
    row = base;
    row(5) = scenarios(s);
    row(13) = join_notes(bindingNotes, signalNote);
    try
        [row(7), stepDetails, note] = read_assessment(assessment, scenarios(s), target);
        details = [details; stepDetails]; %#ok<AGROW>
        row(13) = join_notes(row(13), note);
    catch ME
        row(12) = "FAIL";
        row(13) = join_notes(row(13), string(ME.message));
    end
    selected = find(string({bindings.Scenario}) == scenarios(s));
    if isempty(selected), selected = 0; end
    for b = selected(:).'
        linked = row;
        if b == 0
            linked(6) = "연결 없음";
            linked(13) = join_notes(linked(13), "Assessment scenario has no readable Test Manager input binding.");
        else
            linked(10) = bindings(b).Name;
            linked(11) = bindings(b).Input;
            linked(13) = join_notes(linked(13), bindings(b).Note);
            if strlength(bindings(b).Input) == 0
                linked(6) = "연결 없음";
                if ~noInput
                    linked(13) = join_notes(linked(13), "Signal Editor scenario binding missing.");
                end
            elseif ~isempty(inputPath)
                name = char(bindings(b).Input);
                if ~isKey(inputCache, name)
                    st_log(cfg, 'DEBUG', 'Specification MAT read start | File=%s | Scenario=%s', inputPath, name);
                    try
                        data = load(inputPath, name);
                        if ~isfield(data, name)
                            error('simtest:SpecificationInputMissing', 'MAT scenario variable missing: %s', name);
                        end
                        [content, note] = st_specification_input_lines(data.(name));
                        inputCache(name) = {content, note};
                        st_log(cfg, 'DEBUG', 'Specification MAT read end | Scenario=%s', name);
                    catch ME
                        inputCache(name) = {"<읽기 실패>", string(ME.message)};
                        st_log(cfg, 'ERROR', 'Specification MAT read failed | File=%s | Scenario=%s | %s', ...
                            inputPath, name, ME.message);
                    end
                end
                item = inputCache(name);
                linked(6) = item{1};
                linked(13) = join_notes(linked(13), item{2});
            else
                linked(6) = "<읽기 실패>";
            end
        end
        if noInput, linked(6) = "해당 없음"; end
        if strlength(linked(13)) > 0 && linked(12) == "OK", linked(12) = "WARN"; end
        if linked(12) ~= "OK"
            level = 'WARN';
            if linked(12) == "FAIL", level = 'ERROR'; end
            st_log(cfg, level, 'Specification row | Case=%s | Scenario=%s | %s', ...
                linked(1), linked(5), linked(13));
        end
        rows(end+1,:) = linked; %#ok<AGROW>
    end
end
if ~isempty(inputSignature)
    current = st_file_signature(inputPath);
    if ~strcmp(current.SHA256, inputSignature.SHA256)
        error('simtest:SpecificationSourceChanged', 'Input file changed during inspection: %s', inputPath);
    end
end
st_log(cfg, 'INFO', 'Specification Assessment read end | Block=%s | Rows=%d', assessment, size(rows,1));
end

function [text, details, notes] = read_assessment(block, scenario, target)
steps = string(sltest.testsequence.findStep(block));
steps = steps(startsWith(steps, scenario + ".") | steps == scenario);
% Sort hierarchy by the actual sibling Index, not by alphabetic step names.
keys = strings(numel(steps),1);
for k = 1:numel(steps)
    parts = split(steps(k), '.');
    for depth = 1:numel(parts)
        info = sltest.testsequence.readStep(block, char(strjoin(parts(1:depth), '.')));
        keys(k) = keys(k) + sprintf('%010d/', info.Index);
    end
end
[~, order] = sort(keys);
steps = steps(order);
details = strings(0,8);
lines = strings(0,1);
notes = "";
for k = 1:numel(steps)
    info = sltest.testsequence.readStep(block, char(steps(k)));
    [summary, note] = st_specification_verify_lines(info.Action);
    if strlength(summary) > 0, lines(end+1,1) = summary; end %#ok<AGROW>
    notes = join_notes(notes, note);
    transitions = strings(0,1);
    for t = 1:double(info.TransitionCount)
        transition = sltest.testsequence.readTransition(block, char(steps(k)), t);
        transitions(end+1,1) = string(transition.Condition) + " -> " + string(transition.NextStep); %#ok<AGROW>
    end
    details(end+1,:) = [target.TestCaseName target.HarnessName string(block) ...
        scenario steps(k) string(info.Action) strjoin(transitions, newline) summary]; %#ok<AGROW>
end
text = strjoin(lines, newline);
end

function value = join_notes(a, b)
parts = [string(a); string(b)];
value = strjoin(parts(strlength(parts) > 0), ' | ');
end
