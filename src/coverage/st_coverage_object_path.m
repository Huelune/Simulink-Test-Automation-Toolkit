function path = st_coverage_object_path(row)
%ST_COVERAGE_OBJECT_PATH The path coverage knows a CUT by.
% A standalone bundle renames the CUT, so the coverage object answers to
% StandaloneCUTPath there and to CUTPath everywhere else. This is the value
% decisioninfo and executioninfo accept for that target. The value comes
% from Simulink, so it is returned untrimmed: a CUT whose name ends in a
% space is only found with that space.
path = '';
if ismember('StandaloneCUTPath', row.Properties.VariableNames)
    path = char(string(row.StandaloneCUTPath));
end
if strlength(strtrim(string(path))) == 0
    path = char(string(row.CUTPath));
end
end
