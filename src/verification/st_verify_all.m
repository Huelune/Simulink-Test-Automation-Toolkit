function summary = st_verify_all(varargin)
%ST_VERIFY_ALL Run project-wide verification and preserve machine-readable results.
%
% summary = st_verify_all('Profile','QUICK','Target','CURRENT', ...
%     'ManualEvidence','','KeepWorkspace','ON_FAILURE', ...
%     'FailOnNonPass',true)

options = st_parse_verification_options(varargin{:});
cfg = st_config();
[runId, runDirectory] = create_run_directory(cfg.VerificationRootDir);
workspaceDirectory = fullfile(runDirectory, 'workspace');
mkdir(fullfile(runDirectory, 'logs'));
mkdir(fullfile(runDirectory, 'evidence'));
mkdir(workspaceDirectory);

checks = st_empty_verification_checks();
environment = empty_environment();
manualEvidence = empty_manual_evidence();
catalog = st_verification_catalog();

fprintf('\n============================================\n');
fprintf('Comprehensive Verification\n');
fprintf('Profile : %s\n', options.Profile);
fprintf('Target  : %s\n', options.Target);
fprintf('Run ID  : %s\n', runId);
fprintf('============================================\n');

catalogIssues = st_validate_verification_catalog(catalog);
if isempty(catalogIssues)
    checks = append_check(checks, st_verification_check( ...
        'CATALOG.SCHEMA', 'CORE', options.Profile, options.Target, ...
        true, 'PASS', 'Feature catalog is complete and check IDs are unique'));
else
    checks = append_check(checks, st_verification_check( ...
        'CATALOG.SCHEMA', 'CORE', options.Profile, options.Target, ...
        true, 'FAIL', strjoin(string(catalogIssues), ' | ')));
end

try
    [environment, environmentChecks] = ...
        st_verification_environment(options.Profile);
    checks = [checks; environmentChecks];
catch ME
    checks = append_exception(checks, 'ENV.INSPECTION', 'CORE', ...
        options, ME, true);
end

try
    unitChecks = st_run_verification_unit_tests( ...
        options.Profile, runDirectory);
    checks = [checks; unitChecks];
catch ME
    checks = append_exception(checks, 'UNIT.RUNNER', 'CORE', ...
        options, ME, true);
end

runtimeBlocked = ~isempty(environment) && ...
    any(environment.Required & environment.Status == "BLOCKED");
if any(strcmp(options.Target, {'CURRENT','BOTH'})) && ~runtimeBlocked
    try
        checks = [checks; st_verification_quick_checks(cfg, options)];
    catch ME
        checks = append_exception(checks, 'QUICK.CURRENT', 'CORE', ...
            options, ME, true);
    end
elseif any(strcmp(options.Target, {'CURRENT','BOTH'}))
    checks = append_check(checks, st_verification_check( ...
        'QUICK.CAPABILITY', 'CORE', options.Profile, options.Target, ...
        true, 'BLOCKED', ...
        'Required MATLAB products or license checks are blocked'));
end

if strcmp(options.Target, 'FIXTURE')
    checks = append_check(checks, st_verification_check( ...
        'QUICK.CURRENT', 'CORE', options.Profile, options.Target, ...
        false, 'SKIP', 'CURRENT target was not selected'));
end

if strcmp(options.Profile, 'QUICK')
    if any(strcmp(options.Target, {'FIXTURE','BOTH'}))
        fixtureBuilder = fullfile(st_project_root(), 'tests', ...
            'fixtures', 'st_build_verification_fixture.m');
        if isfile(fixtureBuilder)
            status = 'PASS'; message = 'Fixture builder is available';
        else
            status = 'FAIL'; message = 'Fixture builder is missing';
        end
        checks = append_check(checks, st_verification_check( ...
            'FIXTURE.BUILDER', 'CORE', options.Profile, options.Target, ...
            true, status, message, fixtureBuilder));
    end
elseif ~runtimeBlocked
    try
        runtimeChecks = st_run_verification_runtime( ...
            cfg, options, runDirectory, workspaceDirectory);
        checks = [checks; runtimeChecks];
    catch ME
        checks = append_exception(checks, 'RUNTIME.RUNNER', ...
            'EXECUTION', options, ME, true);
    end
