function specification = st_final_document_defect_rows(specification, details, defects, reasons, cfg)
%ST_FINAL_DOCUMENT_DEFECT_ROWS Rewrite the rows of the defect iterations.
% A defect iteration binds a copy of its source scenario, so the
% specification collector already gives it a row that repeats the source row. That row is
% found by test case name and iteration name, the key the verdict lookup
% uses, and rewritten as if the outcome SLDV found unreachable had run (the
% team's form; the verdict stays the run's, FAIL): Description keeps the
% whole D list and the defect's D line shows that outcome, and the expected
% result says that line runs at least once.
%
% DETAILS is the DecisionBlockDetails table of
% st_format_specification_decision_blocks, DEFECTS comes from
% st_final_document_defects and REASONS from st_read_defect_reasons.
% DefectCode ("", EXACT or APPROXIMATE) and DefectReason are appended for
% st_final_document_table, which uses them for the ID, the output value
% and the reason codes. Every other row is left as it was.
%
% A reason whose Block cell is filled is used only when that cell names the
% defect's block, by its path below the CUT or by its block type, spacing
% and case ignored. Otherwise the name now stands for another block (the
% scenarios or the defects changed), so the default sentence is used and a
% WARN gives the count.
count = height(specification);
code = strings(count, 1);
reason = strings(count, 1);
caseNames = text_column(specification, '테스트 케이스명');
iterations = text_column(specification, 'Iteration명');
catalog = st_specification_decision_catalog();
twoWayTypes = string(catalog.BlockType(string(catalog.TwoWay) == "YES"));
otherBlock = strings(0,1);
for k = 1:height(defects)
    defect = defects(k,:);
    defectCode = "EXACT";
    if defect.Approximate, defectCode = "APPROXIMATE"; end
    [defectReason, refused] = reason_text(reasons, defect, defectCode);
    if refused, otherBlock(end+1,1) = defect.Name; end %#ok<AGROW>
    for row = find(caseNames == defect.TestCaseName & iterations == defect.Name)'
        code(row) = defectCode;
        reason(row) = defectReason;
        [description, line] = defect_line(specification.DecisionBlocks(row), ...
            specification.CUTPath(row), row, details, defect, twoWayTypes);
        specification.DecisionBlocks(row) = description;
        specification.("verify 내용")(row) = line + "가 한 번 이상 실행된다";
    end
end
unknown = setdiff(reasons.TestName, defects.Name);
if ~isempty(unknown)
    % The names stay in the run log file; the console shows only the count.
    st_log(cfg, 'WARN', 'Defect reasons name no defect iteration | Names=%d | Ignored', ...
        numel(unknown));
    st_log(cfg, 'DEBUG', 'Defect reasons ignored | Names=%s', ...
        strjoin(reshape(unknown, 1, []), ', '));
end
if ~isempty(otherBlock)
    st_log(cfg, 'WARN', ['Defect reasons name another block | Reasons=%d | ' ...
        'Default reasons used | Check the Block column'], numel(otherBlock));
    st_log(cfg, 'DEBUG', 'Defect reasons for another block | Names=%s', ...
        strjoin(reshape(otherBlock, 1, []), ', '));
end
specification.DefectCode = code;
specification.DefectReason = reason;
st_log(cfg, 'INFO', 'Final document defect rows | Rows=%d | Defects=%d', ...
    sum(code ~= ""), height(defects));
end


function [description, line] = defect_line(description, cutPath, row, details, defect, twoWayTypes)
% The row keeps its whole D list. A block with exactly one D line in this
% row gets the unreachable outcome in that line's bracket; the other lines
% keep what the run took. A block that is not in the D list (inside a
% nested subsystem), or that has several D lines (If with elseif, Saturate)
% where the outcome cannot be tied to one line, gets a line of its own by
% its path below the CUT, after the list. LINE is the defect's line alone.
%
% Blocks are compared by their path below the CUT, folded the way the
% outcome lookup folds them (st_cut_relative_path): a default block name
% carries a newline, and a CUT name may end in a space.
texts = split(defect.OutcomeTexts, "|");
target = strtrim(regexprep(defect.RelativePath, '\s+', ' '));
rowDetails = details(details.TestSpecificationRow == string(row + 1), :);
match = false(height(rowDetails), 1);
for j = 1:height(rowDetails)
    match(j) = strlength(target) > 0 && ...
        st_cut_relative_path(rowDetails.Path(j), cutPath) == target;
end
decision = unique(rowDetails.Decision(match));
if ismissing(description), description = ""; end
if isscalar(decision)
    lines = split(description, newline);
    at = find(startsWith(lines, decision + " ["), 1);
    if ~isempty(at)
        parts = regexp(char(lines(at)), '^([^\[]*\[)[^\]]*(\].*)$', 'tokens', 'once');
        if ~isempty(parts)
            % SLDV's typeDesc need not be a Simulink BlockType; the D line's is.
            twoWay = any(twoWayTypes == rowDetails.BlockType(find(match, 1)));
            line = string(parts{1}) + outcome_label(texts, twoWay) + string(parts{2});
            lines(at) = line;
            description = strjoin(reshape(lines, 1, []), newline);
            return;
        end
    end
end
% The folded path keeps the line on one line.
line = defect.BlockType + " [" + outcome_label(texts, any(twoWayTypes == defect.BlockType)) + ...
    "] (" + target + ")";
if strlength(description) > 0
    description = description + newline + line;
else
    description = line;
end
end


function label = outcome_label(texts, twoWay)
% A true/false block reads like the rest of the D list ([T], [F]); any
% other block gets the short outcome text the D list uses ("u2").
labels = st_short_outcome_text(texts);
if twoWay
    lowered = lower(texts);
    labels(contains(lowered, "true")) = "T";
    labels(contains(lowered, "false")) = "F";
end
label = strjoin(reshape(labels, 1, []), "/");
end


function [text, refused] = reason_text(reasons, defect, code)
% REFUSED: the reason's Block cell names neither this block's path nor its
% type, so the sentence was written for another block.
at = find(reasons.TestName == defect.Name, 1);
refused = false;
if ~isempty(at)
    block = folded(reasons.Block(at));
    refused = block ~= "" && block ~= folded(defect.RelativePath) && ...
        block ~= folded(defect.BlockType);
end
if ~isempty(at) && ~refused
    text = reasons.Reason(at);
elseif code == "APPROXIMATE"
    text = "SLDV 근사 분석에서 실행할 수 없다고 판정함(확인 필요)";
else
    text = "SLDV가 어떤 입력으로도 실행할 수 없음을 증명함";
end
end


function text = folded(text)
text = lower(strtrim(regexprep(string(text), '\s+', ' ')));
end


function text = text_column(T, name)
text = string(T.(name));
text(ismissing(text)) = "";
end
