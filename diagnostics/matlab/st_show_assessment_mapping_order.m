function [R, Summary] = st_show_assessment_mapping_order(startIndex, endIndex)
%ST_SHOW_ASSESSMENT_MAPPING_ORDER
% Show the proposed Assessment <-> CUT matching order for visual review.
%
% Proposed order:
%   1. CUT direct Inports, ascending Port number
%   2. CUT direct Outports, ascending Port number
%
% Assessment side:
%   Actual Test Assessment Input symbols, ascending Stateflow.Data.Port.
%
% This function DOES NOT decide whether the mapping is correct.
% It only places both sequences side-by-side so the user can review them.
%
% startIndex/endIndex are positional rows in st_load_targets(false).
% Targets.No is shown only for reference and is not used for selection.
%
% Example:
%   [R, Summary] = st_show_assessment_mapping_order(1, 10);
%
% Main preview columns:
%   Order
%   CompareSignalName
%   AssessmentPort
%   AssessmentSymbol
%
% The detailed return table R still keeps the diagnostic columns as well.
%
% PairState:
%   PAIR              : both sides have an item at this order
%   NO_ASSESSMENT     : proposed CUT item exists but Assessment item does not
%   NO_PROPOSED_CUT   : Assessment item exists but proposed CUT item does not
%
% No signal-name normalization is performed.

if nargin < 2
    error( ...
        ['Usage: st_show_assessment_mapping_order(' ...
         'startIndex, endIndex)']);
end

if ~isscalar(startIndex) || ...
        ~isscalar(endIndex) || ...
        ~isfinite(startIndex) || ...
        ~isfinite(endIndex) || ...
        startIndex < 1 || ...
        endIndex < startIndex || ...
        mod(startIndex,1) ~= 0 || ...
        mod(endIndex,1) ~= 0

    error('startIndex/endIndex must be positive integer row positions.');
end

cfg = st_require_runtime_target();
T = st_load_targets(false);

if endIndex > height(T)
    error( ...
        'endIndex=%d exceeds Targets row count=%d.', ...
        endIndex, ...
        height(T));
end

selected = startIndex:endIndex;

detailParts = cell(numel(selected),1);

TargetIndex = zeros(numel(selected),1);
No = zeros(numel(selected),1);
CUTName = strings(numel(selected),1);
CUTPath = strings(numel(selected),1);
HarnessName = strings(numel(selected),1);
AssessmentCount = zeros(numel(selected),1);
ProposedCUTCount = zeros(numel(selected),1);
CountMatch = false(numel(selected),1);
Status = strings(numel(selected),1);
Message = strings(numel(selected),1);

fprintf('\n');
fprintf('============================================\n');
fprintf('Assessment Mapping Order Preview\n');
fprintf('Rows  : %d ~ %d\n', startIndex, endIndex);
fprintf('Rule  : CUT INPUT ports first, then CUT OUTPUT ports\n');
fprintf('============================================\n');

