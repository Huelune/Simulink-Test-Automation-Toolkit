function cutPath = st_escape_cut_name_in_path(cutPath, cutName)
%ST_ESCAPE_CUT_NAME_IN_PATH Write a slash in the CUT name the way Simulink does.
%
% Simulink escapes a '/' inside a block name by doubling it, so a block
% actually named 'AC/DC_Check' appears in a block path as 'AC//DC_Check'.
% An Excel CUTPath cell is normally typed or pasted from the block name, so
% the trailing name arrives with a single slash and nothing resolves.
%
% Guessing where a name ends is ambiguous in general, but the workbook does
% not have to guess: the CUTName column states the leaf name exactly. Only
% the trailing occurrence is rewritten and every separator above it is left
% untouched, so a real hierarchy is never collapsed.
%
% The value is returned unchanged when CUTName holds no slash, when the
% path already carries the escaped form, or when the path does not end with
% the name at all. The result is still validated by st_normalize_cut_path
% against Simulink, so a rewrite that does not exist simply fails as before.
%
% Examples, for CUTName 'AC/DC_Check':
%   TOP/Sub/AC/DC_Check    -> TOP/Sub/AC//DC_Check
%   TOP/Sub/AC//DC_Check   -> unchanged, already escaped
%   TOP/Sub/Other          -> unchanged, does not end with the name
%
% A slash inside a parent name is out of scope here, because no column
% states where those names begin or end.

cutPath = string(cutPath);
cutName = string(cutName);

if isscalar(cutName) && ~isscalar(cutPath)
    cutName = repmat(cutName, size(cutPath));
end

if numel(cutPath) ~= numel(cutName)
    error('simtest:EscapeCutNameSizeMismatch', ...
        'CUTPath and CUTName must have the same number of elements.');
end

for i = 1:numel(cutPath)

    name = cutName(i);
    value = cutPath(i);

    if ismissing(name) || ismissing(value)
        continue;
    end

    % Excel cells keep their whitespace, but a trailing space would never be
    % part of the name being matched here.
    name = strtrim(name);

    if ~contains(name, '/')
        continue;
    end

    escaped = replace(name, '/', '//');

    if endsWith(value, "/" + escaped)
        continue;
    end

    if ~endsWith(value, "/" + name)
        continue;
    end

    head = extractBefore(value, strlength(value) - strlength(name) + 1);
    cutPath(i) = head + escaped;
end

end
