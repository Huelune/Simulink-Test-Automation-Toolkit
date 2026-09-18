function tests = test_scenario_name_identifier
%TEST_SCENARIO_NAME_IDENTIFIER Scenario names stay valid MATLAB identifiers.
%
% A scenario name becomes a Test Sequence and Signal Editor identifier. A
% CUT name is free text, so it can carry a character an identifier cannot
% hold, or be long enough to pass namelengthmax.
tests = functiontests(localfunctions);
end

function testShortValidNameIsUnchanged(testCase)
% The existing contract must survive byte for byte, otherwise every
% scenario, Harness and Test File already built would have to be recreated.
verifyEqual(testCase, st_scenario_name('Controller', 1), ...
    'UT_REQ_Controller_001');
verifyEqual(testCase, st_scenario_name('Controller', 999), ...
    'UT_REQ_Controller_999');
end

function testSlashInNameBecomesUnderscore(testCase)
verifyEqual(testCase, st_scenario_name('AC/DC_Check', 1), ...
    'UT_REQ_AC_DC_Check_001');
end

function testOverlongNameIsCutAndDigested(testCase)
% The real case: 62 characters of CUT name plus prefix and index is 73,
% which no amount of character replacement brings under the limit.
cutName = 'OBC_Operating_State_StartCharging_StartDischarging_AC/DC_Check';
name = st_scenario_name(cutName, 1);

verifyTrue(testCase, isvarname(name));
verifyLessThanOrEqual(testCase, numel(name), namelengthmax);
verifyTrue(testCase, startsWith(name, 'UT_REQ_OBC_Operating_State_'));
verifyTrue(testCase, endsWith(name, '_001'));
end

function testDigestSeparatesNamesThatSanitiseAlike(testCase)
% 'A/B' and 'A_B' collapse to the same stem in step 1. The digest is taken
% from the original name so their scenarios stay distinct.
long = repmat('x', 1, 60);
first = st_scenario_name([long '/B'], 1);
second = st_scenario_name([long '_B'], 1);

verifyTrue(testCase, isvarname(first));
verifyTrue(testCase, isvarname(second));
verifyNotEqual(testCase, first, second);
end

function testSameNameAlwaysGivesTheSameScenario(testCase)
% The rewrite has to be deterministic across sessions, or a rerun would
% stop matching the scenarios already written into the Harness.
cutName = 'OBC_Operating_State_StartCharging_StartDischarging_AC/DC_Check';
verifyEqual(testCase, st_scenario_name(cutName, 3), ...
    st_scenario_name(cutName, 3));
end

function testIndexStillDistinguishesScenarios(testCase)
cutName = 'OBC_Operating_State_StartCharging_StartDischarging_AC/DC_Check';
verifyNotEqual(testCase, st_scenario_name(cutName, 1), ...
    st_scenario_name(cutName, 2));
end

function testIndexValidationIsUnchanged(testCase)
% The index error carries no identifier, so catch it the way the existing
% naming test does rather than matching one.
didThrow = false;
try
    st_scenario_name('Controller', 0);
catch
    didThrow = true;
end
verifyTrue(testCase, didThrow);
end
