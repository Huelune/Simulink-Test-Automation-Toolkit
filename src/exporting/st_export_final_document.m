function [specification, outputFile] = st_export_final_document(varargin)
%ST_EXPORT_FINAL_DOCUMENT Export the customer submission workbook.
%   [T, PATH] = st_export_final_document()
%   Default: result/final_document_<timestamp>.xlsx. Existing output files
%   are refused. Read only: no simulation, no test run, no SLDV generation
%   and no expected-value update.
%
%   The already exported specification workbook is never parsed. The rows
%   are read from the saved model again, exactly as st_export_test_
%   specification reads them. Only the verdicts and the coverage come from
%   earlier result files.
%
%   Collect the results first. With the shipped defaults
%   cfg.GenerateTestReport is false and cfg.PerCutResultCollection is
%   DEFERRED, so running the tests alone leaves no per-iteration verdict on
%   disk. Run st_collect_per_cut_results after a PER_CUT run, or
%   st_generate_test_report after a BATCH run. Without it the verdict column
%   is blank and the TestResults sheet says why.
%
%   The failed verify text is not extracted. The TestResults sheet gives the
%   row to look at and the saved ResultSet to open in Test Manager.
%
%   Options:
%     OutputFile          Target path, default result/final_document_<ts>.xlsx
%     TestCaseIdMode      'COMBINED' (default) or 'SCENARIO'
%     DecisionBlockScope  'EXPLICIT', 'ALL' or 'NONE'
%     CoverageSource      'STANDALONE' (default), 'TEST_RUN' or 'NONE'
%     CoveragePipelineId  Standalone pipeline id, default 'LATEST'
%     ResultRun           'AUTO' (default), 'BATCH', 'PER_CUT' or a run directory
%     RequireTestResults  Fail instead of leaving the verdicts blank
%     RequireCoverage     Fail instead of leaving the coverage N/A
%     IncludeUsageSheet   Append the internal command list, default false
p = inputParser;
addParameter(p, 'OutputFile', '', @is_text_or_empty);
addParameter(p, 'TestCaseIdMode', '', @is_text_or_empty);
addParameter(p, 'DecisionBlockScope', '', @is_text_or_empty);
addParameter(p, 'CoverageSource', '', @is_text_or_empty);
addParameter(p, 'CoveragePipelineId', 'LATEST', @is_text_or_empty);
addParameter(p, 'ResultRun', '', @is_text_or_empty);
addParameter(p, 'RequireTestResults', false, @(v) islogical(v) && isscalar(v));
addParameter(p, 'RequireCoverage', false, @(v) islogical(v) && isscalar(v));
addParameter(p, 'IncludeUsageSheet', [], @(v) isempty(v) || (islogical(v) && isscalar(v)));
parse(p, varargin{:});

cfg = st_config();
decisionScope = resolve_decision_scope(p.Results.DecisionBlockScope, cfg);
idMode = resolve_choice(p.Results.TestCaseIdMode, cfg, ...
    'FinalDocumentTestCaseIdMode', 'COMBINED', {'COMBINED','SCENARIO'}, ...
    'simtest:FinalDocumentTestCaseIdMode', ...
    'TestCaseIdMode must be COMBINED or SCENARIO.');
coverageSource = resolve_choice(p.Results.CoverageSource, cfg, ...
    'FinalDocumentCoverageSource', 'STANDALONE', ...
    {'STANDALONE','TEST_RUN','NONE'}, 'simtest:FinalDocumentCoverageSource', ...
    'CoverageSource must be STANDALONE, TEST_RUN or NONE.');
resultRun = char(string(p.Results.ResultRun));
includeUsage = p.Results.IncludeUsageSheet;
if isempty(includeUsage)
    includeUsage = logical(config_value(cfg, 'FinalDocumentIncludeUsageSheet', false));
end

