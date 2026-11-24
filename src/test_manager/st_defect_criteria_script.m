function script = st_defect_criteria_script(defects)
%ST_DEFECT_CRITERIA_SCRIPT Custom Criteria callback that fails defect iterations.
%
%   script = st_defect_criteria_script(defects)
%
% DEFECTS is profile.DefectIterations. The returned char is the body Test
% Manager runs as customCriteria(test) for every iteration of the Test
% Case. Its first line is the marker st_defect_criteria_action looks for.
% It calls no toolkit function, because standalone bundles run it without
% the toolkit, and it stays ASCII: control and non-ASCII characters in
% names and the Korean message become char(N).
%
% An iteration is looked up by test.sltest_iterationName, then by
% test.TestResult.Name (which of the two holds the Iteration name is not
% verified). One whose name is not in the table passes untouched. For a
% defect iteration it reads that iteration's decision coverage
% (getCoverageResults(test.TestResult)) and finds the block through the
% harness, [test.sltest_bdroot '/' <CUT block name> '/' RelativePath];
% test.sltest_sut is the original model's subsystem, where decisioninfo
% finds nothing (runtime check 2026-11-24, R2025b). Each target outcome is
% matched to the block's coverage outcome whose text the SLDV outcome text
% contains, ignoring case and spacing:
%   one match         verifyGreaterThan(count, 0, '<BlockType> [<text>] 실행 횟수')
%   none or several   one block-level check that every outcome of the block
%                     ran at least once, naming those that did not
% SLDV outcome numbers are not used: their order against the coverage
% outcomes is unverified. Coverage or a block that cannot be read raises
% simtest:DefectCriteriaNoCoverage, so the iteration ends in an error, not
% in a failure.

defects = defects(:);
names = cell(numel(defects), 1);
paths = cell(numel(defects), 1);
types = cell(numel(defects), 1);
texts = cell(numel(defects), 1);
for k = 1:numel(defects)
    names{k} = ['    ' literal(defects(k).Name)];
    paths{k} = ['    ' literal(defects(k).RelativePath)];
    types{k} = ['    ' literal(defects(k).BlockType)];
    outcomes = defects(k).Outcomes(:);
    outcomeTexts = cell(1, numel(outcomes));
    for j = 1:numel(outcomes)
        outcomeTexts{j} = literal(outcomes(j).Text);
    end
    texts{k} = ['    {' strjoin(outcomeTexts, ', ') '}'];
end

