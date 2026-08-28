function R = st_validate_targets()
%ST_VALIDATE_TARGETS Validate CUT paths and existing harness mappings.
% No compilation is performed.

cfg = st_require_runtime_target();
T = st_load_targets(cfg.OnlyEnabled);
st_force_model_stopped(cfg.TopModel);

n = height(T);
NormalizedCUTPath = strings(n,1);
Status = strings(n,1);
Message = strings(n,1);

fprintf('\n=== Target validation (%d rows) ===\n', n);

for i = 1:n
    ownerPath = st_normalize_cut_path(T.CUTPath(i), cfg.TopModel);
    NormalizedCUTPath(i) = string(ownerPath);

    try
        if strlength(T.CUTName(i)) == 0
            error('CUTName is empty.');
        end
        if strlength(T.HarnessName(i)) == 0
            error('HarnessName is empty.');
        end
        if strlength(T.TestCaseName(i)) == 0
            error('TestCaseName is empty.');
        end

        h = getSimulinkBlockHandle(ownerPath);
        if h == -1
            error('CUT path not found: %s', ownerPath);
        end
        if ~strcmp(get_param(h, 'BlockType'), 'SubSystem')
            error('CUT is not a SubSystem: %s', ownerPath);
        end

        hInfo = sltest.harness.find(ownerPath, ...
            'SearchDepth', 0, ...
            'Name', char(T.HarnessName(i)));
        if isempty(hInfo)
            error('Harness not found for CUT: %s', char(T.HarnessName(i)));
        end

        Status(i) = 'OK';
        Message(i) = 'CUT and harness found';
        fprintf('[%d/%d] OK   %s -> %s\n', i, n, ownerPath, char(T.HarnessName(i)));
    catch ME
        Status(i) = 'FAIL';
        Message(i) = string(ME.message);
        fprintf('[%d/%d] FAIL %s\n', i, n, ME.message);
    end
end

R = table(T.No, T.CUTName, NormalizedCUTPath, T.HarnessName, ...
    T.TestCaseName, Status, Message, ...
    'VariableNames', {'No','CUTName','CUTPath','HarnessName','TestCaseName','Status','Message'});

st_write_result('ValidationResult', R);
end
