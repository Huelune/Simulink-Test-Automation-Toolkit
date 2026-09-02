function tests = test_sldv_target_precheck
tests = functiontests(localfunctions);
end


function testPublicEntryPointAndSafeDefaultExist(testCase)

rootDir = st_project_root();
path = fullfile(rootDir, 'src', 'sldv', ...
    'st_validate_sldv_target.m');
text = fileread(path);

verifyTrue(testCase, isfile(path));
verifySubstring(testCase, text, ...
    "addParameter(parser, 'RunActualSLDV', false");
verifySubstring(testCase, text, 'sldvcompat(candidatePath, options)');
verifySubstring(testCase, text, ...
    'if options.RunActualSLDV');
verifySubstring(testCase, text, "st_log(cfg, 'INFO'");
end


function testInvalidPathReturnsStructuredResultWithoutSldv(testCase)

output = evalc([ ...
    'result = st_validate_sldv_target(' ...
    '''st_model_that_does_not_exist/Target'');']);

verifyFalse(testCase, result.Path.Success);
verifyFalse(testCase, result.SLDV.Executed);
verifyEqual(testCase, result.Options.RunActualSLDV, false);
verifyEmpty(testCase, result.ParentChecks);
verifyTrue(testCase, isfield(result.Dependency, ...
    'ExternalDataStoreCount'));
verifyTrue(testCase, isfield(result, 'FirstAnalyzablePath'));
verifySubstring(testCase, output, '[SLDV Precheck]');
verifySubstring(testCase, output, '[ERROR]');
end


function testExternalDataStoreAndGotoAreCandidates(testCase)

[modelName, targetPath, cleanup] = build_dependency_model('external'); %#ok<ASGLU>
dependency = st_inspect_sldv_dependencies(targetPath);

verifyTrue(testCase, dependency.Success);
verifyEqual(testCase, dependency.ExternalDataStoreCount, 1);
verifyEqual(testCase, dependency.ExternalGotoCount, 1);
verifyEqual(testCase, dependency.DataStore(1).Name, 'SharedData');
verifyTrue(testCase, dependency.DataStore(1).External);
verifyEqual(testCase, dependency.GotoFrom(1).Tag, 'SharedTag');
verifyTrue(testCase, dependency.GotoFrom(1).External);
verifyNotEmpty(testCase, dependency.DependencyWarnings);
end


function testInternalDataStoreAndGotoAreNotExternal(testCase)

[modelName, targetPath, cleanup] = build_dependency_model('internal'); %#ok<ASGLU>
dependency = st_inspect_sldv_dependencies(targetPath);

verifyTrue(testCase, dependency.Success);
verifyEqual(testCase, dependency.ExternalDataStoreCount, 0);
verifyEqual(testCase, dependency.ExternalGotoCount, 0);
verifyFalse(testCase, dependency.DataStore(1).External);
verifyFalse(testCase, dependency.GotoFrom(1).External);
end


function testExecutionBoundaryIsWarningCandidate(testCase)

modelName = unique_model_name('boundary');
new_system(modelName);
cleanup = onCleanup(@() close_system(modelName, 0)); %#ok<NASGU>
targetPath = [modelName '/Target'];
add_block('built-in/Subsystem', targetPath);
set_param(targetPath, 'TreatAsAtomicUnit', 'on');
add_block('built-in/EnablePort', [targetPath '/Enable']);

dependency = st_inspect_sldv_dependencies(targetPath);

verifyEqual(testCase, dependency.BoundaryDependencyCount, 1);
verifyEqual(testCase, dependency.Boundary(1).Type, 'Enable');
verifyNotEmpty(testCase, dependency.Warnings);
end


function [modelName, targetPath, cleanup] = build_dependency_model(scope)

modelName = unique_model_name(scope);
new_system(modelName);
cleanup = onCleanup(@() close_system(modelName, 0));
targetPath = [modelName '/Target'];
add_block('built-in/Subsystem', targetPath);

if strcmp(scope, 'external')
    definitionSystem = modelName;
else
    definitionSystem = targetPath;
end

memory = [definitionSystem '/Memory'];
add_block('built-in/DataStoreMemory', memory);
set_param(memory, 'DataStoreName', 'SharedData');

read = [targetPath '/Read'];
add_block('built-in/DataStoreRead', read);
set_param(read, 'DataStoreName', 'SharedData');

goto = [definitionSystem '/Goto'];
add_block('built-in/Goto', goto);
set_param(goto, 'GotoTag', 'SharedTag');
if strcmp(scope, 'external')
    set_param(goto, 'TagVisibility', 'global');
else
    set_param(goto, 'TagVisibility', 'local');
end

from = [targetPath '/From'];
add_block('built-in/From', from);
set_param(from, 'GotoTag', 'SharedTag');
end


function name = unique_model_name(label)

name = matlab.lang.makeValidName(sprintf( ...
    'st_precheck_%s_%s', label, char(java.util.UUID.randomUUID)));
end
