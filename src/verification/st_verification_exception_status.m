function status = st_verification_exception_status(exception)
%ST_VERIFICATION_EXCEPTION_STATUS Separate missing runtime capability from defects.

text = lower(string(exception.identifier) + " " + ...
    string(exception.message));
blockedPatterns = ["license", "checkout", "not installed", ...
    "undefined function", "unrecognized function", ...
    "requires simulink", "requires matlab", "missing product"];
if any(contains(text, blockedPatterns))
    status = 'BLOCKED';
else
    status = 'FAIL';
end
end
