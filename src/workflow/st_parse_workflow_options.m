function options = st_parse_workflow_options(varargin)
%ST_PARSE_WORKFLOW_OPTIONS Parse optional workflow execution overrides.

p = inputParser;
p.FunctionName = 'Simulink Test workflow';
addParameter(p, 'PreparationMode', '', @(v) ischar(v) || isstring(v));
addParameter(p, 'FromStage', '', @(v) ischar(v) || isstring(v));
addParameter(p, 'ExecutionMode', '', @(v) ischar(v) || isstring(v));
addParameter(p, 'SystemUnderTestMode', '', ...
    @(v) ischar(v) || isstring(v));
addParameter(p, 'ContinueOnFailure', [], ...
    @(v) isempty(v) || (islogical(v) && isscalar(v)));
addParameter(p, 'ReportMode', '', @(v) ischar(v) || isstring(v));
addParameter(p, 'FailOnNonPass', [], ...
    @(v) isempty(v) || (islogical(v) && isscalar(v)));
parse(p, varargin{:});

options = struct();
options.PreparationMode = upper(strtrim(char(string( ...
    p.Results.PreparationMode))));
options.FromStage = upper(strtrim(char(string(p.Results.FromStage))));
options.ExecutionMode = upper(strtrim(char(string( ...
    p.Results.ExecutionMode))));
options.SystemUnderTestMode = upper(strtrim(char(string( ...
    p.Results.SystemUnderTestMode))));
options.ContinueOnFailure = p.Results.ContinueOnFailure;
options.ReportMode = upper(strtrim(char(string(p.Results.ReportMode))));
options.FailOnNonPass = p.Results.FailOnNonPass;

if ~isempty(options.PreparationMode) && ...
        ~ismember(options.PreparationMode, {'AUTO','FORCE'})
    error('simtest:InvalidPreparationMode', ...
        'PreparationMode override must be AUTO or FORCE.');
end

validStages = {'START','HARNESS','SLDV','HARNESS_CONFIG', ...
    'SIGNAL_EDITOR','ASSESSMENT','COVERAGE_FILTER','TEST_MANAGER', ...
    'ALIGNMENT'};
if ~isempty(options.FromStage) && ...
        ~ismember(options.FromStage, validStages)
    error('simtest:InvalidPreparationFromStage', ...
        'Invalid FromStage override: %s', options.FromStage);
end

if ~isempty(options.ExecutionMode) && ...
        ~ismember(options.ExecutionMode, {'AUTO','BATCH','PER_CUT'})
    error('simtest:InvalidExecutionMode', ...
        'ExecutionMode override must be AUTO, BATCH, or PER_CUT.');
end
if ~isempty(options.SystemUnderTestMode)
    st_resolve_system_under_test_mode(options.SystemUnderTestMode);
end
if ~isempty(options.ReportMode) && ...
        ~ismember(options.ReportMode, {'SUMMARY','FULL'})
    error('simtest:InvalidPerCutReportMode', ...
        'ReportMode override must be SUMMARY or FULL.');
end
end
