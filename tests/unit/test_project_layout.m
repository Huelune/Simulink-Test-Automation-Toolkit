function tests = test_project_layout
tests = functiontests(localfunctions);
end


function testProjectRootUsesBootstrapLocation(testCase)
expectedRoot = ...
    fileparts( ...
        fileparts( ...
            fileparts(mfilename('fullpath'))));

verifyEqual(testCase, st_project_root(), expectedRoot);
end


function testConfigKeepsRepositoryRelativePaths(testCase)
cfg = st_config();
rootDir = st_project_root();

verifyEqual(testCase, cfg.ManagementExcel, ...
    fullfile(rootDir, 'TestManagement.xlsx'));
verifyEqual(testCase, cfg.ResultDir, ...
    fullfile(rootDir, 'result'));
verifyEqual(testCase, cfg.VerificationRootDir, ...
    fullfile(rootDir, 'result', 'verification'));
end


function testVerificationEntryPointsExist(testCase)
rootDir = st_project_root();
required = { ...
    fullfile(rootDir, 'src', 'verification', 'st_verify_all.m'), ...
    fullfile(rootDir, 'src', 'verification', ...
    'st_run_verification_runtime.m'), ...
    fullfile(rootDir, 'tests', 'fixtures', ...
    'st_build_verification_fixture.m')};
verifyTrue(testCase, all(cellfun(@isfile, required)));
end


function testMaintenanceEntryPointExists(testCase)
rootDir = st_project_root();

verifyTrue(testCase, isfile(fullfile(rootDir, 'src', 'maintenance', ...
    'st_cleanup_results.m')));
end
