function [rows, details, inputFiles, verifyCells, maxTimes, decisionBlockLists] = st_collect_specification_target( ...
        target, cfg, suite, verifyMode)
%ST_COLLECT_SPECIFICATION_TARGET Inspect a loaded Harness; never activate/edit.
% Columns are assigned public Korean headers by the export entry point.
if nargin < 4, verifyMode = 'STEP2'; end
rows = strings(0,13);
details = strings(0,10);
verifyCells = cell(0,1);
maxTimes = zeros(0,1);
decisionBlockLists = strings(0,1);
inputFiles = strings(0,1);
base = strings(1,13);
base([1 2 3 8 9 12]) = [target.TestCaseName target.CUTName ...
    target.HarnessName string(cfg.TopModel) ...
    string(st_normalize_cut_path(target.CUTPath, cfg.TopModel)) "OK"];
harness = char(target.HarnessName);
harnessStopTime = get_param(harness, 'StopTime');
[~, maxTimeSource] = st_specification_max_time(target.SldvMode, harnessStopTime, NaN);
st_log(cfg, 'INFO', 'Specification MaxTime source selected | Case=%s | Mode=%s | Source=%s | HarnessStopTime=%s', ...
    target.TestCaseName, target.SldvMode, maxTimeSource, string(harnessStopTime));
[decisionBlockList, ~, decisionBlockNote] = st_specification_decision_blocks(base(9), cfg);
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
signalEditorAvailable = false;
signalNote = "";
inputPath = '';
inputSignature = [];
try
    signalBlock = st_find_signal_editor_block(harness);
    signalEditorAvailable = true;
    options = st_normalize_options( ...
        get_param(signalBlock, 'options@ActiveScenario'));
    activeScenario = char(get_param(signalBlock, 'ActiveScenario'));
    if isempty(options) || isempty(activeScenario) || ...
            ~ismember(activeScenario, options)
        error('simtest:SignalEditorActiveScenarioInvalid', ...
            ['Signal Editor ActiveScenario is empty or unavailable. ' ...
             'Active=%s | Available=[%s] | Block=%s'], ...
            activeScenario, strjoin(options, ', '), signalBlock);
    end
    configuredFile = get_param(signalBlock, 'Filename');
    inputPath = st_resolve_data_file(configuredFile, cfg.TopModel);
    inputSignature = st_file_signature(inputPath);
    inputFiles = string(inputPath);
    [~, stem, extension] = fileparts(configuredFile);
    base(4) = string([stem extension]);
catch ME
    if strcmpi(target.SldvMode, 'OFF') && ...
            strcmp(ME.identifier, 'simtest:SignalEditorBlockMissing')
        signalBlock = '';
        signalEditorAvailable = false;
        base(4) = "해당 없음";
        signalNote = ...
            "SKIP_NO_SIGNAL_EDITOR: Harness has no Signal Editor block.";
        st_log(cfg, 'WARN', ...
            ['Specification input scenario omitted | Case=%s | ' ...
             'Harness=%s | reason=no Signal Editor block'], ...
            target.TestCaseName, target.HarnessName);
    else
        rethrow(ME);
    end
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

inputCache = containers.Map('KeyType', 'char', 'ValueType', 'any');

for s = 1:numel(scenarios)
    row = base;
    row(5) = scenarios(s);
    if strlength(scenarios(s)) == 0, row(5) = "(단일 실행)"; end
    row(13) = join_notes(join_notes(bindingNotes, signalNote), decisionBlockNote);
    group = "<verify 읽기 실패>";
    try
        [group, stepDetails, note] = st_read_specification_assessment( ...
            assessment, scenarios(s), target, cfg, verifyMode);
        row(7) = group(1);
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
        inputMaxTime = NaN;
        if b == 0
            linked(6) = "연결 없음";
            linked(13) = join_notes(linked(13), "Assessment scenario has no readable Test Manager input binding.");
        else
            linked(10) = bindings(b).Name;
            linked(11) = bindings(b).Input;
            linked(13) = join_notes(linked(13), bindings(b).Note);
            if ~signalEditorAvailable
                linked(6) = "해당 없음";
            elseif strlength(bindings(b).Input) == 0
                linked(6) = "연결 없음";
                linked(13) = join_notes(linked(13), ...
                    "Signal Editor scenario binding missing.");
            elseif ~isempty(inputPath)
                name = char(bindings(b).Input);
                if ~isKey(inputCache, name)
                    st_log(cfg, 'DEBUG', 'Specification MAT read start | File=%s | Scenario=%s', inputPath, name);
                    try
                        data = load(inputPath, name);
                        if ~isfield(data, name)
                            error('simtest:SpecificationInputMissing', 'MAT scenario variable missing: %s', name);
                        end
                        [content, note, inputMaxTime, readStatus] = ...
                            st_specification_input_scenario( ...
                            data.(name), target.SldvMode);
                        inputCache(name) = ...
                            {content, note, inputMaxTime, readStatus};
                        st_log(cfg, 'DEBUG', 'Specification MAT read end | Scenario=%s', name);
                    catch ME
                        inputCache(name) = ...
                            {"<읽기 실패>", string(ME.message), NaN, "FAIL"};
                        st_log(cfg, 'ERROR', 'Specification MAT read failed | File=%s | Scenario=%s | %s', ...
                            inputPath, name, ME.message);
                    end
                end
                item = inputCache(name);
                linked(6) = item{1};
                linked(13) = join_notes(linked(13), item{2});
                inputMaxTime = item{3};
                if item{4} == "FAIL", linked(12) = "FAIL"; end
            else
                linked(6) = "<읽기 실패>";
                linked(12) = "FAIL";
            end
        end
        if ~signalEditorAvailable, linked(6) = "해당 없음"; end
        [maxTime, rowMaxTimeSource, maxTimeNote] = st_specification_max_time( ...
            target.SldvMode, harnessStopTime, inputMaxTime);
        linked(13) = join_notes(linked(13), maxTimeNote);
        st_log(cfg, 'DEBUG', 'Specification MaxTime resolved | Case=%s | Scenario=%s | Source=%s | Value=%.17g', ...
            linked(1), linked(5), rowMaxTimeSource, maxTime);
        if strlength(linked(13)) > 0 && linked(12) == "OK", linked(12) = "WARN"; end
        if linked(12) ~= "OK"
            level = 'WARN';
            if linked(12) == "FAIL", level = 'ERROR'; end
            st_log(cfg, level, 'Specification row | Case=%s | Scenario=%s | %s', ...
                linked(1), linked(5), linked(13));
        end
        rows(end+1,:) = linked; %#ok<AGROW>
        verifyCells{end+1,1} = group; %#ok<AGROW>
        maxTimes(end+1,1) = maxTime; %#ok<AGROW>
        decisionBlockLists(end+1,1) = decisionBlockList; %#ok<AGROW>
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

function value = join_notes(a, b)
parts = [string(a); string(b)];
value = strjoin(parts(strlength(parts) > 0), ' | ');
end
