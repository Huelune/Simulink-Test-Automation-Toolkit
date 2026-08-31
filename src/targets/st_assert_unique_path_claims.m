function st_assert_unique_path_claims(claims)
%ST_ASSERT_UNIQUE_PATH_CLAIMS Reject duplicate existing CUTPath ownership.
%
% claims must contain CUTPath, ExcelRow, and CUTName variables. Empty paths
% are not valid claims and are ignored defensively.

required = {'CUTPath','ExcelRow','CUTName'};

if ~istable(claims) || ...
        ~all(ismember(required, claims.Properties.VariableNames))

    error( ...
        'st_assert_unique_path_claims:InvalidClaims', ...
        'claims must contain CUTPath, ExcelRow, and CUTName variables.');
end

if height(claims) < 2
    return;
end

duplicateLines = {};

for i = 1:height(claims)

    if strlength(claims.CUTPath(i)) == 0
        continue;
    end

    samePath = find(strcmp(claims.CUTPath, claims.CUTPath(i)));

    if numel(samePath) < 2 || i ~= samePath(1)
        continue;
    end

    owners = cell(numel(samePath),1);

    for k = 1:numel(samePath)

        row = samePath(k);
        owners{k} = sprintf( ...
            'row %d (%s)', ...
            double(claims.ExcelRow(row)), ...
            char(claims.CUTName(row)));
    end

    duplicateLines{end+1,1} = sprintf( ...
        '%s <- %s', ...
        char(claims.CUTPath(i)), ...
        strjoin(owners, ', ')); %#ok<AGROW>
end

if isempty(duplicateLines)
    return;
end

fprintf('\nDuplicate existing CUTPath assignments:\n');

for i = 1:numel(duplicateLines)
    fprintf('  %s\n', duplicateLines{i});
end

error( ...
    'st_assert_unique_path_claims:DuplicateCUTPath', ...
    ['The same existing CUTPath is assigned to multiple enabled rows. ' ...
     'No CUTPath values were written.\n%s'], ...
    strjoin(duplicateLines, newline));

end
