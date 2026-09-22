function [text, count, note] = st_specification_decision_blocks( ...
        cutPath, cfg, finder, nameReader, descriptorReader, catalogReader)
%ST_SPECIFICATION_DECISION_BLOCKS Export static control-decision candidates as JSON.
% Each JSON array item contains BlockType, the actual block Name, full
% Simulink Path, branch outcome kind, and saved-parameter expression.
% Only direct child blocks of the CUT are searched.
% This is a static inventory, not the number of compiled coverage objectives.
% The scanned block types and their outcome tokens come from
% st_specification_decision_catalog, which is the only place either is defined.
% Each seam accepts [] so a caller can override one of them and leave the
% rest at their defaults, which is how the export scope reaches the scan.
if nargin < 3 || isempty(finder)
    finder = @default_finder;
end
if nargin < 4 || isempty(nameReader)
    nameReader = @read_name;
end
if nargin < 5 || isempty(descriptorReader)
    descriptorReader = @st_specification_decision_descriptor;
end
if nargin < 6 || isempty(catalogReader)
    catalogReader = @st_specification_decision_catalog;
end
try
    catalog = catalogReader();
    blockTypes = string(catalog.BlockType);
    outcomeDefaults = string(catalog.Outcome);
    st_log(cfg, 'DEBUG', ...
        'Specification decision catalog loaded | Types=%d | Explicit=%d | Implicit=%d', ...
        numel(blockTypes), sum(string(catalog.Kind) == "EXPLICIT"), ...
        sum(string(catalog.Kind) == "IMPLICIT"));
catch ME
    st_log(cfg, 'WARN', 'Specification decision catalog unavailable | CUT=%s | %s', ...
        cutPath, ME.message);
    error('simtest:SpecificationDecisionCatalog', ...
        'Decision block catalog is unavailable: %s', ME.message);
end
% An empty catalog is the DecisionBlockScope=NONE view, not a fault.
if isempty(blockTypes)
    text = "[]";
    count = 0;
    note = "";
    st_log(cfg, 'INFO', ...
        'Specification decision block scan skipped | CUT=%s | Reason=NoBlockTypeInScope', ...
        cutPath);
    return;
end
% BlockType, Name, Path, Outcome, Expression, Status, Message, BranchOrder.
% BranchOrder is a sort key only; it is not written to the JSON.
records = strings(0,8);
notes = strings(0,1);
st_log(cfg, 'INFO', 'Specification decision block scan start | CUT=%s | SearchDepth=1 | Types=%d', ...
    cutPath, numel(blockTypes));
