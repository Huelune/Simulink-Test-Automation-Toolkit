function [stages, index] = st_workflow_stages(workflow, fromStage)
%ST_WORKFLOW_STAGES Single stage vocabulary for inspection and restart.
workflow = upper(char(string(workflow)));
stages = ["HARNESS","SLDV","HARNESS_CONFIG","SIGNAL_EDITOR", ...
    "ASSESSMENT","COVERAGE_FILTER","TEST_MANAGER","ALIGNMENT","EXECUTE"];
switch workflow
    case {'FROM_HARNESS','FULL'}
    case 'AFTER_HARNESS'
        stages = stages(2:end);
    case 'STANDALONE'
        stages = ["EXECUTE","PACKAGE","SUMMARY"];
    otherwise
        error('simtest:RestartWorkflowInvalid', 'Unknown workflow: %s', workflow);
end
if nargin < 2 || strlength(string(fromStage)) == 0, fromStage = stages(1); end
index = find(stages == upper(string(fromStage)), 1);
if isempty(index)
    error('simtest:RestartStageInvalid', 'Stage %s is not available in %s.', fromStage, workflow);
end
end
