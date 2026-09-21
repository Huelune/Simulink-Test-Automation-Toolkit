function coverage = st_final_document_coverage(cfg, requested, pipelineId, runSource)
%ST_FINAL_DOCUMENT_COVERAGE Collect per-CUT coverage for the final document.
% Returns the numerator and denominator separately so the workbook can hold
% a real percentage formula. A missing value stays NaN here and becomes N/A
% in the sheet; nothing is inferred from the percentage text of the source,
% which is already formatted for reading.
%
%   requested  '' uses cfg.FinalDocumentCoverageSource. 'STANDALONE'
%              (default) reads the standalone pipeline summary, 'TEST_RUN'
%              the Coverage sheet of the resolved run, 'NONE' collects none.
%
% The standalone pipeline is a separate execution from the one the verdicts
% come from: it swaps in standalone models and forces expected-value updates
% off, so its pass/fail can differ. Only its coverage is used here, and both
% run identities are recorded in the document metadata.
if nargin < 3, pipelineId = 'LATEST'; end
if nargin < 4, runSource = []; end
if isempty(pipelineId), pipelineId = 'LATEST'; end
token = upper(strtrim(char(string(requested))));
if isempty(token)
    token = upper(strtrim(char(string( ...
        config_value(cfg, 'FinalDocumentCoverageSource', 'STANDALONE')))));
end
if isempty(token), token = 'STANDALONE'; end
if ~ismember(token, {'STANDALONE','TEST_RUN','NONE'})
    error('simtest:FinalDocumentCoverageSource', ...
        'CoverageSource must be STANDALONE, TEST_RUN or NONE.');
end

coverage = struct('Source', token, 'PipelineId', '', 'SummaryFile', '', ...
    'SummarySHA256', '', 'Rows', empty_coverage_table(), 'Notes', empty_note_table());
st_log(cfg, 'INFO', 'Final document coverage start | Source=%s', token);
coverage.Rows = target_rows(cfg);
switch token
    case 'STANDALONE'
        coverage = fill_from_standalone(cfg, coverage, pipelineId);
    case 'TEST_RUN'
        coverage = fill_from_test_run(cfg, coverage, runSource);
    otherwise
        % NONE is a deliberate choice, so it needs no missing-source note.
end
st_log(cfg, 'INFO', ...
    'Final document coverage end | Source=%s | Rows=%d | Notes=%d', ...
    token, height(coverage.Rows), height(coverage.Notes));
end


function T = empty_coverage_table()
T = table(strings(0,1), strings(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'CUT','CUTPath','ExecutionExecuted','ExecutionTotal', ...
    'DecisionExecuted','DecisionTotal'});
end