for k = 1:numel(selected)

    i = selected(k);

    TargetIndex(k) = i;
    No(k) = T.No(i);
    CUTName(k) = T.CUTName(i);
    CUTPath(k) = T.CUTPath(i);
    HarnessName(k) = T.HarnessName(i);

    ownerPath = ...
        st_normalize_cut_path( ...
            T.CUTPath(i), ...
            cfg.TopModel);

    harnessName = ...
        char(T.HarnessName(i));

    fprintf('\n');
    fprintf('--------------------------------------------\n');
    fprintf('[%d/%d] TargetIndex=%d | No=%g\n', ...
        k, numel(selected), i, T.No(i));
    fprintf('CUT     : %s\n', char(T.CUTName(i)));
    fprintf('Path    : %s\n', ownerPath);
    fprintf('Harness : %s\n', harnessName);
    fprintf('--------------------------------------------\n');

    try
        st_force_model_stopped(cfg.TopModel);

        sltest.harness.load( ...
            ownerPath, ...
            harnessName);

        cleanupObj = ...
            onCleanup( ...
                @() st_close_harness_quiet( ...
                    ownerPath, ...
                    harnessName)); %#ok<NASGU>

        assess = ...
            st_find_assessment_block( ...
                harnessName);

        A = ...
            collect_assessment_inputs_by_port( ...
                assess);

        C = ...
            collect_proposed_cut_order( ...
                ownerPath);

        AssessmentCount(k) = height(A);
        ProposedCUTCount(k) = height(C);
        CountMatch(k) = height(A) == height(C);

        rowCount = max(height(A), height(C));

        Order = (1:rowCount).';
        AssessmentPort = nan(rowCount,1);
        AssessmentSymbol = strings(rowCount,1);
        ProposedCUTSide = strings(rowCount,1);
        ProposedCUTPort = nan(rowCount,1);
        CUTPortBlockName = strings(rowCount,1);
        CUTExternalLineName = strings(rowCount,1);
        CompareSignalName = strings(rowCount,1);
        PairState = strings(rowCount,1);

        if height(A) > 0
            AssessmentPort(1:height(A)) = A.AssessmentPort;
            AssessmentSymbol(1:height(A)) = A.AssessmentSymbol;
        end

        if height(C) > 0
            ProposedCUTSide(1:height(C)) = C.ProposedCUTSide;
            ProposedCUTPort(1:height(C)) = C.ProposedCUTPort;
            CUTPortBlockName(1:height(C)) = C.CUTPortBlockName;
            CUTExternalLineName(1:height(C)) = C.CUTExternalLineName;

            % The CUT direct Inport/Outport block name is the primary
            % comparison signal name. If it is empty, fall back to the
            % external line name around the CUT.
            CompareSignalName(1:height(C)) = C.CUTPortBlockName;

            emptyName = ...
                strlength(CompareSignalName(1:height(C))) == 0;

            compareIdx = ...
                find(emptyName);

            if ~isempty(compareIdx)
                CompareSignalName(compareIdx) = ...
                    C.CUTExternalLineName(compareIdx);
            end
        end

        for r = 1:rowCount
            hasAssessment = r <= height(A);
            hasCUT = r <= height(C);

            if hasAssessment && hasCUT
                PairState(r) = 'PAIR';
            elseif hasCUT
                PairState(r) = 'NO_ASSESSMENT';
            else
                PairState(r) = 'NO_PROPOSED_CUT';
            end
        end

        D = table( ...
            repmat(i, rowCount, 1), ...
            repmat(T.No(i), rowCount, 1), ...
            repmat(T.CUTName(i), rowCount, 1), ...
            repmat(T.CUTPath(i), rowCount, 1), ...
            repmat(T.HarnessName(i), rowCount, 1), ...
            Order, ...
            AssessmentPort, ...
            AssessmentSymbol, ...
            ProposedCUTSide, ...
            ProposedCUTPort, ...
            CUTPortBlockName, ...
            CUTExternalLineName, ...
            CompareSignalName, ...
            PairState, ...
            'VariableNames', { ...
                'TargetIndex', ...
                'No', ...
                'CUTName', ...
                'CUTPath', ...
                'HarnessName', ...
                'Order', ...
                'AssessmentPort', ...
                'AssessmentSymbol', ...
                'ProposedCUTSide', ...
                'ProposedCUTPort', ...
                'CUTPortBlockName', ...
                'CUTExternalLineName', ...
                'CompareSignalName', ...
                'PairState'});

        detailParts{k} = D;

        if CountMatch(k)
            Status(k) = 'OK';
            Message(k) = 'Counts match; review row order manually';
        else
            Status(k) = 'CHECK';
            Message(k) = sprintf( ...
                'Count mismatch: Assessment=%d, ProposedCUT=%d', ...
                height(A), ...
                height(C));
        end

        fprintf('\n');
        fprintf('--- Mapping Order Preview ---\n');

        disp(D(:, { ...
            'Order', ...
            'CompareSignalName', ...
            'AssessmentPort', ...
            'AssessmentSymbol'}));

        clear cleanupObj
        st_close_harness_quiet(ownerPath, harnessName);

    catch ME
        detailParts{k} = table();
        Status(k) = 'FAIL';
        Message(k) = string(ME.message);

        fprintf('FAIL: %s\n', ME.message);
    end
end

nonEmpty = ~cellfun( ...
    @(x) isempty(x) || height(x) == 0, ...
    detailParts);

if any(nonEmpty)
    R = vertcat(detailParts{nonEmpty});
else
    R = table();
end

Summary = table( ...
    TargetIndex, ...
    No, ...
    CUTName, ...
    CUTPath, ...
    HarnessName, ...
    AssessmentCount, ...
    ProposedCUTCount, ...
    CountMatch, ...
    Status, ...
    Message);

fprintf('\n');
fprintf('============================================\n');
fprintf('Mapping Order Summary\n');
fprintf('============================================\n');
disp(Summary);

try
    st_write_result( ...
        'AssessmentMappingOrderSummary', ...
        Summary);

    if ~isempty(R)
        st_write_result( ...
            'AssessmentMappingOrderDetail', ...
            R);
    end
catch ME
    warning( ...
        'Preview result write failed: %s', ...
        ME.message);
end

st_force_model_stopped(cfg.TopModel);

end


