function cleanup = st_suppress_warnings(cfg, scope)
%ST_SUPPRESS_WARNINGS Silence configured warnings for one scoped operation.
%
% Simulink repeats the same warning for every target in a long loop, which
% buries the toolkit's own progress output. Disable the configured
% identifiers for the scope, record them once, and restore the caller's
% warning state through the returned onCleanup object.

if nargin < 2 || strlength(strtrim(string(scope))) == 0
    scope = 'OPERATION';
end
scope = upper(char(string(scope)));
identifiers = configured_identifiers(cfg);
if isempty(identifiers)
    cleanup = onCleanup(@() []);
    return;
end

previousState = warning();
applied = {};
for i = 1:numel(identifiers)
    try
        warning('off', identifiers{i});
        applied{end+1} = identifiers{i}; %#ok<AGROW>
    catch ME
        st_log(cfg, 'WARN', ...
            ['Warning suppression rejected an identifier | Scope=%s | ' ...
             'Id=%s | %s'], scope, identifiers{i}, ME.message);
    end
end
st_log(cfg, 'INFO', ...
    'Warning suppression active | Scope=%s | Count=%d | Ids=%s', ...
    scope, numel(applied), strjoin(applied, ', '));
cleanup = onCleanup(@() restore_warnings(previousState, scope, cfg));
end

function restore_warnings(previousState, scope, cfg)
try
    warning(previousState);
    st_log(cfg, 'DEBUG', ...
        'Warning suppression restored | Scope=%s', scope);
catch ME
    st_log(cfg, 'ERROR', ...
        'Warning suppression restore failed | Scope=%s | %s: %s', ...
        scope, ME.identifier, ME.message);
end
end

function identifiers = configured_identifiers(cfg)
identifiers = {};
if ~isstruct(cfg) || ~isfield(cfg, 'SuppressedWarnings'), return; end
raw = cfg.SuppressedWarnings;
if isempty(raw), return; end
values = string(raw);
values = values(:);
values = strtrim(values(~ismissing(values)));
values = values(strlength(values) > 0);
% A bare word is not a warning identifier. Refusing it here keeps a typo
% from silently expanding into warning('off', 'all') behaviour.
valid = ~cellfun(@isempty, regexp(cellstr(values), '^\w+(:\w+)+$', 'once'));
identifiers = cellstr(unique(values(valid), 'stable'));
end
