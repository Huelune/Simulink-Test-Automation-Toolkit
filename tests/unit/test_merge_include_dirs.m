function tests = test_merge_include_dirs
%TEST_MERGE_INCLUDE_DIRS Extra header folders join SimUserIncludeDirs once, at the end.
tests = functiontests(localfunctions);
end

function testAddsToEmpty(testCase)
[merged, added] = st_merge_include_dirs('', {'D:\Project\inc'});
verifyEqual(testCase, merged, '"D:\Project\inc"');
verifyEqual(testCase, added, 1);
end

function testKeepsExistingAndSkipsDuplicates(testCase)
existing = ['.\inc ' newline '"D:\Project\common inc"'];
[merged, added] = st_merge_include_dirs(existing, {'d:\project\COMMON INC\', 'D:\Other'});
verifyEqual(testCase, merged, [existing newline '"D:\Other"']);
verifyEqual(testCase, added, 1);
end

function testNothingToAddLeavesItAsItIs(testCase)
existing = '"D:\Project\inc";..\lib';
[merged, added] = st_merge_include_dirs(existing, {});
verifyEqual(testCase, merged, existing);
verifyEqual(testCase, added, 0);
end
