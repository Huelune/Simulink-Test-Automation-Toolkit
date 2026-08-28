function blockPath = st_find_assessment_block(harnessName)
%ST_FIND_ASSESSMENT_BLOCK Find the separate Test Assessment block.
% sltest.testsequence.find returns both Test Sequence and Test Assessment.

harnessName = char(harnessName);
blocks = sltest.testsequence.find;

if isempty(blocks)
    error('No Test Sequence/Test Assessment block found in loaded models.');
end

if isstring(blocks)
    blocks = cellstr(blocks);
elseif ischar(blocks)
    blocks = {blocks};
end

prefix = [harnessName '/'];
keep = false(size(blocks));
for i = 1:numel(blocks)
    keep(i) = strncmp(blocks{i}, prefix, length(prefix));
end
blocks = blocks(keep);

if isempty(blocks)
    error('No Test Sequence/Test Assessment block found in harness: %s', harnessName);
end

score = false(size(blocks));
for i = 1:numel(blocks)
    b = blocks{i};
    text = '';
    try
        text = [text ' ' get_param(b, 'Name')];
    catch
    end
    try
        text = [text ' ' get_param(b, 'ReferenceBlock')];
    catch
    end
    try
        text = [text ' ' get_param(b, 'MaskType')];
    catch
    end
    score(i) = ~isempty(strfind(lower(text), 'assessment')); %#ok<STREMP>
end

found = blocks(score);
if numel(found) ~= 1
    candidateText = strjoin(blocks, ', ');
    error('Could not identify exactly one Test Assessment block. Found=%d. Candidates: %s', ...
        numel(found), candidateText);
end

blockPath = found{1};
end
