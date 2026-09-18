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

if ~isempty(matches)

    tf = true;

    if verbose

        for m = 1:numel(matches)
            report_match(matches(m), 'NAME', m, numel(matches));
        end
    end

    return;
end

% Step 5: walk the query down the hierarchy, one level at a time, matching
% each remaining piece against the child names Simulink reports. This is
% what resolves a query that omitted the '//' escaping, and it also pins
% down the exact level where a path stops matching.
[handle, stoppedAt, stoppedRest] = resolve_by_children(raw, modelName);

tf = handle ~= -1;

if ~verbose
    return;
end

if tf

    report_match(handle, 'WALK', 1, 1);

    fprintf(['[CUT-PROBE]   NOTE      : the query did not resolve as ' ...
        'typed. Copy the CUTPath above into Excel.\n']);

    return;
end

fprintf('[CUT-PROBE] NOT FOUND\n');
report_walk_stop(stoppedAt, stoppedRest);
report_not_found(raw, modelName, blocks);

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


function [handle, stoppedAt, stoppedRest] = resolve_by_children(raw, modelName)
%RESOLVE_BY_CHILDREN Descend the hierarchy using the names Simulink reports.
%
% The query text is consumed piece by piece, but the pieces come from the
% actual child names rather than from splitting on '/'. A child whose own
% name contains a slash therefore consumes that slash, which is how a query
% written without the '//' escaping still lands on the right block.
%
% On failure, stoppedAt is the deepest block that did match and stoppedRest
% is the part of the query that no child could account for.

handle = -1;
stoppedAt = modelName;
stoppedRest = '';

remaining = strtrim(char(raw));

if isempty(remaining)
    return;
end

prefix = [modelName '/'];

if startsWith(remaining, prefix)
    remaining = remaining(numel(prefix) + 1:end);
elseif strcmp(remaining, modelName)
    return;
end

current = modelName;
maxDepth = 1000;

for depth = 1:maxDepth

    if isempty(remaining)
        handle = block_handle(current);
        return;
    end

    [childPaths, childNames] = child_blocks(current);

    if isempty(childPaths)
        stoppedAt = current;
        stoppedRest = remaining;
        return;
    end

    % Longest name first, so a child actually named 'A/B' is preferred over
    % a sibling named 'A' that would swallow only the first piece.
    [~, order] = sort(strlength(childNames), 'descend');

    consumed = '';
    nextPath = '';

    for k = reshape(order, 1, [])

        name = char(childNames(k));

        if strcmp(remaining, name)
            handle = block_handle(childPaths{k});
            return;
        end

        if startsWith(remaining, [name '/'])
            consumed = name;
            nextPath = childPaths{k};
            break;
        end
    end

    if isempty(nextPath)
        stoppedAt = current;
        stoppedRest = remaining;
        return;
    end

    current = nextPath;
    remaining = remaining(numel(consumed) + 2:end);
end

stoppedAt = current;
stoppedRest = remaining;

end


function [paths, names] = child_blocks(parentPath)

paths = find_system(parentPath, ...
    'SearchDepth', 1, ...
    'LookUnderMasks', 'all', ...
    'FollowLinks', 'off', ...
    'Type', 'Block');

paths = paths(~strcmp(paths, parentPath));
names = strings(numel(paths), 1);

for i = 1:numel(paths)
    names(i) = string(get_param(paths{i}, 'Name'));
end

end


function report_walk_stop(stoppedAt, stoppedRest)

if isempty(stoppedRest)
    return;
end

fprintf('[CUT-PROBE]   the path stops matching here:\n');
fprintf('[CUT-PROBE]     resolved  : %s\n', stoppedAt);
fprintf('[CUT-PROBE]     unmatched : %s\n', stoppedRest);

[~, names] = child_blocks(stoppedAt);

if isempty(names)
    fprintf('[CUT-PROBE]     this block has no children.\n');
    return;
end

names = sort(names);

fprintf('[CUT-PROBE]     children of the resolved block (%d):\n', ...
    numel(names));

for i = 1:min(numel(names), 40)
    fprintf('[CUT-PROBE]       %s\n', display_name(names(i)));
end

if numel(names) > 40
    fprintf('[CUT-PROBE]       ... %d more omitted\n', numel(names) - 40);
end

end


function text = display_name(name)
% Make a line break visible so it is not mistaken for a plain space.

