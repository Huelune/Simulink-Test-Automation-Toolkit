function count = st_apply_sldv_parameters(iteration, params, sourceIndex)
%ST_APPLY_SLDV_PARAMETERS Apply sldvsimdata values to one iteration.

if nargin < 3
    sourceIndex = NaN;
end

normalized = st_normalize_sldv_parameters(params, sourceIndex);
count = 0;
for i = 1:numel(normalized)
    if isempty(normalized(i).Source)
        setVariable(iteration, ...
            'Name', normalized(i).Name, ...
            'Value', normalized(i).Value);
    else
        setVariable(iteration, ...
            'Name', normalized(i).Name, ...
            'Value', normalized(i).Value, ...
            'Source', normalized(i).Source);
    end
    count = count + 1;
end
end
