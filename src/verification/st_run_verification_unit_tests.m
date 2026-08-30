function checks = st_run_verification_unit_tests(profile, runDirectory)
%ST_RUN_VERIFICATION_UNIT_TESTS Run unit regression with official JUnit XML.

checks = st_empty_verification_checks();
started = timestamp_text();
timerValue = tic;
try
    import matlab.unittest.TestSuite
    import matlab.unittest.plugins.XMLPlugin
    suite = TestSuite.fromFolder( ...
        fullfile(st_project_root(), 'tests', 'unit'));
    runner = testrunner('minimal');
    officialJunit = fullfile(runDirectory, 'logs', 'matlab-unit-junit.xml');
    addPlugin(runner, XMLPlugin.producingJUnitFormat(officialJunit));
    results = run(runner, suite);
    for i = 1:numel(results)
        status = result_status(results(i));
        feature = unit_feature(results(i).Name);
        checks = [checks; st_verification_check( ...
            "UNIT." + safe_id(results(i).Name), feature, profile, ...
            'UNIT', true, status, result_message(results(i)), ...
            officialJunit, duration_seconds(results(i).Duration), started, ...
            timestamp_text())]; %#ok<AGROW>
    end
    if isempty(results)
        checks = st_verification_check('UNIT_SUITE', 'CORE', profile, ...
            'UNIT', true, 'BLOCKED', 'No unit tests were discovered', ...
            officialJunit, toc(timerValue), started, timestamp_text());
    end
catch ME
    checks = st_verification_check('UNIT_SUITE', 'CORE', profile, ...
        'UNIT', true, 'FAIL', ME.message, '', toc(timerValue), ...
        started, timestamp_text());
end
end

function value = duration_seconds(value)
if isduration(value), value = seconds(value); end
value = double(value);
if ~isscalar(value) || ~isfinite(value), value = 0; end
end

function status = result_status(result)
if result.Failed
    status = 'FAIL';
elseif result.Incomplete
    status = 'BLOCKED';
else
    status = 'PASS';
end
end

function text = result_message(result)
if result.Passed
    text = "Unit test passed";
elseif result.Failed
    text = "Unit test failed";
else
    text = "Unit test incomplete";
end
end

function feature = unit_feature(name)
name = lower(string(name));
if contains(name, 'export')
    feature = "EXPORT";
elseif contains(name, 'incremental')
    feature = "CACHE";
elseif contains(name, 'report') || contains(name, 'coverage')
    feature = "REPORTING";
elseif contains(name, 'sldv')
    feature = "SLDV";
elseif contains(name, 'expected')
    feature = "EXPECTED_UPDATE";
elseif contains(name, 'project') || contains(name, 'config')
    feature = "CONFIG";
else
    feature = "CORE";
end
end

function value = safe_id(value)
value = upper(regexprep(char(string(value)), '[^A-Za-z0-9]+', '_'));
end

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