else
    checks = append_check(checks, st_verification_check( ...
        'RUNTIME.CAPABILITY', 'EXECUTION', options.Profile, ...
        options.Target, true, 'BLOCKED', ...
        'Runtime verification requires the blocked products and licenses'));
end

targetFingerprint = '';
if any(strcmp(options.Target, {'CURRENT','BOTH'}))
    try
        targetFingerprint = st_verification_target_fingerprint(cfg);
    catch
        targetFingerprint = '';
    end
end
try
    [manualChecks, manualEvidence] = st_verification_manual_checks( ...
        catalog, options, targetFingerprint);
    checks = [checks; manualChecks];
    if ~isempty(options.ManualEvidence) && isfile(options.ManualEvidence)
        archivedEvidence = st_archive_verification_evidence( ...
            options.ManualEvidence, fullfile(runDirectory, 'evidence'));
        checks = [checks; st_verification_check( ...
            'MANUAL.EVIDENCE_ARCHIVE', 'GUI', options.Profile, ...
            options.Target, strcmp(options.Profile, 'CERTIFY'), 'PASS', ...
            sprintf('%d manual evidence file(s) archived', ...
            numel(archivedEvidence)), fullfile(runDirectory, 'evidence'))];
    end
catch ME
    checks = append_exception(checks, 'MANUAL.EVIDENCE', 'GUI', ...
        options, ME, strcmp(options.Profile, 'CERTIFY'));
end

checks = [checks; st_verification_catalog_coverage( ...
    catalog, checks, options)];

features = st_verification_feature_status(catalog, checks);
report = st_write_verification_report(runDirectory, runId, options, ...
    checks, environment, features, manualEvidence, cfg);
summary = report;
summary.Profile = options.Profile;
summary.Target = options.Target;
summary.Environment = environment;
summary.Features = st_verification_feature_status(catalog, report.Checks);
summary.Workspace = workspaceDirectory;

preserveWorkspace = strcmp(options.KeepWorkspace, 'ALWAYS') || ...
    (strcmp(options.KeepWorkspace, 'ON_FAILURE') && ...
    any(strcmp(report.Status, {'FAIL','BLOCKED'})));
if ~preserveWorkspace && isfolder(workspaceDirectory)
    rmdir(workspaceDirectory, 's');
    summary.Workspace = '';
end

fprintf('\nVerification status : %s\n', report.Status);
fprintf('Result directory    : %s\n', runDirectory);
if preserveWorkspace
    fprintf('Workspace preserved : %s\n', workspaceDirectory);
end

if options.FailOnNonPass && any(strcmp(report.Status, {'FAIL','BLOCKED'}))
    error('simtest:VerificationNonPass', ...
        'Verification completed with status %s. Results: %s', ...
        report.Status, runDirectory);
end
end

function [runId, runDirectory] = create_run_directory(rootDirectory)
if ~isfolder(rootDirectory), mkdir(rootDirectory); end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
token = lower(dec2hex(randi([0, 16^6 - 1]), 6));
runId = [stamp '_' token];
runDirectory = fullfile(rootDirectory, 'runs', runId);
while isfolder(runDirectory)
    token = lower(dec2hex(randi([0, 16^6 - 1]), 6));
    runId = [stamp '_' token];
    runDirectory = fullfile(rootDirectory, 'runs', runId);
end
mkdir(runDirectory);
end

function checks = append_exception( ...
        checks, checkId, featureId, options, ME, required)
status = st_verification_exception_status(ME);
checks = append_check(checks, st_verification_check( ...
    checkId, featureId, options.Profile, options.Target, required, ...
    status, sprintf('%s: %s', ME.identifier, ME.message)));
end

function checks = append_check(checks, row)
checks = [checks; row];
end

function T = empty_environment()
T = table(strings(0,1), strings(0,1), false(0,1), false(0,1), ...
    false(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'Name','Version','Required','Installed', ...
    'Licensed','Status','Detail'});
end

function T = empty_manual_evidence()
T = table(strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'CheckId','Status','VerifiedBy','VerifiedAt', ...
    'TargetFingerprint','Notes','EvidencePaths'});
end
