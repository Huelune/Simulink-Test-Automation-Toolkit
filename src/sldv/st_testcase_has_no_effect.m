function tf = st_testcase_has_no_effect(testCase)
%ST_TESTCASE_HAS_NO_EFFECT Interpret nested SLDV dataNoEffect values.
tf = false;
if ~isstruct(testCase) || ~isfield(testCase, 'dataNoEffect') || ...
        isempty(testCase.dataNoEffect)
    return;
end

[hasValue, allNoEffect] = summarize(testCase.dataNoEffect);
tf = hasValue && allNoEffect;
end

function [hasValue, allNoEffect] = summarize(value)
hasValue = false;
allNoEffect = true;
if isempty(value)
    return;
end

if iscell(value)
    for i = 1:numel(value)
        [childHasValue, childAllNoEffect] = summarize(value{i});
        hasValue = hasValue || childHasValue;
        if childHasValue
            allNoEffect = allNoEffect && childAllNoEffect;
        end
    end
    return;
end

if ~(islogical(value) || isnumeric(value))
    error('simtest:InvalidDataNoEffect', ...
        'dataNoEffect must contain only logical, numeric, cell, or empty values.');
end

hasValue = true;
allNoEffect = all(logical(value(:)));
end