outputFile = char(p.Results.OutputFile);
if isempty(outputFile)
    outputFile = fullfile(cfg.ResultDir, ['final_document_' ...
        char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS')) '.xlsx']);
end
outputFile = canonical(outputFile);
[~, ~, extension] = fileparts(outputFile);
if ~strcmpi(extension, '.xlsx')
    error('simtest:FinalDocumentOutput', 'OutputFile must have an .xlsx extension.');
end
if isfile(outputFile)
    error('simtest:FinalDocumentOutputExists', 'Output already exists: %s', outputFile);
end
st_log(cfg, 'INFO', ...
    'Final document export start | TestCaseIdMode=%s | ResultRun=%s | CoverageSource=%s | Output=%s', ...
    idMode, run_label(resultRun, cfg), coverageSource, outputFile);
timer = tic;
try
    [rows, ~, verifyCells, maxTimes, decisionBlockLists] = ...
        st_collect_specification_rows(cfg, 'STEP2', decisionScope);
    specification = st_specification_table(rows, verifyCells, maxTimes, decisionBlockLists);
    % Renders the DecisionBlocks JSON into the Description text.
    specification = st_format_specification_decision_blocks(specification, cfg);
    source = st_final_document_run_source(cfg, resultRun);
    outcomes = st_final_document_outcomes(cfg, source);
    coverage = st_final_document_coverage(cfg, coverageSource, ...
        char(string(p.Results.CoveragePipelineId)), source);
    outcomes.Notes = [outcomes.Notes; coverage.Notes];
    require_results(p.Results.RequireTestResults, source, outcomes);
    require_coverage(p.Results.RequireCoverage, coverage);
    document = st_final_document_table(cfg, specification, outcomes, source, idMode);
    metadata = build_metadata(cfg, source, coverage, idMode, decisionScope, ...
        height(specification));
    usage = [];
    if includeUsage, usage = st_specification_usage_table(cfg); end
    document = st_write_final_document_workbook(document, coverage, metadata, ...
        outputFile, cfg, usage);
    specification = document.Sheet1;
    st_log(cfg, 'INFO', ...
        'Final document export end | Rows=%d | Mode=%s | Elapsed=%.3fs', ...
        height(specification), source.Mode, toc(timer));
    fprintf('Final document exported: %s\n', outputFile);
catch ME
    st_log(cfg, 'ERROR', 'Final document export failed | Elapsed=%.3fs | %s', ...
        toc(timer), ME.message);
    rethrow(ME);
end
end


function tf = is_text_or_empty(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
    (isstring(value) && isscalar(value)) || isempty(value);
end


function value = config_value(cfg, name, fallback)
% A config written before this option exists has no field, so fall back to
% the documented default instead of failing.
value = fallback;
if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
    value = cfg.(name);
end
end


function choice = resolve_choice(requested, cfg, field, fallback, allowed, identifier, message)
choice = upper(strtrim(char(string(requested))));
if isempty(choice)
    choice = upper(strtrim(char(string(config_value(cfg, field, fallback)))));
end
if isempty(choice), choice = fallback; end
if ~ismember(choice, allowed)
    error(identifier, '%s', message);
end
end


function scope = resolve_decision_scope(requested, cfg)
scope = upper(strtrim(char(string(requested))));
if isempty(scope)
    scope = upper(strtrim(char(string(config_value(cfg, 'DecisionBlockScope', 'EXPLICIT')))));
end
if isempty(scope), scope = 'EXPLICIT'; end
if ~ismember(scope, {'EXPLICIT', 'ALL', 'NONE'})
    error('simtest:SpecificationDecisionScope', ...
        'DecisionBlockScope must be EXPLICIT, ALL or NONE.');
end
end


function label = run_label(requested, cfg)
label = upper(strtrim(char(string(requested))));
if isempty(label)
    label = upper(strtrim(char(string(config_value(cfg, 'FinalDocumentResultRun', 'AUTO')))));
end
if isempty(label), label = 'AUTO'; end
end


function require_results(required, source, outcomes)
if ~required, return; end
if strcmp(source.Mode, 'NONE') || ...
        (height(outcomes.Iterations) == 0 && height(outcomes.Cases) == 0)
    error('simtest:FinalDocumentTestResultsRequired', ...
        ['No collected test results were found. Run st_collect_per_cut_results ' ...
        'after a PER_CUT run, or st_generate_test_report after a BATCH run.']);
end
end


function require_coverage(required, coverage)
if ~required, return; end
if strcmp(coverage.Source, 'NONE')
    error('simtest:FinalDocumentCoverageRequired', ...
        'RequireCoverage is set but CoverageSource is NONE.');
end
if height(coverage.Rows) == 0 || all(isnan(coverage.Rows.ExecutionTotal) & ...
        isnan(coverage.Rows.DecisionTotal))
    error('simtest:FinalDocumentCoverageRequired', ...
        ['No coverage values were found. Run st_run_standalone_coverage_pipeline ' ...
        'with Action ALL first.']);
end
end


function metadata = build_metadata(cfg, source, coverage, idMode, decisionScope, rowCount)
% The verdicts and the coverage come from two different executions on
% purpose, so both identities are recorded here.
metaKeys = strings(0,1);
metaValues = strings(0,1);
    function add(key, value)
        metaKeys(end+1,1) = string(key); %#ok<AGROW>
        metaValues(end+1,1) = string(value); %#ok<AGROW>
    end
    function add_source_file(field)
        path = char(string(config_value(cfg, field, '')));
        add(field, path);
        if isempty(path)
            add([field 'SHA256'], '');
            return;
        end
        signature = st_file_signature(path);
        add([field 'SHA256'], signature.SHA256);
    end
add('CreatedAt', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS')));
add('TopModel', config_value(cfg, 'TopModel', ''));
add('MATLABRelease', version('-release'));
add('MATLABVersion', version);
add('SpecificationRows', rowCount);
add_source_file('ModelFile');
add_source_file('TestFile');
add_source_file('ManagementExcel');
add('ResultRunRequested', source.Requested);
add('ResultRunMode', source.Mode);
add('ResultRunId', source.RunId);
add('ResultRunDirectory', source.RunDirectory);
add('ResultRunUpdatedAt', source.UpdatedAt);
add('ResultWorkbooks', join_paths(source.Workbooks));
add('ResultSets', join_paths(source.ResultSets));
add('CoverageSource', coverage.Source);
add('CoveragePipelineId', coverage.PipelineId);
add('CoverageSummary', coverage.SummaryFile);
add('CoverageSummarySHA256', coverage.SummarySHA256);
add('TestCaseIdMode', idMode);
add('DecisionBlockScope', decisionScope);
metadata = table(metaKeys, metaValues, 'VariableNames', {'Key','Value'});
end


function text = join_paths(T)
if isempty(T) || height(T) == 0
    text = "";
    return;
end
labels = T.Stage + ":" + T.File;
text = strjoin(labels, ' | ');
end


function path = canonical(path)
path = char(java.io.File(char(path)).getCanonicalPath());
end
