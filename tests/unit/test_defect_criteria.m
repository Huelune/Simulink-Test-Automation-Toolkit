function tests = test_defect_criteria
tests = functiontests(localfunctions);
end


function testScriptIsSelfContainedAndMarked(testCase)
script = st_defect_criteria_script(sample_defects(), 'Secret_CUT');
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
script = st_defect_criteria_script(defects, 'Secret_CUT');

for k = 1:numel(defects)
    verifyTrue(testCase, contains(script, ['''' defects(k).Name '''']), defects(k).Name);
end
end


function testScriptRaisesInsteadOfFailingWithoutCoverage(testCase)
script = st_defect_criteria_script(sample_defects(), 'Secret_CUT');

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
cutName = sprintf('Secret//C
U%sT', char(233));
script = st_defect_criteria_script(defects, cutName);

[paths, texts, cut] = evaluate_table(script);
verifyEqual(testCase, paths, {defects.RelativePath}');
verifyEqual(testCase, texts{2}, {defects(2).Outcomes.Text});
verifyEqual(testCase, cut, cutName);
verifyTrue(testCase, all(double(script) < 128));
end


function testScriptBuildsTheBlockPathFromItsCutName(testCase)
% In a standalone bundle the Test Case points at the exported model with no
% harness owner, so the CUT block name is a constant, not read from
% test.sltest_sut. The path is built before coverage is read.
defects = sample_defects();
script = st_defect_criteria_script(defects, 'Secret//CUT');
fakeTest = struct('sltest_iterationName', defects(2).Name, ...
    'sltest_bdroot', 'Secret_Model', 'TestResult', struct('Name', defects(2).Name));

[block, err] = built_block_path(script, fakeTest);
verifyEqual(testCase, block, 'Secret_Model/Secret//CUT/Secret_Sub/Secret_Max');
verifyEqual(testCase, err.identifier, 'simtest:DefectCriteriaNoCoverage');
verifyFalse(testCase, contains(script, 'sltest_sut'));
verifyFalse(testCase, contains(script, 'get_param'));
end


function testTestManagerPassesTheLastCutPathElement(testCase)
% st_create_test_manager needs Simulink Test, so this pins by source what
% it passes: the last element of profile.CUTPath, a '//' kept.
source = fileread(fullfile(st_project_root(), 'src', 'test_manager', ...
    'st_create_test_manager.m'));
verifyTrue(testCase, contains(source, ...
    'cutParts = regexp(char(profile.CUTPath), ''(?<!/)/(?!/)'', ''split'');'));
verifyTrue(testCase, contains(source, ...
    'st_defect_criteria_script(defects, cutParts{end})'));
end


function testTestManagerStartLogCountsUndecided(testCase)
% Undecided outcomes never become defects, so the start line counts them.
source = fileread(fullfile(st_project_root(), 'src', 'test_manager', ...
    'st_create_test_manager.m'));
verifyNotEmpty(testCase, regexp(source, ...
    '\[UnreachableDefect\] start \|[^\n]*\n[^\n]*Undecided=%d', 'once'));
verifyTrue(testCase, contains(source, 'counts.Undecided'));
end


function testScriptPassesAnIterationThatIsNoDefect(testCase)
script = st_defect_criteria_script(sample_defects(), 'Secret_CUT');
fakeTest = struct('sltest_iterationName', st_scenario_name("Secret_CUT", 1));

verifyWarningFree(testCase, @() run_script(script, fakeTest));
end


function testScriptRaisesForADefectIterationWithoutCoverage(testCase)
defects = sample_defects();
script = st_defect_criteria_script(defects, 'Secret_CUT');
% With sltest_bdroot the block path is built, so coverage is what fails.
byProperty = struct('sltest_iterationName', defects(1).Name, ...
    'sltest_bdroot', 'Secret_Model');
byResultName = struct('sltest_iterationName', 'Secret other name', ...
    'sltest_bdroot', 'Secret_Model', 'TestResult', struct('Name', defects(2).Name));

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
script = st_defect_criteria_script(sample_defects(), 'Secret_CUT');
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
own = st_defect_criteria_script(defects, 'Secret_CUT');

verifyEqual(testCase, st_defect_criteria_action('', defects), 'SET');
verifyEqual(testCase, st_defect_criteria_action(sprintf(' \n'), defects), 'SET');
verifyEqual(testCase, st_defect_criteria_action(own, defects), 'SET');
verifyEqual(testCase, st_defect_criteria_action(string(own), defects), 'SET');
end


function testCriteriaActionClearsOwnCallbackWhenNoDefects(testCase)
own = st_defect_criteria_script(sample_defects(), 'Secret_CUT');

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


function [paths, texts, cut] = evaluate_table(script)
% The non-defect path runs no coverage or model call, so the whole script
% evaluates and leaves its constant table behind.
test = struct('sltest_iterationName', 'not a defect'); %#ok<NASGU> read by the script
eval(script);
paths = eval('dcPaths');
texts = eval('dcTexts');
cut = eval('dcCut');
end


function [block, err] = built_block_path(script, test) %#ok<INUSD> test is read by the script
% A struct has no coverage, so a defect iteration stops at reading it,
% after the block path is built. The error is returned for the caller.
err = [];
try
    eval(script);
catch err
end
block = eval('dcBlock');
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
