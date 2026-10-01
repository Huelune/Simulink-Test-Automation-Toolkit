function [selectedIndices, selectedNames, ignoredNames] = ...
        st_select_sldv_input_indices( ...
            datasetNames, harnessNames, ignoreUnexpected, harnessDrivenNames)
%ST_SELECT_SLDV_INPUT_INDICES Select SLDV inputs present in the Harness.
%
% harnessDrivenNames (optional) lists SLDV inputs the Harness drives by
% other means, such as the FcnTriggerPort of a function-call CUT that the
% Harness scheduler calls. They are dropped even when ignoreUnexpected is
% false and are reported in ignoredNames; any other unexpected input still
% fails.

if nargin < 4
    harnessDrivenNames = {};
end

datasetNames = cellstr(string(datasetNames(:)));
harnessNames = cellstr(string(harnessNames(:)));
harnessDrivenNames = cellstr(string(harnessDrivenNames(:)));
ignoreUnexpected = logical(ignoreUnexpected);

if ~isscalar(ignoreUnexpected)
    error( ...
        'simtest:InvalidIgnoreUnexpectedSldvInputs', ...
        'IgnoreUnexpectedSldvInputs must be a logical scalar.');
end

if numel(unique(string(datasetNames))) ~= numel(datasetNames)
    error( ...
        'simtest:DuplicateSldvInputNames', ...
        'SLDV Dataset contains duplicate input names: [%s]', ...
        strjoin(datasetNames, ', '));
end

unexpectedMask = ...
    ~ismember(string(datasetNames), string(harnessNames));
drivenMask = unexpectedMask & ...
    ismember(string(datasetNames), string(harnessDrivenNames));
ignoredNames = datasetNames(unexpectedMask);
rejectedNames = datasetNames(unexpectedMask & ~drivenMask);

if ~isempty(rejectedNames) && ~ignoreUnexpected
    error( ...
        'simtest:UnexpectedSldvInputs', ...
        ['SLDV Dataset contains signals that are not present in the ' ...
         'Harness input interface. Unexpected=[%s], Harness=[%s]'], ...
        strjoin(rejectedNames, ', '), ...
        strjoin(harnessNames, ', '));
end

selectedIndices = find(~unexpectedMask);
selectedNames = datasetNames(selectedIndices);

end
