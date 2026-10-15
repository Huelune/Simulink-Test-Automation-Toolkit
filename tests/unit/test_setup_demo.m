function tests = test_setup_demo
%TEST_SETUP_DEMO The demo becomes the target and the replaced files are backed up.
% st_project_root is shadowed by a temporary folder, so the repository's own
% TestManagement.xlsx and runtime_target.mat are never touched.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
if bdIsLoaded('ST_DemoModel'), close_system('ST_DemoModel', 0); end
root = tempname;
mkdir(root);
originalPath = path;
testCase.addTeardown(@() cleanup(root, originalPath));
write_file(fullfile(root, 'st_project_root.m'), sprintf([ ...
    'function r = st_project_root()\n' ...
    'r = fileparts(mfilename(''fullpath''));\nend\n']));
% The real command reads st_config; this one only records the root.
write_file(fullfile(root, 'st_set_standalone_coverage_root.m'), sprintf([ ...
    'function st_set_standalone_coverage_root(d)\n' ...
    'st_save_runtime_target_fields(fullfile(st_project_root(), ''runtime_target.mat''), ' ...
    'struct(''StandaloneCoverageRootDir'', d));\nend\n']));
Previous = "real targets"; %#ok<NASGU>
writetable(table(Previous), fullfile(root, 'TestManagement.xlsx'));
Keep = 1; TopModel = 'RealModel'; %#ok<NASGU>
save(fullfile(root, 'runtime_target.mat'), 'Keep', 'TopModel');
addpath(root, '-begin');
clear st_project_root st_set_standalone_coverage_root;
testCase.TestData.Root = root;
testCase.TestData.Demo = st_setup_demo(fullfile(root, 'demo'));
end

function testDemoWorkbookReplacesTheRootWorkbook(testCase)
T = readtable(fullfile(testCase.TestData.Root, 'TestManagement.xlsx'), ...
    'Sheet', 'Targets', 'TextType', 'string');
verifyEqual(testCase, height(T), 7);
end

function testReplacedFilesAreBackedUp(testCase)
demo = testCase.TestData.Demo;
verifyNumElements(testCase, demo.Backups, 2);
verifyTrue(testCase, all(isfile(demo.Backups)));
workbook = demo.Backups(endsWith(demo.Backups, '.xlsx'));
old = readtable(workbook, 'TextType', 'string');
verifyEqual(testCase, old.Previous, "real targets");
target = load(demo.Backups(endsWith(demo.Backups, '.mat')));
verifyEqual(testCase, target.TopModel, 'RealModel');
end

function testRuntimeTargetSelectsTheDemoAndKeepsOtherFields(testCase)
demo = testCase.TestData.Demo;
target = load(fullfile(testCase.TestData.Root, 'runtime_target.mat'));
verifyEqual(testCase, target.TopModel, demo.TopModel);
verifyEqual(testCase, target.ModelFile, demo.ModelFile);
verifyEqual(testCase, target.StandaloneCoverageRootDir, demo.StandaloneCoverageRoot);
verifyEqual(testCase, target.Keep, 1);
end

function testAnotherDriveIsRefusedBeforeAnythingIsWritten(testCase)
% The standalone bundle needs one folder holding the model and the SLDV data
% under the toolkit's result folder.
assumeTrue(testCase, ispc);
root = testCase.TestData.Root;
other = 'Q:';
if strncmpi(root, other, 2), other = 'R:'; end
before = dir(fullfile(root, '*.backup_*'));
verifyError(testCase, @() st_setup_demo(fullfile(other, 'st_demo')), ...
    'simtest:DemoDriveMismatch');
verifyNumElements(testCase, dir(fullfile(root, '*.backup_*')), numel(before));
end

function cleanup(root, originalPath)
path(originalPath);
clear st_project_root st_set_standalone_coverage_root;
if bdIsLoaded('ST_DemoModel'), close_system('ST_DemoModel', 0); end
if isfolder(root), rmdir(root, 's'); end
end

function write_file(file, text)
fid = fopen(file, 'w');
assert(fid >= 0, 'Cannot create test fixture file.');
fprintf(fid, '%s', text);
fclose(fid);
end
