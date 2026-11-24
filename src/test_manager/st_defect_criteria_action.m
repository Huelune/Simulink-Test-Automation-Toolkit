function action = st_defect_criteria_action(currentCallback, defects)
%ST_DEFECT_CRITERIA_ACTION What to do with a Test Case's Custom Criteria.
%
%   action = st_defect_criteria_action(currentCallback, defects)
%
% CURRENTCALLBACK is the Test Case's Custom Criteria text; DEFECTS is
% profile.DefectIterations. The toolkit owns a callback whose text starts
% with its marker (st_defect_criteria_script, any version) and nothing else:
%   defects, callback empty or the toolkit's   'SET'
%   no defects, the toolkit's callback         'CLEAR' (the model was fixed)
%   no defects, callback empty or hand-written 'NONE'
%   defects, hand-written callback             error simtest:DefectCriteriaForeign
% The error names no Test Case or callback text; the caller's row says which.

marker = '% simtest:unreachable-defect-criteria';
current = strtrim(char(string(currentCallback)));
own = startsWith(current, marker);
if isempty(defects)
    action = 'NONE';
    if own
        action = 'CLEAR';
    end
elseif isempty(current) || own
    action = 'SET';
else
    error('simtest:DefectCriteriaForeign', ...
        ['Test Case에 사람이 쓴 Custom Criteria가 있어 도달 불가 결함 판정을 쓰지 못했습니다. ' ...
        'Test Case의 Custom Criteria를 비우거나 cfg.UnreachableDefectTests=false로 두고 ' ...
        '다시 실행하세요.']);
end
end