for k = 1:numel(blockTypes)
    blockType = blockTypes(k);
    st_log(cfg, 'DEBUG', 'Specification decision block type scan start | CUT=%s | BlockType=%s | Outcome=%s', ...
        cutPath, blockType, outcomeDefaults(k));
    try
        paths = string(finder(char(cutPath), ...
            'SearchDepth', 1, 'Type', 'Block', 'BlockType', char(blockType)));
        paths = paths(:);
        paths = paths(strlength(paths) > 0);
        paths = unique(paths);
        typeRecords = strings(0,8);
        for n = 1:numel(paths)
            name = "";
            try
                name = string(nameReader(char(paths(n))));
                if ~isscalar(name) || ismissing(name) || strlength(name) == 0
                    error('simtest:SpecificationDecisionBlockName', ...
                        'Block Name must be one nonempty value.');
                end
            catch ME
                name = "";
                notes(end+1,1) = string(sprintf('%s Name: %s', paths(n), ME.message)); %#ok<AGROW>
                st_log(cfg, 'WARN', 'Specification decision block name read failed | Path=%s | %s', ...
                    paths(n), ME.message);
            end
            try
                [outcome, expression] = ...
                    descriptorReader(char(paths(n)), char(blockType));
                [outcome, expression] = normalize_branches( ...
                    outcome, expression, blockType, paths(n));
                status = repmat("OK", numel(expression), 1);
                message = strings(numel(expression), 1);
            catch ME
                outcome = outcomeDefaults(k);
                expression = "조건식 읽기 실패";
                status = "WARN";
                message = string(ME.message);
                notes(end+1,1) = string(sprintf('%s Expression: %s', ...
                    paths(n), ME.message)); %#ok<AGROW>
                st_log(cfg, 'WARN', ...
                    'Specification decision block expression read failed | Path=%s | BlockType=%s | Outcome=%s | %s', ...
                    paths(n), blockType, outcomeDefaults(k), ME.message);
            end
            % Column 8 keeps the branches of one block in the order the
            % descriptor produced them. unique and sortrows are lexicographic,
            % so without it an elseif could be numbered before its if.
            branches = numel(expression);
            branchOrder = compose("%03d", (1:branches).');
            typeRecords = [typeRecords; ...
                repmat(blockType, branches, 1) repmat(name, branches, 1) ...
                repmat(paths(n), branches, 1) outcome expression ...
                status message branchOrder]; %#ok<AGROW>
            if branches > 1
                st_log(cfg, 'DEBUG', ...
                    'Specification decision block branches expanded | Path=%s | BlockType=%s | Branches=%d', ...
                    paths(n), blockType, branches);
            end
        end
        records = [records; typeRecords]; %#ok<AGROW>
        st_log(cfg, 'DEBUG', 'Specification decision block type scan end | CUT=%s | BlockType=%s | Blocks=%d | Branches=%d', ...
            cutPath, blockType, numel(paths), size(typeRecords,1));
    catch ME
        message = string(sprintf('%s: %s', blockType, ME.message));
        notes(end+1,1) = message; %#ok<AGROW>
        st_log(cfg, 'WARN', 'Specification decision block type scan failed | CUT=%s | BlockType=%s | %s', ...
            cutPath, blockType, ME.message);
    end
end
if isempty(records)
    text = "[]";
    count = 0;
else
    records = unique(records, 'rows');
    records = sortrows(records, [3 1 8]);
    count = size(records,1);
    items = strings(count,1);
    for k = 1:count
        item = struct('BlockType', char(records(k,1)), ...
            'Name', char(records(k,2)), 'Path', char(records(k,3)), ...
            'Outcome', char(records(k,4)), ...
            'Expression', char(records(k,5)), ...
            'ExpressionStatus', char(records(k,6)), ...
            'Message', char(records(k,7)));
        items(k) = string(jsonencode(item));
    end
    text = "[" + newline + strjoin(items, "," + newline) + newline + "]";
end
note = strjoin(notes, ' | ');
st_log(cfg, 'INFO', 'Specification decision block scan end | CUT=%s | Count=%d | Warnings=%d', ...
    cutPath, count, numel(notes));
end

function name = read_name(path)
name = get_param(path, 'Name');
end

function [outcome, expression] = normalize_branches(outcome, expression, blockType, path)
% A descriptor may return one expression per branch. The outcome is the kind
% of branch, so a scalar outcome applies to every branch of the block.
outcome = string(outcome);
outcome = outcome(:);
expression = string(expression);
expression = expression(:);
if isempty(expression)
    error('simtest:SpecificationDecisionExpression', ...
        'Decision expression is empty: %s', path);
end
if isscalar(outcome) && numel(expression) > 1
    outcome = repmat(outcome, numel(expression), 1);
end
if numel(outcome) ~= numel(expression)
    error('simtest:SpecificationDecisionBranch', ...
        'Decision branch count mismatch for %s (%s): %d outcome(s), %d expression(s).', ...
        path, blockType, numel(outcome), numel(expression));
end
end


function paths = default_finder(root, varargin)
%DEFAULT_FINDER find_system, plus conditional subsystems by their port.
% An Enabled or Triggered Subsystem carries its branch on a port block one
% level inside it, so find_system at depth 1 never sees it. The branch
% belongs to the subsystem the CUT owns, and the subsystem is the name a
% reader recognises, so that is what gets reported.
index = find(strcmp(varargin, 'BlockType'), 1);
blockType = '';
if ~isempty(index) && index < numel(varargin)
    blockType = char(string(varargin{index + 1}));
end
if ~any(strcmp(blockType, {'EnablePort', 'TriggerPort'}))
    args = with_link_options(varargin);
    paths = find_system(root, args{:});
    return;
end
paths = st_conditional_subsystems(root, blockType);
end


function args = with_link_options(args)
% A CUT can be masked, or can sit inside a library link. find_system stops
% at either boundary by default and then reports no children at all, which
% is how a linked CUT once came to look as though it had no ports. The
% conditional subsystem scan and the coverage side already pass these, so
% this is also what makes the three scans agree.
if ~any(strcmp(args, 'LookUnderMasks'))
    args = [args, {'LookUnderMasks', 'all'}];
end
if ~any(strcmp(args, 'FollowLinks'))
    args = [args, {'FollowLinks', 'on'}];
end
end
