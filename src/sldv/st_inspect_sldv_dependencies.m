function dependency = st_inspect_sldv_dependencies(cutPath, cfg)
%ST_INSPECT_SLDV_DEPENDENCIES Find static SLDV dependency candidates.
%   The returned findings are warnings, not SLDV PASS/FAIL decisions.
%   Resolution follows documented Simulink hierarchy rules where a stable
%   public API exists and records ambiguous or unresolved cases explicitly.

if nargin < 2 || isempty(cfg)
    cfg = st_config();
end

cutPath = char(string(cutPath));
modelName = bdroot(cutPath);
inspectionTimer = tic;

st_log(cfg, 'DEBUG', ...
    '[SLDV Precheck] dependency inspection start | CUT=%s', cutPath);

dependency = empty_dependency();
warnings = strings(0,1);

[dependency.DataStore, dataStoreWarnings] = ...
    inspect_data_stores(cutPath, modelName);
[dependency.GotoFrom, gotoWarnings] = ...
    inspect_goto_from(cutPath, modelName);
[dependency.FunctionCaller, functionWarnings] = ...
    inspect_function_callers(cutPath, modelName);
[dependency.Stateflow, stateflowWarnings] = ...
    inspect_stateflow_data(cutPath);
[dependency.Boundary, boundaryWarnings] = ...
    inspect_boundary(cutPath);

warnings = [warnings; dataStoreWarnings; gotoWarnings; ...
    functionWarnings; stateflowWarnings; boundaryWarnings];
warnings = unique(warnings(warnings ~= ""), 'stable');

dependency.ExternalDataStoreCount = ...
    sum([dependency.DataStore.External]);
dependency.ExternalGotoCount = ...
    sum([dependency.GotoFrom.External]);
dependency.FunctionCallerCount = numel(dependency.FunctionCaller);
dependency.ExternalFunctionCallerCount = ...
    sum([dependency.FunctionCaller.External]);
dependency.StateflowExternalDataCount = ...
    sum([dependency.Stateflow.ExternalCandidate]);
dependency.BoundaryDependencyCount = numel(dependency.Boundary);
dependency.Warnings = warnings;
dependency.DependencyWarnings = warnings;
dependency.Success = true;
dependency.Message = sprintf( ...
    ['Static inspection completed: DataStore=%d, Goto=%d, ' ...
     'FunctionCaller=%d, Stateflow=%d, Boundary=%d'], ...
    dependency.ExternalDataStoreCount, ...
    dependency.ExternalGotoCount, ...
    dependency.FunctionCallerCount, ...
    dependency.StateflowExternalDataCount, ...
    dependency.BoundaryDependencyCount);

if isempty(dependency.Warnings)
    st_log(cfg, 'DEBUG', ...
        ['[SLDV Precheck] dependency inspection done | CUT=%s | ' ...
         'Warnings=0 | ElapsedSec=%.3f'], cutPath, toc(inspectionTimer));
else
    st_log(cfg, 'WARN', ...
        ['[SLDV Precheck] dependency candidates found | CUT=%s | ' ...
         'Warnings=%d | DataStore=%d | Goto=%d | ' ...
         'FunctionCaller=%d | Stateflow=%d | Boundary=%d | ' ...
         'ElapsedSec=%.3f'], ...
        cutPath, numel(dependency.Warnings), ...
        dependency.ExternalDataStoreCount, ...
        dependency.ExternalGotoCount, ...
        dependency.FunctionCallerCount, ...
        dependency.StateflowExternalDataCount, ...
        dependency.BoundaryDependencyCount, toc(inspectionTimer));

    for i = 1:numel(dependency.Warnings)
        st_log(cfg, 'DEBUG', ...
            '[SLDV Precheck] dependency detail | CUT=%s | %s', ...
            cutPath, dependency.Warnings(i));
    end
end
end


function dependency = empty_dependency()

dependency = struct();
dependency.Success = false;
dependency.Message = '';
dependency.DataStore = struct( ...
    'AccessBlock', {}, 'AccessType', {}, 'Name', {}, ...
    'DefinitionPath', {}, 'Resolution', {}, 'External', {});
dependency.GotoFrom = struct( ...
    'FromBlock', {}, 'Tag', {}, 'GotoPath', {}, ...
    'Visibility', {}, 'Resolution', {}, 'External', {});