code = [
    {'% simtest:unreachable-defect-criteria v1'
    '% Written by the Simulink test toolkit, which rewrites or clears it: change'
    '% the toolkit inputs, not this text. A defect iteration fails when the'
    '% decision outcome SLDV proved unreachable has no execution in its coverage.'
    '% Other iterations are left alone. Unreadable coverage is an error.'
    'dcNames = {'}
    names
    {'    };'
    'dcPaths = {'}
    paths
    {'    };'
    'dcTypes = {'}
    types
    {'    };'
    'dcTexts = {'}
    texts
    {'    };'
    '% The Korean for " execution count", as character codes to keep this text ASCII.'
    ['dcSuffix = ' literal(' 실행 횟수') ';']
    '% The iteration name: the criteria property first, then the result name.'
    'dcRow = [];'
    'try'
    '    dcRow = find(strcmp(dcNames, char(test.sltest_iterationName)), 1);'
    'catch'
    'end'
    'if isempty(dcRow)'
    '    try'
    '        dcRow = find(strcmp(dcNames, char(test.TestResult.Name)), 1);'
    '    catch'
    '    end'
    'end'
    'if ~isempty(dcRow)'
    '    dcCvd = {};'
    '    try'
    '        dcRaw = {getCoverageResults(test.TestResult)};'
    '        while ~isempty(dcRaw)'
    '            dcValue = dcRaw{1};'
    '            dcRaw(1) = [];'
    '            if iscell(dcValue)'
    '                dcRaw = [dcRaw, reshape(dcValue, 1, [])];'
    '            elseif isa(dcValue, ''cv.cvdatagroup'')'
    '                dcRaw{end + 1} = getAll(dcValue);'
    '            elseif isa(dcValue, ''cvdata'')'
    '                for dcK = 1:numel(dcValue)'
    '                    dcCvd{end + 1} = dcValue(dcK);'
    '                end'
    '            end'
    '        end'
    '    catch dcError'
    '        error(''simtest:DefectCriteriaNoCoverage'', [''Coverage of this iteration could not be read'' ...'
    '            '' | Id=%s | Record decision coverage and run again.''], dcError.identifier);'
    '    end'
    '    if isempty(dcCvd)'
    '        error(''simtest:DefectCriteriaNoCoverage'', [''This iteration has no coverage data'' ...'
    '            '' | Record decision coverage and run again.'']);'
    '    end'
    '    try'
    '        dcBlock = [char(test.sltest_bdroot) ''/'' ...'
    '            strrep(char(get_param(test.sltest_sut, ''Name'')), ''/'', ''//'') ''/'' dcPaths{dcRow}];'
    '    catch dcError'
    '        error(''simtest:DefectCriteriaNoCoverage'', [''The harness path of the %s block could not '' ...'
    '            ''be built | Id=%s''], dcTypes{dcRow}, dcError.identifier);'
    '    end'
    '    dcInfo = [];'
    '    dcLastId = ''none'';'
    '    for dcK = 1:numel(dcCvd)'
    '        try'
    '            [dcValues, dcFound] = decisioninfo(dcCvd{dcK}, dcBlock);'
    '            if ~isempty(dcValues)'
    '                dcInfo = dcFound;'
    '                break;'
    '            end'
    '        catch dcError'
    '            dcLastId = dcError.identifier;'
    '        end'
    '    end'
    '    if ~isstruct(dcInfo) || ~isfield(dcInfo, ''decision'') || isempty(dcInfo.decision)'
    '        error(''simtest:DefectCriteriaNoCoverage'', [''Coverage has no decision for the %s block'' ...'
    '            '' | Id=%s | Record decision coverage and check that the block still exists.''], ...'
    '            dcTypes{dcRow}, dcLastId);'
    '    end'
    '    dcOutcomes = {};'
    '    dcCounts = [];'
    '    try'
    '        for dcD = 1:numel(dcInfo.decision)'
    '            for dcO = 1:numel(dcInfo.decision(dcD).outcome)'
    '                dcOutcomes{end + 1} = char(dcInfo.decision(dcD).outcome(dcO).text);'
    '                dcCounts(end + 1) = double(dcInfo.decision(dcD).outcome(dcO).executionCount);'
    '            end'
    '        end'
    '    catch dcError'
    '        error(''simtest:DefectCriteriaNoCoverage'', [''Decision outcomes of the %s block could not '' ...'
    '            ''be read | Id=%s''], dcTypes{dcRow}, dcError.identifier);'
    '    end'
    '    if isempty(dcCounts)'
    '        error(''simtest:DefectCriteriaNoCoverage'', ''Coverage lists no outcome for the %s block.'', ...'
    '            dcTypes{dcRow});'
    '    end'
    '    dcKeys = regexprep(lower(strtrim(dcOutcomes)), ''\s+'', '' '');'
    '    dcBlockCheck = false;'
    '    for dcT = 1:numel(dcTexts{dcRow})'
    '        dcTarget = regexprep(lower(strtrim(dcTexts{dcRow}{dcT})), ''\s+'', '' '');'
    '        dcMatch = [];'
    '        for dcO = 1:numel(dcKeys)'
    '            if ~isempty(dcKeys{dcO}) && contains(dcTarget, dcKeys{dcO})'
    '                dcMatch(end + 1) = dcO;'
    '            end'
    '        end'
    '        if isscalar(dcMatch)'
    '            test.verifyGreaterThan(dcCounts(dcMatch), 0, ...'
    '                sprintf(''%s [%s]%s'', dcTypes{dcRow}, dcOutcomes{dcMatch}, dcSuffix));'
    '        else'
    '            dcBlockCheck = true;'
    '        end'
    '    end'
    '    if dcBlockCheck'
    '        test.verifyGreaterThan(min(dcCounts), 0, sprintf(''%s [%s]%s'', dcTypes{dcRow}, ...'
    '            strjoin(dcOutcomes(dcCounts == 0), '', ''), dcSuffix));'
    '    end'
    'end'}];
script = strjoin(code.', newline);
end


function code = literal(text)
%LITERAL MATLAB expression for TEXT that stays ASCII and on one line.
% A block name may hold a newline; it and any non-ASCII character become
% char(N) between quoted runs.
text = char(text);
plain = text >= 32 & text <= 126;
if all(plain)
    code = ['''' strrep(text, '''', '''''') ''''];
    return;
end
parts = {};
k = 1;
while k <= numel(text)
    if plain(k)
        last = k;
        while last < numel(text) && plain(last + 1)
            last = last + 1;
        end
        parts{end + 1} = ['''' strrep(text(k:last), '''', '''''') '''']; %#ok<AGROW>
        k = last + 1;
    else
        parts{end + 1} = sprintf('char(%d)', double(text(k))); %#ok<AGROW>
        k = k + 1;
    end
end
code = ['[' strjoin(parts, ' ') ']'];
end
