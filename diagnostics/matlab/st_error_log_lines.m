function lines = st_error_log_lines(logLines, maxLines)
%ST_ERROR_LOG_LINES Screen lines for the ERROR lines of run logs, identifiers only.
%
% lines = st_error_log_lines(logLines, maxLines)
%
% logLines are lines of a run log file or of the console. The message
% names models, CUTs and paths, so none of it is shown. Each ERROR line
% becomes its time, the PER_CUT order ('PER_CUT 1/3') when it has one, and
% its error identifiers. An identifier whose first part is not a MathWorks
% product or the toolkit shows as (다른 식별자), since the team's own code
% may name its errors. Lines that say the same thing are one line with a
% count. At most maxLines lines; the rest is a count.
if nargin < 2, maxLines = 12; end
public = ["Simulink", "MATLAB", "sltest", "stm", "Stateflow", "simtest", "sldv", "Sldv", ...
    "Slvnv", "SimulinkFixedPoint", "SimulinkCoderApp", "RTW", "Coder", "coder", "SL", "sl", ...
    "Simscape", "physmod", "slcoverage", "SystemComposer"];
logLines = string(logLines(:));
keys = strings(0, 1);
times = strings(0, 1);
counts = zeros(0, 1);
for k = 1:numel(logLines)
    % A run log file writes '[yyyy-MM-dd HH:mm:ss.SSS][ERROR] ...', the console '[HH:mm:ss] ERROR ...'.
    parts = regexp(logLines(k), ['^\[(?:\d{4}-\d\d-\d\d )?(\d\d:\d\d:\d\d)(?:\.\d+)?\]' ...
        '\s*(?:\[ERROR\]|ERROR)\s+(.*)$'], 'tokens', 'once');
    if isempty(parts), continue; end
    message = parts(2);
    order = regexp(message, 'PER_CUT (\d+/\d+)', 'tokens', 'once');
    ids = regexp(message, '(?<![\w\\/.])[A-Za-z]\w*(?::\w+)+', 'match');
    shown = strings(0, 1);
    for id = ids
        if any(extractBefore(id, ":") == public), shown(end+1, 1) = id; else, shown(end+1, 1) = "(다른 식별자)"; end %#ok<AGROW>
    end
    shown = unique(shown, 'stable');
    text = "식별자 없음";
    if ~isempty(shown), text = strjoin(shown', ", "); end
    if ~isempty(order), text = "PER_CUT " + order + " | " + text; end
    at = find(keys == text, 1);
    if isempty(at)
        keys(end+1, 1) = text; %#ok<AGROW>
        times(end+1, 1) = parts(1); %#ok<AGROW>
        counts(end+1, 1) = 1; %#ok<AGROW>
    else
        counts(at) = counts(at) + 1;
    end
end
lines = cell(1, 0);
for k = 1:min(maxLines, numel(keys))
    line = "  [" + times(k) + "] " + keys(k);
    if counts(k) > 1, line = line + sprintf(" (%d번)", counts(k)); end
    lines{end+1} = char(line); %#ok<AGROW>
end
if numel(keys) > maxLines
    lines{end+1} = sprintf('  다른 ERROR %d가지 더 있음', numel(keys) - maxLines);
end
if isempty(keys), lines = {'  ERROR 없음'}; end
end
