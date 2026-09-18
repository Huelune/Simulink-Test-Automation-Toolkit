function status = st_combine_run_status(varargin)
%ST_COMBINE_RUN_STATUS Reduce stage statuses to the worst one observed.
%
% Severity order: NOT_RUN/SKIP < OK < PARTIAL < FAIL. PARTIAL never collapses
% into OK, so a run that updated some scenarios and failed others cannot be
% reported as a clean pass.

values = strings(0,1);
for i = 1:numel(varargin)
    values = [values; upper(string(varargin{i}(:)))]; %#ok<AGROW>
end

if isempty(values)
    status = 'NOT_RUN';
    return;
end

if any(values == "FAIL")
    status = 'FAIL';
elseif any(values == "PARTIAL")
    status = 'PARTIAL';
elseif any(values == "OK")
    status = 'OK';
elseif any(values == "SKIP")
    status = 'SKIP';
else
    status = 'NOT_RUN';
end
end
