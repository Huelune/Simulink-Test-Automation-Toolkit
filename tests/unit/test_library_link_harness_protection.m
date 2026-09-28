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


function testLinkedCutFailsUnlessLinkDisableIsOptedIn(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'sldv', ...
    'st_prepare_sldv_targets.m'));

% The linked-CUT failure stays the default and is only bypassed by the
% explicit opt-in flag.
verifyNotEmpty(testCase, regexp(source, ...
    ['disableLink = isfield\(cfg, ''DisableLibraryLinkForSldvTargets''\)' ...
     '[\s\S]*?if linkState\.IsLinked && ~disableLink[\s\S]*?' ...
     'simtest:SldvLinkedCUTRequiresAtomic'], 'once'));

% Opting in disables only the model-side instance link through the shared
% helper and records a distinct AtomicAction.
verifyNotEmpty(testCase, regexp(source, ...
    'st_disable_cut_library_link\(cfg, ownerPath\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'LINK_DISABLED_CONVERTED', 'once'));
verifyFalse(testCase, contains(source, 'save_system('), ...
    'The SLDV stage must not save the model or any library file.');

helper = fileread(fullfile(root, 'src', 'sldv', ...
    'st_disable_cut_library_link.m'));
verifyNotEmpty(testCase, regexp(helper, ...
    'linkOwner = find_library_link_owner\(cutPath\)', 'once'));
verifyNotEmpty(testCase, regexp(helper, ...
    'set_param\(linkOwner, ''LinkStatus'', ''inactive''\)', 'once'));
verifyNotEmpty(testCase, regexp(helper, ...
    'simtest:SldvLibraryLinkOwnerNotFound', 'once'));
verifyNotEmpty(testCase, regexp(helper, ...
    'simtest:SldvLibraryLinkDisableFailed', 'once'));
verifyNotEmpty(testCase, regexp(helper, ...
    'simtest:SldvLibraryLinkDisableBlockedByHarness', 'once'));
verifyFalse(testCase, contains(helper, 'save_system('));
verifyFalse(testCase, contains(helper, 'load_system('), ...
    'The helper must never open a library file.');

% Changing the flag must invalidate the SLDV stage fingerprint.
plan = fileread(fullfile(root, 'src', 'workflow', ...
    'st_build_execution_plan.m'));
inputs = fileread(fullfile(root, 'src', 'workflow', ...
    'st_stage_inputs.m'));
verifyTrue(testCase, contains(plan, ...
    'sldv.DisableLibraryLink = cfg.DisableLibraryLinkForSldvTargets'));
verifyTrue(testCase, contains(inputs, ...
    '''DisableLibraryLink'',cfg.DisableLibraryLinkForSldvTargets'));
end


function testLinkDisableRunsBeforeHarnessCreation(testCase)
root = st_project_root();
workflow = fileread(fullfile(root, 'src', 'workflow', ...
    'st_run_workflow.m'));

% Simulink refuses to disable a link once a Harness exists inside it, so
% the opt-in disable step must be ordered before 'Create Harnesses' and
% stay gated on the flag.
disableAt = regexp(workflow, ...
    ['if cfg\.DisableLibraryLinkForSldvTargets[\s\S]*?' ...
     'st_disable_sldv_target_library_links\(T, cfg\)'], 'once');
createAt = regexp(workflow, '''Create Harnesses''', 'once');
verifyNotEmpty(testCase, disableAt);
verifyNotEmpty(testCase, createAt);
verifyLessThan(testCase, disableAt, createAt);

prepass = fileread(fullfile(root, 'src', 'sldv', ...
    'st_disable_sldv_target_library_links.m'));
verifyNotEmpty(testCase, regexp(prepass, ...
    'st_disable_cut_library_link\(cfg, cutPath\)', 'once'));
verifyNotEmpty(testCase, regexp(prepass, ...
    'tf = ~strcmp\(format, ''MAT''\)', 'once'), ...
    'FILE+MAT targets must not have their link disabled.');
verifyNotEmpty(testCase, regexp(prepass, ...
    'SldvLibraryLinkDisableResult', 'once'));
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
