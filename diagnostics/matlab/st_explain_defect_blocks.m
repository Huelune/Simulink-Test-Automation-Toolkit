function lines = st_explain_defect_blocks(maxLinesPerBlock)
%ST_EXPLAIN_DEFECT_BLOCKS Explain why each defect block's outcome is unreachable, name-free.
%
% lines = st_explain_defect_blocks()
% lines = st_explain_defect_blocks(maxLinesPerBlock)   % default 6
%
% For every defect iteration of every target (the final document's list,
% st_final_document_defects), finds the block in the CUT and prints the
% logic feeding it with st_explain_block_logic: constants as numbers,
% delays as D1, CUT inputs as In1 with their declared type and Min/Max.
% A condition that a constant, a delay or a range keeps one way is what
% SLDV proved. Block types, symbols and numbers only; nothing is saved.
if nargin < 1, maxLinesPerBlock = 6; end
title = '결함 블록 입력 보기';
cfg = st_config();
st_log(cfg, 'INFO', 'Defect block explain start');
lines = {};
try
    cfg = st_require_runtime_target();
    load_system(cfg.ModelFile);
    targets = st_load_targets(cfg.OnlyEnabled);
    defects = st_final_document_defects(cfg);
catch ME
    lines = show(title, {sprintf('준비 실패 | %s | 모델 고르기와 TestManagement.xlsx를 확인하세요', id_of(ME))});
    st_log(cfg, 'WARN', 'Defect block explain stopped | %s', ME.identifier);
    return;
end
if height(defects) == 0
    lines = show(title, {'결함 Iteration이 없습니다. 1단계(SLDV)를 돌린 결과가 있는지 확인하세요'});
    st_log(cfg, 'WARN', 'Defect block explain found no defects');
    return;
end
lines{end+1} = sprintf('결함 %d개 | 대상 %d개', height(defects), height(targets));
seen = cell(0, 2);   % {joined explanation, defect number} so a repeat prints one line
for k = 1:height(defects)
    no = find(string(targets.TestCaseName) == defects.TestCaseName(k), 1);
    head = sprintf('[%d] 대상 %s | %s', k, target_no(targets, no), char(defects.BlockType(k)));
    texts = st_short_outcome_text(split(defects.OutcomeTexts(k), "|"));
    head = sprintf('%s | 도달 불가 [%s]', head, char(strjoin(texts, "/")));
    if defects.Approximate(k), head = [head ' (근사)']; end
    try
        if isempty(no), error('st:defect:noTarget', 'no target'); end
        cut = st_normalize_cut_path(targets.CUTPath(no), cfg.TopModel);
        block = find_block(cut, defects.RelativePath(k));
        if isempty(block), error('st:defect:noBlock', 'no block'); end
        explained = {};
        evalc('explained = st_explain_block_logic(block, ''Boundary'', cut, ''MaxLines'', maxLinesPerBlock, ''ShowRanges'', true);');
        joined = strjoin(explained, newline);
        same = find(strcmp(seen(:, 1), joined), 1);
        if isempty(same)
            seen(end+1, :) = {joined, k}; %#ok<AGROW>
            lines = [lines, {head}, strcat({'  '}, explained)]; %#ok<AGROW>
        else
            lines{end+1} = sprintf('%s | 입력 로직 [%d]와 같음', head, seen{same, 2}); %#ok<AGROW>
        end
    catch ME
        lines = [lines, {[head ' | 읽기 실패 ' id_of(ME)]}]; %#ok<AGROW>
    end
end
lines{end+1} = '식의 In은 CUT 입력, D는 Delay 상태, T는 긴 식, P?는 값을 못 읽은 설정입니다';
lines = show(title, lines);
st_log(cfg, 'INFO', 'Defect block explain complete | defects=%d', height(defects));
end


function block = find_block(cut, relative)
% The defect's path is folded the way the outcome lookup folds it.
block = '';
target = strtrim(regexprep(string(relative), '\s+', ' '));
if target == "." || target == "", block = cut; return; end
found = find_system(cut, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Block');
for k = 1:numel(found)
    if st_cut_relative_path(found{k}, cut) == target
        block = found{k};
        return;
    end
end
end


function text = target_no(targets, no)
text = '?';
if ~isempty(no), text = num2str(double(targets.No(no))); end
end


function lines = show(title, lines)
clc;
lines = [{sprintf('MATLAB %s | %s', version('-release'), title)}, lines];
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