dependency.FunctionCaller = struct( ...
    'CallerBlock', {}, 'FunctionName', {}, 'Prototype', {}, ...
    'DefinitionPath', {}, 'Resolution', {}, 'External', {});
dependency.Stateflow = struct( ...
    'ChartPath', {}, 'Name', {}, 'Scope', {}, 'ExternalCandidate', {});
dependency.Boundary = struct( ...
    'Type', {}, 'BlockPath', {}, 'Detail', {});
dependency.ExternalDataStoreCount = 0;
dependency.ExternalGotoCount = 0;
dependency.FunctionCallerCount = 0;
dependency.ExternalFunctionCallerCount = 0;
dependency.StateflowExternalDataCount = 0;
dependency.BoundaryDependencyCount = 0;
dependency.Warnings = strings(0,1);
dependency.DependencyWarnings = strings(0,1);
end


function [entries, warnings] = inspect_data_stores(cutPath, modelName)

template = empty_dependency();
entries = template.DataStore;
warnings = strings(0,1);
reads = safe_find_blocks(cutPath, 'DataStoreRead');
writes = safe_find_blocks(cutPath, 'DataStoreWrite');
accesses = [reads(:); writes(:)];

for i = 1:numel(accesses)
    access = accesses{i};
    name = safe_get_param(access, {'DataStoreName'}, '');
    [definition, resolution, ambiguous] = ...
        resolve_data_store(access, name, modelName);

    external = isempty(definition) || ...
        ~is_descendant_path(definition, cutPath);
    if isempty(definition)
        definitionText = '<workspace or unresolved>';
    else
        definitionText = definition;
    end

    entry = struct();
    entry.AccessBlock = access;
    entry.AccessType = get_param(access, 'BlockType');
    entry.Name = name;
    entry.DefinitionPath = definitionText;
    entry.Resolution = resolution;
    entry.External = external;
    entries(end+1,1) = entry; %#ok<AGROW>

    if external
        warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
            'External Data Store candidate: %s (%s) -> %s', ...
            access, name, definitionText));
    end
    if ambiguous
        warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
            'Ambiguous Data Store definition candidate: %s (%s)', ...
            access, name));
    end
end
end


function [definition, resolution, ambiguous] = ...
        resolve_data_store(accessPath, name, modelName)

definition = '';
resolution = 'Unresolved';
ambiguous = false;
currentSystem = get_param(accessPath, 'Parent');

while ~isempty(currentSystem)
    memories = find_blocks_at_level(currentSystem, 'DataStoreMemory');
    matches = filter_parameter(memories, 'DataStoreName', name);
    if ~isempty(matches)
        definition = matches{1};
        ambiguous = numel(matches) > 1;
        if ambiguous
            resolution = 'NearestHierarchyAmbiguous';
        else
            resolution = 'NearestHierarchy';
        end
        return;
    end

    if strcmp(currentSystem, modelName)
        break;
    end
    currentSystem = get_param(currentSystem, 'Parent');
end

[foundVariable, variableSource] = find_data_store_variable(modelName, name);
if foundVariable
    resolution = 'SimulinkVariable';
    definition = variableSource;
else
    resolution = 'WorkspaceOrUnresolved';
end
end


function [found, source] = find_data_store_variable(modelName, name)

found = false;
source = '';
if isempty(name) || exist('Simulink.findVars', 'file') == 0
    return;
end

try
    variables = Simulink.findVars( ...
        modelName, 'Name', name, 'SearchMethod', 'cached');
    if isempty(variables)
        return;
    end

    found = true;
    source = '<workspace variable>';
    candidateFields = {'Source', 'SourceType'};
    for i = 1:numel(candidateFields)
        field = candidateFields{i};
        try
            value = variables(1).(field);
            if ~isempty(value)
                source = sprintf('<%s: %s>', field, char(string(value)));
                return;
            end
        catch
        end
    end
catch
    % A cached variable query is optional and must not trigger compilation.
end
end


function [entries, warnings] = inspect_goto_from(cutPath, modelName)

template = empty_dependency();
entries = template.GotoFrom;
warnings = strings(0,1);
fromBlocks = safe_find_blocks(cutPath, 'From');
allGoto = safe_find_blocks(modelName, 'Goto');
allVisibility = safe_find_blocks(modelName, 'GotoTagVisibility');

