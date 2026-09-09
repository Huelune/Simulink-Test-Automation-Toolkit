function [outcome, expression] = st_specification_decision_descriptor( ...
        blockPath, blockType, parameterReader)
%ST_SPECIFICATION_DECISION_DESCRIPTOR Read a static decision summary.
% This does not compile or execute the model. It only describes the saved
% block parameters that select a branch or input.
if nargin < 3
    parameterReader = @get_param;
end

blockType = string(blockType);
if ~isscalar(blockType) || ismissing(blockType)
    error('simtest:SpecificationDecisionBlockType', ...
        'BlockType must be one nonmissing text value.');
end

switch blockType
    case "If"
        outcome = "T/F";
        expression = parameter_text(parameterReader, blockPath, 'IfExpression');
        elseIf = parameter_text(parameterReader, blockPath, 'ElseIfExpressions');
        if strlength(elseIf) > 0
            expression = expression + "; elseif " + elseIf;
        end

    case "Switch"
        outcome = "T/F";
        criteria = parameter_text(parameterReader, blockPath, 'Criteria');
        if contains(criteria, "Threshold")
            threshold = parameter_text(parameterReader, blockPath, 'Threshold');
            expression = replace(criteria, "Threshold", threshold);
        else
            expression = criteria;
        end

    case "MinMax"
        outcome = "SELECT";
        operation = parameter_text(parameterReader, blockPath, 'Function');
        inputs = parameter_text(parameterReader, blockPath, 'Inputs');
        expression = operation + "; Inputs=" + inputs;

    case "MultiPortSwitch"
        outcome = "SELECT";
        order = parameter_text(parameterReader, blockPath, 'DataPortOrder');
        if strcmpi(order, "Specify indices")
            indices = parameter_text(parameterReader, blockPath, 'DataPortIndices');
            expression = "DataPortOrder=" + order + "; DataPortIndices=" + indices;
        else
            inputs = parameter_text(parameterReader, blockPath, 'Inputs');
            expression = "DataPortOrder=" + order + "; Inputs=" + inputs;
        end

    case "SwitchCase"
        outcome = "CASE";
        conditions = parameter_text(parameterReader, blockPath, 'CaseConditions');
        expression = "u1 in " + conditions;

    otherwise
        error('simtest:SpecificationDecisionBlockType', ...
            'Unsupported decision block type: %s', blockType);
end

if strlength(strtrim(expression)) == 0
    error('simtest:SpecificationDecisionExpression', ...
        'Decision expression is empty: %s', blockPath);
end
end

function value = parameter_text(reader, blockPath, parameter)
raw = reader(char(blockPath), parameter);
value = string(raw);
value = value(:);
value = value(~ismissing(value));
if isempty(value)
    value = "";
else
    value = strjoin(value, ', ');
end
value = strtrim(value);
end
