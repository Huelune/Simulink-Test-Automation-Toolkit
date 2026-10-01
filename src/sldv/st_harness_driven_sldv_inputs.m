function names = st_harness_driven_sldv_inputs(ownerPath)
%ST_HARNESS_DRIVEN_SLDV_INPUTS SLDV inputs that the CUT's Harness drives itself.
%
% SLDV reports the call of a function-call CUT as a Dataset input named
% FcnTriggerPort. A Harness created with a scheduler block makes that call
% itself and has no such Signal Editor input, so st_select_sldv_input_indices
% drops the name instead of failing the target. Every other input missing
% from the Harness still fails.
%
% The Harness scheduler decides when the call happens, which need not be
% the steps the SLDV TestCase assumed.

names = cell(0,1);
triggers = find_system(ownerPath, ...
    'SearchDepth', 1, ...
    'FollowLinks', 'on', ...
    'LookUnderMasks', 'all', ...
    'BlockType', 'TriggerPort');
for i = 1:numel(triggers)
    if strcmpi(get_param(triggers{i}, 'TriggerType'), 'function-call')
        names = {'FcnTriggerPort'};
        return;
    end
end
end
