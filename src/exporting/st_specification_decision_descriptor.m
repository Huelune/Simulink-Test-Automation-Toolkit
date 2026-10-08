function [outcome, expression, coverageTexts] = st_specification_decision_descriptor( ...
        blockPath, blockType, parameterReader, catalogReader)
%ST_SPECIFICATION_DECISION_DESCRIPTOR Read a static decision summary.
% This does not compile or execute the model. It only describes the saved
% block parameters that select a branch or input.
% The outcome token comes from st_specification_decision_catalog. A block
% type whose expression is a plain list of saved parameters is handled by
% the generic formatter, so only an irregular type needs a case below.
% An empty EXPRESSION means the saved settings give the block no Decision
% objective at all, as the catalog DecisionWhen column describes. The scan
% then leaves the block out of the list.
% COVERAGETEXTS holds, per branch, the decision text Simulink Coverage
% prints for it when the catalog lists Branches for the type, and "" for
% every other type. The final document pairs a branch with its recorded
% outcome by this text.
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
coverageTexts = strings(0,1);
if ~has_decision(parameterReader, blockPath, catalog.DecisionWhen(index))
    expression = strings(0,1);
    return;
end

branches = "";
if ismember('Branches', catalog.Properties.VariableNames)
    branches = strtrim(string(catalog.Branches(index)));
end
if strlength(branches) > 0
    % One line per branch. When no branch survives its condition the result
    % is empty: the saved settings give the block no Decision objective, the
    % same as a failed DecisionWhen, and the scan leaves it out.
    [expression, coverageTexts] = branch_expressions( ...
        parameterReader, blockPath, branches);
    return;
end

switch blockType
    case "If"
        % One branch per condition, because Simulink Coverage counts the if
        % and each elseif separately. The implicit else is not listed: it is
        % the absence of every condition, not a condition of its own.
        expression = parameter_text(parameterReader, blockPath, 'IfExpression');
        elseIf = split_conditions( ...
            parameter_text(parameterReader, blockPath, 'ElseIfExpressions'));
        expression = [expression; "elseif " + elseIf];

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

expression = string(expression);
expression = expression(:);
if isempty(expression) || any(strlength(strtrim(expression)) == 0)
    error('simtest:SpecificationDecisionExpression', ...
        'Decision expression is empty: %s', blockPath);
end
coverageTexts = repmat("", numel(expression), 1);
end

function parts = split_conditions(text)
% Split a comma separated condition list without cutting inside a call.
% Simulink stores ElseIfExpressions as one string, and a condition may
% contain its own commas, as in "min(u1, u2) > 0".
parts = strings(0,1);
text = char(strtrim(string(text)));
if isempty(text)
    return;
end
depth = 0;
first = 1;
for i = 1:numel(text)
    switch text(i)
        case {'(', '[', '{'}
            depth = depth + 1;
        case {')', ']', '}'}
            depth = depth - 1;
        case ','
            if depth == 0
                parts(end+1,1) = strtrim(string(text(first:i-1))); %#ok<AGROW>
                first = i + 1;
            end
    end
end
parts(end+1,1) = strtrim(string(text(first:end)));
parts = parts(strlength(parts) > 0);
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

function [expression, coverageTexts] = branch_expressions(reader, blockPath, spec)
% One line per Simulink Coverage decision, in the order coverage reports
% them. Each line starts with the decision text coverage prints, followed
% by the saved parameter that decision compares against. A parameter read
% failure propagates so the scan keeps the block as a WARN row.
expression = strings(0,1);
coverageTexts = strings(0,1);
for entry = strtrim(split(string(spec), ';')).'
    if strlength(entry) == 0, continue; end
    fields = strtrim(split(entry, ':'));
    if numel(fields) < 2 || numel(fields) > 3 || any(strlength(fields(1:2)) == 0)
        error('simtest:SpecificationDecisionBranch', ...
            'Malformed Branches entry: %s', entry);
    end
    if numel(fields) == 3 && ~has_decision(reader, blockPath, fields(3))
        continue;
    end
    value = parameter_text(reader, blockPath, char(fields(2)));
    expression(end+1,1) = fields(1) + "; " + fields(2) + "=" + value; %#ok<AGROW>
    coverageTexts(end+1,1) = fields(1); %#ok<AGROW>
end
end

function tf = has_decision(reader, blockPath, rule)
% Any one term is enough: each names a setting that adds a decision of its
% own, such as the reset and the limits of a Discrete-Time Integrator. A
% read failure propagates so the block is kept with a WARN status rather
% than dropped on a guess.
terms = name_list(rule);
tf = isempty(terms);
for k = 1:numel(terms)
    parts = regexp(char(terms(k)), '^(\w+)\s*(!?=)\s*(.+)$', 'tokens', 'once');
    if isempty(parts)
        error('simtest:SpecificationDecisionRule', ...
            'Malformed DecisionWhen term: %s', terms(k));
    end
    value = parameter_text(reader, blockPath, parts{1});
    equal = strcmpi(value, strtrim(string(parts{3})));
    if equal == strcmp(parts{2}, '=')
        tf = true;
        return;
    end
end
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
