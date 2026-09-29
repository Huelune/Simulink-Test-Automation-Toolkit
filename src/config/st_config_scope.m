function value = st_config_scope(action, arg)
%ST_CONFIG_SCOPE Temporary, nestable st_config overrides; never edits files.
%
% guard = st_config_scope('enter', overrides)
%     overrides is a struct whose fields replace the same st_config fields
%     until guard is cleared. The caller must retain the returned onCleanup
%     guard for its entire scope. An empty struct enters an empty scope.
% cfg = st_config_scope('apply', cfg)
%     Called by st_config. Returns cfg with the active overrides applied.
%
% Every stage calls st_config() on its own, so a command option that must
% reach every stage lives here instead of being threaded through each call.
persistent active
switch action
    case 'enter'
        previous = active;
        active = arg;
        value = onCleanup(@() st_config_scope('restore', previous));
    case 'restore'
        active = arg;
        value = [];
    case 'apply'
        value = arg;
        if isstruct(active)
            names = fieldnames(active);
            for k = 1:numel(names)
                if ~isfield(value, names{k})
                    error('simtest:UnknownConfigOverride', ...
                        'Unknown st_config override: %s', names{k});
                end
                value.(names{k}) = active.(names{k});
            end
        end
    otherwise
        error('simtest:InvalidConfigScope', ...
            'Unknown config scope action: %s', action);
end
end
