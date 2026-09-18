function [runContext, workflowResult, workflowPlan, info] = ...
    st_load_run_record(recordId, cfg)
%ST_LOAD_RUN_RECORD Rebuild a finished run from what st_save_run_record wrote.
%
% The ResultSets are imported back into the Test Manager session, so the
% caller gets the same shape st_run_generated_tests returned live.
%
% recordId is a saved record id, or 'LATEST' (default).

if nargin < 1 || strlength(string(recordId)) == 0
    recordId = 'LATEST';
end
if nargin < 2 || isempty(cfg)
    cfg = st_require_runtime_target();
end
recordId = char(string(recordId));

if strcmpi(recordId, 'LATEST')
    if ~isfile(cfg.LatestRunRecordPointer)
        error('simtest:RunRecordPointerMissing', ...
            ['No saved run record. Run the workflow with execution ' ...
             'enabled first; the pointer is written to %s.'], ...
            cfg.LatestRunRecordPointer);
    end
    latest = jsondecode(fileread(cfg.LatestRunRecordPointer));
    recordId = char(string(latest.RecordId));
end

directory = fullfile(cfg.RunRecordRootDir, recordId);
recordFile = fullfile(directory, 'run_record.mat');
if ~isfile(recordFile)
    error('simtest:RunRecordMissing', ...
        'Saved run record is missing: %s', recordFile);
end

loaded = load(recordFile, 'record');
record = loaded.record;

st_log(cfg, 'INFO', 'Run record import start | Id=%s', recordId);
initial = import_one(record.InitialFile);
if strcmp(record.FinalFile, record.InitialFile)
    final = initial;
else
    final = import_one(record.FinalFile);
end
st_log(cfg, 'INFO', 'Run record import complete | Id=%s', recordId);

runContext = struct( ...
    'InitialResult', initial, ...
    'FinalResult', final, ...
    'RerunPerformed', logical(record.RerunPerformed), ...
    'StartedAt', record.StartedAt, ...
    'CompletedAt', record.CompletedAt, ...
    'ExpectedUpdateResult', {record.ExpectedUpdateResult}, ...
    'CoverageFilterResult', {record.CoverageFilterResult});
workflowResult = record.WorkflowResult;
workflowPlan = record.WorkflowPlan;
info = struct( ...
    'RecordId', recordId, ...
    'Directory', directory, ...
    'Record', recordFile);
end

function resultObj = import_one(file)
if ~isfile(file)
    error('simtest:RunRecordResultMissing', ...
        'Saved ResultSet is missing: %s', file);
end
imported = sltest.testmanager.importResults(file);
if isempty(imported)
    error('simtest:RunRecordResultEmpty', ...
        'Saved ResultSet imported no results: %s', file);
end
resultObj = imported(1);
end
