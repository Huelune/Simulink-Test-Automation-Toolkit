function st_show_target_errors()
%ST_SHOW_TARGET_ERRORS Why targets failed in the latest runs, on one screen.
%
% For todo.md; it runs nothing and changes nothing.
%   1. Per target, the latest PER_CUT run's record: status, first and last
%      Test Manager outcome, run count, CVF and model cleanup status.
%   2. The ERROR lines of the latest step 1 run log, of the latest standalone
%      pipeline log and of the standalone bundle's own logs, as time, PER_CUT
%      order and error identifiers only (st_error_log_lines). The messages
%      name models, CUTs and paths, so they stay in the logs.
title = '대상 실패 이유 보기';
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
cfg = st_config();
st_log(cfg, 'INFO', 'Target errors view start');
lines = {sprintf('MATLAB %s | %s', version('-release'), title)};
try
    latest = jsondecode(fileread(cfg.PerCutLatestPointer));
    manifest = jsondecode(fileread(char(string(latest.Manifest))));
    targets = manifest.Targets;
    if iscell(targets), targets = [targets{:}]; end
    lines{end+1} = sprintf('1단계 실행 | 상태 %s | 대상 %d', value(manifest, 'Status'), numel(targets));
    for k = 1:numel(targets)
        t = targets(k);
        lines{end+1} = sprintf('대상 %s | %s | 처음 %s | 끝 %s | 실행 %s번 | CVF %s | 모델 정리 %s', ...
            value(t, 'No'), value(t, 'Status'), value(t, 'InitialOutcome'), value(t, 'FinalOutcome'), ...
            value(t, 'RunCount'), value(t, 'FilterGenerationStatus'), value(t, 'ModelCleanupStatus')); %#ok<AGROW>
    end
catch ME
    lines{end+1} = sprintf('1단계 기록 읽기 실패 | %s', ME.identifier);
end

logDir = fullfile(cfg.ResultDir, 'logs');
lines = [lines, log_section('1단계 로그 ERROR', newest(logDir, '*_st_run_from_harness.log'), 10)];
lines = [lines, log_section('3단계 로그 ERROR', ...
    newest(logDir, '*_st_run_standalone_coverage_pipeline.log'), 6)];
try
    standalone = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir, 'LATEST');
    files = dir(fullfile(cfg.StandaloneCoverageRootDir, char(string(standalone.PipelineId)), '**', '*.log'));
    files = files(~endsWith({files.name}, '.console.log'));
    text = strings(0, 1);
    for k = 1:numel(files)
        text = [text; read_lines(fullfile(files(k).folder, files(k).name))]; %#ok<AGROW>
    end
    lines = [lines, {sprintf('standalone 번들 로그 ERROR | 로그 파일 %d', numel(files))}, ...
        st_error_log_lines(text, 8)];
catch ME
    lines{end+1} = sprintf('standalone 번들 로그 읽기 실패 | %s', ME.identifier);
end
st_log(cfg, 'INFO', 'Target errors view end');
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end


function out = log_section(label, file, maxLines)
if isempty(file)
    out = {[label ' | 로그 없음']};
    return;
end
out = [{label}, st_error_log_lines(read_lines(file), maxLines)];
end


function file = newest(folder, pattern)
file = '';
listing = dir(fullfile(folder, pattern));
if isempty(listing), return; end
[~, at] = max([listing.datenum]);
file = fullfile(listing(at).folder, listing(at).name);
end


function text = read_lines(file)
text = splitlines(string(fileread(file, 'Encoding', 'UTF-8')));
end


function text = value(item, name)
% Record fields hold fixed words (PASS, EXCEPT, Passed, OK) and counts only.
text = '-';
if ~isfield(item, name), return; end
raw = item.(name);
if isnumeric(raw) || islogical(raw)
    if ~isempty(raw), text = num2str(raw(1)); end
elseif strlength(string(raw)) > 0
    text = char(string(raw));
end
end
