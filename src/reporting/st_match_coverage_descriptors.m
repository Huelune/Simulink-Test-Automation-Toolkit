function indices = st_match_coverage_descriptors(descriptors, targetPath)
%ST_MATCH_COVERAGE_DESCRIPTORS Select cvdata metadata for one CUT.
%
% Matching deliberately requires component identity metadata. Falling back
% to every coverage object makes decisioninfo/executioninfo perform an
% expensive and potentially pathological cross-product lookup.

required = {'Root','OwnerModel','OwnerBlock','AnalyzedModel'};
for i = 1:numel(required)
    if ~ismember(required{i}, descriptors.Properties.VariableNames)
        error('simtest:InvalidCoverageDescriptors', ...
            'Coverage descriptors are missing %s.', required{i});
    end
end

target = normalize_path(targetPath);
scores = zeros(height(descriptors), 1);
for i = 1:height(descriptors)
    ownerBlock = normalize_path(descriptors.OwnerBlock(i));
    analyzedModel = normalize_path(descriptors.AnalyzedModel(i));
    root = normalize_path(descriptors.Root(i));
    ownerModel = normalize_path(descriptors.OwnerModel(i));

    if same_path(ownerBlock, target)
        scores(i) = 4;
    elseif same_path(analyzedModel, target)
        scores(i) = 3;
    elseif same_path(root, target)
        scores(i) = 2;
    elseif ~contains(target, '/') && same_path(ownerModel, target)
        scores(i) = 1;
    end
    if scores(i) > 0 && ...
            ismember('DataType', descriptors.Properties.VariableNames) && ...
            upper(string(descriptors.DataType(i))) == "DERIVED_DATA"
        scores(i) = scores(i) + 0.5;
    end
end

best = max(scores, [], 'omitnan');
if isempty(best) || best <= 0
    indices = zeros(0, 1);
else
    indices = find(scores == best);
end
end

function value = normalize_path(value)
value = strtrim(string(value));
value = replace(value, '\', '/');
while contains(value, '//')
    value = replace(value, '//', '/');
end
value = regexprep(value, '^/+|/+$', '');
end

function tf = same_path(left, right)
tf = strlength(left) > 0 && strlength(right) > 0 && left == right;
end
