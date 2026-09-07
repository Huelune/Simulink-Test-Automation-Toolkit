function snap = st_harness_content_snapshot(owner, harness, cfg, storage, allowMissingInput)
%ST_HARNESS_CONTENT_SNAPSHOT Inspect standard test content and optionally clone blocks.
% storage is an empty temporary subsystem path; empty means inspection only.
if nargin < 4, storage = ''; end
if nargin < 5, allowMissingInput = false; end
owner = char(owner); harness = char(harness);
st_log(cfg, 'DEBUG', 'Import snapshot start | CUT=%s | Harness=%s', owner, harness);
matches = sltest.harness.find(owner, 'SearchDepth', 0, 'Name', harness);
if numel(matches) ~= 1
    error('simtest:ImportHarnessMissing', 'Expected one existing Harness: %s / %s', owner, harness);
end
loadedHere = ~bdIsLoaded(harness);
if loadedHere
    st_log(cfg, 'DEBUG', 'Import harness.load start | Harness=%s', harness);
    sltest.harness.load(owner, harness);
    st_log(cfg, 'DEBUG', 'Import harness.load end | Harness=%s', harness);
end
cleanup = onCleanup(@() close_loaded(owner, harness, loadedHere)); %#ok<NASGU>
if strcmp(get_param(harness, 'Dirty'), 'on')
    error('simtest:ImportUnsaved', 'Save Harness changes before import: %s', harness);
end
snap = struct('Owner', owner, 'Harness', harness, 'Storage', storage);
workspace = get_param(harness,'ModelWorkspace');
if ~isempty(whos(workspace))
    error('simtest:ImportLocalWorkspace', ...
        'Harness-local workspace data is outside standard import scope: %s',harness);
end
snap.HarnessFile = '';
if matches.saveExternally
    snap.HarnessFile = get_param(harness, 'FileName');
end
cutName = get_param(owner, 'Name');
rootBlocks = find_system(harness, 'SearchDepth', 1, 'Type', 'Block');
rootBlocks(strcmp(rootBlocks, harness)) = [];
names = cellfun(@(b) get_param(b, 'Name'), rootBlocks, 'UniformOutput', false);
cut = rootBlocks(strcmp(names, cutName));
if numel(cut) ~= 1
    error('simtest:ImportStructure', 'Cannot identify the original CUT block in %s.', harness);
end
allSequence = cellstr(string(sltest.testsequence.find));
sequence = allSequence(startsWith(allSequence, [harness '/']));
for k = 1:numel(sequence)
    if ~strcmp(get_param(sequence{k}, 'Parent'), harness)
        error('simtest:ImportStructure', 'Nested test blocks are not supported: %s', sequence{k});
    end
end
assessment = st_find_assessment_block(harness);
signal = {};
for k = 1:numel(rootBlocks)
    parameters = get_param(rootBlocks{k}, 'DialogParameters');
    if isfield(parameters, 'Filename') && isfield(parameters, 'ActiveScenario')
        signal{end+1,1} = rootBlocks{k}; %#ok<AGROW>
    end
end
if numel(signal) > 1 || numel(sequence) > 2
    error('simtest:ImportStructure', 'Only one Signal Editor and standard test blocks are supported.');
end
copyBlocks = sort([signal(:); sequence(:)]);
snap.BlockNames = cellfun(@(b) get_param(b, 'Name'), copyBlocks, 'UniformOutput', false);
snap.Connections = connections(harness);
snap.Structure = cell(numel(rootBlocks), 1);
for k = 1:numel(rootBlocks)
    b = rootBlocks{k};
    name = get_param(b, 'Name');
    kind = get_param(b, 'BlockType');
    if ~ismember(b, [copyBlocks; cut])
        allowedConversion = ismember(name, {'Input Conversion','Output Conversion'}) ...
            && strcmp(kind, 'SubSystem');
        if ~allowedConversion && ~ismember(kind, {'Inport','Outport'})
            error('simtest:ImportStructure', 'Nonstandard Harness block: %s', b);
        end
    end
    snap.Structure{k} = struct('Name', name, 'Type', kind, ...
        'Ports', get_param(b, 'Ports'));
    if ismember(name, {'Input Conversion','Output Conversion'}) && ~ismember(b,cut)
        snap.Structure{k}.Conversion = conversion_content(b);
    end
end
[~, order] = sort(names);
snap.Structure = snap.Structure(order);
snap.Settings = struct();
settings = {'StartTime','StopTime','SolverType','Solver','FixedStep', ...
    'MaxStep','MinStep','InitialStep','RelTol','AbsTol'};