for i = 1:numel(fromBlocks)
    fromPath = fromBlocks{i};
    tag = safe_get_param(fromPath, {'GotoTag'}, '');
    [matches, visibility, resolution] = resolve_goto( ...
        fromPath, tag, allGoto, allVisibility);

    externalFlags = false(numel(matches), 1);
    for k = 1:numel(matches)
        externalFlags(k) = ~is_descendant_path(matches{k}, cutPath);
    end
    external = ~isempty(matches) && all(externalFlags);

    entry = struct();
    entry.FromBlock = fromPath;
    entry.Tag = tag;
    entry.GotoPath = strjoin(matches, ' | ');
    entry.Visibility = visibility;
    entry.Resolution = resolution;
    entry.External = external;
    entries(end+1,1) = entry; %#ok<AGROW>

    if external
        warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
            'External Goto candidate: %s (%s) -> %s', ...
            fromPath, tag, entry.GotoPath));
    elseif isempty(matches)
        warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
            ['Goto resolution was inconclusive: %s (%s). ' ...
             'Compilation/sldvcompat remains authoritative.'], ...
            fromPath, tag));
    elseif numel(matches) > 1
        warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
            'Multiple visible Goto candidates: %s (%s)', fromPath, tag));
    end
end
end


function [matches, visibility, resolution] = ...
        resolve_goto(fromPath, tag, allGoto, allVisibility)

matches = {};
visibility = '';
resolution = 'Unresolved';
fromParent = get_param(fromPath, 'Parent');

tagMatches = filter_parameter(allGoto, 'GotoTag', tag);
if isempty(tagMatches)
    return;
end

% Local and scoped Goto blocks in the same system are directly visible.
sameSystem = tagMatches(cellfun( ...
    @(path) strcmp(get_param(path, 'Parent'), fromParent), tagMatches));
localOrScoped = sameSystem(cellfun(@(path) ismember(lower( ...
    safe_get_param(path, {'TagVisibility'}, 'local')), ...
    {'local', 'scoped'}), sameSystem));
if ~isempty(localOrScoped)
    matches = localOrScoped;
    visibility = safe_get_param(matches{1}, {'TagVisibility'}, 'local');
    resolution = 'SameSystemScope';
    return;
end

% Scoped tags use the nearest visible Goto Tag Visibility block.
visibilityMatches = filter_parameter(allVisibility, 'GotoTag', tag);
bestDistance = Inf;
bestMatches = {};
for i = 1:numel(visibilityMatches)
    scopeSystem = get_param(visibilityMatches{i}, 'Parent');
    distance = ancestor_distance(fromParent, scopeSystem);
    if ~isfinite(distance) || ...
            ~strcmp(routing_domain(fromPath), routing_domain(scopeSystem))
        continue;
    end

    scopedGoto = tagMatches(cellfun(@(path) ...
        strcmpi(safe_get_param(path, {'TagVisibility'}, ''), 'scoped') && ...
        is_descendant_path(path, scopeSystem) && ...
        strcmp(routing_domain(path), routing_domain(fromPath)), ...
        tagMatches));
    if isempty(scopedGoto)
        continue;
    end

    if distance < bestDistance
        bestDistance = distance;
        bestMatches = scopedGoto;
    elseif distance == bestDistance
        bestMatches = [bestMatches; scopedGoto(:)]; %#ok<AGROW>
    end
end
if ~isempty(bestMatches)
    matches = unique(bestMatches, 'stable');
    visibility = 'scoped';
    resolution = 'GotoTagVisibilityScope';
    return;
end

% Global tags are visible only within the same nonvirtual routing domain.
fromDomain = routing_domain(fromPath);
globalMatches = tagMatches(cellfun(@(path) ...
    strcmpi(safe_get_param(path, {'TagVisibility'}, ''), 'global') && ...
    strcmp(routing_domain(path), fromDomain), tagMatches));
if ~isempty(globalMatches)
    matches = globalMatches;
    visibility = 'global';
    resolution = 'GlobalRoutingDomain';
end
end


function [entries, warnings] = inspect_function_callers(cutPath, modelName)

template = empty_dependency();
entries = template.FunctionCaller;
warnings = strings(0,1);
callers = safe_find_blocks(cutPath, 'FunctionCaller');
definitions = find_simulink_function_definitions(modelName);

