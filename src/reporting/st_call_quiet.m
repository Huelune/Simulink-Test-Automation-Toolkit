function varargout = st_call_quiet(cfg, label, fn)
%ST_CALL_QUIET Run a chatty MathWorks API with its console output in the log.
%
% [a, b] = st_call_quiet(cfg, 'sldvrun', @() sldvrun(path, opts, false))
%
% Everything fn prints, warnings included, goes to the run log as DEBUG
% lines tagged [SYS label]. The console gets one WARN line when that output
% held warnings. An error inside fn is rethrown unchanged after its output
% has been logged, so nothing printed before the failure is lost.
label = char(string(label));
outputs = cell(1, nargout);
callError = [];
timerValue = tic;
st_log(cfg, 'DEBUG', '[SYS %s] start', label);
if nargout == 0
    captured = evalc('try, fn(); catch callError, end');
else
    captured = evalc('try, [outputs{:}] = fn(); catch callError, end');
end

lines = splitlines(string(captured));
lines = lines(strlength(strtrim(lines)) > 0);
if ~isempty(lines)
    st_log(cfg, 'DEBUG', '%s', char(strjoin("[SYS " + label + "] " + lines, newline)));
end
warningPattern = ['^(Warning|' char([0xACBD 0xACE0]) ')\s*:'];
isWarning = ~cellfun(@isempty, regexp(cellstr(strtrim(lines)), warningPattern, 'once'));
warningLines = strtrim(lines(isWarning));
if ~isempty(warningLines)
    st_log(cfg, 'WARN', '%s system warnings: %d (%d distinct) - see log', ...
        label, numel(warningLines), numel(unique(warningLines)));
end
st_log(cfg, 'DEBUG', '[SYS %s] end | lines=%d | %s', ...
    label, numel(lines), st_log_elapsed_text(toc(timerValue)));

if ~isempty(callError)
    rethrow(callError);
end
varargout = outputs;
end
