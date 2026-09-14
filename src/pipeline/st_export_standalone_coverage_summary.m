function manifest = st_export_standalone_coverage_summary( ...
        outputRoot, manifest)
%ST_EXPORT_STANDALONE_COVERAGE_SUMMARY Merge manifest scalars into Excel.

cfg = st_require_runtime_target('LoadModel', false);
timerValue = tic;
pipelineRoot = fullfile(outputRoot, char(string(manifest.PipelineId)));
st_log(cfg, 'INFO', ...
    'Standalone coverage SUMMARY start | PipelineId=%s', ...
    char(string(manifest.PipelineId)));
require_package(manifest);
require_not_started(manifest, 'SUMMARY');
manifest.Actions.SUMMARY = action_state('RUNNING', ...
    'Writing CoverageSummary.xlsx from manifest scalar metrics');
st_write_standalone_pipeline_manifest(outputRoot, manifest);

n = numel(manifest.Targets);
NUM = zeros(n,1);
CUT_NAME = strings(n,1);
CUT_PATH = strings(n,1);
TestCaseName = strings(n,1);
HarnessName = strings(n,1);
DecisionExecuted = NaN(n,1);
DecisionTotal = NaN(n,1);
Decision = strings(n,1);
ExecutionExecuted = NaN(n,1);
ExecutionTotal = NaN(n,1);
Execution = strings(n,1);
for i = 1:n
    item = manifest.Targets(i);
    NUM(i) = double(item.No);
    CUT_NAME(i) = string(item.CUTName);
    CUT_PATH(i) = string(item.CUTPath);
    TestCaseName(i) = string(item.TestCaseName);
    HarnessName(i) = string(item.HarnessName);
    DecisionExecuted(i) = scalar_metric(item.DecisionCovered);
    DecisionTotal(i) = scalar_metric(item.DecisionTotal);
    Decision(i) = string(item.DecisionPercentageText);
    ExecutionExecuted(i) = scalar_metric(item.ExecutionCovered);
    ExecutionTotal(i) = scalar_metric(item.ExecutionTotal);
    Execution(i) = string(item.ExecutionPercentageText);
    if strcmpi(item.PackageStatus, 'OK')
        manifest.Targets(i).SummaryStatus = 'OK';
    else
        manifest.Targets(i).SummaryStatus = 'FAIL';
    end
end

summary = table(NUM, CUT_NAME, CUT_PATH, TestCaseName, HarnessName, ...
    DecisionExecuted, DecisionTotal, Decision, ...
    ExecutionExecuted, ExecutionTotal, Execution, 'VariableNames', ...
    {'NUM','CUT_NAME','CUT_PATH','Test Case Name','Harness Name', ...
    'Decision Executed','Decision Total','Decision (%)', ...
    'Execution Executed','Execution Total','Execution (%)'});
summaryPath = fullfile(pipelineRoot, 'CoverageSummary.xlsx');
st_log(cfg, 'DEBUG', ...
    'SUMMARY Excel write start | Path=%s', summaryPath);
write_excel_atomic(summaryPath, summary, manifest);
st_log(cfg, 'DEBUG', ...
    'SUMMARY Excel write complete | Path=%s', summaryPath);
manifest.CoverageSummary = summaryPath;
manifest.CoverageSummarySHA256 = st_file_signature(summaryPath).SHA256;
status = target_action_status(manifest.Targets, 'SummaryStatus');
manifest.Actions.SUMMARY = action_state(status, ...
    'CoverageSummary.xlsx written from manifest scalar metrics');
manifest.Status = pipeline_status(manifest);
manifest.UpdatedAt = timestamp_text();
st_log(cfg, 'INFO', ...
    'Standalone coverage SUMMARY complete | Rows=%d | elapsed=%.3f sec', ...
    n, toc(timerValue));
end

function value = scalar_metric(raw)
value = NaN;
if isnumeric(raw) && isscalar(raw), value = double(raw); end
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

function require_package(manifest)
if ~ismember(double(manifest.Version), [2 3]) || ~isfield(manifest, 'Actions') || ...
        ~isfield(manifest.Actions, 'PACKAGE') || ...
        ~ismember(upper(string(manifest.Actions.PACKAGE.Status)), ["OK","WARN"])
    error('simtest:StandalonePipelineActionNotReady', ...
        'PACKAGE must complete before SUMMARY.');
end
end

function require_not_started(manifest, name)
if ~isfield(manifest, 'Actions') || ~isfield(manifest.Actions, name) || ...
        ~strcmpi(char(string(manifest.Actions.(name).Status)), 'NOT_RUN')
    error('simtest:StandalonePipelineActionAlreadyStarted', ...
        ['%s can run only once per pipeline. Start a new EXECUTE action ' ...
         'instead of rewriting lifecycle artifacts.'], name);
end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end

function value = action_state(status, message)
value = struct('Status', status, 'Message', message, ...
    'UpdatedAt', timestamp_text());
end

function status = target_action_status(targets, field)
values = upper(string({targets.(field)}));
if any(values == "FAIL" | values == "SKIP")
    status = 'WARN';
else
    status = 'OK';
end
end

function status = pipeline_status(manifest)
names = fieldnames(manifest.Actions);
values = strings(numel(names),1);
for i = 1:numel(names)
    values(i) = upper(string(manifest.Actions.(names{i}).Status));
end
if any(values == "FAIL")
    status = 'FAIL';
elseif any(values == "WARN" | values == "NOT_RUN")
    status = 'PARTIAL';
else
    status = 'OK';
end
end

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
