function tests = test_library_link_harness_protection
%TEST_LIBRARY_LINK_HARNESS_PROTECTION Static contracts for linked CUT safety.
tests = functiontests(localfunctions);
end


function testNewLinkedHarnessUsesOneWaySynchronization(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'harness', ...
    'st_create_harnesses.m'));

verifyNotEmpty(testCase, regexp(source, ...
    'if linkState\.IsLinked[\s\S]*?synchronizationMode = ''SyncOnOpen''', ...
    'once'));
verifyNotEmpty(testCase, regexp(source, ...
    '''SynchronizationMode'', synchronizationMode', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'st_assert_cut_library_link_unchanged', 'once'));
end


function testCloneIsProtectedBeforeFirstOpen(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'harness', ...
    'st_clone_template_harness.m'));

clonePosition = regexp(source, ...
    'clone_logged\(source,sourceName,owner,name,cfg\)', 'once');
tail = source(clonePosition:end);
protectOffset = regexp(tail, ...
    'st_protect_linked_cut_harness\(owner,name,cfg\)', 'once');
openOffset = regexp(tail, ...
    'open_logged\(owner,name,cfg\)', 'once');
verifyNotEmpty(testCase, clonePosition);
verifyNotEmpty(testCase, protectOffset);
verifyNotEmpty(testCase, openOffset);
protectPosition = clonePosition + protectOffset - 1;
openPosition = clonePosition + openOffset - 1;
verifyLessThan(testCase, clonePosition, protectPosition);
verifyLessThan(testCase, protectPosition, openPosition);
verifyGreaterThanOrEqual(testCase, numel(regexp(source, ...
    'st_assert_cut_library_link_unchanged', 'match')), 3);
end


function testCloneTemplateIsProtectedBeforeOpen(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'harness', ...
    'st_clone_template_harness.m'));

protectPosition = regexp(source, ...
    'st_protect_linked_cut_harness\( \.\.\.\s*source,sourceName,cfg\)', ...
    'once');
openPosition = regexp(source, ...
    'open_logged\(source,sourceName,cfg\)', 'once');
verifyNotEmpty(testCase, protectPosition);
verifyNotEmpty(testCase, openPosition);
verifyLessThan(testCase, protectPosition, openPosition);
verifyNotEmpty(testCase, regexp(source, ...
    'sourceLinkState,source,''Template Harness close''', 'once'));
end


function testAfterHarnessProtectsExistingLinkedHarnessesFirst(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'workflow', ...
    'st_run_workflow.m'));

protectPosition = regexp(source, ...
    'Protect Library-Linked CUT Harnesses', 'once');
validationPosition = regexp(source, ...
    'if strcmpi\(workflowKind, ''FULL''\)', 'once');
verifyLessThan(testCase, protectPosition, validationPosition);
verifyNotEmpty(testCase, regexp(source, ...
    'st_protect_linked_cut_harnesses\(T, cfg\)', 'once'));
end


function testOrdinaryMatDoesNotRequestAtomicConversion(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'sldv', ...
    'st_prepare_sldv_targets.m'));

verifyNotEmpty(testCase, regexp(source, ...
    ['strcmp\(mode, ''FILE''\) && strcmp\(dataFileFormat, ''MAT''\)' ...
     '[\s\S]*?NOT_REQUIRED_MAT'], 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'simtest:SldvLinkedCUTRequiresAtomic', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'st_cut_library_link_state\(ownerPath\)', 'once'));
end


function testLinkComparisonChecksStatusAndReference(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'harness', ...
    'st_assert_cut_library_link_unchanged.m'));

verifyNotEmpty(testCase, regexp(source, ...
    'before\.StaticLinkStatus', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'before\.ReferenceBlock', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'simtest:HarnessChangedLibraryLink', 'once'));
end
