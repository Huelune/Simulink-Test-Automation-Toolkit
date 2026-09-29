function st_log_progress(cfg, i, n, status, label, varargin)
%ST_LOG_PROGRESS One console line per target: [ 3/26] FAIL  <label>  30.9s  <message>.
%
% st_log_progress(cfg, i, n, 'START', label)
% st_log_progress(cfg, i, n, status, label, 'Elapsed', sec, ...
%     'Message', msg, 'Detail', cutPath)
%
% FAIL/EXCEPT/ERROR print as ERROR, WARN/PARTIAL as WARN, the rest as STEP.
% The console line is clipped; Detail and the full message go to the log.
p = inputParser;
addParameter(p, 'Elapsed', []);
addParameter(p, 'Message', '');
addParameter(p, 'Detail', '');
parse(p, varargin{:});

status = upper(strtrim(char(string(status))));
width = numel(sprintf('%d', n));
counter = sprintf('[%*d/%d]', width, i, n);
message = regexprep(char(string(p.Results.Message)), '\s*[\r\n]+\s*', ' ');
elapsed = '';
if ~isempty(p.Results.Elapsed)
    elapsed = st_log_elapsed_text(p.Results.Elapsed);
end

switch status
    case {'FAIL', 'EXCEPT', 'ERROR'}, level = 'ERROR';
    case {'WARN', 'PARTIAL'},         level = 'WARN';
    otherwise,                        level = 'STEP';
end
line = sprintf('    %s %-6s %-40s %7s  %s', counter, status, ...
    clip(char(string(label)), 40), elapsed, clip(message, 60));
st_log(cfg, level, '    %s', strtrim(line));

detail = char(string(p.Results.Detail));
if ~isempty(detail) || numel(message) > 60
    st_log(cfg, 'DEBUG', '%s detail | %s | %s', counter, detail, message);
end
end

function text = clip(text, limit)
if numel(text) > limit
    text = [text(1:limit-3) '...'];
end
end
