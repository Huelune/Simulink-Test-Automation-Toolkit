function scenarioNames = st_select_sldv_template_names( ...
        validNames, preferredName, originalNames, sourceIndices)
%ST_SELECT_SLDV_TEMPLATE_NAMES Match Harness templates to SLDV scenarios.
%
% A manually imported SLDV Signal Editor MAT commonly contains variables
% named TestCase_1, TestCase_2, ... . Map those by source index before
% applying the legacy single-template fallback. This preserves distinct
% Harness-only input values for each original scenario.

validNames = cellstr(string(validNames(:)));
preferredName = char(string(preferredName));
originalNames = cellstr(string(originalNames(:)));
sourceIndices = double(sourceIndices(:));
scenarioCount = numel(sourceIndices);
scenarioNames = {};

if scenarioCount == 0
    return;
end

% A defect scenario repeats its source's index and original name, so the
% names must match the indices one to one rather than be unique.
pairs = string(originalNames) + "|" + string(sourceIndices);
if numel(originalNames) == scenarioCount && ...
        all(ismember(originalNames, validNames)) && ...
        numel(unique(originalNames)) == numel(unique(sourceIndices)) && ...
        numel(unique(pairs)) == numel(unique(sourceIndices))
    scenarioNames = originalNames;
    return;
end

indexedNames = arrayfun( ...
    @(index) sprintf('TestCase_%d', index), ...
    sourceIndices, ...
    'UniformOutput', false);
if all(ismember(indexedNames, validNames))
    scenarioNames = indexedNames(:);
    return;
end

if any(strcmp(validNames, preferredName))
    scenarioNames = repmat({preferredName}, scenarioCount, 1);
    return;
end

if any(strcmp(validNames, 'InputScenario'))
    scenarioNames = repmat({'InputScenario'}, scenarioCount, 1);
    return;
end

if numel(validNames) == 1
    scenarioNames = repmat(validNames(:), scenarioCount, 1);
end
end
