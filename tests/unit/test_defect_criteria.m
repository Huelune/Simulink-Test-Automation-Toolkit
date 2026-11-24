function tests = test_defect_criteria
tests = functiontests(localfunctions);
end


function testScriptIsSelfContainedAndMarked(testCase)
script = st_defect_criteria_script(sample_defects());
scriptLines = splitlines(string(script));

verifyEqual(testCase, scriptLines(1), "% simtest:unreachable-defect-criteria v1");
verifyEmpty(testCase, regexp(script, '\<st_\w+\(', 'once'));
% Test Manager stores and runs this text; character codes keep it ASCII.
verifyTrue(testCase, all(double(script) < 128));
% One statement per line, as in the verified probe callback.
verifyFalse(testCase, contains(script, '...'));
end


function testScriptNamesEveryDefectIteration(testCase)
defects = sample_defects();
script = st_defect_criteria_script(defects);

for k = 1:numel(defects)
    verifyTrue(testCase, contains(script, ['''' defects(k).Name '''']), defects(k).Name);
end
end


function testScriptRaisesInsteadOfFailingWithoutCoverage(testCase)
script = st_defect_criteria_script(sample_defects());

verifyTrue(testCase, contains(script, 'simtest:DefectCriteriaNoCoverage'));
verifyEmpty(testCase, regexp(script, ...
    '(verify|assert)\w*\([^\n]*\<(false|true)\>', 'once'));
verifyEmpty(testCase, regexp(script, ...
    '(verify|assert)\w*\(\s*(test\s*,\s*)?[0-9]', 'once'));
end


function testScriptTableKeepsAwkwardPathsExactly(testCase)
% A block name may hold a newline, a quote or an escaped '/'; the callback
% finds the harness block by this exact path.
defects = sample_defects();
defects(2).RelativePath = sprintf('Secret_Sub//A\nB/Secret''s Max');
defects(2).Outcomes(1).Text = ['input' char(9) '1 ' char(233)];
script = st_defect_criteria_script(defects);

[paths, texts] = evaluate_table(script);
verifyEqual(testCase, paths, {defects.RelativePath}');
verifyEqual(testCase, texts{2}, {defects(2).Outcomes.Text});
verifyTrue(testCase, all(double(script) < 128));
end


function testScriptPassesAnIterationThatIsNoDefect(testCase)
script = st_defect_criteria_script(sample_defects());
fakeTest = struct('sltest_iterationName', st_scenario_name("Secret_CUT", 1));

verifyWarningFree(testCase, @() run_script(script, fakeTest));
end


function testScriptRaisesForADefectIterationWithoutCoverage(testCase)
defects = sample_defects();
script = st_defect_criteria_script(defects);
byProperty = struct('sltest_iterationName', defects(1).Name);
byResultName = struct('sltest_iterationName', 'Secret other name', ...
    'TestResult', struct('Name', defects(2).Name));

verifyError(testCase, @() run_script(script, byProperty), ...
    'simtest:DefectCriteriaNoCoverage');
verifyError(testCase, @() run_script(script, byResultName), ...
    'simtest:DefectCriteriaNoCoverage');
try
    run_script(script, byProperty);
catch err
    verifyFalse(testCase, contains(err.message, 'Secret'));
end
end


function testScriptRaisesWhenNoIterationNameIsReadable(testCase)
% Without a readable name a defect iteration would pass unjudged.
script = st_defect_criteria_script(sample_defects());
noName = struct('Secret_other', 1);
nameOnlyInResult = struct('TestResult', struct('Name', 'Secret not a defect'));

verifyError(testCase, @() run_script(script, noName), ...
    'simtest:DefectCriteriaNoIterationName');
try
    run_script(script, noName);
catch err
    verifyFalse(testCase, contains(err.message, 'Secret'));
end
% One readable name that is no defect passes.
verifyWarningFree(testCase, @() run_script(script, nameOnlyInResult));
end


function testCriteriaActionSetsWhenDefectsExist(testCase)
defects = sample_defects();
own = st_defect_criteria_script(defects);

verifyEqual(testCase, st_defect_criteria_action('', defects), 'SET');
verifyEqual(testCase, st_defect_criteria_action(sprintf(' \n'), defects), 'SET');
verifyEqual(testCase, st_defect_criteria_action(own, defects), 'SET');
verifyEqual(testCase, st_defect_criteria_action(string(own), defects), 'SET');
end


function testCriteriaActionClearsOwnCallbackWhenNoDefects(testCase)
own = st_defect_criteria_script(sample_defects());

verifyEqual(testCase, st_defect_criteria_action(own, no_defects()), 'CLEAR');
% A later script version still carries the marker without "v1".
verifyEqual(testCase, st_defect_criteria_action( ...
    sprintf('%% simtest:unreachable-defect-criteria v2\nx = 1;'), no_defects()), 'CLEAR');
end


function testCriteriaActionLeavesForeignCallbackWithoutDefects(testCase)
verifyEqual(testCase, st_defect_criteria_action(foreign_callback(), no_defects()), 'NONE');
verifyEqual(testCase, st_defect_criteria_action('', no_defects()), 'NONE');
end


function testCriteriaActionRefusesForeignCallback(testCase)
defects = sample_defects();

verifyError(testCase, @() st_defect_criteria_action(foreign_callback(), defects), ...
    'simtest:DefectCriteriaForeign');
try
    st_defect_criteria_action(foreign_callback(), defects);
catch err
    verifySubstring(testCase, err.message, 'Custom Criteria');
    verifySubstring(testCase, err.message, 'cfg.UnreachableDefectTests=false');
    verifyFalse(testCase, contains(err.message, 'Secret'));
end
end


function run_script(script, test) %#ok<INUSD> test is read by the script
eval(script);
end


function [paths, texts] = evaluate_table(script)
% The non-defect path runs no coverage or model call, so the whole script
% evaluates and leaves its constant table behind.
test = struct('sltest_iterationName', 'not a defect'); %#ok<NASGU> read by the script
eval(script);
paths = eval('dcPaths');
texts = eval('dcTexts');
end


function text = foreign_callback()
text = sprintf('%% Secret hand-written criteria\ntest.verifyTrue(Secret_signal > 0);');
end


function defects = no_defects()
defects = st_build_defect_iterations();
end


function defects = sample_defects()
defects = st_build_defect_iterations();
outcome = struct('Index', 0, 'Text', '', 'Approximate', false);
defects(1).Name = char(st_scenario_name("Secret_CUT", 4));
defects(1).SourceScenario = char(st_scenario_name("Secret_CUT", 3));
defects(1).SourceIndex = 3;
defects(1).BlockType = 'Switch';
defects(1).RelativePath = 'Secret_Switch';
defects(1).Sid = 'Secret:12';
defects(1).Outcomes = outcome;
defects(1).Outcomes.Index = 2;
defects(1).Outcomes.Text = 'false (output is from 3rd input port)';
defects(2).Name = char(st_scenario_name("Secret_CUT", 5));
defects(2).SourceScenario = char(st_scenario_name("Secret_CUT", 3));
defects(2).SourceIndex = 3;
defects(2).BlockType = 'MinMax';
defects(2).RelativePath = 'Secret_Sub/Secret_Max';
defects(2).Sid = 'Secret:34';
defects(2).Outcomes = [outcome; outcome];
defects(2).Outcomes(1).Index = 1;
defects(2).Outcomes(1).Text = 'input 1';
defects(2).Outcomes(2).Index = 2;
defects(2).Outcomes(2).Text = 'input 2';
defects(2).Outcomes(2).Approximate = true;
defects = defects(:);
end
