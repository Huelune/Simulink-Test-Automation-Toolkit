function info = st_save_run_record(runContext, workflowResult, workflowPlan, cfg)
%ST_SAVE_RUN_RECORD Persist one finished run so reporting can be deferred.
%
% A ResultSet lives in the Test Manager session, so the integrated report
% could only ever be produced by the same MATLAB session that ran the tests.
% Saving the pair of ResultSets and the tables around them turns reporting
% into a separate step, the way the standalone pipeline separates EXECUTE
% from PACKAGE.
%
% st_generate_test_report('RunRecord', info.RecordId) rebuilds the report
% from what this function wrote.

if nargin < 4 || isempty(cfg)
    cfg = st_require_runtime_target();
end
st_report_run_context(runContext);

recordId = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
directory = fullfile(cfg.RunRecordRootDir, recordId);
if isfolder(directory)
    error('simtest:RunRecordExists', ...
        'Run record directory already exists: %s', directory);
end
mkdir(directory);

st_log(cfg, 'INFO', 'Run record save start | Id=%s | Directory=%s', ...
    recordId, directory);

initialFile = fullfile(directory, 'initial.mldatx');
finalFile = fullfile(directory, 'final.mldatx');
sltest.testmanager.exportResults(runContext.InitialResult, initialFile);
require_export(initialFile);
if logical(runContext.RerunPerformed)
    sltest.testmanager.exportResults(runContext.FinalResult, finalFile);
    require_export(finalFile);
else
    % Without a rerun both labels name the same ResultSet. Keeping one file
    % and pointing both at it avoids claiming two independent runs exist.
    finalFile = initialFile;
end

record = struct( ...
    'Version', 1, ...
    'RecordId', recordId, ...
    'InitialFile', initialFile, ...
    'FinalFile', finalFile, ...
    'RerunPerformed', logical(runContext.RerunPerformed), ...
    'StartedAt', char(string(runContext.StartedAt)), ...
    'CompletedAt', char(string(runContext.CompletedAt)), ...
    'ExpectedUpdateResult', {runContext.ExpectedUpdateResult}, ...
    'CoverageFilterResult', {optional_field(runContext, 'CoverageFilterResult')}, ...
    'WorkflowResult', {workflowResult}, ...
    'WorkflowPlan', {workflowPlan});
recordFile = fullfile(directory, 'run_record.mat');
st_atomic_save(recordFile, struct('record', record));

latest = struct( ...
    'Version', 1, ...
    'RecordId', recordId, ...
    'Directory', directory, ...
    'Record', recordFile, ...
    'RerunPerformed', record.RerunPerformed, ...
    'UpdatedAt', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
st_write_json_atomic(cfg.LatestRunRecordPointer, latest);

info = struct( ...
    'RecordId', recordId, ...
    'Directory', directory, ...
    'Record', recordFile, ...
    'InitialFile', initialFile, ...
    'FinalFile', finalFile);

st_log(cfg, 'INFO', 'Run record save complete | Id=%s', recordId);
end

function require_export(file)
if ~isfile(file)
    error('simtest:RunRecordExportMissing', ...
        'ResultSet export did not create %s.', file);
end
end

function value = optional_field(source, name)
value = table();
if isfield(source, name)
    value = source.(name);
end
end
