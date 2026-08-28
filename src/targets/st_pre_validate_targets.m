function R = st_pre_validate_targets()
%ST_PRE_VALIDATE_TARGETS Validate CUT paths before Harness creation.
%
% Checks only:
%   1. CUTPath is not empty.
%   2. CUTPath can be normalized against the selected runtime model.
%   3. The block exists.
%   4. The block is a Subsystem.
%
% Does NOT check:
%   - Harness existence
%   - Signal Editor
%   - Test Assessment
%   - Scenario
%   - Test Manager / Test Case

cfg = st_require_runtime_target();

T = st_load_targets( ...
    cfg.OnlyEnabled);

n = height(T);

if n == 0

    warning('No CUT rows to validate.');
    R = table();
    return;
end


InputCUTPath = strings(n,1);
NormalizedCUTPath = strings(n,1);
Status = strings(n,1);
Message = strings(n,1);
Timestamp = strings(n,1);


fprintf('\n');
fprintf('============================================\n');
fprintf('Pre-Validate CUT Paths\n');
fprintf('Model : %s\n', cfg.TopModel);
fprintf('Count : %d\n', n);
fprintf('============================================\n');


for i = 1:n

    rawPath = ...
        string(T.CUTPath(i));

    InputCUTPath(i) = ...
        rawPath;

    fprintf('\n[%d/%d] %s\n', ...
        i, ...
        n, ...
        char(T.CUTName(i)));

    fprintf('  Input Path : %s\n', ...
        char(rawPath));


    try

        if ismissing(rawPath) || ...
                strlength(strtrim(rawPath)) == 0

            error('CUTPath is empty.');
        end


        ownerPath = ...
            st_normalize_cut_path( ...
                rawPath, ...
                cfg.TopModel);

        NormalizedCUTPath(i) = ...
            string(ownerPath);

        fprintf('  Normalized : %s\n', ...
            ownerPath);


        blockHandle = ...
            getSimulinkBlockHandle( ...
                ownerPath);

        if blockHandle == -1

            error( ...
                'CUT block not found: %s', ...
                ownerPath);
        end


        blockType = ...
            get_param( ...
                blockHandle, ...
                'BlockType');

        if ~strcmp(blockType, 'SubSystem')

            error( ...
                ['Target exists but is not a Subsystem. ' ...
                 'BlockType=%s'], ...
                blockType);
        end


        Status(i) = ...
            'OK';

        Message(i) = ...
            'Valid CUT path';

        fprintf('  -> OK\n');


    catch ME

        Status(i) = ...
            'FAIL';

        Message(i) = ...
            string(ME.message);

        fprintf('  -> FAIL : %s\n', ...
            ME.message);
    end


    Timestamp(i) = ...
        string(datetime( ...
            'now', ...
            'Format', 'yyyy-MM-dd HH:mm:ss'));
end


R = table( ...
    T.No, ...
    T.CUTName, ...
    InputCUTPath, ...
    NormalizedCUTPath, ...
    Status, ...
    Message, ...
    Timestamp, ...
    'VariableNames', { ...
        'No', ...
        'CUTName', ...
        'InputCUTPath', ...
        'NormalizedCUTPath', ...
        'Status', ...
        'Message', ...
        'Timestamp'});


st_write_result( ...
    'PreValidationResult', ...
    R);


fprintf('\n');
fprintf('============================================\n');
fprintf('Pre-Validation Result\n');
fprintf('============================================\n');
fprintf('OK   : %d\n', sum(Status == 'OK'));
fprintf('FAIL : %d\n', sum(Status == 'FAIL'));
fprintf('Total: %d\n', n);
fprintf('============================================\n');

end
