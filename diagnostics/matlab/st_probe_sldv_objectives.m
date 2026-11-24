function lines = st_probe_sldv_objectives(files)
%ST_PROBE_SLDV_OBJECTIVES Count SLDV decision objectives by status, name-free.
%
%   st_probe_sldv_objectives                 % every enabled target's SLDV data
%   lines = st_probe_sldv_objectives({file1, file2})
%
% The unreachable-outcome defect TC reads sldvData.Objectives and the
% ModelObjects entry each objective points at. Before that is built, this
% shows what real data looks like:
%
%   대상 1 | 결정 목표 12 | Satisfied 8 | Unsatisfiable 1 | 근사 1 | Undecided 1 | 기타 1 (Excluded)
%   Objectives 필드: ...            (first readable file)
%   ModelObjects 필드: ...
%   ModelInformation 필드: ...
%   경로 구조 | 첫 요소=분석 모델 예(5/5) | 둘째 요소=CUT 예(5/5) | ...
%
% Counts are over objectives whose type is Decision; 기타 lists its distinct
% status texts (fixed MathWorks values). In the last line, over
% every ModelObjects.slPath of every file read:
%   첫 요소=분석 모델     the first element is ModelInformation.Name
%   둘째 요소=CUT         the second element is the CUT name (the target
%                         row's, or the last element of SubsystemPath)
%   SubsystemPath로 시작  slPath starts with ModelInformation.SubsystemPath/
%   designSid             files whose ModelObjects has a designSid field
% 모름 means the reference was missing. Paths are compared here and never
% printed, so the screen can leave the company. Targets with SldvMode OFF
% or a MAT data file are only counted. A failure prints its identifier, or
% for a toolkit error without one a fixed kind and what to do; never the
% message, which holds paths. Nothing is changed or saved.

cfg = [];
configError = [];
try, cfg = st_config(); catch configError, end
if isstruct(cfg)
    % DEBUG lines carry paths, and this screen leaves the company.
    cfg.ConsoleLogLevel = 'STEP';
end
log_line(cfg, 'INFO', 'SLDV objective probe start | FilesGiven=%d', nargin >= 1);
lines = {};
skipped = 0;
if nargin < 1 || isempty(files)
    if isempty(cfg)
        lines = {['툴킷 설정 읽기 실패 | ' kind_text(configError)]};
    elseif ~isfile(cfg.SldvManifestFile)
        lines = {'SLDV manifest 없음: SLDV 준비 단계를 먼저 돌려 주세요'};
        log_line(cfg, 'WARN', 'SLDV objective probe stopped: the SLDV manifest is missing');
    end
    if ~isempty(lines)
        fprintf('%s\n', lines{1});
        return;
    end
    [targets, skipped, lines] = target_files(cfg);
else
    files = cellstr(string(files));
    targets = struct('Index', num2cell(1:numel(files)), ...
        'File', reshape(files, 1, []), 'CUTName', {''});
end

fieldLines = {};
shape = struct('First', [0 0], 'Second', [0 0], 'Prefix', [0 0], 'DesignSid', [0 0]);
for t = 1:numel(targets)
    try
        loaded = load(targets(t).File, 'sldvData');
        data = loaded.sldvData;
        lines{end+1} = count_line(targets(t).Index, data.Objectives); %#ok<AGROW>
    catch readError
        lines{end+1} = sprintf('대상 %d | 읽기 실패 | %s', ...
            targets(t).Index, kind_text(readError)); %#ok<AGROW>
        log_failure(cfg, 'could not read a data file', targets(t).Index, readError);
        continue;
    end
    if isempty(fieldLines)
        fieldLines = {field_line(data, 'Objectives'), field_line(data, 'ModelObjects'), ...
            field_line(data, 'ModelInformation')};
    end
    shape = add_shape(shape, data, targets(t).CUTName);
end
if isempty(targets)
    lines{end+1} = 'SLDV 데이터 파일 0';
end
if skipped > 0
    lines{end+1} = sprintf('건너뜀 %d (SldvMode OFF 또는 MAT 데이터)', skipped);
end
if ~isempty(fieldLines)
    lines = [lines, fieldLines, {shape_line(shape)}];
end
for k = 1:numel(lines)
    fprintf('%s\n', lines{k});
end
log_line(cfg, 'INFO', 'SLDV objective probe end | Files=%d | Skipped=%d | Lines=%d', ...
    numel(targets), skipped, numel(lines));
end


function [targets, skipped, lines] = target_files(cfg)
%TARGET_FILES The SLDV data file of every enabled target that has one.
targets = struct('Index', {}, 'File', {}, 'CUTName', {});
skipped = 0;
lines = {};
try
    rows = st_load_targets(true);
catch loadError
    lines{end+1} = ['대상 목록 읽기 실패 | ' kind_text(loadError)];
    log_failure(cfg, 'could not load targets', 0, loadError);
    return;
end
for k = 1:height(rows)
    try
        profile = st_get_sldv_profile(rows(k,:), cfg);
    catch profileError
        lines{end+1} = sprintf('대상 %d | SLDV 프로필 실패 | %s', ...
            k, kind_text(profileError)); %#ok<AGROW>
        log_failure(cfg, 'skipped a target', k, profileError);
        continue;
    end
    if strcmp(profile.Mode, 'OFF') || ~strcmp(profile.DataFileFormat, 'SLDV')
        skipped = skipped + 1;
        continue;
    end
    targets(end+1) = struct('Index', k, 'File', profile.EffectiveDataFile, ...
        'CUTName', profile.CUTName); %#ok<AGROW>
end
end


function text = count_line(index, objectives)
types = string({objectives.type});
statuses = strtrim(string({objectives(strcmpi(types, 'Decision')).status}));
unsatisfiable = statuses == "Unsatisfiable";
approximate = startsWith(statuses, "Unsatisfiable") & ...
    contains(statuses, "approximation", 'IgnoreCase', true);
undecided = startsWith(statuses, "Undecided", 'IgnoreCase', true);
satisfied = startsWith(statuses, "Satisfied", 'IgnoreCase', true);
other = ~(unsatisfiable | approximate | undecided | satisfied);
text = sprintf(['대상 %d | 결정 목표 %d | Satisfied %d | Unsatisfiable %d | ' ...
    '근사 %d | Undecided %d | 기타 %d'], index, numel(statuses), sum(satisfied), ...
    sum(unsatisfiable), sum(approximate), sum(undecided), sum(other));
if any(other)
    text = sprintf('%s (%s)', text, char(strjoin(unique(statuses(other)), ', ')));
end
end


function text = field_line(data, name)
if isfield(data, name) && isstruct(data.(name))
    text = sprintf('%s 필드: %s', name, strjoin(reshape(fieldnames(data.(name)), 1, []), ', '));
else
    text = sprintf('%s 필드: (없음)', name);
end
end


function shape = add_shape(shape, data, cutName)
%ADD_SHAPE Add one file's slPath comparisons as [matches, compared] pairs.
info = struct();
if isfield(data, 'ModelInformation'), info = data.ModelInformation; end
analysis = text_field(info, 'Name');
subsystem = text_field(info, 'SubsystemPath');
if isempty(cutName) && ~isempty(subsystem)
    parts = path_parts(subsystem);
    cutName = parts{end};
end
objects = struct([]);
if isfield(data, 'ModelObjects'), objects = data.ModelObjects; end
shape.DesignSid = shape.DesignSid + [isfield(objects, 'designSid'), 1];
if ~isfield(objects, 'slPath'), return; end
for k = 1:numel(objects)
    value = objects(k).slPath;
    if ~(ischar(value) || (isstring(value) && isscalar(value))) || isempty(char(value))
        continue;
    end
    value = char(value);
    parts = path_parts(value);
    if ~isempty(analysis)
        shape.First = shape.First + [strcmp(parts{1}, analysis), 1];
    end
    if ~isempty(cutName)
        shape.Second = shape.Second + [numel(parts) >= 2 && strcmp(parts{2}, cutName), 1];
    end
    if ~isempty(subsystem)
        shape.Prefix = shape.Prefix + [startsWith(value, [subsystem '/']), 1];
    end
end
end


function text = shape_line(shape)
text = sprintf('경로 구조 | 첫 요소=분석 모델 %s | 둘째 요소=CUT %s | SubsystemPath로 시작 %s | designSid %s', ...
    ratio(shape.First), ratio(shape.Second), ratio(shape.Prefix), ratio(shape.DesignSid));
end


function text = ratio(pair)
if pair(2) == 0
    text = '모름';
    return;
end
word = '아니오';
if pair(1) == pair(2), word = '예'; end
text = sprintf('%s(%d/%d)', word, pair(1), pair(2));
end


function parts = path_parts(value)
% A '/' inside a block name is written '//' in a Simulink path.
parts = regexp(char(value), '(?<!/)/(?!/)', 'split');
end


function text = text_field(s, name)
text = '';
if isstruct(s) && isscalar(s) && isfield(s, name)
    try, text = strtrim(char(string(s.(name)))); catch, end
end
end


function text = kind_text(err)
%KIND_TEXT The identifier, or for a toolkit error without one a fixed kind
% and what to do, matched on the start of its fixed message text.
if ~isempty(err.identifier)
    text = ['식별자 ' err.identifier];
    return;
end
kinds = {
    'SLDV manifest is missing', 'SLDV manifest 없음: SLDV 준비 단계를 먼저 돌려 주세요'
    'SLDV manifest is invalid', 'SLDV manifest가 다른 모델 것이거나 깨짐: SLDV 준비 단계를 다시 돌려 주세요'
    'SLDV target preparation was not successful', 'SLDV 준비가 실패한 대상: SLDV 준비 단계 결과를 보세요'
    'Prepared FILE/SLDV data file is missing', 'SLDV 데이터 파일 없음: SLDV 준비 단계를 다시 돌려 주세요'
    'Management Excel not found', '관리 Excel 없음: 대상 모델을 다시 고르세요'
    'Targets sheet is empty', 'Targets 시트가 비어 있음'
    'Required Excel column not found', 'Targets 시트에 필수 열 없음'};
text = '식별자 없는 오류(분류 밖): 로그 파일을 보세요';
for k = 1:size(kinds, 1)
    if startsWith(err.message, kinds{k, 1})
        text = kinds{k, 2};
        return;
    end
end
end


function log_failure(cfg, what, index, err)
% WARN reaches the screen, so it carries the identifier only; the message,
% which holds paths, goes to the log file at DEBUG.
log_line(cfg, 'WARN', 'SLDV objective probe %s | Target=%d | Id=%s', what, index, err.identifier);
log_line(cfg, 'DEBUG', 'SLDV objective probe %s | Target=%d | %s', what, index, err.message);
end


function log_line(cfg, level, varargin)
if isempty(cfg), return; end
try, st_log(cfg, level, varargin{:}); catch, end
end
