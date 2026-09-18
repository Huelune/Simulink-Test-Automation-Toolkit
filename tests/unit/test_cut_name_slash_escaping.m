function tests = test_cut_name_slash_escaping
%TEST_CUT_NAME_SLASH_ESCAPING CUTName slash is doubled in CUTPath.
%
% Simulink writes a '/' inside a block name as '//' in a block path. A
% workbook cell typed from the block name carries a single slash, so the
% path resolves against nothing. The CUTName column says where the leaf
% name begins, which is what makes the rewrite unambiguous.
tests = functiontests(localfunctions);
end

function testTrailingNameIsEscaped(testCase)
verifyEqual(testCase, ...
    st_escape_cut_name_in_path( ...
        "TOP/Sub/OBC_State_AC/DC_Check", "OBC_State_AC/DC_Check"), ...
    "TOP/Sub/OBC_State_AC//DC_Check");
end

function testSeparatorsAboveTheNameAreUntouched(testCase)
% Only the trailing name is rewritten. A real hierarchy above it must
% survive unchanged, otherwise the path would collapse.
verifyEqual(testCase, ...
    st_escape_cut_name_in_path("TOP/A/B/C/X/Y", "X/Y"), ...
    "TOP/A/B/C/X//Y");
end

function testAlreadyEscapedPathIsUnchanged(testCase)
% The workbook may already hold the Simulink notation, and doubling it
% again would produce '////'.
verifyEqual(testCase, ...
    st_escape_cut_name_in_path("TOP/Sub/X//Y", "X/Y"), ...
    "TOP/Sub/X//Y");
end

function testNameWithoutSlashIsUnchanged(testCase)
% The common case must not be touched at all. Here 'DC_Check' is a real
% child of a block named 'AC', which is a different path from a single
% block named 'AC/DC_Check'.
verifyEqual(testCase, ...
    st_escape_cut_name_in_path("TOP/Sub/AC/DC_Check", "DC_Check"), ...
    "TOP/Sub/AC/DC_Check");
end

function testPathNotEndingWithTheNameIsUnchanged(testCase)
% A stale or mismatched cell is left for validation to report, rather than
% being rewritten into something that was never asked for.
verifyEqual(testCase, ...
    st_escape_cut_name_in_path("TOP/Sub/Other", "X/Y"), ...
    "TOP/Sub/Other");
end

function testEmptyValuesAreUnchanged(testCase)
verifyEqual(testCase, st_escape_cut_name_in_path("", "X/Y"), "");
verifyEqual(testCase, st_escape_cut_name_in_path("TOP/Sub/X", ""), ...
    "TOP/Sub/X");
end

function testColumnsAreRewrittenElementwise(testCase)
paths = ["TOP/A/X/Y"; "TOP/B/Plain"; "TOP/C/P//Q"];
names = ["X/Y"; "Plain"; "P/Q"];
verifyEqual(testCase, st_escape_cut_name_in_path(paths, names), ...
    ["TOP/A/X//Y"; "TOP/B/Plain"; "TOP/C/P//Q"]);
end

function testMismatchedColumnHeightsAreRejected(testCase)
verifyError(testCase, ...
    @() st_escape_cut_name_in_path(["a"; "b"], ["x"; "y"; "z"]), ...
    'simtest:EscapeCutNameSizeMismatch');
end

function testLoaderNormalisesBeforeBuildingTheTable(testCase)
% The rewrite has to happen where both columns exist. Every consumer takes
% CUTPath alone, so a second place doing this would drift.
root = st_project_root();
loader = fileread(fullfile(root, 'src', 'targets', 'st_load_targets.m'));
verifyTrue(testCase, contains(loader, ...
    'CUTPath = st_escape_cut_name_in_path(CUTPath, CUTName);'));

finder = fileread(fullfile(root, 'src', 'targets', ...
    'st_find_target_paths.m'));
verifyTrue(testCase, contains(finder, 'st_escape_cut_name_in_path'));
end
