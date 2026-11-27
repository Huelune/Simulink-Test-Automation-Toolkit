function text = st_build_error_kind(ME)
%ST_BUILD_ERROR_KIND A Simulink build failure as cause identifiers and a kind, for a screen line.
%
% text = st_build_error_kind(ME)
%
% A build error's message is compiler output with paths, file and function
% names, so only two things are taken from it:
%   - the identifiers of the error and its causes, those of MathWorks
%     products as they are and any other as (다른 식별자);
%   - a kind found in the compiler text: path too long, no compiler, a
%     missing include file, an unresolved symbol at link, a C compile error,
%     else 기타.
% ME is an MException or a struct with identifier, message and cause.
public = ["Simulink", "MATLAB", "sltest", "Stateflow", "simtest", "sldv", "Slvnv", "RTW", ...
    "Coder", "coder", "SL", "sl", "Simscape", "slcoverage", "SimulinkFixedPoint", "SimulinkCoderApp"];
[ids, messages] = collect(ME);
shown = strings(0, 1);
for id = reshape(ids, 1, [])
    if strlength(id) == 0, continue; end
    if any(extractBefore(id + ":", ":") == public), shown(end+1, 1) = id; %#ok<AGROW>
    else, shown(end+1, 1) = "(다른 식별자)"; end %#ok<AGROW>
end
shown = unique(shown, 'stable');
combined = lower(strjoin(messages, newline));
if contains(combined, ["too long", "max_path", "path length"])
    kind = "경로 길이 초과";
elseif contains(combined, ["no supported compiler", "mex -setup", "compiler not found"])
    kind = "컴파일러 없음";
elseif contains(combined, ["cannot open include file", "c1083", "no such file or directory"])
    kind = "include 파일 없음";
elseif contains(combined, ["unresolved external", "undefined reference", "lnk2019", "lnk1120"])
    kind = "링크 실패(정의 없는 함수)";
elseif ~isempty(regexp(combined, 'error c\d{4}', 'once'))
    kind = "C 컴파일 오류";
else
    kind = "기타";
end
text = char("식별자 " + strjoin(shown', ", ") + " | 종류 " + kind);
end


function [ids, messages] = collect(ME)
ids = string(ME.identifier);
messages = string(ME.message);
causes = {};
if isfield(ME, 'cause') || isprop(ME, 'cause'), causes = ME.cause; end
for k = 1:numel(causes)
    [childIds, childMessages] = collect(causes{k});
    ids = [ids; childIds]; %#ok<AGROW>
    messages = [messages; childMessages]; %#ok<AGROW>
end
end
