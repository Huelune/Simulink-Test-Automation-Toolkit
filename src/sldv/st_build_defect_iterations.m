function defects = st_build_defect_iterations(objectives, scenarioNames, cutName, selector)
%ST_BUILD_DEFECT_ITERATIONS Group unreachable decision outcomes into defect iterations.
%
% objectives is a table with columns Sid, BlockType, RelativePath,
% OutcomeIndex, OutcomeText and Approximate. One defect iteration is built
% per Sid, ordered by RelativePath. Defects are named after the last
% scenario (st_scenario_name(cutName, N+k)) and replay the scenario chosen
% by selector: "" (last), a 1-based number in text, or an exact scenario name.
%
% Called without arguments it returns the empty defect list, which is the
% default of the DefectIterations profile field.

emptyOutcomes = repmat(struct('Index', 0, 'Text', '', 'Approximate', false), 0, 1);
template = struct('Name', '', 'SourceScenario', '', 'SourceIndex', NaN, ...
    'BlockType', '', 'RelativePath', '', 'Sid', '', ...
    'Outcomes', {emptyOutcomes});
defects = repmat(template, 0, 1);

% The selector is checked only when a defect exists, so a bad workbook cell
% matters only for a CUT that actually has defects.
if nargin < 1 || isempty(objectives) || height(objectives) == 0
    return;
end

scenarioNames = cellstr(scenarioNames);
sourceIndex = resolve_source_index(string(selector), scenarioNames);

sids = string(objectives.Sid);
[uniqueSids, firstRow] = unique(sids, 'stable');
paths = string(objectives.RelativePath(firstRow));
[~, order] = sortrows([paths(:), uniqueSids(:)]);
uniqueSids = uniqueSids(order);
firstRow = firstRow(order);
paths = paths(order);

count = numel(uniqueSids);
defects = repmat(template, count, 1);
baseCount = numel(scenarioNames);
for k = 1:count
    rows = find(sids == uniqueSids(k));
    [~, byIndex] = sort(double(objectives.OutcomeIndex(rows)));
    rows = rows(byIndex);
    outcomes = repmat(struct('Index', 0, 'Text', '', 'Approximate', false), ...
        numel(rows), 1);
    for j = 1:numel(rows)
        outcomes(j).Index = double(objectives.OutcomeIndex(rows(j)));
        outcomes(j).Text = char(string(objectives.OutcomeText(rows(j))));
        outcomes(j).Approximate = logical(objectives.Approximate(rows(j)));
    end
    defects(k).Name = st_scenario_name(cutName, baseCount + k);
    defects(k).SourceScenario = scenarioNames{sourceIndex};
    defects(k).SourceIndex = sourceIndex;
    defects(k).BlockType = char(string(objectives.BlockType(firstRow(k))));
    defects(k).RelativePath = char(paths(k));
    defects(k).Sid = char(uniqueSids(k));
    defects(k).Outcomes = outcomes;
end
end


function index = resolve_source_index(selector, scenarioNames)
selector = strtrim(selector);
count = numel(scenarioNames);
index = [];
if selector == ""
    index = count;
elseif any(strcmp(scenarioNames, char(selector)))
    index = find(strcmp(scenarioNames, char(selector)), 1);
elseif ~isempty(regexp(char(selector), '^\d+$', 'once'))
    candidate = str2double(selector);
    if candidate >= 1 && candidate <= count
        index = candidate;
    end
end
if isempty(index) || index < 1
    error('simtest:DefectInputScenarioInvalid', ...
        ['Targets 시트의 DefectInputScenario를 1~%d 또는 시나리오 이름으로 ' ...
        '고치세요. 현재 값: "%s"'], count, char(selector));
end
end