if isa(getActiveConfigSet(harness), 'Simulink.ConfigSetRef')
    error('simtest:ImportConfigReference', 'Referenced Harness configuration is not supported.');
end
for k = 1:numel(settings)
    snap.Settings.(settings{k}) = get_param(harness, settings{k});
end
snap.Content = cell(numel(copyBlocks),1);
snap.InputFile = ''; snap.InputSHA256 = '';
snap.Profile = st_empty_sldv_profile();
snap.Profile.Mode = 'HARNESS_IMPORT';
snap.Profile.Status = 'OK';
snap.Profile.HasSignalEditor = ~isempty(signal);
snap.Profile.UsesScenarios = sltest.testsequence.isUsingScenarios(assessment);
snap.Profile.ScenarioNames = {'Iteration 1'};
snap.Profile.SignalScenarioNames = {};
if snap.Profile.UsesScenarios
    snap.Profile.ScenarioNames = cellstr(string(sltest.testsequence.getAllScenarios(assessment)));
end
if ~isempty(signal)
    try
        snap.Profile.SignalScenarioNames = cellstr(string(st_normalize_options( ...
            get_param(signal{1}, 'options@ActiveScenario'))));
    catch ME
        if ~allowMissingInput, rethrow(ME); end
        snap.Profile.SignalScenarioNames = {'<unavailable>'};
    end
    try
        snap.InputFile = st_resolve_data_file(get_param(signal{1}, 'Filename'), cfg.TopModel);
        inputSignature = st_file_signature(snap.InputFile);
        if ~inputSignature.Exists, error('simtest:ImportInputMissing', 'Input file is missing.'); end
        snap.InputSHA256 = inputSignature.SHA256;
    catch ME
        if ~allowMissingInput, rethrow(ME); end
        snap.InputSHA256 = 'MISSING';
    end
    if ~snap.Profile.UsesScenarios
        % A non-scenario assessment is run once with the current input.
        snap.Profile.SignalScenarioNames = {char(get_param(signal{1}, 'ActiveScenario'))};
    elseif ~isequal(sort(string(snap.Profile.ScenarioNames(:))), ...
            sort(string(snap.Profile.SignalScenarioNames(:))))
        if ~allowMissingInput
            error('simtest:ImportScenarioMismatch', 'Signal Editor and Assessment scenario names differ.');
        end
    else
        snap.Profile.SignalScenarioNames = snap.Profile.ScenarioNames;
    end
end
for k = 1:numel(copyBlocks)
    b = copyBlocks{k};
    reject_callbacks(b);
    if ismember(b, sequence)
        content = sequence_content(b);
    else
        content = dialog_content(b);
        content = rmfield(content, intersect(fieldnames(content), {'Filename'}));
    end
    % Never rewrite executable user expressions by textual path substitution.
    if contains(jsonencode(content), harness) || contains(jsonencode(content), owner)
        error('simtest:ImportLocalReference', 'Test content refers to the source Harness/CUT: %s', b);
    end
    snap.Content{k} = content;
    if ~isempty(storage)
        dest = [storage '/' escape_name(snap.BlockNames{k})];
        add_block(b, dest);
    end
end
snap.Fingerprint = st_hash_value(struct('Content', {snap.Content}, ...
    'Settings', snap.Settings, 'InputSHA256', snap.InputSHA256, ...
    'Structure', {snap.Structure}, 'Connections', {snap.Connections}, ...
    'Scenarios', {snap.Profile.ScenarioNames}));
st_log(cfg, 'DEBUG', 'Import snapshot end | CUT=%s | Harness=%s | SHA256=%s', ...
    owner, harness, snap.Fingerprint);
end

function content = sequence_content(block)
content = struct('Properties', sltest.testsequence.getProperty(block));
content.Properties = rmfield(content.Properties, ...
    intersect(fieldnames(content.Properties), {'Name'}));
symbols = cellstr(string(sltest.testsequence.findSymbol(block)));
content.Symbols = cell(numel(symbols),1);
for i = 1:numel(symbols)
    content.Symbols{i} = sltest.testsequence.readSymbol(block, symbols{i});
end
steps = cellstr(string(sltest.testsequence.findStep(block)));
content.Steps = cell(numel(steps),1);
for i = 1:numel(steps)
    item = sltest.testsequence.readStep(block, steps{i});
    item.Transitions = cell(item.TransitionCount,1);
    for j = 1:item.TransitionCount
        item.Transitions{j} = sltest.testsequence.readTransition(block, steps{i}, j);
    end
    content.Steps{i} = item;
