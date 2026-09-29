function st_log_stage_result(label, result, ME)
%ST_LOG_STAGE_RESULT Print how a workflow step ended and keep its failures.
%
% st_log_stage_result(label, result)      step returned; result may be a table
% st_log_stage_result(label, [], ME)      step threw ME
%
% The Command Window scrolls away and a lost MATLAB session takes it along,
% so every step's outcome and every failed target is also appended to
% WorkflowStageLog.log under cfg.ResultReportDir. The INI result files are
% replaced on every run; this log keeps the history.

cfg = st_config();
lines = strings(0,1);

if nargin >= 3 && ~isempty(ME)
    text = sprintf('%s | EXCEPTION | %s: %s', label, ME.identifier, ME.message);
    st_log(cfg, 'ERROR', '[StageResult] %s', text);
    lines(end+1,1) = line_text('ERROR', text);
elseif istable(result) && ismember('Status', result.Properties.VariableNames)
    status = upper(strtrim(string(result.Status)));
    failed = ismember(status, ["FAIL","EXCEPT"]);
    text = sprintf('%s | targets=%d | %s', label, height(result), ...
        count_text(status));
    fprintf('RESULT  : %s\n', count_text(status));
    if any(failed)
        st_log(cfg, 'WARN', '[StageResult] %s', text);
        lines(end+1,1) = line_text('WARN', text);
    else
        st_log(cfg, 'INFO', '[StageResult] %s', text);
        lines(end+1,1) = line_text('INFO', text);
    end
    for row = find(failed(:)).'
        detail = sprintf('%s | %s | %s', label, ...
            target_text(result(row,:)), message_text(result(row,:)));
        st_log(cfg, 'ERROR', '[StageResult] %s', detail);
        lines(end+1,1) = line_text('ERROR', detail); %#ok<AGROW>
    end
else
    text = sprintf('%s | DONE', label);
    st_log(cfg, 'INFO', '[StageResult] %s', text);
    lines(end+1,1) = line_text('INFO', text);
end

append_lines(cfg, lines);
end


function text = count_text(status)
[names, ~, index] = unique(status, 'stable');
counts = accumarray(index(:), 1);
parts = names(:) + "=" + string(counts(:));
text = char(strjoin(parts, ', '));
if isempty(text), text = 'no rows'; end
end


function text = target_text(row)
parts = strings(0,1);
for name = ["No","CUTName","HarnessName","TestCaseName"]
    if ismember(name, row.Properties.VariableNames)
        value = string(row.(name)(1));
        if ~ismissing(value) && strlength(value) > 0
            parts(end+1,1) = name + "=" + value; %#ok<AGROW>
        end
    end
end
text = char(strjoin(parts, ' | '));
end


function text = message_text(row)
text = '';
if ismember('Message', row.Properties.VariableNames)
    text = char(string(row.Message(1)));
end
text = regexprep(text, '\s*[\r\n]+\s*', ' ');
end


function text = line_text(level, message)
text = string(sprintf('[%s][%s] %s', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), level, message));
end


function append_lines(cfg, lines)
% A log that cannot be written must not fail the step it describes.
try
    if ~isfolder(cfg.ResultReportDir)
        mkdir(cfg.ResultReportDir);
    end
    logPath = fullfile(cfg.ResultReportDir, 'WorkflowStageLog.log');
    fileId = fopen(logPath, 'a', 'n', 'UTF-8');
    if fileId < 0
        error('simtest:StageLogOpenFailed', 'Cannot open %s', logPath);
    end
    closeFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
    fprintf(fileId, '%s\n', lines);
catch ME
    st_log(cfg, 'WARN', 'Stage result log write failed | %s', ME.message);
end
end