for i = 1:numel(callers)
    caller = callers{i};
    [functionName, prototype] = caller_function_name(caller);
    [matches, resolution] = resolve_function_definition( ...
        caller, functionName, definitions, cutPath);

    externalFlags = false(numel(matches), 1);
    for k = 1:numel(matches)
        externalFlags(k) = ~is_descendant_path(matches{k}, cutPath);
    end
    external = ~isempty(matches) && all(externalFlags);

    entry = struct();
    entry.CallerBlock = caller;
    entry.FunctionName = functionName;
    entry.Prototype = prototype;
    entry.DefinitionPath = strjoin(matches, ' | ');
    entry.Resolution = resolution;
    entry.External = external;
    entries(end+1,1) = entry; %#ok<AGROW>

    if external
        warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
            'External Simulink Function candidate: %s (%s) -> %s', ...
            caller, functionName, entry.DefinitionPath));
    elseif isempty(matches)
        warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
            ['Function Caller definition was not statically resolved: ' ...
             '%s (%s). It may be exported by Stateflow, an S-Function, ' ...
             'or a referenced model.'], caller, functionName));
    elseif numel(matches) > 1
        warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
            'Multiple Simulink Function definition candidates: %s (%s)', ...
            caller, functionName));
    end
end
end


function definitions = find_simulink_function_definitions(modelName)

definitions = struct('Path', {}, 'Name', {}, 'Visibility', {});
triggers = safe_find_blocks(modelName, 'TriggerPort');

for i = 1:numel(triggers)
    trigger = triggers{i};
    if ~parameter_exists(trigger, 'FunctionVisibility')
        continue;
    end

    name = safe_get_param(trigger, ...
        {'FunctionName', 'ScopedFunctionName', 'FunctionPrototype'}, '');
    name = prototype_function_name(name);
    if isempty(name)
        continue;
    end

    entry = struct();
    entry.Path = get_param(trigger, 'Parent');
    entry.Name = name;
    entry.Visibility = safe_get_param( ...
        trigger, {'FunctionVisibility'}, 'scoped');
    definitions(end+1,1) = entry; %#ok<AGROW>
end
end


function [name, prototype] = caller_function_name(caller)

prototype = safe_get_param(caller, {'FunctionPrototype', 'Prototype'}, '');
name = safe_get_param(caller, ...
    {'ScopedFunctionName', 'FunctionName', 'Function'}, '');
if isempty(name)
    name = prototype_function_name(prototype);
else
    name = prototype_function_name(name);
end
end


function name = prototype_function_name(value)

textValue = strtrim(char(string(value)));
name = '';
if isempty(textValue)
    return;
end

openParen = find(textValue == '(', 1, 'first');
if ~isempty(openParen)
    textValue = textValue(1:openParen - 1);
end
equals = find(textValue == '=', 1, 'last');
if ~isempty(equals)
    textValue = textValue(equals + 1:end);
end
tokens = regexp(strtrim(textValue), ...
    '[A-Za-z]\w*(?:\.[A-Za-z]\w*)*', 'match');
if ~isempty(tokens)
    name = tokens{end};
end
end


function [matches, resolution] = resolve_function_definition( ...
        caller, functionName, definitions, cutPath)

matches = {};
resolution = 'Unresolved';
if isempty(functionName) || isempty(definitions)
    return;
end

unqualified = regexp(functionName, '[^.]+$', 'match', 'once');
definitionNames = {definitions.Name};
matched = strcmp(definitionNames, functionName) | ...
    strcmp(definitionNames, unqualified);
candidateDefinitions = definitions(matched);
if isempty(candidateDefinitions)
    return;
end

insideCut = arrayfun(@(item) ...
    is_descendant_path(item.Path, cutPath), candidateDefinitions);
if any(insideCut)
    matches = {candidateDefinitions(insideCut).Path}.';
    resolution = 'DefinitionInsideCUT';
    return;
end

callerParent = get_param(caller, 'Parent');
distances = Inf(numel(candidateDefinitions), 1);
for i = 1:numel(candidateDefinitions)
    definitionParent = get_param(candidateDefinitions(i).Path, 'Parent');
    distances(i) = hierarchy_proximity(callerParent, definitionParent);
