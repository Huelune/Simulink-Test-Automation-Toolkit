function status = st_report_status(artifactStatuses)
%ST_REPORT_STATUS Resolve the bundle status without hiding partial output.

artifactStatuses = upper(string(artifactStatuses(:)));
if any(artifactStatuses == "FAIL")
    status = "PARTIAL";
else
    status = "OK";
end
end
