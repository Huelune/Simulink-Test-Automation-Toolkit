function info = st_probe_stateflow_decisions(targetNumber, cvtFile)
%ST_PROBE_STATEFLOW_DECISIONS Show what a CUT's Stateflow charts expose.
% Read only. Prints the Stateflow objects under one CUT and, when a saved
% coverage file is given, what decisioninfo answers for them.
%
%   st_probe_stateflow_decisions(21)
%   st_probe_stateflow_decisions(21, 'C:\...\CoverageResult.cvt')
%
% This exists because the shape of a Stateflow object id, and the shape
% decisioninfo returns for one, cannot be read out of the documentation
% with enough confidence to build against. Run it once and the exporter can
% be written against the real output instead of an assumption.
if nargin < 1, targetNumber = 1; end
if nargin < 2, cvtFile = ''; end

cfg = st_config();
targets = st_load_targets(cfg.OnlyEnabled);
row = pick_target(targets, targetNumber);
cut = char(st_normalize_cut_path(row.CUTPath, cfg.TopModel));
fprintf('\n==== CUT ====\n%s\n', cut);

info = struct('CUT', cut, 'Charts', {{}}, 'Coverage', []);
info.Charts = probe_charts(cut);
if ~isempty(cvtFile)
    info.Coverage = probe_coverage(cvtFile, cut, info.Charts);
end
end


function row = pick_target(targets, targetNumber)
match = targets.No == targetNumber;
if ~any(match)
    error('simtest:ProbeTargetMissing', ...
        'No target with No = %g. Available: %s', targetNumber, ...
        strjoin(compose('%g', targets.No(:)'), ', '));
end
row = targets(find(match, 1), :);
end


function charts = probe_charts(cut)
charts = {};
fprintf('\n==== 1. CUT 직계 블록 (Chart 후보) ====\n');
blocks = find_system(cut, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'Type', 'Block');
for i = 1:numel(blocks)
    path = char(string(blocks{i}));
    if strcmp(path, cut), continue; end
    fprintf('  %-60s BlockType=%-12s MaskType=%-16s SFBlockType=%s\n', ...
        shorten(path, cut), param_text(path, 'BlockType'), ...
        param_text(path, 'MaskType'), param_text(path, 'SFBlockType'));
end

fprintf('\n==== 2. Stateflow API가 보는 Chart ====\n');
found = stateflow_charts(cut);
if isempty(found)
    fprintf('  (없음)\n');
    return;
end
for i = 1:numel(found)
    charts{end+1,1} = describe_chart(found{i}, cut); %#ok<AGROW>
end
end


function found = stateflow_charts(cut)
% A chart's Simulink path is the block path, so charts under this CUT are
% the ones whose Path starts with it.
found = {};
try
    root = sfroot;
    all = root.find('-isa', 'Stateflow.Chart');
catch ME
    fprintf('  sfroot 조회 실패: %s\n', ME.message);
    return;
end
for i = 1:numel(all)
    chart = all(i);
    path = '';
    try
        path = char(string(chart.Path));
    catch
        % Older releases spell it differently; the describe step reports it.
    end
    if startsWith([path '/'], [cut '/']) || strcmp(path, cut)
        found{end+1,1} = chart; %#ok<AGROW>
    end
end
fprintf('  CUT 아래 Chart 수: %d (전체 %d 중)\n', numel(found), numel(all));
end


function summary = describe_chart(chart, cut)
summary = struct('Name', '', 'Path', '', 'Transitions', [], 'States', []);
try
    summary.Name = char(string(chart.Name));
    summary.Path = char(string(chart.Path));
catch
end
fprintf('\n  --- Chart: %s ---\n', summary.Name);
fprintf('    Path       : %s\n', shorten(summary.Path, cut));
fprintf('    Chart id   : %s\n', id_text(chart));
fprintf('    Simulink 경로(추정): %s/%s\n', shorten(summary.Path, cut), summary.Name);

summary.Transitions = list_objects(chart, 'Stateflow.Transition', ...
    {'LabelString', 'ExecutionOrder'}, '전이');
summary.States = list_objects(chart, 'Stateflow.State', ...
    {'Name', 'LabelString'}, '상태');
end


function items = list_objects(chart, className, properties, label)
items = {};
try
    found = chart.find('-isa', className);
catch ME
    fprintf('    %s 조회 실패: %s\n', label, ME.message);
    return;
end
fprintf('    %s %d개\n', label, numel(found));
for i = 1:numel(found)
    object = found(i);
    parts = {};
    for k = 1:numel(properties)
        parts{end+1} = sprintf('%s=%s', properties{k}, ...
            object_text(object, properties{k})); %#ok<AGROW>
    end
    fprintf('      id=%-10s %s\n', id_text(object), strjoin(parts, ' | '));
    items{end+1,1} = object; %#ok<AGROW>
end
end


function info = probe_coverage(cvtFile, cut, charts)
info = struct('File', cvtFile, 'Loaded', false);
fprintf('\n==== 3. 커버리지가 Stateflow에 답하는 모양 ====\n');
if ~isfile(cvtFile)
    fprintf('  파일 없음: %s\n', cvtFile);
    return;
end
try
    loaded = cvload(cvtFile);
catch ME
    fprintf('  cvload 실패: %s\n', ME.message);
    return;
end
if isempty(loaded)
    fprintf('  cvload가 아무것도 돌려주지 않음\n');
    return;
end
cvd = loaded{1};
info.Loaded = true;
report_decisioninfo('CUT 자체', @() decisioninfo(cvd, cut));
for i = 1:numel(charts)
    chart = charts{i};
    name = object_text(chart, 'Name');
    report_decisioninfo(sprintf('Chart %s (객체 직접)', name), ...
        @() decisioninfo(cvd, chart));
end
end


function report_decisioninfo(label, call)
fprintf('  -- %s\n', label);
try
    [values, description] = call();
catch ME
    fprintf('     실패: %s\n', ME.message);
    return;
end
fprintf('     values = %s\n', mat2str(values));
if isempty(description)
    fprintf('     description = (비어 있음)\n');
    return;
end
fprintf('     description 클래스=%s 크기=%s\n', class(description), ...
    mat2str(size(description)));
try
    fprintf('     description 필드: %s\n', ...
        strjoin(fieldnames(description)', ', '));
catch
end
end


function text = param_text(path, name)
text = '-';
try
    text = char(string(get_param(path, name)));
catch
end
if isempty(text), text = '-'; end
end


function text = object_text(object, name)
text = '-';
try
    value = object.(name);
    text = char(string(value));
catch
end
text = strtrim(strrep(text, newline, ' '));
if isempty(text), text = '-'; end
end


function text = id_text(object)
text = '-';
try
    text = char(string(object.Id));
catch
end
end


function text = shorten(path, cut)
text = char(string(path));
if startsWith(text, [cut '/'])
    text = ['<CUT>' extractAfter(text, numel(cut))];
elseif strcmp(text, cut)
    text = '<CUT>';
end
end
