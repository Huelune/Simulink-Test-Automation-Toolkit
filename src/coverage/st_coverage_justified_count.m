function value = st_coverage_justified_count(description)
%ST_COVERAGE_JUSTIFIED_COUNT Objectives a coverage filter excused.
% decisioninfo and executioninfo return the objective totals in their first
% output and the per-objective detail in the second. A registered coverage
% filter does not remove an objective from the total; it marks it as
% justified here. Subtract this from the total to get what the filter
% actually left to measure.
%
% NaN means the detail could not be read, which is not the same as zero
% justified objectives and must not be treated as such.
value = 0;
try
    if isstruct(description) && isfield(description, 'justifiedCoverage')
        value = sum(double([description.justifiedCoverage]));
    end
catch
    value = NaN;
end
if isempty(value)
    value = 0;
end
end
