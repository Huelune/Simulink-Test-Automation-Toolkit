function st_log_stage(cfg, phase, label, varargin)
%ST_LOG_STAGE Start and end lines of one workflow stage.
%
% st_log_stage(cfg, 'start', label)
% st_log_stage(cfg, 'end',  label, 'Result', T, 'Elapsed', sec)
% st_log_stage(cfg, 'fail', label, 'Exception', ME, 'Elapsed', sec)
%
% 'end' counts T.Status and lists every FAIL/EXCEPT row as ERROR, so the
% stage's failures stay together in the log after a long run.
p = inputParser;
addParameter(p, 'Result', []);
addParameter(p, 'Exception', []);
addParameter(p, 'Elapsed', 0);
parse(p, varargin{:});
label = char(string(label));
elapsed = st_log_elapsed_text(p.Results.Elapsed);

switch phase
    case 'start'
        index = st_log_scope('next_stage');
        st_log(cfg, 'STEP', '--> %s%s', stage_tag(index), label);
    case 'end'
        tag = current_tag();
        result = p.Results.Result;
        if istable(result) && ismember('Status', result.Properties.VariableNames)
            status = upper(strtrim(string(result.Status)));
            failed = ismember(status, ["FAIL", "EXCEPT"]);
            level = 'STEP';
            if any(failed), level = 'WARN'; end
            st_log(cfg, level, '<-- %s%s | %s | %s', tag, label, ...
                count_text(status), elapsed);
            for row = find(failed(:)).'
                st_log(cfg, 'ERROR', '    %s | %s', ...
                    target_text(result(row, :)), message_text(result(row, :)));
            end
        else
            st_log(cfg, 'STEP', '<-- %s%s | DONE | %s', tag, label, elapsed);
        end
    case 'fail'
        ME = p.Results.Exception;
        st_log(cfg, 'ERROR', '<-- %s%s | FAILED | %s | %s: %s', current_tag(), ...
            label, elapsed, ME.identifier, ME.message);
    otherwise
        error('simtest:InvalidLogStagePhase', 'Unknown stage phase: %s', phase);
end
end

function tag = current_tag()
state = st_log_scope('current');
tag = stage_tag(state.StageIndex);
end

function tag = stage_tag(index)
tag = '';
if index > 0, tag = sprintf('[%d] ', index); end
end

function text = count_text(status)
[names, ~, index] = unique(status, 'stable');
counts = accumarray(index(:), 1);
text = char(strjoin(names(:) + "=" + string(counts(:)), ', '));
if isempty(text), text = 'no rows'; end
end

function text = target_text(row)
parts = strings(0, 1);
for name = ["No", "CUTName", "HarnessName", "TestCaseName"]
    if ismember(name, row.Properties.VariableNames)
        value = string(row.(name)(1));
        if ~ismissing(value) && strlength(value) > 0
            parts(end+1, 1) = name + "=" + value; %#ok<AGROW>
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
