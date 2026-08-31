function tests = test_comprehensive_verification
tests = functiontests(localfunctions);
end

function testPublicOptionDefaults(testCase)
options = st_parse_verification_options();
verifyEqual(testCase, options.Profile, 'QUICK');
verifyEqual(testCase, options.Target, 'CURRENT');
verifyEqual(testCase, options.ManualEvidence, '');
verifyEqual(testCase, options.KeepWorkspace, 'ON_FAILURE');
verifyTrue(testCase, options.FailOnNonPass);
end

function testPublicOptionsNormalizeValues(testCase)
options = st_parse_verification_options( ...
    'Profile', ' certify ', 'Target', ' both ', ...
    'KeepWorkspace', ' always ', 'FailOnNonPass', false);
verifyEqual(testCase, options.Profile, 'CERTIFY');
verifyEqual(testCase, options.Target, 'BOTH');
verifyEqual(testCase, options.KeepWorkspace, 'ALWAYS');
verifyFalse(testCase, options.FailOnNonPass);
end

function testInvalidPublicOptionsFail(testCase)
verifyError(testCase, @() st_parse_verification_options( ...
    'Profile', 'FULL'), 'simtest:InvalidVerificationProfile');
verifyError(testCase, @() st_parse_verification_options( ...
    'Target', 'MODEL'), 'simtest:InvalidVerificationTarget');
verifyError(testCase, @() st_parse_verification_options( ...
    'KeepWorkspace', 'SOMETIMES'), ...
    'simtest:InvalidVerificationWorkspacePolicy');
end

function testOverallStatusPriority(testCase)
checks = st_empty_verification_checks();
checks = [checks; check('PASS', true); check('WARN', false)];
verifyEqual(testCase, st_verification_overall_status(checks), ...
    "PASS_WITH_WARNINGS");
checks = [checks; check('BLOCKED', true)];
verifyEqual(testCase, st_verification_overall_status(checks), "BLOCKED");
checks = [checks; check('FAIL', true)];
verifyEqual(testCase, st_verification_overall_status(checks), "FAIL");
end

function testOptionalBlockedIsWarning(testCase)
checks = check('BLOCKED', false);
verifyEqual(testCase, st_verification_overall_status(checks), ...
    "PASS_WITH_WARNINGS");
end

function testCatalogIsCompleteAndUnique(testCase)
catalog = st_verification_catalog();
verifyEmpty(testCase, st_validate_verification_catalog(catalog));
verifyEqual(testCase, numel(unique(catalog.FeatureId)), height(catalog));
end

function testCatalogRejectsDuplicateCheckId(testCase)
catalog = st_verification_catalog();
catalog.AutomatedCheckIds(2) = catalog.AutomatedCheckIds(1);
issues = st_validate_verification_catalog(catalog);
verifyTrue(testCase, any(contains(issues, 'unique')));
end

function testCatalogRejectsUnconnectedFeature(testCase)
catalog = st_verification_catalog();
catalog.AutomatedCheckIds(1) = "";
catalog.ManualCheckIds(1) = "";
issues = st_validate_verification_catalog(catalog);
verifyTrue(testCase, any(contains(issues, 'no verification check')));
end

function testCatalogCoverageFailsMissingResult(testCase)
catalog = st_verification_catalog();
options = st_parse_verification_options();
checks = st_verification_check('ONLY.CORE', 'CORE', ...
    'QUICK', 'CURRENT', true, 'PASS', 'ok');
coverage = st_verification_catalog_coverage(catalog, checks, options);
verifyEqual(testCase, coverage.Status(coverage.FeatureId == "CORE"), ...
    "PASS");
verifyTrue(testCase, all(coverage.Status(coverage.FeatureId ~= "CORE") ...
    == "FAIL"));
end