end
content.UsesScenarios = sltest.testsequence.isUsingScenarios(block);
if content.UsesScenarios
    content.Scenarios = sltest.testsequence.getAllScenarios(block);
    content.ActiveScenario = sltest.testsequence.getActiveScenario(block);
    content.ScenarioControlSource = sltest.testsequence.getScenarioControlSource(block);
end
end

function content = dialog_content(block)
content = struct();
parameters = fieldnames(get_param(block, 'DialogParameters'));
for i = 1:numel(parameters)
    content.(parameters{i}) = get_param(block, parameters{i});
end
end

function reject_callbacks(block)
parameters = get_param(block, 'ObjectParameters');
names = fieldnames(parameters);
for i = 1:numel(names)
    if endsWith(names{i}, 'Fcn') && ~isempty(get_param(block, names{i}))
        % Linked standard blocks can carry MathWorks callbacks; only deviations fail.
        reference = get_param(block,'ReferenceBlock');
        if ~isempty(reference)
            library = extractBefore(string(reference),'/');
            load_system(char(library));
            if isequal(get_param(block,names{i}),get_param(reference,names{i})), continue; end
        end
        error('simtest:ImportCallback', 'Custom block callback is not supported: %s / %s', block, names{i});
    end
end
end

function result = connections(model)
% Destination-oriented enumeration preserves fan-out without line handles.
blocks = find_system(model, 'SearchDepth', 1, 'Type', 'Block');
blocks(strcmp(blocks, model)) = [];
result = cell(0,1);
for i = 1:numel(blocks)
    ports = get_param(blocks{i}, 'PortHandles');
    fields = fieldnames(ports);
    for f = 1:numel(fields)
        type = fields{f};
        if ismember(type, {'Outport','State','LConn','RConn'}), continue; end
        for p = 1:numel(ports.(type))
            line = get_param(ports.(type)(p), 'Line');
            if line == -1, continue; end
            source = get_param(line, 'SrcPortHandle');
            if source == -1
                error('simtest:ImportConnection', 'Unresolved Harness connection.');
            end
            srcBlock = get_param(source, 'Parent');
            logging = struct();
            for parameter = {'DataLogging','DataLoggingNameMode','DataLoggingName', ...
                    'DataLoggingDecimateData','DataLoggingDecimation', ...
                    'DataLoggingLimitDataPoints','DataLoggingMaxPoints'}
                logging.(parameter{1}) = get_param(line,parameter{1});
            end
            result{end+1,1} = struct('Source', get_param(srcBlock, 'Name'), ...
                'SourcePort', numeric_port(get_param(source, 'PortNumber')), ...
                'Destination', get_param(blocks{i}, 'Name'), ...
                'DestinationType', type, 'DestinationPort', p, ...
                'Name', get_param(line, 'Name'), 'Logging',logging); %#ok<AGROW>
        end
    end
end
keys = cellfun(@jsonencode, result, 'UniformOutput', false);
[~, order] = sort(keys); result = result(order);
end

function value = numeric_port(value)
if ischar(value) || isstring(value), value = str2double(value); end
value = double(value);
end

function result = conversion_content(root)
% Conversion plumbing must also match; added computation is not copied silently.
blocks = find_system(root,'LookUnderMasks','all','FollowLinks','on','Type','Block');
blocks(strcmp(blocks,root)) = [];
result = cell(numel(blocks),1);
allowed = {'SubSystem','Inport','Outport','SignalConversion','DataTypeConversion', ...
    'BusCreator','BusSelector','BusAssignment','BusToVector','SignalSpecification', ...
    'Reshape','RateTransition'};
for i = 1:numel(blocks)
    b = blocks{i};
    kind = get_param(b,'BlockType');
    if ~ismember(kind,allowed)
        error('simtest:ImportStructure','Unsupported conversion block: %s',b);
    end
    result{i} = struct('Path',b(numel(root)+2:end),'Type',kind, ...
        'Parameters',dialog_content(b));
    if strcmp(kind,'SubSystem'), result{i}.Connections = connections(b); end
end
keys = cellfun(@(x) x.Path,result,'UniformOutput',false);
[~,order] = sort(keys); result = result(order);
result{end+1} = struct('RootConnections',{connections(root)});
end

function name = escape_name(name)
name = strrep(name, '/', '//');
end

function close_loaded(owner, harness, loadedHere)
if loadedHere && bdIsLoaded(harness)
    sltest.harness.close(owner, harness);
end
end