text = replace(string(name), newline, '\n');

end


function report_not_found(raw, modelName, blocks)
% Narrow down why the query did not resolve. Each section answers one
% distinct cause, so a single run tells the caller which one applies.

names = block_names(blocks);
shown = 0;

% A. Same name except for letter case.
shown = shown + report_candidates( ...
    'same name, different letter case', blocks, ...
    strcmpi(names, raw) & ~strcmp(names, raw));

% B. Same name except for surrounding whitespace.
shown = shown + report_candidates( ...
    'same name, different surrounding whitespace', blocks, ...
    strcmp(strtrim(names), strtrim(string(raw))) & ~strcmp(names, raw));

% C. Name matches once line breaks are treated as spaces. Simulink keeps
%    the break inside the stored name, and it never survives an Excel cell.
%    Only report blocks that actually match the query this way, otherwise
%    every stock library block with a wrapped label shows up as noise.
shown = shown + report_candidates( ...
    'name matches only if line breaks are treated as spaces', blocks, ...
    contains(names, newline) & ...
    strcmpi(flatten_whitespace(names), flatten_whitespace(string(raw))));

% D. Partial name match, so a typo or a truncated entry is visible.
if strlength(string(raw)) > 0

    shown = shown + report_candidates( ...
        'name contains the query as a substring', blocks, ...
        contains(names, raw, 'IgnoreCase', true) & ~strcmpi(names, raw));
end

% E. Blocks whose own name contains a slash, with the CUTPath they need.
shown = shown + report_candidates( ...
    'name contains ''/'' (needs ''//'' in CUTPath)', blocks, ...
    contains(names, '/'));

if shown == 0
    fprintf(['[CUT-PROBE]   no block in this model resembles the query, ' ...
        'and no block name contains ''/''.\n']);
end

% F. Scope limits. The search above matches the toolkit: it does not follow
%    library links and does not descend into referenced models.
report_scope_limits(raw, modelName, blocks);

end


function count = report_candidates(label, blocks, mask)

hits = find(mask);
count = numel(hits);

if isempty(hits)
    return;
end

fprintf('[CUT-PROBE]   %s:\n', label);

for i = 1:min(numel(hits), 20)

    b = hits(i);

    fprintf('[CUT-PROBE]     CUTName "%s" -> CUTPath "%s"\n', ...
        get_param(blocks{b}, 'Name'), blocks{b});
end

if numel(hits) > 20
    fprintf('[CUT-PROBE]     ... %d more omitted\n', numel(hits) - 20);
end

end


function report_scope_limits(raw, modelName, blocks)

% Library links: the toolkit searches with FollowLinks off, so a CUT that
% only exists inside a linked block is invisible to it.
try

    linked = find_system(modelName, ...
        'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', ...
        'Type', 'Block');

    names = block_names(linked);
    hits = find(strcmp(names, raw));

    if ~isempty(hits) && numel(linked) > numel(blocks)

        fprintf(['[CUT-PROBE]   found only when following library ' ...
            'links (FollowLinks on):\n']);

        for i = 1:min(numel(hits), 20)
            fprintf('[CUT-PROBE]     %s\n', linked{hits(i)});
        end
    end

catch ME
    fprintf('[CUT-PROBE]   library-link search failed: %s\n', ME.message);
end

% Referenced models are separate block diagrams. find_system on this model
% never enters them, so the CUT must be probed against that model instead.
references = find_system(modelName, ...
    'LookUnderMasks', 'all', ...
    'FollowLinks', 'off', ...
    'BlockType', 'ModelReference');

if isempty(references)
    return;
end

fprintf(['[CUT-PROBE]   this model references other models, which are ' ...
    'outside the search above.\n']);

referenced = strings(0, 1);

for i = 1:numel(references)
    referenced(end+1, 1) = string(get_param(references{i}, 'ModelName')); %#ok<AGROW>
end

referenced = unique(referenced);

for i = 1:numel(referenced)
    fprintf('[CUT-PROBE]     retry: st_probe_cut(''%s'', ''Model'', ''%s'')\n', ...
        raw, referenced(i));
end

end


function value = flatten_whitespace(value)

value = regexprep(string(value), '\s+', ' ');
value = strtrim(value);

end


function names = block_names(blocks)

names = strings(numel(blocks), 1);

for b = 1:numel(blocks)
    names(b) = string(get_param(blocks{b}, 'Name'));
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
