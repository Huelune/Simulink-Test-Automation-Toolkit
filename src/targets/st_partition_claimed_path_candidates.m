function [availablePaths, claimedCandidates] = ...
    st_partition_claimed_path_candidates(candidatePaths, claims)
%ST_PARTITION_CLAIMED_PATH_CANDIDATES Remove already assigned CUT paths.
%
% candidatePaths is a cell array, string array, or character vector of
% canonical Simulink subsystem paths. claims is a table with CUTPath,
% ExcelRow, and CUTName variables. The returned claimedCandidates table
% records which worksheet row already owns every removed path.

candidatePaths = st_claim_to_cellstr(candidatePaths);

required = {'CUTPath','ExcelRow','CUTName'};

if ~istable(claims) || ...
        ~all(ismember(required, claims.Properties.VariableNames))

    error( ...
        'st_partition_claimed_path_candidates:InvalidClaims', ...
        'claims must contain CUTPath, ExcelRow, and CUTName variables.');
end

availablePaths = {};
CandidatePath = strings(0,1);
ClaimedExcelRow = zeros(0,1);
ClaimedCUTName = strings(0,1);

for i = 1:numel(candidatePaths)

    candidate = candidatePaths{i};
    owner = find(strcmp(string(candidate), claims.CUTPath), 1, 'first');

    if isempty(owner)

        availablePaths{end+1,1} = candidate; %#ok<AGROW>

    else

        CandidatePath(end+1,1) = string(candidate); %#ok<AGROW>
        ClaimedExcelRow(end+1,1) = ...
            double(claims.ExcelRow(owner)); %#ok<AGROW>
        ClaimedCUTName(end+1,1) = ...
            string(claims.CUTName(owner)); %#ok<AGROW>
    end
end

claimedCandidates = table( ...
    CandidatePath, ...
    ClaimedExcelRow, ...
    ClaimedCUTName);

end


function values = st_claim_to_cellstr(value)

if isempty(value)

    values = {};

elseif iscell(value)

    values = cellfun(@char, value(:), 'UniformOutput', false);

elseif isstring(value)

    values = cellstr(value(:));

elseif ischar(value)

    values = {value};

else

    values = cellstr(string(value(:)));
end

end
