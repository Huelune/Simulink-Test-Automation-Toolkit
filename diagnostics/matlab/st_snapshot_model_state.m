function snapshot = st_snapshot_model_state(model)
%ST_SNAPSHOT_MODEL_STATE Read model, config set and block parameters of a loaded model.
%
% snapshot = st_snapshot_model_state(model)
%
% Returns a table with one row per readable parameter:
%   Key    scope|relative block path|parameter, the same for two copies of
%          one model saved under different names, so snapshots of the
%          loaded model and of a renamed copy of its saved file line up.
%   Label  scope and parameter only (Model, Config or the BlockType), safe
%          to print because it carries no block or model name.
%   Value  the get_param result.
% Used to find what makes a model Dirty: snapshot the loaded model, load a
% renamed copy of the saved file, snapshot it, and compare the Value of
% equal Keys. Read only; nothing is changed or saved.
cfg = struct('ConsoleLogLevel', 'WARN');
st_log(cfg, 'DEBUG', 'Model state snapshot start | Model=%s', model);
keys = strings(0,1);
labels = strings(0,1);
values = cell(0,1);

names = fieldnames(get_param(model, 'ObjectParameters'));
for k = 1:numel(names)
    add(model, names{k}, "Model", "Model", "");
end
configSet = getActiveConfigSet(model);
names = fieldnames(get_param(configSet, 'ObjectParameters'));
for k = 1:numel(names)
    add(configSet, names{k}, "Config", "Config", "");
end
blocks = find_system(model, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
    'Type', 'Block');
prefix = strlength(string(model)) + 1;
for b = 1:numel(blocks)
    relative = extractAfter(string(blocks{b}), prefix);
    try
        type = string(get_param(blocks{b}, 'BlockType'));
        dialog = get_param(blocks{b}, 'DialogParameters');
    catch
        continue;
    end
    names = {};
    if isstruct(dialog), names = fieldnames(dialog); end
    for k = 1:numel(names)
        add(blocks{b}, names{k}, "Block", type, relative);
    end
end
snapshot = table(keys, labels, values, 'VariableNames', {'Key','Label','Value'});
st_log(cfg, 'DEBUG', 'Model state snapshot end | Model=%s | Parameters=%d', ...
    model, height(snapshot));

    function add(owner, name, scope, label, relative)
        try
            value = get_param(owner, name);
        catch
            return;
        end
        keys(end+1,1) = scope + "|" + relative + "|" + string(name);
        labels(end+1,1) = label + " " + string(name);
        values{end+1,1} = value;
    end
end
