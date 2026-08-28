function [R, Summary] = st_diagnose_assessment_port_mapping_range(startIndex, endIndex)
%ST_DIAGNOSE_ASSESSMENT_PORT_MAPPING_RANGE
% Diagnose Assessment input port mapping for a range of Targets rows.
%
% This function does NOT use Targets.No.
% startIndex/endIndex are positional rows in st_load_targets(false).
%
% Example:
%   [R, Summary] = ...
%       st_diagnose_assessment_port_mapping_range(10, 20);
%
% Notes:
%   - Disabled rows are included because st_load_targets(false) is used.
%   - Completely empty Excel rows are already removed by st_load_targets.
%   - Each selected row's CUTPath and HarnessName are used directly.
%   - The model/harness is not modified.
%
% Output:
%   R       : detailed port-by-port mapping for all selected Harnesses
%   Summary : one row per selected target

if nargin < 2
    error( ...
        ['Usage: st_diagnose_assessment_port_mapping_range(' ...
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

nTargets = height(T);

if endIndex > nTargets
    error( ...
        'endIndex=%d exceeds Targets row count=%d.', ...
        endIndex, ...
        nTargets);
end

selected = ...
    startIndex:endIndex;

detailParts = cell(numel(selected),1);

TargetIndex = zeros(numel(selected),1);
No = zeros(numel(selected),1);
CUTName = strings(numel(selected),1);
CUTPath = strings(numel(selected),1);
HarnessName = strings(numel(selected),1);
AssessmentInputCount = zeros(numel(selected),1);
ComparableCount = zeros(numel(selected),1);
SameSourceCount = zeros(numel(selected),1);
Result = strings(numel(selected),1);
Message = strings(numel(selected),1);

fprintf('\n');
fprintf('============================================\n');
fprintf('Assessment Port Mapping Range Diagnostic\n');
fprintf('Target rows : %d ~ %d\n', startIndex, endIndex);
fprintf('Total       : %d\n', numel(selected));
fprintf('============================================\n');

for k = 1:numel(selected)

    i = selected(k);

    TargetIndex(k) = i;
    No(k) = T.No(i);
    CUTName(k) = T.CUTName(i);
    CUTPath(k) = T.CUTPath(i);
    HarnessName(k) = T.HarnessName(i);

    fprintf('\n');
    fprintf('--------------------------------------------\n');
    fprintf('[%d/%d] TargetIndex=%d\n', k, numel(selected), i);
    fprintf('CUT     : %s\n', char(T.CUTName(i)));
    fprintf('Harness : %s\n', char(T.HarnessName(i)));
    fprintf('--------------------------------------------\n');

    try
        D = ...
            st_diagnose_assessment_port_mapping( ...
                T.CUTPath(i), ...
                T.HarnessName(i));

        if isempty(D)
            detailParts{k} = table();
            Result(k) = 'INCONCLUSIVE';
            Message(k) = 'No port rows returned';
            continue;
        end

        targetIndexCol = ...
            repmat(i, height(D), 1);

        noCol = ...
            repmat(T.No(i), height(D), 1);

        cutNameCol = ...
            repmat(T.CUTName(i), height(D), 1);

        cutPathCol = ...
            repmat(T.CUTPath(i), height(D), 1);

        harnessNameCol = ...
            repmat(T.HarnessName(i), height(D), 1);

        D = ...
            addvars( ...
                D, ...
                targetIndexCol, ...
                noCol, ...
                cutNameCol, ...
                cutPathCol, ...
                harnessNameCol, ...
                'Before', ...
                1, ...
                'NewVariableNames', { ...
                    'TargetIndex', ...
                    'No', ...
                    'CUTName', ...
                    'CUTPath', ...
                    'HarnessName'});

        detailParts{k} = D;

        AssessmentInputCount(k) = ...
            sum(strlength(D.AssessmentSymbol) > 0);

        ComparableCount(k) = ...
            sum(D.SourceComparable);

        SameSourceCount(k) = ...
            sum(D.SameSourcePort);

        if ComparableCount(k) == 0

            Result(k) = 'INCONCLUSIVE';
            Message(k) = ...
                'No source-port handles were comparable';

        elseif SameSourceCount(k) == ComparableCount(k) && ...
                AssessmentInputCount(k) == height(D)

            Result(k) = 'PASS';
            Message(k) = ...
                'All comparable same-number ports share the same source';

        else

            Result(k) = 'CHECK';
            Message(k) = ...
                'At least one same-number port did not share the same source';
        end

    catch ME

        detailParts{k} = table();
        Result(k) = 'FAIL';
        Message(k) = string(ME.message);

        fprintf('FAIL: %s\n', ME.message);
    end
end

nonEmpty = ...
    ~cellfun( ...
        @(x) isempty(x) || height(x) == 0, ...
        detailParts);

if any(nonEmpty)

    R = ...
        vertcat( ...
            detailParts{nonEmpty});

else

    R = table();
end

Summary = ...
    table( ...
        TargetIndex, ...
        No, ...
        CUTName, ...
        CUTPath, ...
        HarnessName, ...
        AssessmentInputCount, ...
        ComparableCount, ...
        SameSourceCount, ...
        Result, ...
        Message);

fprintf('\n');
fprintf('============================================\n');
fprintf('Range Diagnostic Summary\n');
fprintf('============================================\n');
disp(Summary);

fprintf('PASS         : %d\n', sum(strcmp(Result, 'PASS')));
fprintf('CHECK        : %d\n', sum(strcmp(Result, 'CHECK')));
fprintf('INCONCLUSIVE : %d\n', sum(strcmp(Result, 'INCONCLUSIVE')));
fprintf('FAIL         : %d\n', sum(strcmp(Result, 'FAIL')));
fprintf('============================================\n');

try
    st_write_result( ...
        'AssessmentPortMappingSummary', ...
        Summary);

    if ~isempty(R)
        st_write_result( ...
            'AssessmentPortMappingDetail', ...
            R);
    end
catch ME
    warning( ...
        'Diagnostic result write failed: %s', ...
        ME.message);
end

% Leave the selected top model in a stopped state.
st_force_model_stopped(cfg.TopModel);

end
