function varargout = st_pre_validate_targets(varargin)
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
%
% Called directly it writes its own run log; called from the workflow it
% appends to the workflow's run log.

% max(nargout, 1) keeps a bare call showing its result table as ans.
[varargout{1:max(nargout, 1)}] = st_log_run(mfilename, ...
    @() pre_validate_body(varargin{:}));
end


function R = pre_validate_body()

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


st_log(cfg, 'INFO', 'Pre-Validate CUT Paths | Model=%s | Count=%d', ...
    cfg.TopModel, n);


for i = 1:n

    rawPath = ...
        string(T.CUTPath(i));

    InputCUTPath(i) = ...
        rawPath;

    st_log(cfg, 'DEBUG', ...
        '[PreValidate %d/%d] start | CUT=%s | Input=%s', ...
        i, n, char(T.CUTName(i)), char(rawPath));


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


    catch ME

        Status(i) = ...
            'FAIL';

        Message(i) = ...
            string(ME.message);
    end


    Timestamp(i) = ...
        string(datetime( ...
            'now', ...
            'Format', 'yyyy-MM-dd HH:mm:ss'));

    st_log_progress(cfg, i, n, Status(i), char(T.CUTName(i)), ...
        'Message', Message(i), 'Detail', char(NormalizedCUTPath(i)));
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

end
