function required = st_verify_results_required( ...
        verifyHarnessOutportsOnly, usableHarnessOutputCount)
%ST_VERIFY_RESULTS_REQUIRED Decide whether verify results must exist.
if ~(islogical(verifyHarnessOutportsOnly) && ...
        isscalar(verifyHarnessOutportsOnly))
    error('simtest:InvalidVerifyOutputPolicy', ...
        'VerifyHarnessOutportsOnly must be one logical value.');
end

count = double(usableHarnessOutputCount);
if ~isscalar(count) || ~isfinite(count) || count < 0 || mod(count, 1) ~= 0
    error('simtest:InvalidVerifyOutputCount', ...
        'Usable Harness output count must be one nonnegative integer.');
end

required = ~verifyHarnessOutportsOnly || count > 0;
end
