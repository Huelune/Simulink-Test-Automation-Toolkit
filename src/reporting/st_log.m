function st_log(cfg, level, formatText, varargin)
%ST_LOG Timestamped diagnostic log: every level to file, some to console.
%
% Every message goes to the active run log (st_log_scope) or, outside a
% command, to <cfg.ResultDir>/logs/session_<yyyyMMdd>.log. The console
% shows only levels at or above cfg.ConsoleLogLevel:
%
%   TRACE < DEBUG < INFO < STEP < WARN < ERROR
%
% cfg.ConsoleLogLevel = 'STEP' (default) prints stage and target progress
% plus WARN/ERROR. A cfg without ConsoleLogLevel falls back to
% VerboseLogging (true = DEBUG, false = STEP) so older structs still work.

if nargin < 3
    error('Usage: st_log(cfg, level, formatText, ...)');
end
level = upper(strtrim(char(level)));
message = sprintf(char(formatText), varargin{:});
stamp = datetime('now');

scope = st_log_scope('current');
logPath = scope.LogPath;
if isempty(logPath)
    logPath = session_log_path(cfg, stamp);
end
if ~isempty(logPath)
    write_line(logPath, level, message, stamp);
end

if level_rank(level) >= level_rank(console_level(cfg))
    fprintf('%s\n', console_text(level, message, stamp));
end
end

function rank = level_rank(level)
switch level
    case 'TRACE', rank = 1;
    case 'DEBUG', rank = 2;
    case 'INFO',  rank = 3;
    case 'STEP',  rank = 4;
    case 'WARN',  rank = 5;
    case 'ERROR', rank = 6;
    otherwise,    rank = 3;
end
end

function level = console_level(cfg)
level = 'STEP';
if ~isstruct(cfg), return; end
if isfield(cfg, 'ConsoleLogLevel')
    candidate = upper(strtrim(char(string(cfg.ConsoleLogLevel))));
    if ismember(candidate, {'TRACE', 'DEBUG', 'INFO', 'STEP'})
        level = candidate;
    end
elseif isfield(cfg, 'VerboseLogging') && logical(cfg.VerboseLogging)
    level = 'DEBUG';
end
end

function text = console_text(level, message, stamp)
clockText = char(stamp, 'HH:mm:ss');
if strcmp(level, 'STEP')
    text = sprintf('[%s] %s', clockText, message);
else
    text = sprintf('[%s] %-5s %s', clockText, level, message);
end
end

function path = session_log_path(cfg, stamp)
path = '';
if ~isstruct(cfg) || ~isfield(cfg, 'ResultDir'), return; end
path = fullfile(char(cfg.ResultDir), 'logs', ...
    ['session_' char(stamp, 'yyyyMMdd') '.log']);
end

function write_line(logPath, level, message, stamp)
% A log that cannot be written must never fail the operation it describes.
try
    folder = fileparts(logPath);
    if ~isfolder(folder), mkdir(folder); end
    fileId = fopen(logPath, 'a', 'n', 'UTF-8');
    if fileId < 0
        error('simtest:LogOpenFailed', 'Cannot open %s', logPath);
    end
    closeFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
    fprintf(fileId, '[%s][%s] %s\n', ...
        char(stamp, 'yyyy-MM-dd HH:mm:ss.SSS'), level, message);
catch ME
    if st_log_scope('mark_write_failed', logPath)
        fprintf('[%s] WARN  Log file write failed; continuing without it | %s | %s\n', ...
            char(stamp, 'HH:mm:ss'), logPath, ME.message);
    end
end
end