function [specification, outputFile] = st_export_test_specification(varargin)
%ST_EXPORT_TEST_SPECIFICATION Export saved Assessment definitions without running.
%   [T, PATH] = st_export_test_specification('OutputFile', 'specification.xlsx')
%   Default: result/test_specification_<timestamp>.xlsx. Existing output files
%   are refused. This independent command never invokes the test workflow.
%   VerifyMode: 'STEP2' (default) accepts direct Step 2 names such as
%   step2, step_2, Step 2, or STEP-02. 'ALL_STEPS_COLUMNS' puts each
%   verify-bearing step in a separate column with its relative step path.
%   Input scenarios are read from the actual Test Manager binding whenever
%   the Harness contains a Signal Editor, regardless of direct CUT Inports.
%   MaxTime is the input scenario Tmax for FILE/GENERATE cases, and
%   the Harness solver StopTime for OFF cases.
%   DecisionBlocks shows each direct child decision block Name followed by
%   a D-numbered saved-parameter condition. DecisionBlockDetails retains
%   outcomes, expressions, types, paths, and JSON.
%   DecisionBlockScope: 'EXPLICIT' (default) lists only the blocks that
%   carry a condition in their dialog. 'ALL' adds the blocks that create
%   coverage objectives without one, such as Saturate, Relay and the
%   lookup table family. 'NONE' leaves the column empty. Omit it to use
%   cfg.DecisionBlockScope.
p = inputParser;
addParameter(p, 'OutputFile', '', @(v) (ischar(v) && isrow(v)) || ...
    (isstring(v) && isscalar(v)) || isempty(v));
addParameter(p, 'VerifyMode', 'STEP2', @(v) ...
    (ischar(v) && isrow(v)) || (isstring(v) && isscalar(v)));
addParameter(p, 'DecisionBlockScope', '', @(v) (ischar(v) && isrow(v)) || ...
    (isstring(v) && isscalar(v)) || isempty(v));
parse(p, varargin{:});
verifyMode = upper(strtrim(char(p.Results.VerifyMode)));
if ~ismember(verifyMode, {'STEP2', 'ALL_STEPS_COLUMNS'})
    error('simtest:SpecificationVerifyMode', 'VerifyMode must be STEP2 or ALL_STEPS_COLUMNS.');
end
cfg = st_config();
decisionScope = resolve_decision_scope(p.Results.DecisionBlockScope, cfg);
outputFile = char(p.Results.OutputFile);
if isempty(outputFile)
    outputFile = fullfile(cfg.ResultDir, ['test_specification_' ...
        char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS')) '.xlsx']);
end
outputFile = canonical(outputFile);
[~, ~, extension] = fileparts(outputFile);
if ~strcmpi(extension, '.xlsx')
    error('simtest:SpecificationOutput', 'OutputFile must have an .xlsx extension.');
end
if isfile(outputFile)
    error('simtest:SpecificationOutputExists', 'Output already exists: %s', outputFile);
end
st_log(cfg, 'INFO', ...
    'Specification export start | VerifyMode=%s | DecisionBlockScope=%s | Output=%s', ...
    verifyMode, decisionScope, outputFile);
timer = tic;
try
    [rows, details, verifyCells, maxTimes, decisionBlockLists] = ...
        st_collect_specification_rows(cfg, verifyMode, decisionScope);
    specification = st_specification_table(rows, verifyCells, maxTimes, decisionBlockLists);
    detailTable = array2table(details, 'VariableNames', {'TestCaseName', ...
        'HarnessName','AssessmentBlock','ScenarioName','StepPath', ...
        'OriginalAction','Transitions','VerifySummary','ReadStatus','Message'});
    st_log(cfg, 'INFO', 'Specification workbook write start | Rows=%d | File=%s', ...
        height(specification), outputFile);
    [specification, detailTable] = st_write_specification_workbook( ...
        specification, detailTable, outputFile, cfg); %#ok<ASGLU>
    st_log(cfg, 'INFO', 'Specification workbook write end | File=%s', outputFile);
    st_log(cfg, 'INFO', 'Specification export end | Rows=%d | Elapsed=%.3fs', ...
        height(specification), toc(timer));
    fprintf('Test specification exported: %s\n', outputFile);
catch ME
    st_log(cfg, 'ERROR', 'Specification export failed | Elapsed=%.3fs | %s', toc(timer), ME.message);
    rethrow(ME);
end
end

function scope = resolve_decision_scope(requested, cfg)
% An argument wins over cfg. A config written before this option exists has
% no field, so fall back to the documented default instead of failing.
scope = upper(strtrim(char(requested)));
if isempty(scope)
    if isstruct(cfg) && isfield(cfg, 'DecisionBlockScope')
        scope = upper(strtrim(char(string(cfg.DecisionBlockScope))));
    else
        scope = 'EXPLICIT';
    end
end
if isempty(scope)
    scope = 'EXPLICIT';
end
if ~ismember(scope, {'EXPLICIT', 'ALL', 'NONE'})
    error('simtest:SpecificationDecisionScope', ...
        'DecisionBlockScope must be EXPLICIT, ALL or NONE.');
end
end

function path = canonical(path)
path = char(java.io.File(char(path)).getCanonicalPath());
end
