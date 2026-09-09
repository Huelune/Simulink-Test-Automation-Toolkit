function signatures = st_clone_cut_interfaces(owners, cfg)
%ST_CLONE_CUT_INTERFACES Reuse compiled port/bus analysis for one owner model.
owners = cellstr(unique(string(owners(:))));
owners(cellfun(@isempty, owners)) = [];
signatures = containers.Map('KeyType','char','ValueType','char');
st_log(cfg, 'INFO', 'Clone interface compile start | Model=%s', cfg.TopModel);
cleanup = onCleanup(@() terminate_compile(cfg)); %#ok<NASGU>
try
    feval(cfg.TopModel, [], [], [], 'compile');
catch ME
    st_log(cfg, 'ERROR', 'Clone interface compile failed | Model=%s | %s', cfg.TopModel, ME.message);
    rethrow(ME);
end
st_log(cfg, 'INFO', 'Clone interface compile end | Model=%s', cfg.TopModel);
for i = 1:numel(owners)
    owner = owners{i};
    if ~strcmp(get_param(owner, 'BlockType'), 'SubSystem')
        error('simtest:CloneCUTType', 'Clone requires a Subsystem CUT: %s', owner);
    end
    ports = get_param(owner, 'PortHandles');
    assert_supported_ports(owner, ports);
    content = struct();
    for field = {'Inport','Outport','Enable','Trigger','Ifaction','Reset'}
        name = field{1};
        values = {};
        if isfield(ports, name)
            for j = 1:numel(ports.(name))
                port = ports.(name)(j);
                values{j} = struct('Type', get_param(port, 'CompiledPortDataType'), ...
                    'Dimensions', get_param(port, 'CompiledPortDimensions'), ...
                    'Complex', get_param(port, 'CompiledPortComplexSignal')); %#ok<AGROW>
                if ismember(name,{'Inport','Outport'})
                    values{j}.BusType = get_param(port,'CompiledBusType');
                    if ~strcmp(values{j}.BusType,'NOT_BUS')
                        hierarchy = get_param(port,'SignalHierarchy');
                        if isempty(hierarchy.BusObject)
                            error('simtest:CloneAnonymousBus', ...
                                'Clone requires a named Bus object to verify element types: %s',owner);
                        end
                        values{j}.Bus = bus_definition(hierarchy.BusObject,owner,{});
                    end
                end
            end
        end
        content.(name) = values;
    end
    for field = {'Inport','Outport'}
        blocks = find_system(owner, 'SearchDepth', 1, 'BlockType', field{1});
        numbers = cellfun(@(b) str2double(get_param(b,'Port')), blocks);
        [~, order] = sort(numbers);
        content.([field{1} 'Names']) = cellfun(@(b) get_param(b,'Name'), ...
            blocks(order), 'UniformOutput', false);
        content.([field{1} 'SampleTimes']) = cellfun(@(b) get_param(b,'CompiledSampleTime'), ...
            blocks(order), 'UniformOutput', false);
    end
    content.SampleTime = get_param(owner,'CompiledSampleTime');
    signatures(owner) = st_hash_value(content);
end
end

function assert_supported_ports(owner, ports)
unsupported = {'LConn','RConn','Event'};
for i = 1:numel(unsupported)
    name = unsupported{i};
    if isfield(ports, name) && ~isempty(ports.(name))
        error('simtest:CloneUnsupportedPort', ...
            'Clone does not support physical or event CUT ports: %s / %s', ...
            owner, name);
    end
end
end

function value = bus_definition(name,owner,visited)
name = char(string(name));
if ismember(name,visited)
    error('simtest:CloneRecursiveBus','Recursive Bus definition: %s',name);
end
bus = slResolve(name,owner);
if ~isa(bus,'Simulink.Bus')
    error('simtest:CloneBusUnresolved','Cannot resolve Bus %s in %s.',name,owner);
end
value = cell(numel(bus.Elements),1);
for k = 1:numel(bus.Elements)
    element = bus.Elements(k);
    value{k} = struct('Name',element.Name,'DataType',element.DataType, ...
        'Dimensions',element.Dimensions,'DimensionsMode',element.DimensionsMode, ...
        'Complexity',element.Complexity,'Unit',element.Unit);
    dataType = char(string(element.DataType));
    if startsWith(dataType,'Bus:')
        value{k}.Bus = bus_definition(strtrim(extractAfter(dataType,':')), ...
            owner,[visited {name}]);
    end
end
end

function terminate_compile(cfg)
st_log(cfg, 'DEBUG', 'Clone compile termination start | Model=%s', cfg.TopModel);
try
    feval(cfg.TopModel, [], [], [], 'term');
catch ME
    st_log(cfg,'WARN','Clone compile termination failed | Model=%s | %s',cfg.TopModel,ME.message);
end
st_log(cfg, 'DEBUG', 'Clone compile termination end | Model=%s', cfg.TopModel);
end