end
nearest = min(distances);
if isfinite(nearest)
    candidateDefinitions = candidateDefinitions(distances == nearest);
end

matches = {candidateDefinitions.Path}.';
if numel(matches) == 1
    resolution = 'StaticHierarchyCandidate';
else
    resolution = 'StaticHierarchyAmbiguous';
end
end


function distance = hierarchy_proximity(a, b)

ancestorsA = system_ancestors(a);
ancestorsB = system_ancestors(b);
distance = Inf;
for i = 1:numel(ancestorsA)
    match = find(strcmp(ancestorsB, ancestorsA{i}), 1, 'first');
    if ~isempty(match)
        distance = (i - 1) + (match - 1);
        return;
    end
end
end


function [entries, warnings] = inspect_stateflow_data(cutPath)

template = empty_dependency();
entries = template.Stateflow;
warnings = strings(0,1);
if exist('sfroot', 'file') == 0
    return;
end

try
    dataObjects = find(sfroot, '-isa', 'Stateflow.Data');
catch ME
    warnings = "Stateflow inspection unavailable: " + string(ME.message);
    return;
end

externalScopes = {'Parameter', 'Constant', 'Data Store Memory', ...
    'Imported', 'Exported'};
for i = 1:numel(dataObjects)
    object = dataObjects(i);
    try
        chartPath = char(object.Path);
        if ~is_descendant_path(chartPath, cutPath)
            continue;
        end

        scope = char(object.Scope);
        external = any(strcmpi(scope, externalScopes));
        entry = struct();
        entry.ChartPath = chartPath;
        entry.Name = char(object.Name);
        entry.Scope = scope;
        entry.ExternalCandidate = external;
        entries(end+1,1) = entry; %#ok<AGROW>

        if external
            warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
                'Stateflow parent/external data candidate: %s/%s (Scope=%s)', ...
                chartPath, entry.Name, scope));
        end
    catch ME
        warnings(end+1,1) = ...
            "Stateflow data inspection was incomplete: " + string(ME.message); %#ok<AGROW>
    end
end
end


function [entries, warnings] = inspect_boundary(cutPath)

template = empty_dependency();
entries = template.Boundary;
warnings = strings(0,1);
if strcmp(get_param(cutPath, 'Type'), 'block_diagram')
    return;
end

if strcmpi(safe_get_param(cutPath, ...
        {'TreatAsAtomicUnit'}, 'off'), 'off')

    entry = struct();
    entry.Type = 'NonatomicSubsystem';
    entry.BlockPath = cutPath;
    entry.Detail = 'TreatAsAtomicUnit=off';
    entries(end+1,1) = entry;
    warnings(end+1,1) = string(sprintf( ...
        ['SLDV subsystem extraction candidate: %s is not atomic ' ...
         '(TreatAsAtomicUnit=off).'], cutPath));
end

boundaryTypes = {'EnablePort', 'TriggerPort', 'ResetPort', 'ActionPort'};
for i = 1:numel(boundaryTypes)
    blocks = find_blocks_at_level(cutPath, boundaryTypes{i});
    for k = 1:numel(blocks)
        block = blocks{k};
        detail = boundary_detail(block, boundaryTypes{i});
        entry = struct();
        entry.Type = boundary_label(boundaryTypes{i}, detail);
        entry.BlockPath = block;
        entry.Detail = detail;
        entries(end+1,1) = entry; %#ok<AGROW>
        warnings(end+1,1) = string(sprintf( ... %#ok<AGROW>
            'Boundary execution dependency candidate: %s (%s)', ...
            block, entry.Type));
    end
end
end


function detail = boundary_detail(block, blockType)

switch blockType
    case 'TriggerPort'
        detail = safe_get_param(block, ...
            {'TriggerType', 'TriggerSignalType'}, 'trigger');
    case 'EnablePort'
        detail = safe_get_param(block, {'StatesWhenEnabling'}, 'enable');
    case 'ResetPort'
        detail = safe_get_param(block, {'ResetTriggerType'}, 'reset');
    case 'ActionPort'
        detail = safe_get_param(block, ...
            {'InitializeStates', 'StatesWhenEnabling'}, 'action');
    otherwise
        detail = blockType;
end
end


function label = boundary_label(blockType, detail)

if strcmp(blockType, 'TriggerPort') && contains(lower(detail), 'function')
    label = 'Function-call';