%% ============================================================
% Assessment Input Symbols, sorted by actual Stateflow.Data.Port
%% ============================================================

function A = collect_assessment_inputs_by_port(assessmentBlock)

dataObjects = find( ...
    sfroot, ...
    '-isa', ...
    'Stateflow.Data');

Port = [];
Symbol = strings(0,1);

for i = 1:numel(dataObjects)
    obj = dataObjects(i);

    try
        if ~strcmp(char(obj.Scope), 'Input')
            continue;
        end

        if ~strcmp(char(obj.Path), assessmentBlock)
            continue;
        end

        p = double(obj.Port);

        if isempty(p) || ...
                ~isscalar(p) || ...
                ~isfinite(p)
            continue;
        end

        Port(end+1,1) = p; %#ok<AGROW>
        Symbol(end+1,1) = string(obj.Name); %#ok<AGROW>

    catch
    end
end

if isempty(Port)
    error( ...
        'No Assessment Input symbols with usable Port values: %s', ...
        assessmentBlock);
end

[Port, idx] = sort(Port);
Symbol = Symbol(idx);

A = table( ...
    Port, ...
    Symbol, ...
    'VariableNames', { ...
        'AssessmentPort', ...
        'AssessmentSymbol'});

end


%% ============================================================
% Proposed CUT order:
% direct Inports ascending, then direct Outports ascending
%% ============================================================

function C = collect_proposed_cut_order(ownerPath)

inBlocks = find_system( ...
    ownerPath, ...
    'SearchDepth', 1, ...
    'Type', 'Block', ...
    'BlockType', 'Inport');

outBlocks = find_system( ...
    ownerPath, ...
    'SearchDepth', 1, ...
    'Type', 'Block', ...
    'BlockType', 'Outport');

[inBlocks, inPorts] = sort_port_blocks(inBlocks);
[outBlocks, outPorts] = sort_port_blocks(outBlocks);

nIn = numel(inBlocks);
nOut = numel(outBlocks);
n = nIn + nOut;

ProposedCUTSide = strings(n,1);
ProposedCUTPort = nan(n,1);
CUTPortBlockName = strings(n,1);
CUTExternalLineName = strings(n,1);

row = 0;

for i = 1:nIn
    row = row + 1;

    ProposedCUTSide(row) = 'INPUT';
    ProposedCUTPort(row) = inPorts(i);
    CUTPortBlockName(row) = string(get_param(inBlocks{i}, 'Name'));
    CUTExternalLineName(row) = ...
        get_owner_external_input_line_name( ...
            ownerPath, ...
            inPorts(i));
end

for i = 1:nOut
    row = row + 1;

    ProposedCUTSide(row) = 'OUTPUT';
    ProposedCUTPort(row) = outPorts(i);
    CUTPortBlockName(row) = string(get_param(outBlocks{i}, 'Name'));
    CUTExternalLineName(row) = ...
        get_owner_external_output_line_name( ...
            ownerPath, ...
            outPorts(i));
end

C = table( ...
    ProposedCUTSide, ...
    ProposedCUTPort, ...
    CUTPortBlockName, ...
    CUTExternalLineName);

end


function [blocks, ports] = sort_port_blocks(blocks)

n = numel(blocks);
ports = nan(n,1);

for i = 1:n
    ports(i) = str2double(get_param(blocks{i}, 'Port'));
end

[ports, idx] = sort(ports);
blocks = blocks(idx);

end


%% ============================================================
% External line names around the CUT block in the parent model
%% ============================================================

function name = get_owner_external_input_line_name(ownerPath, portNumber)

name = "";

try
    ph = get_param(ownerPath, 'PortHandles');

    if portNumber < 1 || ...
            portNumber > numel(ph.Inport)
        return;
    end

    lineHandle = get_param(ph.Inport(portNumber), 'Line');

    if isempty(lineHandle) || ...
            lineHandle == -1
        return;
    end

    name = string(get_param(lineHandle, 'Name'));

catch
end

end


function name = get_owner_external_output_line_name(ownerPath, portNumber)

name = "";

try
    ph = get_param(ownerPath, 'PortHandles');

    if portNumber < 1 || ...
            portNumber > numel(ph.Outport)
        return;
    end

    lineHandle = get_param(ph.Outport(portNumber), 'Line');

    if isempty(lineHandle) || ...
            lineHandle == -1
        return;
    end

    if numel(lineHandle) > 1
        lineHandle = lineHandle(1);
    end

    name = string(get_param(lineHandle, 'Name'));

catch
end

end


function st_close_harness_quiet(ownerPath, harnessName)

try
    sltest.harness.close( ...
        ownerPath, ...
        harnessName);
catch
end

end
