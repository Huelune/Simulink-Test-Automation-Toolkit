function name = st_standalone_model_name(targetRow, phase)
%ST_STANDALONE_MODEL_NAME Return a deterministic collision-resistant name.

phase = lower(strtrim(char(string(phase))));
if ~ismember(phase, {'initial','final'})
    error('simtest:InvalidStandaloneModelPhase', ...
        'Standalone model phase must be INITIAL or FINAL.');
end

identity = struct( ...
    'No', double(targetRow.No), ...
    'CUTPath', char(string(targetRow.CUTPath)), ...
    'HarnessName', char(string(targetRow.HarnessName)), ...
    'TestCaseName', char(string(targetRow.TestCaseName)));
digest = st_hash_value(identity);
safe = matlab.lang.makeValidName( ...
    st_export_safe_name(char(string(targetRow.CUTName))));
if isempty(safe)
    safe = 'CUT';
end
suffix = sprintf('_%s_%s', digest(1:10), phase);
prefix = sprintf('sth_%03d_', round(double(targetRow.No)));
available = namelengthmax - numel(prefix) - numel(suffix);
if available < 1
    error('simtest:StandaloneModelNameLimit', ...
        'MATLAB namelengthmax is too small for standalone model names.');
end
safe = safe(1:min(numel(safe), available));
name = [prefix safe suffix];
if ~isvarname(name)
    error('simtest:StandaloneModelNameInvalid', ...
        'Generated standalone model name is invalid: %s', name);
end
end