elseif strcmp(blockType, 'EnablePort')
    label = 'Enable';
elseif strcmp(blockType, 'TriggerPort')
    label = 'Trigger';
elseif strcmp(blockType, 'ResetPort')
    label = 'Reset';
elseif strcmp(blockType, 'ActionPort')
    label = 'Action';
else
    label = blockType;
end
end


function blocks = safe_find_blocks(systemPath, blockType)

try
    blocks = find_system( ...
        systemPath, ...
        'FollowLinks', 'on', ...
        'LookUnderMasks', 'all', ...
        'Type', 'Block', ...
        'BlockType', blockType);
catch
    blocks = {};
end
blocks = blocks(:);
end


function blocks = find_blocks_at_level(systemPath, blockType)

try
    blocks = find_system( ...
        systemPath, ...
        'SearchDepth', 1, ...
        'FollowLinks', 'on', ...
        'LookUnderMasks', 'all', ...
        'Type', 'Block', ...
        'BlockType', blockType);
catch
    blocks = {};
end
blocks = blocks(:);
end


function matches = filter_parameter(blocks, parameter, expected)

matches = blocks(cellfun(@(path) ...
    strcmp(safe_get_param(path, {parameter}, ''), expected), blocks));
end


function value = safe_get_param(block, candidates, defaultValue)

value = defaultValue;
for i = 1:numel(candidates)
    name = candidates{i};
    if ~parameter_exists(block, name)
        continue;
    end
    try
        candidate = get_param(block, name);
        if ~isempty(candidate)
            value = char(string(candidate));
            return;
        end
    catch
    end
end
end


function tf = parameter_exists(block, parameter)

tf = false;
try
    parameters = get_param(block, 'ObjectParameters');
    tf = isfield(parameters, parameter);
catch
end
end


function tf = is_descendant_path(path, ancestor)

tf = false;
if isempty(path) || isempty(ancestor) || startsWith(path, '<')
    return;
end

current = path;
while ~isempty(current)
    if strcmp(current, ancestor)
        tf = true;
        return;
    end
    try
        parent = get_param(current, 'Parent');
    catch
        return;
    end
    if isempty(parent) || strcmp(parent, current)
        return;
    end
    current = parent;
end
end


function distance = ancestor_distance(path, ancestor)

distance = Inf;
current = path;
for i = 0:1000
    if strcmp(current, ancestor)
        distance = i;
        return;
    end
    try
        parent = get_param(current, 'Parent');
    catch
        return;
    end
    if isempty(parent) || strcmp(parent, current)
        return;
    end
    current = parent;
end
end


function ancestors = system_ancestors(path)

ancestors = cell(0,1);
current = path;
for i = 1:1000
    ancestors{end+1,1} = current; %#ok<AGROW>
    try
        parent = get_param(current, 'Parent');
    catch
        break;
    end
    if isempty(parent) || strcmp(parent, current)
        break;
    end
    current = parent;
end
end


function domain = routing_domain(path)

try
    if strcmp(get_param(path, 'Type'), 'block') && ...
            ~strcmp(get_param(path, 'BlockType'), 'SubSystem')
        current = get_param(path, 'Parent');
    else
        current = path;
    end
catch
    domain = bdroot(path);
    return;
end

domain = bdroot(current);
while ~isempty(current)
    if strcmp(get_param(current, 'Type'), 'block_diagram')
        return;
    end
    if is_nonvirtual_system(current)
        domain = current;
        return;
    end
    current = get_param(current, 'Parent');
end
end


function tf = is_nonvirtual_system(systemPath)

tf = false;
if strcmp(get_param(systemPath, 'Type'), 'block_diagram')
    return;
end

value = safe_get_param(systemPath, {'IsSubsystemVirtual'}, '');
if ~isempty(value)
    tf = strcmpi(value, 'off');
    return;
end

tf = strcmpi(safe_get_param(systemPath, {'TreatAsAtomicUnit'}, 'off'), 'on');
if tf
    return;
end

controlTypes = {'EnablePort', 'TriggerPort', 'ResetPort', 'ActionPort'};
for i = 1:numel(controlTypes)
    if ~isempty(find_blocks_at_level(systemPath, controlTypes{i}))
        tf = true;
        return;
    end
end
end
