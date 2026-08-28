function cutPath = st_normalize_cut_path(cutPath, modelName)
%ST_NORMALIZE_CUT_PATH Resolve Excel CUT path to a Simulink full path.
%
% Resolution order:
%   1. Preserve the original CUTPath whitespace and check whether that exact
%      Simulink path exists.
%   2. If it does not exist, apply the legacy outer strtrim behavior and
%      check again.
%   3. If neither exists, return the legacy-trimmed candidate so downstream
%      validation reports the same style of not-found error as before.
%
% This allows a real block whose final name contains trailing whitespace to
% be resolved without breaking existing Excel rows that contain accidental
% leading/trailing whitespace.
%
% Examples normalized structurally to TEST_TARGET_MODEL_NAME/A/B:
%   /TEST_TARGET_MODEL_NAME/A/B
%   TEST_TARGET_MODEL_NAME/A/B
%   TEST_TARGET_MODEL_NAME/TEST_TARGET_MODEL_NAME/A/B
%   A/B
%
% Whitespace example:
%   Actual block name: 'B '
%   Excel path       : 'TEST_TARGET_MODEL_NAME/A/B '
%   -> exact path is checked first and preserved when it exists.
%
%   Actual block name: 'B'
%   Excel path       : 'TEST_TARGET_MODEL_NAME/A/B '
%   -> exact path fails, legacy strtrim candidate is checked and used.

rawCutPath = st_scalar_text(cutPath);
modelName = strtrim(st_scalar_text(modelName));

if isempty(rawCutPath)
    cutPath = '';
    return;
end

% Candidate 1: preserve original outer whitespace.
exactCandidate = ...
    st_build_candidate( ...
        rawCutPath, ...
        modelName);

if st_cut_path_exists(exactCandidate)

    cutPath = exactCandidate;
    return;
end

% Candidate 2: legacy behavior.
trimmedInput = ...
    strtrim(rawCutPath);

trimmedCandidate = ...
    st_build_candidate( ...
        trimmedInput, ...
        modelName);

if st_cut_path_exists(trimmedCandidate)

    cutPath = trimmedCandidate;
    return;
end

% Keep legacy failure behavior when neither candidate resolves.
cutPath = trimmedCandidate;

end


function candidate = st_build_candidate(cutPath, modelName)
% Structural normalization only. Do not trim cutPath here.

candidate = cutPath;

% Convert Windows-style separator to Simulink separator.
candidate(candidate == char(92)) = '/';

% Remove leading slash characters.
while ~isempty(candidate) && ...
        candidate(1) == '/'

    candidate(1) = [];
end

% Remove accidental TOP/TOP/... duplication.
doublePrefix = ...
    [modelName '/' modelName '/'];

while length(candidate) >= length(doublePrefix) && ...
        strncmp( ...
            candidate, ...
            doublePrefix, ...
            length(doublePrefix))

    candidate = ...
        candidate(length(modelName) + 2:end);
end

% Add top model only when the path is relative.
modelPrefix = ...
    [modelName '/'];

if ~strcmp(candidate, modelName) && ...
        ~(length(candidate) >= length(modelPrefix) && ...
          strncmp( ...
              candidate, ...
              modelPrefix, ...
              length(modelPrefix)))

    candidate = ...
        [modelName '/' candidate];
end

end


function tf = st_cut_path_exists(candidate)

tf = false;

if isempty(candidate)
    return;
end

try

    blockHandle = ...
        getSimulinkBlockHandle( ...
            candidate);

    tf = ...
        blockHandle ~= -1;

catch

    tf = false;
end

end


function out = st_scalar_text(v)

if iscell(v)

    if isempty(v)
        out = '';
        return;
    end

    v = v{1};
end

if isstring(v)

    if isempty(v) || ismissing(v)
        out = '';
        return;
    end

    out = char(v(1));

elseif ischar(v)

    out = v;

elseif isnumeric(v) || islogical(v)

    out = char(string(v));

else

    out = char(string(v));
end

end
