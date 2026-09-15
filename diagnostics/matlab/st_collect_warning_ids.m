function ids = st_collect_warning_ids(varargin)
%ST_COLLECT_WARNING_IDS List the warning identifiers a long run emits.
%
%   IDS = ST_COLLECT_WARNING_IDS(TASK) runs TASK, a function handle, with
%   verbose warnings and a diary, then returns the unique identifiers it
%   emitted. lastwarn reports only the final warning, so a run that mixes
%   several kinds cannot be silenced from it.
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

if isempty(logFile)
    logFile = [tempname(tempdir) '.txt'];
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
end

if ~isfile(logFile)
    error('simtest:WarningIdCollectorLogMissing', ...
        'No log to parse: %s', logFile);
end

text = fileread(logFile);
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
