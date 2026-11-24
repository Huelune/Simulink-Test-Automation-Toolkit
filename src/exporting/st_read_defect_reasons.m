function reasons = st_read_defect_reasons(cfg)
%ST_READ_DEFECT_REASONS Reasons a person wrote for the defect iterations.
% The management workbook may carry a sheet, cfg.DefectReasonSheet or its
% Korean name 도달불가사유, with one defect iteration name (TestName or
% 결함TC) and one reason (Reason or 사유) per row. Only the final document
% reads it, so it is in no stage fingerprint: after editing a reason only
% the final document has to be exported again.
%
% REASONS is a table of TestName and Reason. No workbook, no sheet or no
% usable column gives an empty table, and every defect row then uses its
% default sentence. A name given twice keeps its first row.
reasons = table(strings(0,1), strings(0,1), 'VariableNames', {'TestName','Reason'});
file = char(string(config_value(cfg, 'ManagementExcel', '')));
if isempty(file) || ~isfile(file)
    st_log(cfg, 'WARN', ...
        'Defect reasons unavailable | Management workbook not found | Default reasons used');
    return;
end
try
    % Excel treats sheet names without case, so a hand-typed name matches
    % the same way; the configured name is tried before the Korean one.
    candidates = [string(config_value(cfg, 'DefectReasonSheet', 'DefectReasons')), "도달불가사유"];
    sheets = string(sheetnames(file));
    [~, at] = ismember(lower(candidates), lower(sheets));
    at = at(at > 0);
    if isempty(at)
        st_log(cfg, 'INFO', 'Defect reasons | No reason sheet | Default reasons used');
        return;
    end
    raw = readtable(file, 'Sheet', char(sheets(at(1))), 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
catch ME
    st_log(cfg, 'WARN', 'Defect reasons unreadable | Kind=%s | Default reasons used', ...
        error_kind(ME));
    return;
end
[names, hasNames] = column(raw, ["TestName", "결함TC"]);
[texts, hasTexts] = column(raw, ["Reason", "사유"]);
if ~hasNames || ~hasTexts
    st_log(cfg, 'WARN', ['Defect reasons | Columns TestName/결함TC and Reason/사유 ' ...
        'not found | Default reasons used']);
    return;
end
keep = find(strlength(names) > 0 & strlength(texts) > 0);
[~, first] = unique(names(keep), 'stable');
repeated = setdiff((1:numel(keep))', first);
if ~isempty(repeated)
    % Excel rows, counted after the header row.
    st_log(cfg, 'WARN', 'Defect reasons repeat a name | Rows=%s | First row used', ...
        strjoin(string(keep(repeated)' + 1), ','));
end
reasons = table(names(keep(first)), texts(keep(first)), ...
    'VariableNames', {'TestName','Reason'});
st_log(cfg, 'INFO', 'Defect reasons read | Reasons=%d', height(reasons));
end


function [values, found] = column(raw, aliases)
% Header aliases are matched ignoring case and surrounding spaces, as
% st_load_targets matches the Targets columns.
values = strings(height(raw), 1);
headers = lower(strtrim(string(raw.Properties.VariableNames)));
index = find(ismember(headers, lower(aliases)), 1);
found = ~isempty(index);
if ~found, return; end
cells = raw{:, index};
if isnumeric(cells)
    % A column with no text is read as double and its empty cells as NaN,
    % which string() would turn into "NaN".
    valid = ~isnan(cells);
    values(valid) = string(cells(valid));
else
    values = strtrim(string(cells));
    values(ismissing(values)) = "";
end
end


function kind = error_kind(ME)
kind = ME.identifier;
if isempty(kind), kind = 'unidentified'; end
end


function value = config_value(cfg, name, fallback)
value = fallback;
if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
    value = cfg.(name);
end
end
