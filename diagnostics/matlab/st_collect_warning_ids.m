function ids = st_collect_warning_ids(varargin)
%ST_COLLECT_WARNING_IDS List the warning identifiers a long run emits.
%
%   IDS = ST_COLLECT_WARNING_IDS(TASK) runs TASK, a function handle, with
%   verbose warnings and a diary, then returns the unique identifiers it
%   emitted. lastwarn reports only the final warning, so a run that mixes
%   several kinds cannot be silenced from it.
%
%   MathWorks calls the toolkit wraps (st_call_quiet) print into the run
%   log as [SYS <label>] lines, not to the console the diary records. So
%   the run logs under <cfg.ResultDir>/logs written while TASK ran (the
%   .log files, not .console.log) are read as well. The task's own command
%   finds this diary already on and keeps no .console.log copy.
%
%   IDS = ST_COLLECT_WARNING_IDS('LogFile', PATH) parses a diary you already
%   captured instead of running anything.
%
%   The printed block can be pasted into cfg.SuppressedWarnings. Read the
%   list before suppressing it: a parameterized library link warning is
%   about the model, not about noise.
%
%   Example:
%     ids = st_collect_warning_ids(@() st_export_test_bundle( ...
%         'ExecutionModelMode', 'STANDALONE_HARNESS'));

p = inputParser;
p.FunctionName = mfilename;
addOptional(p, 'Task', [], @(x) isempty(x) || isa(x, 'function_handle'));
addParameter(p, 'LogFile', '', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
task = p.Results.Task;
logFile = strtrim(char(string(p.Results.LogFile)));

if isempty(task) && isempty(logFile)
    error('simtest:WarningIdCollectorInputMissing', ...
        'Pass a function handle to run, or LogFile of a captured diary.');
end

runLogs = {};
if isempty(logFile)
    logFile = [tempname(tempdir) '.txt'];
    % dir() reports modification times to the second. Round the start down
    % so a run log opened in the same second still counts.
    taskStart = floor(now * 86400) / 86400;
    previousVerbose = warning('query', 'verbose');
    restoreVerbose = onCleanup(@() warning(previousVerbose)); %#ok<NASGU>
    warning('on', 'verbose');
    diary(logFile);
    diaryCleanup = onCleanup(@() diary('off'));
    fprintf('Collecting warning identifiers into %s\n', logFile);
    try
        task();
    catch ME
        fprintf('Task failed: %s: %s\n', ME.identifier, ME.message);
        fprintf('Identifiers emitted before the failure are still listed.\n');
    end
    clear diaryCleanup;
    runLogs = run_logs_since(taskStart);
    fprintf('Also reading %d run log(s) written during the task.\n', ...
        numel(runLogs));
end

if ~isfile(logFile)
    error('simtest:WarningIdCollectorLogMissing', ...
        'No log to parse: %s', logFile);
end

text = fileread(logFile);
for k = 1:numel(runLogs)
    text = [text newline system_lines(runLogs{k})]; %#ok<AGROW>
end
tokens = regexp(text, 'warning off ([A-Za-z]\w*(?::\w+)+)', 'tokens');
if isempty(tokens)
    ids = {};
    fprintf(['No identifier found. Verbose warnings must be on while the ' ...
        'run happens; a diary captured without them has no ids.\n']);
    return;
end
ids = unique(cellfun(@(c) c{1}, tokens, 'UniformOutput', false), 'stable');

fprintf('\n%d warning identifier(s):\n', numel(ids));
for i = 1:numel(ids)
    fprintf('  %s\n', ids{i});
end
fprintf('\nPaste into src/config/st_config.m after reviewing each entry:\n');
fprintf('cfg.SuppressedWarnings = { ...\n');
for i = 1:numel(ids)
    fprintf('    ''%s'', ...\n', ids{i});
end
fprintf('    };\n');
end

function paths = run_logs_since(startTime)
%RUN_LOGS_SINCE Run logs under <cfg.ResultDir>/logs modified since startTime.
paths = {};
try
    cfg = st_config();
    listing = dir(fullfile(char(cfg.ResultDir), 'logs', '*.log'));
catch ME
    fprintf('Run logs not read: %s\n', ME.message);
    return;
end
if isempty(listing), return; end
keep = ~endsWith({listing.name}, '.console.log') & ...
    [listing.datenum] >= startTime;
listing = listing(keep);
if isempty(listing), return; end
paths = fullfile({listing.folder}, {listing.name});
end

function text = system_lines(path)
%SYSTEM_LINES The [SYS <label>] lines of one run log, where wrapped MathWorks
% output (its warnings included) is kept.
lines = cellstr(splitlines(string(fileread(path))));
text = sprintf('%s\n', lines{contains(lines, '[SYS ')});
end
