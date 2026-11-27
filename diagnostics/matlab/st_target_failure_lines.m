function lines = st_target_failure_lines(no, emptyFields, statuses, messages)
%ST_TARGET_FAILURE_LINES Screen lines for the Excel check before a run.
%
% lines = st_target_failure_lines(no, emptyFields, statuses, messages)
%
% no          target numbers (Excel No), n x 1
% emptyFields n x 3 logical: CUTName, HarnessName, TestCaseName left empty
% statuses    st_pre_validate_targets Status, n x 1
% messages    st_pre_validate_targets Message, n x 1
%
% One count line, then one line per kind of failure with its target
% numbers (at most 15, then the count of the rest), so a sheet with many
% bad rows still fits one screen. Messages carry paths, so only their kind
% is shown; an unknown message shows as 기타.
fields = ["CUTName", "HarnessName", "TestCaseName"];
count = numel(no);
kinds = strings(count, 1);
for k = 1:count
    if any(emptyFields(k, :))
        kinds(k) = strjoin(fields(emptyFields(k, :)), "·") + " 빈 칸";
    elseif string(statuses(k)) ~= "OK"
        kinds(k) = message_kind(string(messages(k)));
    end
end
bad = kinds ~= "";
lines = {sprintf('Excel 검사 | 대상 %d | OK %d | 실패 %d', count, sum(~bad), sum(bad))};
for kind = unique(kinds(bad), 'stable')'
    numbers = double(no(kinds == kind));
    text = strjoin(string(numbers(1:min(15, end))), ', ');
    if numel(numbers) > 15, text = text + sprintf(' 외 %d개', numel(numbers) - 15); end
    lines{end+1} = char("  " + kind + " | 대상 " + text); %#ok<AGROW>
end
end


function kind = message_kind(message)
if startsWith(message, 'CUTPath is empty')
    kind = "CUTPath 빈 칸";
elseif startsWith(message, 'CUT block not found')
    kind = "CUT 블록 없음(경로 오타나 빠진 중간 Subsystem)";
elseif startsWith(message, 'Target exists but is not a Subsystem')
    kind = "Subsystem 아님(블록 종류 " + strtrim(extractAfter(message, 'BlockType=')) + ")";
else
    kind = "기타(경로 해석 실패)";
end
end
