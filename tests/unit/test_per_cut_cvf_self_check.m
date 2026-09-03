function tests = test_per_cut_cvf_self_check
%TEST_PER_CUT_CVF_SELF_CHECK Static contract for the R2025b CVF diagnostic.
tests = functiontests(localfunctions);
end


function testDiagnosticUsesFixedSixBitContract(testCase)
root = st_project_root();
path = fullfile(root, 'diagnostics', 'matlab', ...
    'st_check_per_cut_cvf.m');
verifyTrue(testCase, isfile(path));

source = fileread(path);
labels = {'B1:INTEGRITY','B2:LIFECYCLE','B3:RULE_COUNT', ...
    'B4:CUT_EXCLUDED','B5:DIRECT_CHILDREN','B6:MODE_ACTION'};
for i = 1:numel(labels)
    verifyNotEmpty(testCase, regexp(source, labels{i}, 'once'));
end
verifyNotEmpty(testCase, regexp(source, ...
    'CVF-CHECK-v1 OVERALL=%s', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'overallCode\s*=\s*bits_to_code\(all\(bitRows, 1\)\)', 'once'));
end


function testDiagnosticReadsSavedRulesAndChecksDirectChildren(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'diagnostics', 'matlab', ...
    'st_check_per_cut_cvf.m'));

verifyNotEmpty(testCase, regexp(source, ...
    'savedFilter\s*=\s*slcoverage\.Filter\(cvfPath\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'savedRules\s*=\s*rules\(savedFilter\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'direct_child_subsystems\(ownerPath\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    '~any\(selectedSids\s*==\s*ownerSid\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'exact_string_set', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'expectedSelectorType\s*=\s*"BLOCKINSTANCE"', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'expectedSelectorType\s*=\s*"SUBSYSTEMALLCONTENT"', 'once'));
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
