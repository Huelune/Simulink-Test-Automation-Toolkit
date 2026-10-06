function tests = test_normalize_cut_path
%TEST_NORMALIZE_CUT_PATH A resolved CUT path comes back as Simulink spells it.
%
% Path lookup accepts more than one spelling of a block, but Test Manager
% compares HarnessOwner as text against the Harness owner Simulink reports.
% Every stage takes its owner path from st_normalize_cut_path, so that path
% has to be the getfullname spelling.
tests = functiontests(localfunctions);
end

function testExactPathKeepsATrailingSpaceInTheName(testCase)
[model, spaced] = build_model(testCase);
verifyEqual(testCase, st_normalize_cut_path(spaced, model), spaced);
end

function testRelativePathIsPrefixedWithTheModel(testCase)
model = build_model(testCase);
verifyEqual(testCase, st_normalize_cut_path('Plain', model), ...
    [model '/Plain']);
end

function testResolvedPathIsReturnedAsSimulinkSpellsIt(testCase)
% On 2026-10-01 a CUTPath ending in ' /' resolved, created a Harness, and
% was then rejected by Test Manager as HarnessOwner.
[model, spaced] = build_model(testCase);
typed = [spaced '/'];
handle = getSimulinkBlockHandle(typed);
assumeNotEqual(testCase, handle, -1, ...
    'This release does not resolve a trailing separator.');
verifyEqual(testCase, st_normalize_cut_path(typed, model), ...
    getfullname(handle));
end

function testUnresolvedPathKeepsTheTrimmedCandidate(testCase)
% Validation reports a missing block with the same text as before.
model = build_model(testCase);
verifyEqual(testCase, st_normalize_cut_path('Missing ', model), ...
    [model '/Missing']);
end

function [model, spaced] = build_model(testCase)
model = matlab.lang.makeValidName(sprintf( ...
    'st_normalize_%s', char(java.util.UUID.randomUUID)));
new_system(model);
testCase.addTeardown(@() close_system(model, 0));
add_block('built-in/Subsystem', [model '/Plain']);
handle = add_block('built-in/Subsystem', [model '/Range']);
set_param(handle, 'Name', 'Range ');
assumeEqual(testCase, get_param(handle, 'Name'), 'Range ', ...
    'This release does not keep a trailing space in a block name.');
spaced = getfullname(handle);
end
