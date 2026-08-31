function selection = st_normalize_stage_selection(T, selection)
%ST_NORMALIZE_STAGE_SELECTION Normalize optional workflow row selection.

n = height(T);
if nargin < 2 || isempty(selection)
    selection = struct( ...
        'Run', true(n,1), ...
        'Action', repmat("RUN", n, 1), ...
        'Reason', repmat("Direct stage call", n, 1));
    return;
end

required = {'Run','Action','Reason'};
for i = 1:numel(required)
    if ~isfield(selection, required{i})
        error('simtest:InvalidStageSelection', ...
            'Stage selection is missing %s.', required{i});
    end
end

selection.Run = logical(selection.Run(:));
selection.Action = string(selection.Action(:));
selection.Reason = string(selection.Reason(:));
if numel(selection.Run) ~= n || ...
        numel(selection.Action) ~= n || ...
        numel(selection.Reason) ~= n
    error('simtest:InvalidStageSelection', ...
        'Stage selection row count must match Targets.');
end
end
