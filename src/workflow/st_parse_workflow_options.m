function options = st_parse_workflow_options(varargin)
%ST_PARSE_WORKFLOW_OPTIONS Parse optional workflow execution overrides.

p = inputParser;
p.FunctionName = 'Simulink Test workflow';
addParameter(p, 'PreparationMode', '', @(v) ischar(v) || isstring(v));
addParameter(p, 'FromStage', '', @(v) ischar(v) || isstring(v));
parse(p, varargin{:});

options = struct();
options.PreparationMode = upper(strtrim(char(string( ...
    p.Results.PreparationMode))));
options.FromStage = upper(strtrim(char(string(p.Results.FromStage))));

if ~isempty(options.PreparationMode) && ...
        ~ismember(options.PreparationMode, {'AUTO','FORCE'})
    error('simtest:InvalidPreparationMode', ...
        'PreparationMode override must be AUTO or FORCE.');
end

validStages = {'START','HARNESS','SLDV','HARNESS_CONFIG', ...
    'SIGNAL_EDITOR','ASSESSMENT','TEST_MANAGER','ALIGNMENT'};
if ~isempty(options.FromStage) && ...
        ~ismember(options.FromStage, validStages)
    error('simtest:InvalidPreparationFromStage', ...
        'Invalid FromStage override: %s', options.FromStage);
end
end
