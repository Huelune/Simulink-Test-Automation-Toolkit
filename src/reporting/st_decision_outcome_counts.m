function [counts, texts] = st_decision_outcome_counts(description)
%ST_DECISION_OUTCOME_COUNTS True and false execution counts per decision.
% DESCRIPTION is the second output of decisioninfo for one block. Row k of
% COUNTS is [TrueCount FalseCount] for description.decision(k), and TEXTS(k)
% is that decision's text.
%
% Only a block whose every decision has exactly the outcomes true and false
% is described. Anything else returns empty for the whole block: keeping
% the two-way decisions of a mixed block would shift the decision order
% the final document pairs its D lines with.
counts = zeros(0,2);
texts = strings(0,1);
if ~isstruct(description) || ~isscalar(description) || ...
        ~isfield(description, 'decision') || isempty(description.decision)
    return;
end
decisions = description.decision;
found = zeros(numel(decisions), 2);
names = strings(numel(decisions), 1);
for k = 1:numel(decisions)
    if ~isfield(decisions(k), 'outcome') || numel(decisions(k).outcome) ~= 2
        return;
    end
    outcomes = decisions(k).outcome;
    labels = lower(strtrim(string({outcomes.text})));
    t = find(labels == "true");
    f = find(labels == "false");
    if ~isscalar(t) || ~isscalar(f)
        return;
    end
    found(k,:) = [double(outcomes(t).executionCount), ...
        double(outcomes(f).executionCount)];
    if isfield(decisions(k), 'text')
        names(k) = string(decisions(k).text);
    end
end
counts = found;
texts = names;
end
