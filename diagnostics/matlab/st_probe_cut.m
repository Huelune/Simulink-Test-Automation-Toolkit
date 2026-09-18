function found = st_probe_cut(query, varargin)
%ST_PROBE_CUT Report whether a CUT exists, using Simulink's own resolver.
%
% found = st_probe_cut('A/B')
% found = st_probe_cut('TOP/X/A//B')
% found = st_probe_cut(["A/B" "Ctrl"])
% found = st_probe_cut(..., 'Model', 'TOP')
% found = st_probe_cut(..., 'Verbose', false)
%
% The probe answers one question only: does this CUT exist in the model?
% It never edits Excel, never saves the model, and never writes artifacts.
%
% Resolution is delegated to Simulink. The query text is never split on
% '/', so a block whose own name contains a slash is handled the same way
% Simulink handles it:
%
%   1. PATH  getSimulinkBlockHandle on the query as typed.
%   2. PATH  the same, with outer whitespace trimmed.
%   3. PATH  the same two candidates prefixed with the model name.
%   4. NAME  get_param(block,'Name') compared against the query. The Name
%            parameter returns the raw block name, so 'A/B' matches a block
%            actually named 'A/B'.
%
% Steps 1-3 accept Simulink path notation, where a slash inside a block
% name is written twice ('TOP/X/A//B'). Step 4 accepts the raw name as the
% Excel CUTName column stores it ('A/B').

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'Model', '', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(p, 'Verbose', true, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

verbose = p.Results.Verbose;
modelName = resolve_model(char(string(p.Results.Model)));

queries = string(query);
queries = queries(:);
found = false(numel(queries), 1);

blocks = find_system(modelName, ...
    'LookUnderMasks', 'all', ...
    'FollowLinks', 'off', ...
    'Type', 'Block');

if verbose
    fprintf('[CUT-PROBE] Model  : %s\n', modelName);
    fprintf('[CUT-PROBE] Blocks : %d\n', numel(blocks));
end

for i = 1:numel(queries)
    found(i) = probe_one(queries(i), modelName, blocks, verbose);
end

if nargout == 0
    clear found;
end

end


%% ============================================================
% One query
%% ============================================================

function tf = probe_one(queryText, modelName, blocks, verbose)

raw = char(queryText);

if verbose
    fprintf('[CUT-PROBE] ------------------------------------------\n');
    fprintf('[CUT-PROBE] Query  : "%s"\n', raw);
end

% Steps 1-3: let Simulink resolve the text as a block path.
candidates = { ...
    raw, ...
    strtrim(raw), ...
    [modelName '/' raw], ...
    [modelName '/' strtrim(raw)]};

for c = 1:numel(candidates)

    handle = block_handle(candidates{c});

    if handle ~= -1 && in_model(handle, modelName)

        tf = true;

        if verbose
            report_match(handle, 'PATH', 1, 1);
        end

        return;
    end
end

% Step 4: compare against the raw block name Simulink reports.
matches = [];

for b = 1:numel(blocks)

    if strcmp(get_param(blocks{b}, 'Name'), raw)
        matches(end+1, 1) = get_param(blocks{b}, 'Handle'); %#ok<AGROW>
    end
end

tf = ~isempty(matches);

if verbose

    if tf

        for m = 1:numel(matches)
            report_match(matches(m), 'NAME', m, numel(matches));
        end

    else
        fprintf('[CUT-PROBE] NOT FOUND\n');
        report_slash_hint(blocks);
    end
end

end


%% ============================================================
% Reporting
%% ============================================================

function report_match(handle, how, index, total)

if total > 1
    label = sprintf('FOUND via %s (%d/%d)', how, index, total);
else
    label = sprintf('FOUND via %s', how);
end

fprintf('[CUT-PROBE] %s\n', label);
fprintf('[CUT-PROBE]   CUTName   : %s\n', get_param(handle, 'Name'));
fprintf('[CUT-PROBE]   CUTPath   : %s\n', getfullname(handle));
fprintf('[CUT-PROBE]   BlockType : %s\n', block_type_text(handle));

if ~is_subsystem(handle)
    fprintf(['[CUT-PROBE]   NOTE      : not a SubSystem. ' ...
        'The toolkit only accepts SubSystem targets.\n']);
end

if total > 1 && index == total
    fprintf(['[CUT-PROBE]   NOTE      : the name is ambiguous. ' ...
        'Put the full CUTPath above into the Excel CUTPath column.\n']);
end

end


function report_slash_hint(blocks)
% List blocks whose own name contains a slash, so the caller can see the
% Simulink path notation the CUTPath column expects.

shown = 0;

for b = 1:numel(blocks)

    name = get_param(blocks{b}, 'Name');

    if ~contains(name, '/')
        continue;
    end

    if shown == 0
        fprintf(['[CUT-PROBE]   hint: blocks whose name contains ' ...
            '''/'' and the CUTPath they need:\n']);
    end

    shown = shown + 1;

    if shown > 20
        fprintf('[CUT-PROBE]     ... more omitted\n');
        return;
    end

    fprintf('[CUT-PROBE]     CUTName "%s" -> CUTPath "%s"\n', ...
        name, blocks{b});
end

if shown == 0
    fprintf('[CUT-PROBE]   hint: no block in this model has ''/'' in its name.\n');
end

end


%% ============================================================
% Helpers
%% ============================================================

function text = block_type_text(handle)

if strcmp(get_param(handle, 'Type'), 'block_diagram')
    text = '<model root>';
    return;
end

try
    text = get_param(handle, 'BlockType');
catch
    text = '<unknown>';
end

end


function tf = is_subsystem(handle)

tf = false;

if strcmp(get_param(handle, 'Type'), 'block_diagram')
    return;
end

try
    tf = strcmp(get_param(handle, 'BlockType'), 'SubSystem');
catch
    tf = false;
end

end


function tf = in_model(handle, modelName)
% Guard against a same-named block resolving inside another loaded model.

tf = false;

try
    tf = strcmp(get_param(bdroot(handle), 'Name'), modelName);
catch
    tf = false;
end

end


function handle = block_handle(candidate)

handle = -1;

if isempty(candidate)
    return;
end

try
    handle = getSimulinkBlockHandle(candidate);
catch
    handle = -1;
end

end


function modelName = resolve_model(requested)

if ~isempty(strtrim(requested))

    modelName = strtrim(requested);

    if ~bdIsLoaded(modelName)
        load_system(modelName);
    end

    return;
end

cfg = st_require_runtime_target();
modelName = cfg.TopModel;

end
