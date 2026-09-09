function active = st_coverage_filter_active(targets)
%ST_COVERAGE_FILTER_ACTIVE True for content filtering or a CUT boundary.

active = string(targets.CoverageFilterMode) ~= "OFF";
if ismember('CoverageBoundaryMode', targets.Properties.VariableNames)
    active = active | string(targets.CoverageBoundaryMode) ~= "OFF";
end
end
