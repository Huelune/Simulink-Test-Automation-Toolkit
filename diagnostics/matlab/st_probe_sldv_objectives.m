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
%   대상 1 | 결정 목표 12 | Satisfied 9 | Unsatisfiable 1 | 근사 1 | Undecided 1 | 기타 0
%   Objectives 필드: ...            (first readable file)
%   ModelObjects 필드: ...
%   ModelInformation 필드: ...
%   경로 구조 | 첫 요소=분석 모델 예(5/5) | 둘째 요소=CUT 예(5/5) | ...
%
% Counts are over objectives whose type is Decision. In the last line, over
% every ModelObjects.slPath of every file read:
%   첫 요소=분석 모델     the first element is ModelInformation.Name
%   둘째 요소=CUT         the second element is the CUT name (the target
%                         row's, or the last element of SubsystemPath)
%   SubsystemPath로 시작  slPath starts with ModelInformation.SubsystemPath/
%   designSid             files whose ModelObjects has a designSid field
% 모름 means the reference was missing. Paths are compared here and never
% printed, so the screen can leave the company. Targets with SldvMode OFF
% or a MAT data file are only counted. Nothing is changed or saved.

cfg = [];
try, cfg = st_config(); catch, end
log_line(cfg, 'INFO', 'SLDV objective probe start | FilesGiven=%d', nargin >= 1);
lines = {};
skipped = 0;
if nargin < 1 || isempty(files)
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
        lines{end+1} = sprintf('대상 %d | 읽기 실패 | 식별자 %s', ...
            targets(t).Index, id_text(readError)); %#ok<AGROW>
        log_line(cfg, 'WARN', 'SLDV objective probe could not read a data file | Target=%d | Id=%s', ...
            targets(t).Index, id_text(readError));
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
    lines{end+1} = sprintf('대상 목록 읽기 실패 | 식별자 %s', id_text(loadError));
    log_line(cfg, 'WARN', 'SLDV objective probe could not load targets | Id=%s', id_text(loadError));
    return;
end
for k = 1:height(rows)
    try
        profile = st_get_sldv_profile(rows(k,:), cfg);
    catch profileError
        lines{end+1} = sprintf('대상 %d | SLDV 프로필 실패 | 식별자 %s', ...
            k, id_text(profileError)); %#ok<AGROW>
        log_line(cfg, 'WARN', 'SLDV objective probe skipped a target | Target=%d | Id=%s', ...
            k, id_text(profileError));
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
unsatisfiable = sum(statuses == "Unsatisfiable");
approximate = sum(startsWith(statuses, "Unsatisfiable") & ...
    contains(statuses, "approximation", 'IgnoreCase', true));
undecided = sum(startsWith(statuses, "Undecided", 'IgnoreCase', true));
satisfied = sum(startsWith(statuses, "Satisfied", 'IgnoreCase', true));
other = numel(statuses) - unsatisfiable - approximate - undecided - satisfied;
text = sprintf(['대상 %d | 결정 목표 %d | Satisfied %d | Unsatisfiable %d | ' ...
    '근사 %d | Undecided %d | 기타 %d'], index, numel(statuses), satisfied, ...
    unsatisfiable, approximate, undecided, other);
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


function text = id_text(err)
text = err.identifier;
if isempty(text), text = '없음'; end
end


function log_line(cfg, level, varargin)
if isempty(cfg), return; end
try, st_log(cfg, level, varargin{:}); catch, end
end