function testJUnitStatusMapping(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
checks = [check('PASS', true); check('FAIL', true); ...
    check('BLOCKED', true); check('SKIP', false); check('WARN', false)];
path = fullfile(folder, 'junit.xml');
st_write_verification_junit(path, checks);
text = fileread(path);
verifySubstring(testCase, text, 'failures="1"');
verifySubstring(testCase, text, 'skipped="2"');
verifySubstring(testCase, text, '<failure');
verifySubstring(testCase, text, '<skipped');
verifySubstring(testCase, text, 'WARN:');
end

function testManualEvidenceRequiresCurrentFingerprintAndFile(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
evidencePath = fullfile(folder, 'report.png');
fileId = fopen(evidencePath, 'w');
fprintf(fileId, 'evidence');
fclose(fileId);
entry = struct( ...
    'CheckId', 'MANUAL.REPORT_VISUAL', 'Status', 'PASS', ...
    'VerifiedBy', 'reviewer', ...
    'VerifiedAt', '2026-08-30T15:00:00+09:00', ...
    'TargetFingerprint', 'fingerprint', 'Notes', 'checked', ...
    'EvidencePaths', {{evidencePath}});
jsonPath = fullfile(folder, 'manual.json');
fileId = fopen(jsonPath, 'w');
fprintf(fileId, '%s', jsonencode(struct('Checks', entry)));
fclose(fileId);
options = st_parse_verification_options( ...
    'Profile', 'CERTIFY', 'Target', 'CURRENT', ...
    'ManualEvidence', jsonPath);
[checks, evidence] = st_verification_manual_checks( ...
    st_verification_catalog(), options, 'fingerprint');
row = checks.CheckId == "MANUAL.REPORT_VISUAL";
verifyEqual(testCase, checks.Status(row), "PASS");
verifyEqual(testCase, evidence.Status( ...
    evidence.CheckId == "MANUAL.REPORT_VISUAL"), "PASS");
end

function testCapabilityExceptionClassification(testCase)
blocked = MException('MATLAB:license:checkout', ...
    'License checkout failed');
defect = MException('simtest:Unexpected', 'Incorrect result');
verifyEqual(testCase, st_verification_exception_status(blocked), ...
    'BLOCKED');
verifyEqual(testCase, st_verification_exception_status(defect), 'FAIL');
end

function testReportWritesRequiredArtifactsAndSheets(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
runDirectory = fullfile(folder, 'runs', 'unit_run');
mkdir(runDirectory);
options = st_parse_verification_options('FailOnNonPass', false);
checks = check('PASS', true);
catalog = st_verification_catalog();
features = st_verification_feature_status(catalog, checks);
environment = table("MATLAB", string(version), true, true, true, ...
    "PASS", "Available", 'VariableNames', {'Name','Version','Required', ...
    'Installed','Licensed','Status','Detail'});
manual = empty_manual_table();
cfg = struct('VerificationRootDir', folder);
report = st_write_verification_report(runDirectory, 'unit_run', ...
    options, checks, environment, features, manual, cfg);
verifyEqual(testCase, report.Status, 'PASS');
verifyTrue(testCase, isfile(report.Summary));
verifyTrue(testCase, isfile(report.JSON));
verifyTrue(testCase, isfile(report.JUnit));
verifyTrue(testCase, isfile(report.Manifest));
verifyTrue(testCase, isfile(fullfile(folder, 'latest.json')));
actualSheets = string(sheetnames(report.Summary));
verifyEqual(testCase, actualSheets(:), ...
    ["Overview"; "Features"; "Checks"; "Environment"; ...
    "ManualEvidence"; "Artifacts"]);
end

function testFixtureBuilderDeclaresAllRequiredScenarios(testCase)
path = fullfile(st_project_root(), 'tests', 'fixtures', ...
    'st_build_verification_fixture.m');
verifyTrue(testCase, isfile(path));
text = fileread(path);
required = {'ScalarApply','NumericArray','NestedBus','BusArray', ...
    'NoInportOff','SldvBranch','GENERATE','APPLY','OFF'};
for i = 1:numel(required)
    verifySubstring(testCase, text, required{i});
end
end


function testQuickInspectorContainsNoMutationOrSimulationCalls(testCase)
path = fullfile(st_project_root(), 'src', 'verification', ...
    'st_verification_quick_checks.m');
text = fileread(path);
forbidden = {'save_system(', 'set_param(', 'writetable(', ...
    'st_write_result(', 'run(tf)', 'sim('};
for i = 1:numel(forbidden)
    verifyFalse(testCase, contains(text, forbidden{i}));
end
end

function row = check(status, required)
row = st_verification_check("CHECK." + string(status), 'CORE', ...
    'QUICK', 'UNIT', required, status, lower(status));
end

function T = empty_manual_table()
T = table(strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'CheckId','Status','VerifiedBy','VerifiedAt', ...
    'TargetFingerprint','Notes','EvidencePaths'});
end
