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
    candidates = [string(config_value(cfg, 'DefectReasonSheet', 'DefectReasons')), "도달불가사유"];
    sheet = intersect(candidates, string(sheetnames(file)), 'stable');
    if isempty(sheet)
        st_log(cfg, 'INFO', 'Defect reasons | No reason sheet | Default reasons used');
        return;
    end
    raw = readtable(file, 'Sheet', char(sheet(1)), 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
catch ME
    st_log(cfg, 'WARN', 'Defect reasons unreadable | Kind=%s | Default reasons used', ...
        ME.identifier);
    return;
end
names = column(raw, ["TestName", "결함TC"]);
texts = column(raw, ["Reason", "사유"]);
if isempty(names) || isempty(texts)
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


function values = column(raw, aliases)
% Header aliases are matched ignoring case and surrounding spaces, as
% st_load_targets matches the Targets columns.
values = [];
headers = lower(strtrim(string(raw.Properties.VariableNames)));
index = find(ismember(headers, lower(aliases)), 1);
if isempty(index), return; end
values = strtrim(string(raw{:, index}));
values(ismissing(values)) = "";
end


function value = config_value(cfg, name, fallback)
value = fallback;
if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
    value = cfg.(name);
end
end