function T = empty_note_table()
T = table(zeros(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','TestCaseName','Reason','Message'});
end


function T = append_note(T, no, name, reason, message)
T = [T; table(double(no), string(name), string(reason), string(message), ...
    'VariableNames', {'No','TestCaseName','Reason','Message'})];
end


function T = target_rows(cfg)
% Every managed CUT gets a row even when no coverage was collected, so the
% sheet shows what is missing instead of quietly leaving it out. One row per
% CUT: several targets can share a CUT and they measure the same objectives.
T = empty_coverage_table();
targets = st_load_targets(config_value(cfg, 'OnlyEnabled', true));
seen = strings(0,1);
for i = 1:height(targets)
    path = string(targets.CUTPath(i));
    if any(seen == path), continue; end
    seen(end+1,1) = path; %#ok<AGROW>
    T = [T; table(string(targets.CUTName(i)), path, NaN, NaN, NaN, NaN, ...
        'VariableNames', T.Properties.VariableNames)]; %#ok<AGROW>
end
end


function value = config_value(cfg, name, fallback)
value = fallback;
if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
    value = cfg.(name);
end
end


function coverage = fill_from_standalone(cfg, coverage, pipelineId)
outputRoot = char(string(config_value(cfg, 'StandaloneCoverageRootDir', '')));
if isempty(outputRoot) || ~isfolder(outputRoot)
    coverage.Notes = append_note(coverage.Notes, 0, "", "NO_COVERAGE_SOURCE", ...
        'No standalone coverage output exists. Run st_run_standalone_coverage_pipeline first.');
    return;
end
try
    manifest = st_load_standalone_pipeline_manifest(outputRoot, pipelineId);
catch ME
    coverage.Notes = append_note(coverage.Notes, 0, "", "NO_COVERAGE_SOURCE", ME.message);
    st_log(cfg, 'WARN', 'Final document coverage manifest unavailable | %s', ME.message);
    return;
end
coverage.PipelineId = char(string(manifest_field(manifest, 'PipelineId', '')));
summaryFile = char(string(manifest_field(manifest, 'CoverageSummary', '')));
expected = char(string(manifest_field(manifest, 'CoverageSummarySHA256', '')));
if isempty(summaryFile) || ~isfile(summaryFile)
    coverage.Notes = append_note(coverage.Notes, 0, "", "NO_COVERAGE_SOURCE", ...
        'The pipeline has no CoverageSummary.xlsx yet. Run the SUMMARY action.');
    return;
end
coverage.SummaryFile = summaryFile;
signature = st_file_signature(summaryFile);
coverage.SummarySHA256 = char(string(signature.SHA256));
% A summary that no longer matches its manifest cannot be quoted as the
% coverage of that pipeline run, so this is fatal rather than a note.
if ~isempty(expected) && ~strcmpi(coverage.SummarySHA256, expected)
    error('simtest:FinalDocumentCoverageChanged', ...
        'CoverageSummary.xlsx does not match its manifest checksum: %s', summaryFile);
end
summary = readtable(summaryFile, 'Sheet', 'CoverageSummary', ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
coverage = merge_summary(cfg, coverage, summary);
end


function coverage = merge_summary(cfg, coverage, summary)
columns = string(summary.Properties.VariableNames);
required = ["CUT_NAME","Decision Executed","Decision Total", ...
    "Execution Executed","Execution Total"];
if ~all(ismember(required, columns))
    coverage.Notes = append_note(coverage.Notes, 0, "", "NO_COVERAGE_SOURCE", ...
        'CoverageSummary.xlsx does not have the expected 11 columns.');
    return;
end
names = strtrim(string(summary.CUT_NAME));
for i = 1:height(coverage.Rows)
    rows = names == coverage.Rows.CUT(i);
    if ~any(rows)
        coverage.Notes = append_note(coverage.Notes, 0, coverage.Rows.CUT(i), ...
            "COVERAGE_ROW_MISSING", 'No coverage row for this CUT.');
        continue;
    end
    [coverage, executed, total] = reduce_metric(coverage, coverage.Rows.CUT(i), ...
        "Execution", summary{rows, 'Execution Executed'}, ...
        summary{rows, 'Execution Total'});
    coverage.Rows.ExecutionExecuted(i) = executed;
    coverage.Rows.ExecutionTotal(i) = total;
    [coverage, executed, total] = reduce_metric(coverage, coverage.Rows.CUT(i), ...
        "Decision", summary{rows, 'Decision Executed'}, ...
        summary{rows, 'Decision Total'});
    coverage.Rows.DecisionExecuted(i) = executed;
    coverage.Rows.DecisionTotal(i) = total;
end
extra = setdiff(names, coverage.Rows.CUT, 'stable');
for i = 1:numel(extra)
    coverage.Notes = append_note(coverage.Notes, 0, extra(i), ...
        "COVERAGE_ROW_UNKNOWN_CUT", ...
        'The coverage summary has a CUT that the management Excel does not list.');
    st_log(cfg, 'WARN', 'Final document coverage unknown CUT | CUT=%s', extra(i));
end
end


function [coverage, executed, total] = reduce_metric(coverage, cut, metric, executedValues, totalValues)
% Several targets can share a CUT. They measure the same objectives, so
% adding them would count each objective more than once. Equal denominators
% mean the same measurement, and the largest numerator is the best run.
executed = NaN;
total = NaN;
executedValues = double(executedValues(:));
totalValues = double(totalValues(:));
keep = ~isnan(totalValues);
if ~any(keep), return; end
totals = unique(totalValues(keep));
if numel(totals) > 1
    coverage.Notes = append_note(coverage.Notes, 0, cut, "COVERAGE_CONFLICT", ...
        sprintf('%s rows for this CUT disagree on the objective count.', metric));
    return;
end
total = totals;
candidates = executedValues(keep);
candidates = candidates(~isnan(candidates));
if isempty(candidates), return; end
executed = max(candidates);
end


function value = manifest_field(manifest, name, fallback)
value = fallback;
if isstruct(manifest) && isscalar(manifest) && isfield(manifest, name)
    value = manifest.(name);
end
end


function coverage = fill_from_test_run(cfg, coverage, runSource)
% The Coverage sheet of the ordinary run reports the same two metrics with
% a covered/total pair per CUT, so the sheet 2 shape does not change.
if isempty(runSource) || height(runSource.Workbooks) == 0
    coverage.Notes = append_note(coverage.Notes, 0, "", "NO_COVERAGE_SOURCE", ...
        'The resolved run has no workbook to read coverage from.');
    return;
end
gathered = table(strings(0,1), strings(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'CUT','Metric','Covered','Total'});
for i = 1:height(runSource.Workbooks)
    file = runSource.Workbooks.File(i);
    try
        sheets = string(sheetnames(file));
        if ~any(sheets == "Coverage"), continue; end
        rows = readtable(file, 'Sheet', 'Coverage', 'TextType', 'string', ...
            'VariableNamingRule', 'preserve');
    catch ME
        coverage.Notes = append_note(coverage.Notes, 0, "", "NO_COVERAGE_SOURCE", ...
            ME.message);
        continue;
    end
    required = ["Run","CUTName","Metric","Covered","Total"];
    if ~all(ismember(required, string(rows.Properties.VariableNames)))
        continue;
    end
    final = rows(upper(string(rows.Run)) == "FINAL", :);
    if height(final) == 0, final = rows; end
    gathered = [gathered; table(strtrim(string(final.CUTName)), ...
        strtrim(string(final.Metric)), double(final.Covered), ...
        double(final.Total), 'VariableNames', gathered.Properties.VariableNames)]; %#ok<AGROW>
end
if height(gathered) == 0
    coverage.Notes = append_note(coverage.Notes, 0, "", "NO_COVERAGE_SOURCE", ...
        'No Coverage rows were found in the resolved run.');
    return;
end
for i = 1:height(coverage.Rows)
    cut = coverage.Rows.CUT(i);
    rows = gathered.CUT == cut;
    if ~any(rows)
        coverage.Notes = append_note(coverage.Notes, 0, cut, ...
            "COVERAGE_ROW_MISSING", 'No coverage row for this CUT.');
        continue;
    end
    execution = rows & upper(gathered.Metric) == "EXECUTION";
    decision = rows & upper(gathered.Metric) == "DECISION";
    [coverage, executed, total] = reduce_metric(coverage, cut, "Execution", ...
        gathered.Covered(execution), gathered.Total(execution));
    coverage.Rows.ExecutionExecuted(i) = executed;
    coverage.Rows.ExecutionTotal(i) = total;
    [coverage, executed, total] = reduce_metric(coverage, cut, "Decision", ...
        gathered.Covered(decision), gathered.Total(decision));
    coverage.Rows.DecisionExecuted(i) = executed;
    coverage.Rows.DecisionTotal(i) = total;
end
st_log(cfg, 'DEBUG', 'Final document coverage from run | Rows=%d', height(gathered));
end
