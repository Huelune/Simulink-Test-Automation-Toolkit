function [indices, isExplicit, normalizedText] = ...
        st_select_sldv_test_cases(selectionText, testCaseCount)
%ST_SELECT_SLDV_TEST_CASES Resolve the SldvTestCases cell to TestCase indices.
%
% [indices, isExplicit, normalizedText] = ...
%     st_select_sldv_test_cases(selectionText, testCaseCount)
%
% selectionText  Text of the Excel SldvTestCases cell. Empty means every
%                TestCase. Otherwise a list of 1-based TestCase numbers
%                separated by ',', ';' or whitespace. 'a-b' is an inclusive
%                range. Duplicates collapse and the result is sorted.
% testCaseCount  Number of TestCases in the sldvData. Omit (or pass Inf)
%                to validate only the text, e.g. while loading the workbook.
%
% indices        Column vector of selected 1-based TestCase numbers.
%                1:testCaseCount when selectionText is empty.
% isExplicit     true when the cell named specific TestCases.
% normalizedText '' for the whole set, otherwise the sorted unique numbers
%                joined by ','. Two cells naming the same set normalize to
%                the same text, so fingerprints and manifest lookups agree.

if nargin < 2 || isempty(testCaseCount)
    testCaseCount = Inf;
end

text = normalize_text(selectionText);
isExplicit = ~isempty(text);

if ~isExplicit
    normalizedText = '';
    if isfinite(testCaseCount)
        indices = (1:double(testCaseCount)).';
    else
        indices = zeros(0,1);
    end
    return;
end

tokens = regexp(text, '[,;\s]+', 'split');
tokens = tokens(~cellfun(@isempty, tokens));

indices = zeros(0,1);
for k = 1:numel(tokens)
    token = tokens{k};
    single = regexp(token, '^(\d+)$', 'tokens', 'once');
    range = regexp(token, '^(\d+)-(\d+)$', 'tokens', 'once');
    if ~isempty(single)
        first = str2double(single{1});
        last = first;
    elseif ~isempty(range)
        first = str2double(range{1});
        last = str2double(range{2});
    else
        error('simtest:InvalidSldvTestCases', ...
            ['SldvTestCases must list 1-based TestCase numbers such as ' ...
             '"1,3,5" or "2-4". Invalid token "%s" in "%s".'], token, text);
    end
    if first < 1 || last < 1
        error('simtest:InvalidSldvTestCases', ...
            'SldvTestCases numbers start at 1. Invalid token "%s" in "%s".', ...
            token, text);
    end
    if last < first
        error('simtest:InvalidSldvTestCases', ...
            ['SldvTestCases range must be ascending. ' ...
             'Invalid token "%s" in "%s".'], token, text);
    end
    indices = [indices; (first:last).']; %#ok<AGROW>
end

if isempty(indices)
    error('simtest:InvalidSldvTestCases', ...
        'SldvTestCases "%s" names no TestCase.', text);
end

indices = unique(indices);
normalizedText = char(strjoin(string(indices), ','));

if isfinite(testCaseCount)
    outOfRange = indices(indices > testCaseCount);
    if ~isempty(outOfRange)
        error('simtest:SldvTestCaseOutOfRange', ...
            ['SldvTestCases names TestCase [%s] but the SLDV data has ' ...
             'only %d TestCases.'], ...
            char(strjoin(string(outOfRange), ',')), testCaseCount);
    end
end

end


function text = normalize_text(value)
if isempty(value) || (isnumeric(value) && isscalar(value) && isnan(value))
    text = '';
    return;
end
value = string(value);
if ~isscalar(value)
    error('simtest:InvalidSldvTestCases', ...
        'SldvTestCases must be a single text value.');
end
if ismissing(value)
    text = '';
    return;
end
text = strtrim(char(value));
end
