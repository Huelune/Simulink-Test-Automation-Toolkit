function taken = st_decision_outcome_taken(description)
%ST_DECISION_OUTCOME_TAKEN Execution count of every outcome, for a block that is not two-way.
% DESCRIPTION is the second output of decisioninfo for one block. TAKEN has
% one row per outcome of every decision: DecisionIndex, DecisionText,
% OutcomeText and Count. A MinMax, for example, gives "input 1 is the
% maximum" and "input 2 is the maximum" with how often each was taken.
%
% st_decision_outcome_counts covers the true/false blocks; this is for the
% rest, whose outcomes are not true/false, so the final document can show
% the outcomes a row's test took instead of a static [T/F]. An odd shape
% returns an empty table for the whole block.
taken = table(zeros(0,1), strings(0,1), strings(0,1), zeros(0,1), ...
    'VariableNames', {'DecisionIndex','DecisionText','OutcomeText','Count'});
if ~isstruct(description) || ~isscalar(description) || ...
        ~isfield(description, 'decision') || isempty(description.decision)
    return;
end
rows = taken;
decisions = description.decision;
for k = 1:numel(decisions)
    if ~isfield(decisions(k), 'outcome') || isempty(decisions(k).outcome)
        return;
    end
    decisionText = "";
    if isfield(decisions(k), 'text')
        value = string(decisions(k).text);
        if isscalar(value) && ~ismissing(value), decisionText = value; end
    end
    outcomes = decisions(k).outcome;
    for j = 1:numel(outcomes)
        text = string(outcomes(j).text);
        count = double(outcomes(j).executionCount);
        if ~isscalar(text) || ismissing(text) || ~isscalar(count) || ~isfinite(count)
            return;
        end
        rows(end+1, :) = {k, decisionText, strtrim(text), count}; %#ok<AGROW>
    end
end
taken = rows;
end
