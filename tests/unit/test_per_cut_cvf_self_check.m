function tests = test_per_cut_cvf_self_check
%TEST_PER_CUT_CVF_SELF_CHECK Static contract for the R2025b CVF diagnostic.
tests = functiontests(localfunctions);
end


function testDiagnosticUsesFixedSixBitV2Contract(testCase)
root = st_project_root();
path = fullfile(root, 'diagnostics', 'matlab', ...
    'st_check_per_cut_cvf.m');
verifyTrue(testCase, isfile(path));

source = fileread(path);
labels = {'B1:INTEGRITY','B2:LIFECYCLE','B3:RULE_COUNT', ...
    'B4:BLOCK_SELECTORS','B5:RULE_CATEGORIES','B6:RULE_POLICY'};
for i = 1:numel(labels)
    verifyNotEmpty(testCase, regexp(source, labels{i}, 'once'));
end
verifyNotEmpty(testCase, regexp(source, ...
    'CVF-CHECK-v2 OVERALL=%s', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'overallCode\s*=\s*bits_to_code\(all\(bitRows, 1\)\)', 'once'));
end


function testDiagnosticReadsSavedRulesAndChecksBoundaryPolicy(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'diagnostics', 'matlab', ...
    'st_check_per_cut_cvf.m'));

verifyNotEmpty(testCase, regexp(source, ...
    'savedFilter\s*=\s*slcoverage\.Filter\(cvfPath\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'savedRules\s*=\s*rules\(savedFilter\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'boundaryRules\s*=\s*ruleRationales', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'expectedSelectorType\s*=\s*"BLOCKINSTANCE"', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'expectedSelectorType\s*=\s*"SUBSYSTEMALLCONTENT"', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'ruleModes\(boundaryRules\)\s*==\s*"EXCLUDE"', 'once'));
end


function testDiagnosticDoesNotWriteOrSaveProjectAssets(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'diagnostics', 'matlab', ...
    'st_check_per_cut_cvf.m'));

verifyEmpty(testCase, regexp(source, '\<writetable\s*\(', 'once'));
verifyEmpty(testCase, regexp(source, '\<writecell\s*\(', 'once'));
verifyEmpty(testCase, regexp(source, '\<save_system\s*\(', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'close_system\(modelName, 0\)', 'once'));
end
