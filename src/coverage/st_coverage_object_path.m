function path = st_coverage_object_path(row)
%ST_COVERAGE_OBJECT_PATH The path coverage knows a CUT by.
% A standalone bundle renames the CUT, so the coverage object answers to
% StandaloneCUTPath there and to CUTPath everywhere else. This is the value
% decisioninfo and executioninfo accept for that target.
path = '';
if ismember('StandaloneCUTPath', row.Properties.VariableNames)
    path = strtrim(char(string(row.StandaloneCUTPath)));
end
if isempty(path)
    path = char(string(row.CUTPath));
end
end
