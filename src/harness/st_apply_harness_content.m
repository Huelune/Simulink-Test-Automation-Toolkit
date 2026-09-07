function st_apply_harness_content(source, target, inputFile, cfg)
%ST_APPLY_HARNESS_CONTENT Replace test blocks while retaining the original CUT.
owner = target.Owner; harness = target.Harness;
st_log(cfg, 'INFO', 'Import apply start | CUT=%s | Harness=%s', owner, harness);
st_log(cfg, 'DEBUG', 'Import harness.load start | Harness=%s', harness);
sltest.harness.load(owner, harness);
st_log(cfg, 'DEBUG', 'Import harness.load end | Harness=%s', harness);
% Rebuild root-level wiring from destination endpoints; never replace the CUT.
lines = find_system(harness, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line');
roots = false(size(lines));
for i = 1:numel(lines)
    roots(i) = get_param(lines(i), 'LineParent') == -1;
end
for line = reshape(lines(roots),1,[]), delete_line(line); end
for i = 1:numel(target.BlockNames)
    name = strrep(target.BlockNames{i}, '/', '//');
    destination = [harness '/' name];
    position = get_param(destination, 'Position');
    orientation = get_param(destination, 'Orientation');
    delete_block(destination);
    add_block([source.Storage '/' name], destination, ...
        'Position', position, 'Orientation', orientation);
end
if source.Profile.HasSignalEditor
    block = st_find_signal_editor_block(harness);
    active = get_param(block, 'ActiveScenario');
    set_param(block, 'Filename', inputFile);
    set_param(block, 'ActiveScenario', active);
end
settings = fieldnames(source.Settings);
for i = 1:numel(settings)
    set_param(harness, settings{i}, source.Settings.(settings{i}));
end
for i = 1:numel(source.Connections)
    c = source.Connections{i};
    sourcePorts = get_param([harness '/' strrep(c.Source,'/','//')], 'PortHandles');
    destPorts = get_param([harness '/' strrep(c.Destination,'/','//')], 'PortHandles');
    line = add_line(harness, sourcePorts.Outport(c.SourcePort), ...
        destPorts.(c.DestinationType)(c.DestinationPort), 'autorouting','on');
    set_param(line, 'Name', c.Name);
    fields = fieldnames(c.Logging);
    for k = 1:numel(fields)
        set_param(line,fields{k},c.Logging.(fields{k}));
    end
end
st_log(cfg, 'DEBUG', 'Import save_system start | Harness=%s', harness);
save_system(harness);
sltest.harness.close(owner, harness);
save_system(cfg.TopModel);
st_log(cfg, 'DEBUG', 'Import save_system end | Harness=%s', harness);
st_log(cfg, 'INFO', 'Import apply end | CUT=%s | Harness=%s', owner, harness);
end
