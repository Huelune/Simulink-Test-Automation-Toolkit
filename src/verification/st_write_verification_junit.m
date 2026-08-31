function st_write_verification_junit(path, checks)
%ST_WRITE_VERIFICATION_JUNIT Write normalized checks as JUnit XML.

fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:VerificationJunitWriteFailed', ...
        'Cannot write JUnit XML: %s', path);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>

failureCount = sum(checks.Status == "FAIL");
skippedCount = sum(ismember(checks.Status, ["BLOCKED","SKIP"]));
fprintf(fileId, '<?xml version="1.0" encoding="UTF-8"?>\n');
fprintf(fileId, '<testsuites tests="%d" failures="%d" skipped="%d">\n', ...
    height(checks), failureCount, skippedCount);
fprintf(fileId, '  <testsuite name="SimulinkVerification" tests="%d" failures="%d" skipped="%d">\n', ...
    height(checks), failureCount, skippedCount);
for i = 1:height(checks)
    fprintf(fileId, '    <testcase classname="%s" name="%s" time="%.6f">\n', ...
        xml_text(checks.FeatureId(i)), xml_text(checks.CheckId(i)), ...
        checks.DurationSec(i));
    status = upper(string(checks.Status(i)));
    message = xml_text(checks.Message(i));
    if status == "FAIL"
        fprintf(fileId, '      <failure message="%s">%s</failure>\n', ...
            message, message);
    elseif ismember(status, ["BLOCKED","SKIP"])
        fprintf(fileId, '      <skipped message="%s"/>\n', message);
    elseif status == "WARN"
        fprintf(fileId, '      <system-out>WARN: %s</system-out>\n', message);
    end
    fprintf(fileId, '    </testcase>\n');
end
fprintf(fileId, '  </testsuite>\n</testsuites>\n');
end

function value = xml_text(value)
value = char(string(value));
value = strrep(value, '&', '&amp;');
value = strrep(value, '<', '&lt;');
value = strrep(value, '>', '&gt;');
value = strrep(value, '"', '&quot;');
value = strrep(value, '''', '&apos;');
end
