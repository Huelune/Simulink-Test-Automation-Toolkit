function [percentage, displayValue] = st_coverage_percentage(covered, total)
%ST_COVERAGE_PERCENTAGE Calculate coverage without treating 0/0 as zero.

covered = double(covered);
total = double(total);
if isempty(total) || ~isscalar(total) || isnan(total) || total <= 0
    percentage = NaN;
    displayValue = "N/A";
    return;
end

percentage = 100 * covered / total;
displayValue = string(sprintf('%.2f%%', percentage));
end
