function info = st_run_from_stage(varargin)
%ST_RUN_FROM_STAGE Strict restart; never repairs earlier stages implicitly.
p = inputParser;
addParameter(p,'Workflow','');
addParameter(p,'FromStage','');
addParameter(p,'SourcePipelineId','');
parse(p,varargin{:});
workflow = upper(char(string(p.Results.Workflow)));
from = upper(char(string(p.Results.FromStage)));
if isempty(workflow) || isempty(from)
    error('simtest:RestartSelectionRequired','Specify Workflow and FromStage explicitly.');
end
st_workflow_stages(workflow,from);
cfg = st_config();
st_log(cfg,'INFO','Stage restart start | Workflow=%s | FromStage=%s',workflow,from);
try
    [summary,checks] = st_check_readiness('Workflow',workflow,'FromStage',from, ...
        'SourcePipelineId',p.Results.SourcePipelineId);
    if ~summary.Ready
        disp(checks(checks.Status == "BLOCKED",:));
        error('simtest:RestartBlocked','Required start: %s. See readiness checks.',summary.RecommendedFromStage);
    end
    switch workflow
        case 'STANDALONE'
            if strcmp(from,'EXECUTE')
                info = st_run_standalone_coverage_pipeline('Action','ALL','SaveTestResult',true);
            else
                info = st_regenerate_standalone_results(cfg,p.Results.SourcePipelineId,from);
            end
        case {'FROM_HARNESS','AFTER_HARNESS'}
            kind = 'FULL'; if strcmp(workflow,'AFTER_HARNESS'), kind = workflow; end
            [~,~,result,report] = st_run_workflow(kind,'FromStage',from, ...
                'PreparationMode','FORCE','StrictRestart',true,'ExecuteTests',true);
            info = struct('Workflow',workflow,'FromStage',from,'Result',result,'Report',report);
        otherwise
            error('simtest:RestartWorkflowInvalid','Use FROM_HARNESS, AFTER_HARNESS or STANDALONE.');
    end
    st_log(cfg,'INFO','Stage restart complete | Workflow=%s | FromStage=%s',workflow,from);
catch ME
    st_log(cfg,'ERROR','Stage restart failed | %s: %s',ME.identifier,ME.message);
    rethrow(ME);
end
end
