function value = st_log_scope(action, varargin)
%ST_LOG_SCOPE One run log per top-level command; nested commands share it.
%
% guard = st_log_scope('enter', commandName)
% guard = st_log_scope('enter', commandName, logDir)
%     The outermost enter creates <logDir>/<yyyyMMdd_HHmmss>_<command>.log
%     (logDir defaults to <cfg.ResultDir>/logs). Nested enters reuse it.
%     Keep guard for the whole command; clearing it closes the scope.
% st_log_scope('fail', ME)          outermost command failed with ME
% st_log_scope('complete')          outermost command returned normally
%     Closing the scope prints done after complete, FAILED after fail and
%     INTERRUPTED after neither: Ctrl+C skips catch blocks and runs only
%     the guard's onCleanup, so an unmarked close is not a success.
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
        % A path that failed once (a locked file, a full disk) gets another
        % chance in each new command instead of staying silent all session.
        failedPaths = {};
        logDir = '';
        if numel(varargin) >= 2, logDir = char(string(varargin{2})); end
        cfg = safe_config(isempty(logDir));
        if isempty(logDir), logDir = default_log_dir(cfg); end
        state = open_state(commandName, logDir, cfg);
        value = onCleanup(@() st_log_scope('leave'));
        state = start_diary(state);
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
        % The closing lines are best effort. Whatever happens in them, the
        % scope must end here, or every later command would nest inside it.
        try
            log_closing_lines(finished);
        catch
        end
        try
            stop_diary(finished);
        catch
        end
        state = idle_state();
    case 'complete'
        value = [];
        % Only the outermost command returning normally ends the run as done.
        if state.Depth == 1, state.Completed = true; end
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
    'Timer', uint64(0), 'Failure', [], 'Completed', false, ...
    'StageIndex', 0, 'DiaryOwned', false, 'PreviousDiaryFile', '');
end

function log_closing_lines(finished)
elapsed = st_log_elapsed_text(toc(finished.Timer));
if ~isempty(finished.Failure)
    st_log(finished.Cfg, 'ERROR', '<== %s FAILED | %s | %s: %s', ...
        finished.Command, elapsed, finished.Failure.identifier, ...
        finished.Failure.message);
elseif finished.Completed
    st_log(finished.Cfg, 'STEP', '<== %s done | %s', ...
        finished.Command, elapsed);
else
    % Neither complete nor fail was called: Ctrl+C, or an error that left
    % through a path without a catch.
    st_log(finished.Cfg, 'ERROR', '<== %s INTERRUPTED | %s', ...
        finished.Command, elapsed);
end
if ~isempty(finished.LogPath)
    st_log(finished.Cfg, 'STEP', '    log: %s', finished.LogPath);
end
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

function cfg = safe_config(logDirFromConfig)
try
    cfg = st_config();
catch ME
    cfg = struct('ConsoleLogLevel', 'STEP');
    if logDirFromConfig
        % No scope or log file exists yet, so only the console can say so.
        fprintf('[%s] WARN  st_config failed; this run has no log file | %s\n', ...
            char(datetime('now', 'Format', 'HH:mm:ss')), ME.message);
    end
end
end

function logDir = default_log_dir(cfg)
logDir = '';
if isstruct(cfg) && isfield(cfg, 'ResultDir')
    logDir = fullfile(char(cfg.ResultDir), 'logs');
end
end

function state = start_diary(state)
if isempty(state.ConsolePath), return; end
if strcmp(get(0, 'Diary'), 'on')
    st_log(state.Cfg, 'WARN', ...
        'diary is already on; console copy not recorded | DiaryFile=%s', ...
        get(0, 'DiaryFile'));
    return;
end
state.PreviousDiaryFile = get(0, 'DiaryFile');
try
    diary(state.ConsolePath);
    state.DiaryOwned = true;
catch ME
    st_log(state.Cfg, 'WARN', 'Console copy could not start | %s', ME.message);
end
end

function stop_diary(state)
if ~state.DiaryOwned, return; end
try
    diary('off');
    set(0, 'DiaryFile', state.PreviousDiaryFile);
catch ME
    st_log(state.Cfg, 'WARN', 'Console copy could not stop | %s', ME.message);
end
end