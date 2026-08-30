function status = st_verification_overall_status(checks)
%ST_VERIFICATION_OVERALL_STATUS Apply FAIL > BLOCKED > WARN > PASS.

if isempty(checks)
    status = "BLOCKED";
    return;
end
values = upper(string(checks.Status));
if any(values == "FAIL")
    status = "FAIL";
elseif any(values == "BLOCKED" & logical(checks.Required))
    status = "BLOCKED";
elseif any(values == "WARN") || any(values == "BLOCKED")
    status = "PASS_WITH_WARNINGS";
else
    status = "PASS";
end
end
