function path = st_coverage_object_path(row)
%ST_COVERAGE_OBJECT_PATH The path coverage knows a CUT by.
% Coverage read back while its Harness is loaded answers to the Harness's
% CUT (HarnessCUTPath), not to the Top Model's CUT. A standalone bundle
% renames the CUT, so its coverage answers to StandaloneCUTPath. Everywhere
% else it is CUTPath. This is the value decisioninfo and executioninfo
% accept for that target. The value comes from Simulink, so it is returned
% untrimmed: a CUT whose name ends in a space is only found with that space.
path = '';
for name = {'HarnessCUTPath', 'StandaloneCUTPath'}
    if strlength(strtrim(string(path))) == 0 && ...
            ismember(name{1}, row.Properties.VariableNames)
        path = char(string(row.(name{1})));
    end
end
if strlength(strtrim(string(path))) == 0
    path = char(string(row.CUTPath));
end
end
