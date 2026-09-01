function selected = st_select_asset_targets(targets, testCaseNames)
%ST_SELECT_ASSET_TARGETS Map selected result cases to management rows.

required = {'TestCaseName','CUTPath','HarnessName'};
if ~istable(targets) || ~all(ismember(required, ...
        targets.Properties.VariableNames))
    error('simtest:InvalidAssetTargetTable', ...
        'Target table must contain TestCaseName, CUTPath, and HarnessName.');
end

names = unique(strtrim(string(testCaseNames(:))), 'stable');
names = names(strlength(names) > 0);
if isempty(names)
    error('simtest:AssetResultHasNoTestCases', ...
        'The selected result contains no named Test Cases.');
end

targetNames = strtrim(string(targets.TestCaseName));
indices = zeros(numel(names), 1);
for i = 1:numel(names)
    matches = find(targetNames == names(i));
    if isempty(matches)
        error('simtest:AssetResultTargetMissing', ...
            'Result Test Case is not mapped in TestManagement: %s', ...
            char(names(i)));
    end
    if numel(matches) > 1
        error('simtest:AssetResultTargetDuplicate', ...
            ['Result Test Case maps to multiple TestManagement rows: ' ...
             '%s'], char(names(i)));
    end
    indices(i) = matches;
end

selected = targets(indices, :);
end
