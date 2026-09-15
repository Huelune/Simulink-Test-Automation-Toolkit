function [outcome, expression] = st_specification_decision_descriptor( ...
        blockPath, blockType, parameterReader, catalogReader)
%ST_SPECIFICATION_DECISION_DESCRIPTOR Read a static decision summary.
% This does not compile or execute the model. It only describes the saved
% block parameters that select a branch or input.
% The outcome token comes from st_specification_decision_catalog. A block
% type whose expression is a plain list of saved parameters is handled by
% the generic formatter, so only an irregular type needs a case below.
if nargin < 3
    parameterReader = @get_param;
end
if nargin < 4
    catalogReader = @st_specification_decision_catalog;
end

blockType = string(blockType);
if ~isscalar(blockType) || ismissing(blockType)
    error('simtest:SpecificationDecisionBlockType', ...
        'BlockType must be one nonmissing text value.');
end

catalog = catalogReader();
index = find(string(catalog.BlockType) == blockType, 1);
if isempty(index)
    error('simtest:SpecificationDecisionBlockType', ...
        'Unsupported decision block type: %s', blockType);
end
outcome = string(catalog.Outcome(index));

switch blockType
    case "If"
        expression = parameter_text(parameterReader, blockPath, 'IfExpression');
        elseIf = parameter_text(parameterReader, blockPath, 'ElseIfExpressions');
        if strlength(elseIf) > 0
            expression = expression + "; elseif " + elseIf;
        end

    case "Switch"
        criteria = parameter_text(parameterReader, blockPath, 'Criteria');
        if contains(criteria, "Threshold")
            threshold = parameter_text(parameterReader, blockPath, 'Threshold');
            expression = replace(criteria, "Threshold", threshold);
        else
            expression = criteria;
        end

    case "MinMax"
        operation = parameter_text(parameterReader, blockPath, 'Function');
        inputs = parameter_text(parameterReader, blockPath, 'Inputs');
        expression = operation + "; Inputs=" + inputs;

    case "MultiPortSwitch"
        order = parameter_text(parameterReader, blockPath, 'DataPortOrder');
        if strcmpi(order, "Specify indices")
            indices = parameter_text(parameterReader, blockPath, 'DataPortIndices');
            expression = "DataPortOrder=" + order + "; DataPortIndices=" + indices;
        else
            inputs = parameter_text(parameterReader, blockPath, 'Inputs');
            expression = "DataPortOrder=" + order + "; Inputs=" + inputs;
        end

    case "SwitchCase"
        conditions = parameter_text(parameterReader, blockPath, 'CaseConditions');
        expression = "u1 in " + conditions;

    otherwise
        expression = generic_expression( ...
            parameterReader, blockPath, catalog(index,:));
end

if strlength(strtrim(expression)) == 0
    error('simtest:SpecificationDecisionExpression', ...
        'Decision expression is empty: %s', blockPath);
end
end

function expression = generic_expression(reader, blockPath, row)
% Join the saved parameters of a block whose branch has no dialog condition.
% A required parameter read failure propagates so the caller records the
% block with a WARN status instead of dropping it. An optional parameter is
% skipped when it is absent on this release or inactive in this dialog state.
parts = strings(0,1);
fixed = strtrim(string(row.FixedText));
if strlength(fixed) > 0
    parts(end+1,1) = fixed;
end
required = name_list(row.Parameters);
for k = 1:numel(required)
    value = parameter_text(reader, blockPath, char(required(k)));
    if strlength(value) > 0
        parts(end+1,1) = required(k) + "=" + value; %#ok<AGROW>
    end
end
optional = name_list(row.OptionalParameters);
for k = 1:numel(optional)
    try
        value = parameter_text(reader, blockPath, char(optional(k)));
    catch
        continue;
    end
    if strlength(value) > 0
        parts(end+1,1) = optional(k) + "=" + value; %#ok<AGROW>
    end
end
expression = strjoin(parts, '; ');
end

function names = name_list(text)
names = strtrim(split(string(text), ','));
names = names(:);
names = names(strlength(names) > 0);
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
