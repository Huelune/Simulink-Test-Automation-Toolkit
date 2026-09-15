function value = st_artifact_stem(testCaseName)
%ST_ARTIFACT_STEM Delivery artifact stem for one standalone target.
%
% The packaged folder, CVF, CVT and Coverage report all share this stem,
% and the checker recomputes it to verify the delivery. Deriving it in more
% than one place is how those names drift apart, so every producer and the
% checker call this function instead of assembling the string themselves.
%
% Prefixing is idempotent: a workbook that already carries UT_REQ_ does not
% become UT_REQ_UT_REQ_. The prefix goes on before the safe-name pass so the
% 80-character cap still bounds the whole stem under the Windows path limit.

value = char(string(testCaseName));
if ~startsWith(lower(string(value)), "ut_req_")
    value = ['UT_REQ_' value];
end
value = st_export_safe_name(value);
end
