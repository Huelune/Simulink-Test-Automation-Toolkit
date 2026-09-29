function specs = st_collect_output_specs(T, modelName, cfg)
%ST_COLLECT_OUTPUT_SPECS Compile top model once and collect direct CUT Outports.
% This function is used only when cfg.VerifyAllAssessmentInputs is false.
% cfg is optional and only routes log output; without it messages still go
% to the console at the default level and to the active run log.

if nargin < 3
    cfg = [];
end
modelName = char(modelName);
if ~bdIsLoaded(modelName)
    load_system(modelName);
end

st_force_model_stopped(modelName);

n = height(T);
emptySignals = table(strings(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', {'Name','Port','Width'});

specs = repmat(struct( ...
    'CUTPath', '', ...
    'Signals', emptySignals, ...
    'Status', '', ...
    'Message', ''), n, 1);

st_log(cfg, 'INFO', 'Collect Output Specs | Model=%s | Count=%d', ...
    modelName, n);
st_log(cfg, 'DEBUG', '[Compile] start | Model=%s', modelName);
feval(modelName, [], [], [], 'compile');
cleanupObj = onCleanup(@() cleanup_compile(modelName)); %#ok<NASGU>
st_log(cfg, 'DEBUG', '[Compile] complete | Model=%s', modelName);

for i = 1:n
    cutPath = st_normalize_cut_path(T.CUTPath(i), modelName);
    specs(i).CUTPath = cutPath;

    try
        h = getSimulinkBlockHandle(cutPath);
        if h == -1
            error('CUT path not found: %s', cutPath);
        end
        if ~strcmp(get_param(h, 'BlockType'), 'SubSystem')
            error('CUT is not a SubSystem: %s', cutPath);
        end

        outports = find_system(cutPath, ...
            'SearchDepth', 1, ...
            'Type', 'Block', ...
            'BlockType', 'Outport');

        numOut = numel(outports);
        names = strings(numOut,1);
        ports = zeros(numOut,1);
        widths = zeros(numOut,1);

        for k = 1:numOut
            b = outports{k};
            names(k) = string(get_param(b, 'Name'));
            ports(k) = str2double(get_param(b, 'Port'));

            cpw = get_param(b, 'CompiledPortWidths');
            if ~isstruct(cpw) || ~isfield(cpw, 'Inport') || isempty(cpw.Inport)
                error('CompiledPortWidths unavailable: %s', b);
            end

            widths(k) = double(cpw.Inport(1));
            if isempty(widths(k)) || isnan(widths(k)) || widths(k) < 1
                error('Invalid compiled Outport width: %s', b);
            end
        end

        [ports, idx] = sort(ports);
        specs(i).Signals = table(names(idx), ports, widths(idx), ...
            'VariableNames', {'Name','Port','Width'});
        specs(i).Status = 'OK';
        specs(i).Message = sprintf('Outport %d', numOut);

    catch ME
        specs(i).Signals = emptySignals;
        specs(i).Status = 'FAIL';
        specs(i).Message = ME.message;
    end

    st_log_progress(cfg, i, n, specs(i).Status, char(T.CUTName(i)), ...
        'Message', specs(i).Message, 'Detail', cutPath);
end

st_log(cfg, 'DEBUG', '[Compile] terminate | Model=%s', modelName);
st_force_model_stopped(modelName);
st_log(cfg, 'DEBUG', '[SimulationStatus] %s', ...
    get_param(modelName, 'SimulationStatus'));

end

function cleanup_compile(modelName)
try
    st_force_model_stopped(modelName);
catch
end
end
