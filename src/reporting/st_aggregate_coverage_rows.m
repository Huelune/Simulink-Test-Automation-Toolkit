function summary = st_aggregate_coverage_rows(rows)
%ST_AGGREGATE_COVERAGE_ROWS Outcome-weight compatible CUT coverage.
%
% Rows for the same CoverageRoot are compatible only when their Checksum
% values agree. Incompatible roots are excluded rather than added.

required = {'CoverageRoot','Checksum','Metric','Covered','Total','Justified'};
for i = 1:numel(required)
    if ~ismember(required{i}, rows.Properties.VariableNames)
        error('simtest:InvalidCoverageRows', ...
            'Coverage rows are missing %s.', required{i});
    end
end

metrics = unique(string(rows.Metric), 'stable');
Metric = strings(numel(metrics),1);
Covered = zeros(numel(metrics),1);
Total = zeros(numel(metrics),1);
Justified = zeros(numel(metrics),1);
Percentage = NaN(numel(metrics),1);
PercentageText = strings(numel(metrics),1);
CompatibleCUTCount = zeros(numel(metrics),1);
IncompatibleCUTCount = zeros(numel(metrics),1);
Status = strings(numel(metrics),1);

for m = 1:numel(metrics)
    Metric(m) = metrics(m);
    metricRows = rows(string(rows.Metric) == metrics(m), :);
    roots = unique(string(metricRows.CoverageRoot), 'stable');
    for r = 1:numel(roots)
        rootRows = metricRows( ...
            string(metricRows.CoverageRoot) == roots(r), :);
        checksums = unique(string(rootRows.Checksum));
        checksums(checksums == "") = [];
        if numel(checksums) ~= 1
            IncompatibleCUTCount(m) = IncompatibleCUTCount(m) + 1;
            continue;
        end

        % Identical root/checksum rows describe the same aggregated CUT.
        % Keep the row with the largest denominator instead of double-counting.
        [~, representative] = max(double(rootRows.Total));
        Covered(m) = Covered(m) + double(rootRows.Covered(representative));
        Total(m) = Total(m) + double(rootRows.Total(representative));
        Justified(m) = Justified(m) + ...
            double(rootRows.Justified(representative));
        CompatibleCUTCount(m) = CompatibleCUTCount(m) + 1;
    end

    [Percentage(m), PercentageText(m)] = ...
        st_coverage_percentage(Covered(m), Total(m));
    if IncompatibleCUTCount(m) > 0
        Status(m) = "PARTIAL_CHECKSUM_MISMATCH";
    elseif CompatibleCUTCount(m) == 0
        Status(m) = "N/A";
    else
        Status(m) = "OK";
    end
end

summary = table(Metric, Covered, Total, Justified, Percentage, ...
    PercentageText, CompatibleCUTCount, IncompatibleCUTCount, Status);
end
