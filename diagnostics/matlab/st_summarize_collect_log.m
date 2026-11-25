function info = st_summarize_collect_log(logFile, cfg)
%ST_SUMMARIZE_COLLECT_LOG Count what a PER_CUT collect log recorded, without names.
%
% info = st_summarize_collect_log(logFile, cfg)
%
% Reads one st_collect_per_cut_results log and returns text safe for a screen
% that leaves the company: counts and kinds, never a model name or a path.
%   Starts  targets the collect started
%   Copies  [CVF copies that found no file, CVF copies that found files]
%   Held    times another model held the Harness name, how it ended, and the
%           last such model's state
%   Loaded  times the collect loaded the Harness, and its own judgement of
%           the last one (a "no" here means the judgement is wrong)
info = struct('Starts', NaN, 'Copies', [NaN NaN], 'Held', "없음", 'Loaded', "-");
text = splitlines(string(fileread(logFile)));
copies = text(contains(text, "Portable coverage filter copy complete"));
info.Copies = [sum(contains(copies, "files=0")), sum(~contains(copies, "files=0"))];
% Target progress lines only; report steps log "[ResultReport 1/6] START" too.
info.Starts = sum(contains(text, regexpPattern("\[\s*\d+/\d+\] START")));

held = text(contains(text, "Harness name in use by another model"));
if ~isempty(held)
    outcome = "닫고 계속";
    if contains(held(end), "[ERROR]"), outcome = "멈춤"; end
    info.Held = sprintf("%d번(%s)", numel(held), outcome);
    tokens = regexp(char(held(end)), ...
        'IsHarness=(on|off|\?) \| OpenHarness=(\d) \| File=(.*)$', 'tokens', 'once');
    if ~isempty(tokens)
        info.Held = sprintf("%s, 마지막 IsHarness %s, 열린 Harness %s, 파일 %s", ...
            info.Held, tokens{1}, yes_no(tokens{2}), ...
            st_model_file_kind(strtrim(tokens{3}), cfg));
    end
end

loaded = text(contains(text, "Harness loaded for coverage"));
if ~isempty(loaded)
    info.Loaded = sprintf("%d번", numel(loaded));
    tokens = regexp(char(loaded(end)), ...
        'IsHarness=(on|off|\?) \| OpenHarness=(\d)', 'tokens', 'once');
    if ~isempty(tokens)
        info.Loaded = sprintf("%s, 마지막 IsHarness %s, 열린 Harness %s", ...
            info.Loaded, tokens{1}, yes_no(tokens{2}));
    end
end
end


function text = yes_no(flag)
text = "아님";
if strcmp(flag, '1'), text = "맞음"; end
end
