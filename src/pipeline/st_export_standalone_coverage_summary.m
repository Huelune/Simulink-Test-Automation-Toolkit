function manifest = st_export_standalone_coverage_summary( ...
        outputRoot, manifest)
%ST_EXPORT_STANDALONE_COVERAGE_SUMMARY Write one persisted row per CUT.

cfg = st_require_runtime_target();
timerValue = tic;
pipelineRoot = fullfile(outputRoot, char(string(manifest.PipelineId)));
st_log(cfg, 'INFO', ...
    'Standalone coverage STEP6 start | PipelineId=%s', ...
    char(string(manifest.PipelineId)));
require_step5(manifest);
manifest.Steps.STEP6 = step_state('RUNNING', ...
    'Writing consolidated coverage summary');
st_write_standalone_pipeline_manifest(outputRoot, manifest);

n = numel(manifest.Targets);
No = zeros(n,1);
CUTName = strings(n,1);
TestCase = strings(n,1);
DecisionCovered = nan(n,1);
DecisionTotal = nan(n,1);
DecisionPercent = strings(n,1);
ExecutionCovered = nan(n,1);
ExecutionTotal = nan(n,1);
ExecutionPercent = strings(n,1);
Status = strings(n,1);
Message = strings(n,1);

for i = 1:n
    item = manifest.Targets(i);
    if strcmpi(item.Step5Status, 'OK')
        item = read_metric_snapshot(item);
        manifest.Targets(i) = item;
    end
    No(i) = double(item.No);
    CUTName(i) = string(item.CUTName);
    TestCase(i) = string(item.TestCaseName);
    DecisionCovered(i) = numeric_or_nan(item.DecisionCovered);
    DecisionTotal(i) = numeric_or_nan(item.DecisionTotal);
    DecisionPercent(i) = percentage_text( ...
        DecisionCovered(i), DecisionTotal(i));
    ExecutionCovered(i) = numeric_or_nan(item.ExecutionCovered);
    ExecutionTotal(i) = numeric_or_nan(item.ExecutionTotal);
    ExecutionPercent(i) = percentage_text( ...
        ExecutionCovered(i), ExecutionTotal(i));
    if strcmpi(item.Step5Status, 'OK')
        Status(i) = string(item.FinalOutcome);
        if strlength(Status(i)) == 0, Status(i) = "OK"; end
    else
        Status(i) = string(item.Step5Status);
    end
    Message(i) = string(item.Message);
    manifest.Targets(i).Step6Status = 'OK';
end

summary = table(No, CUTName, TestCase, DecisionCovered, DecisionTotal, ...
    DecisionPercent, ExecutionCovered, ExecutionTotal, ...
    ExecutionPercent, Status, Message, ...
    'VariableNames', {'No','CUT Name','Test Case', ...
    'Decision Covered','Decision Total','Decision %', ...
    'Execution Covered','Execution Total','Execution %', ...
    'Status','Message'});
summaryPath = fullfile(pipelineRoot, 'CoverageSummary.xlsx');
st_log(cfg, 'DEBUG', ...
    'STEP6 CoverageSummary write start | Path=%s', summaryPath);
write_excel_atomic(summaryPath, summary, manifest);
st_log(cfg, 'DEBUG', ...
    'STEP6 CoverageSummary write complete | Path=%s', summaryPath);
manifest.CoverageSummary = summaryPath;
manifest.Steps.STEP6 = step_state('OK', ...
    'CoverageSummary.xlsx written from persisted filtered metrics');
manifest.Status = pipeline_status(manifest);
manifest.UpdatedAt = timestamp_text();
st_log(cfg, 'INFO', ...
    'Standalone coverage STEP6 complete | Rows=%d | elapsed=%.3f sec', ...
    n, toc(timerValue));
end

function item = read_metric_snapshot(item)
if ~isfield(item, 'MetricSnapshot') || ...
        ~isfile(char(string(item.MetricSnapshot)))
    error('simtest:StandaloneMetricSnapshotMissing', ...
        'Persisted API metric snapshot is missing for %s.', item.CUTName);
end
signature = st_file_signature(item.MetricSnapshot);
if ~strcmpi(signature.SHA256, char(string(item.MetricSnapshotSHA256)))
    error('simtest:StandaloneMetricSnapshotChecksumMismatch', ...
        'Metric snapshot checksum changed for %s.', item.CUTName);
end
loaded = load(item.MetricSnapshot, 'metrics');
if ~isfield(loaded, 'metrics') || ~istable(loaded.metrics)
    error('simtest:StandaloneMetricSnapshotInvalid', ...
        'Metric snapshot is invalid for %s.', item.CUTName);
end
item = assign_metric(item, loaded.metrics, 'Decision');
item = assign_metric(item, loaded.metrics, 'Execution');
end

function item = assign_metric(item, metrics, metricName)
rows = metrics.Level == "CUT" & ...
    strcmpi(metrics.Metric, metricName) & metrics.Status == "OK";
if ~any(rows)
    item.([metricName 'Covered']) = NaN;
    item.([metricName 'Total']) = NaN;
    item.([metricName 'Percentage']) = NaN;
    item.([metricName 'PercentageText']) = 'N/A';
    return;
end
row = metrics(find(rows, 1),:);
item.([metricName 'Covered']) = double(row.Covered);
item.([metricName 'Total']) = double(row.Total);
[percentage, percentageText] = st_coverage_percentage( ...
    row.Covered, row.Total);
item.([metricName 'Percentage']) = percentage;
item.([metricName 'PercentageText']) = char(percentageText);
end

function write_excel_atomic(path, summary, manifest)
folder = fileparts(path);
temporary = [tempname(folder) '.xlsx'];
cleanup = onCleanup(@() delete_if_present(temporary)); %#ok<NASGU>
writetable(summary, temporary, 'Sheet', 'CoverageSummary');
metadata = table( ...
    ["PipelineId";"CreatedAt";"UpdatedAt";"SourceManifest"], ...
    [string(manifest.PipelineId);string(manifest.CreatedAt); ...
     string(manifest.UpdatedAt); ...
     string(fullfile(manifest.PipelineRoot, 'pipeline-manifest.json'))], ...
    'VariableNames', {'Key','Value'});
writetable(metadata, temporary, 'Sheet', 'Metadata');
[ok, message] = movefile(temporary, path, 'f');
if ~ok
    error('simtest:StandaloneCoverageSummaryWriteFailed', ...
        'Cannot replace %s: %s', path, message);
end
end

function value = numeric_or_nan(raw)
if isempty(raw)
    value = NaN;
else
    value = double(raw);
    if ~isscalar(value), value = NaN; end
end
end

function value = percentage_text(covered, total)
[~, value] = st_coverage_percentage(covered, total);
value = string(value);
end

function require_step5(manifest)
if ~isfield(manifest, 'Steps') || ~isfield(manifest.Steps, 'STEP5') || ...
        ~ismember(upper(string(manifest.Steps.STEP5.Status)), ["OK","WARN"])
    error('simtest:StandalonePipelineStageNotReady', ...
        'STEP5 must complete before STEP6.');
end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end

function value = step_state(status, message)
value = struct('Status', status, 'Message', message, ...
    'UpdatedAt', timestamp_text());
end

function status = pipeline_status(manifest)
names = fieldnames(manifest.Steps);
values = strings(numel(names),1);
for i = 1:numel(names)
    values(i) = string(manifest.Steps.(names{i}).Status);
end
if any(values == "FAIL")
    status = 'FAIL';
elseif any(values == "WARN") || any(values == "NOT_RUN")
    status = 'WARN';
else
    status = 'OK';
end
end

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
