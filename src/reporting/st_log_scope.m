function value = st_log_scope(action, varargin)
%ST_LOG_SCOPE One run log per top-level command; nested commands share it.
%
% guard = st_log_scope('enter', commandName)
% guard = st_log_scope('enter', commandName, logDir)
%     The outermost enter creates <logDir>/<yyyyMMdd_HHmmss>_<command>.log
%     (logDir defaults to <cfg.ResultDir>/logs). Nested enters reuse it.
%     Keep guard for the whole command; clearing it closes the scope.
% st_log_scope('fail', ME)          outermost command failed with ME
% state = st_log_scope('current')   LogPath is '' outside every command
% k = st_log_scope('next_stage')    number the next workflow stage
% first = st_log_scope('mark_write_failed', path)   true once per path
persistent state failedPaths
if isempty(state), state = idle_state(); end
if ~iscell(failedPaths), failedPaths = {}; end

switch action
    case 'enter'
        commandName = char(string(varargin{1}));
        if state.Depth > 0
            state.Depth = state.Depth + 1;
            st_log(state.Cfg, 'INFO', 'Nested command | %s', commandName);
            value = onCleanup(@() st_log_scope('leave'));
            return;
        end
        cfg = safe_config();
        logDir = '';
        if numel(varargin) >= 2, logDir = char(string(varargin{2})); end
        if isempty(logDir), logDir = default_log_dir(cfg); end
        state = open_state(commandName, logDir, cfg);
        value = onCleanup(@() st_log_scope('leave'));
        st_log(state.Cfg, 'STEP', '==> %s start', commandName);
        if ~isempty(state.LogPath)
            st_log(state.Cfg, 'STEP', '    log: %s', state.LogPath);
        end
    case 'leave'
        value = [];
        if state.Depth > 1
            state.Depth = state.Depth - 1;
            return;
        end
        if state.Depth < 1, return; end
        finished = state;
        elapsed = st_log_elapsed_text(toc(finished.Timer));
        if isempty(finished.Failure)
            st_log(finished.Cfg, 'STEP', '<== %s done | %s', ...
                finished.Command, elapsed);
        else
            st_log(finished.Cfg, 'ERROR', '<== %s FAILED | %s | %s: %s', ...
                finished.Command, elapsed, finished.Failure.identifier, ...
                finished.Failure.message);
        end
        if ~isempty(finished.LogPath)
            st_log(finished.Cfg, 'STEP', '    log: %s', finished.LogPath);
        end
        state = idle_state();
    case 'fail'
        value = [];
        % Only the outermost command decides how the run ended; an inner
        % failure the outer command handled is not a failed run.
        if state.Depth == 1 && isempty(state.Failure)
            state.Failure = varargin{1};
            st_log(state.Cfg, 'DEBUG', 'Failure report | %s\n%s', ...
                state.Command, getReport(varargin{1}, 'extended', ...
                'hyperlinks', 'off'));
        end
    case 'current'
        value = state;
    case 'next_stage'
        state.StageIndex = state.StageIndex + 1;
        value = state.StageIndex;
    case 'mark_write_failed'
        path = char(string(varargin{1}));
        value = ~any(strcmp(failedPaths, path));
        if value, failedPaths{end+1} = path; end
    otherwise
        error('simtest:InvalidLogScope', 'Unknown log scope action: %s', action);
end
end

function state = idle_state()
state = struct('Depth', 0, 'Command', '', 'LogPath', '', ...
    'ConsolePath', '', 'Cfg', struct('ConsoleLogLevel', 'STEP'), ...
    'Timer', uint64(0), 'Failure', [], 'StageIndex', 0, ...
    'DiaryOwned', false, 'PreviousDiaryFile', '');
end

function state = open_state(commandName, logDir, cfg)
state = idle_state();
state.Depth = 1;
state.Command = commandName;
state.Cfg = cfg;
state.Timer = tic;
if isempty(logDir), return; end
try
    if ~isfolder(logDir), mkdir(logDir); end
catch
    % st_log reports the unwritable path once on its first write.
end
stem = regexprep(commandName, '[^\w]', '_');
base = fullfile(logDir, [char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss')) '_' stem]);
candidate = [base '.log'];
k = 2;
while isfile(candidate)
    candidate = sprintf('%s_%d.log', base, k);
    k = k + 1;
end
state.LogPath = candidate;
state.ConsolePath = [candidate(1:end-4) '.console.log'];
end

function cfg = safe_config()
try
    cfg = st_config();
catch
    cfg = struct('ConsoleLogLevel', 'STEP');
end
end

function logDir = default_log_dir(cfg)
logDir = '';
if isstruct(cfg) && isfield(cfg, 'ResultDir')
    logDir = fullfile(char(cfg.ResultDir), 'logs');
end
end