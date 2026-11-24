function tests = test_unreachable_objectives
%TEST_UNREACHABLE_OBJECTIVES SLDV-proved unreachable outcomes read from sldvData.
% The fake data uses the field names measured on real R2025b data. Every
% name carries "Secret"; a WARN reaches the screen, which leaves the
% company, so none may print.
tests = functiontests(localfunctions);
end


function testOnlyDecisionUnsatisfiableAreKept(testCase)
objectives = decision_objectives([1 1 1 1], ...
    ["Unsatisfiable" "Satisfied" "Unsatisfiable" "Excluded"], [1 2 1 1], ...
    ["Secret false" "Secret true" "Secret condition" "Secret false"]);
objectives(3).type = 'Condition';
data = fake_data(model_objects("Secret_Root/Secret_CUT/Secret_Switch", "Switch"), ...
    objectives);

[kept, counts] = st_unreachable_objectives(data, "OFF");

verifyEqual(testCase, height(kept), 1);
verifyEqual(testCase, kept.Sid, "Secret_Root:1");
verifyEqual(testCase, kept.BlockType, "Switch");
verifyEqual(testCase, kept.RelativePath, "Secret_Switch");
verifyEqual(testCase, kept.OutcomeIndex, 1);
verifyEqual(testCase, kept.OutcomeText, "Secret false");
verifyEqual(testCase, kept.Approximate, false);
verifyEqual(testCase, counts.Decision, 3);
verifyEqual(testCase, counts.Unsatisfiable, 1);
end


function testApproximateStatusIsFlagged(testCase)
data = fake_data(model_objects("Secret_Root/Secret_CUT/Secret_Switch", "Switch"), ...
    decision_objectives([1 1], ...
    ["Unsatisfiable" "Unsatisfiable under approximation"], [1 2], ...
    ["Secret false" "Secret true"]));

[kept, counts] = st_unreachable_objectives(data, "OFF");

verifyEqual(testCase, kept.Approximate, [false; true]);
verifyEqual(testCase, kept.OutcomeIndex, [1; 2]);
verifyEqual(testCase, counts.Unsatisfiable, 1);
verifyEqual(testCase, counts.Approximate, 1);
end


function testUndecidedIsCountedNotKept(testCase)
data = fake_data(model_objects("Secret_Root/Secret_CUT/Secret_Switch", "Switch"), ...
    decision_objectives([1 1], ["Undecided" "Undecided due to approximations"], ...
    [1 2], ["Secret false" "Secret true"]));

[kept, counts] = st_unreachable_objectives(data, "OFF");

verifyEqual(testCase, height(kept), 0);
verifyEqual(testCase, counts.Undecided, 2);
verifyEqual(testCase, counts.Decision, 2);
verifyEqual(testCase, counts.Unsatisfiable + counts.Approximate, 0);
end


function testRelativePathDropsRootAndCut(testCase)
% A '/' inside a name is written '//' and stays; so does the newline of a
% default block name. The CUT name itself may hold a '//'.
paths = ["Secret_Root/Secret_CUT/Secret_Switch", ...
    "Secret_Root/Secret_CUT/Secret_Sub/Secret_Max", ...
    "Secret_Root/Secret_CUT/Secret_a//b", ...
    "Secret_Root/Secret//CUT/Secret_Switch", ...
    "Secret_Root/Secret_CUT/Secret" + newline + "Switch"];
data = fake_data(model_objects(paths, repmat("Switch", 1, 5)), ...
    decision_objectives(1:5, repmat("Unsatisfiable", 1, 5), ones(1, 5), ...
    repmat("Secret false", 1, 5)));

kept = st_unreachable_objectives(data, "OFF");

verifyEqual(testCase, kept.RelativePath, ["Secret_Switch"; "Secret_Sub/Secret_Max"; ...
    "Secret_a//b"; "Secret_Switch"; "Secret" + newline + "Switch"]);
end


function testCutItselfIsCountedNotKept(testCase)
data = fake_data(model_objects("Secret_Root/Secret_CUT", "SubSystem"), ...
    decision_objectives(1, "Unsatisfiable", 1, "Secret enable"));

[kept, counts] = st_unreachable_objectives(data, "SUBSYSTEM");

verifyEqual(testCase, height(kept), 0);
verifyEqual(testCase, counts.CutItself, 1);
verifyEqual(testCase, counts.FilteredByCvf, 0);
end


function testCvfOffKeepsAll(testCase)
for mode = ["OFF" ""]
    [kept, counts] = st_unreachable_objectives(cvf_data(), mode);
    verifyEqual(testCase, height(kept), 4);
    verifyEqual(testCase, counts.FilteredByCvf, 0);
end
end


function testCvfSubsystemDropsDirectChildSubsystemOutcomes(testCase)
[kept, counts] = st_unreachable_objectives(cvf_data(), "SUBSYSTEM");

verifyEqual(testCase, kept.RelativePath, ...
    ["Secret_Sub/Secret_Switch"; "Secret_Switch"; "Secret_a//b"]);
verifyEqual(testCase, counts.FilteredByCvf, 1);
end


function testCvfAllContentDropsNestedBlocks(testCase)
% A '//' inside a direct child's name is not a level.
[kept, counts] = st_unreachable_objectives(cvf_data(), "ALL_CONTENT");

verifyEqual(testCase, kept.RelativePath, ["Secret_Switch"; "Secret_a//b"]);
verifyEqual(testCase, counts.FilteredByCvf, 2);
end


function testDesignSidPreferredOverSid(testCase)
objects = model_objects(["Secret_Root/Secret_CUT/Secret_A", ...
    "Secret_Root/Secret_CUT/Secret_B"], ["Switch" "Switch"]);
objects(1).designSid = 'Secret_Design:7';
data = fake_data(objects, decision_objectives([1 2], ...
    ["Unsatisfiable" "Unsatisfiable"], [1 1], ["Secret false" "Secret false"]));

kept = st_unreachable_objectives(data, "OFF");
verifyEqual(testCase, kept.Sid, ["Secret_Design:7"; "Secret_Root:2"]);

% Data without the designSid field uses sid.
data.ModelObjects = rmfield(objects, 'designSid');
kept = st_unreachable_objectives(data, "OFF");
verifyEqual(testCase, kept.Sid, ["Secret_Root:1"; "Secret_Root:2"]);
end


function testDataWithoutObjectivesYieldsNoDefects(testCase)
data = struct('ModelInformation', struct('Name', 'Secret_Model', ...
    'SubsystemPath', 'Secret_Model/Secret_CUT'));
cfg = struct('VerboseLogging', false);
% Declared first: a name only evalc assigns would bind to a function.
kept = [];
counts = [];
output = evalc('[kept, counts] = st_unreachable_objectives(data, "OFF", cfg);');

verifyEqual(testCase, height(kept), 0);
verifyEqual(testCase, kept.Properties.VariableNames, {'Sid','BlockType', ...
    'RelativePath','OutcomeIndex','OutcomeText','Approximate'});
verifyEqual(testCase, counts.Decision, 0);
verifyTrue(testCase, contains(output, "WARN"));
verifyFalse(testCase, contains(output, "Secret"));
% Without cfg nothing prints.
quiet = [];
verifyEmpty(testCase, evalc('quiet = st_unreachable_objectives(data, "OFF");'));
verifyEqual(testCase, height(quiet), 0);
end


function testProfileFillsDefectsAndRethrowsOnlyBadSelector(testCase)
% st_get_sldv_profile reads the prepared data file of an SLDV row.
[target, cfg] = prepared_target(testCase);
profile = st_get_sldv_profile(target, cfg);
verifyEqual(testCase, numel(profile.DefectIterations), 1);
verifyEqual(testCase, profile.DefectIterations.RelativePath, 'Secret_Switch');
verifyEqual(testCase, profile.DefectIterations.Name, st_scenario_name('Secret_CUT', 4));
verifyEqual(testCase, profile.DefectIterations.SourceIndex, 2);

% The toggle turns it off.
cfg.UnreachableDefectTests = false;
verifyEmpty(testCase, st_get_sldv_profile(target, cfg).DefectIterations);
cfg.UnreachableDefectTests = true;

% A DefectInputScenario naming no scenario is the user's to fix.
target.DefectInputScenario = "9";
verifyError(testCase, @() st_get_sldv_profile(target, cfg), ...
    'simtest:DefectInputScenarioInvalid');
target.DefectInputScenario = "";

% An unreadable data file leaves the list empty and the profile usable.
fileId = fopen(char(target.SldvDataFile), 'w');
fprintf(fileId, 'Secret not a MAT-file');
fclose(fileId);
profile = [];
output = evalc('profile = st_get_sldv_profile(target, cfg);');
verifyEmpty(testCase, profile.DefectIterations);
verifyEqual(testCase, profile.Status, 'OK');
verifyTrue(testCase, contains(output, "WARN"));
verifyFalse(testCase, contains(output, "Secret"));
end


function data = cvf_data()
% A subsystem directly below the CUT with an outcome of its own (Enable),
% a block inside it, a block directly below the CUT, and a direct child
% whose name holds a '/'.
data = fake_data(model_objects(["Secret_Root/Secret_CUT/Secret_Sub", ...
    "Secret_Root/Secret_CUT/Secret_Sub/Secret_Switch", ...
    "Secret_Root/Secret_CUT/Secret_Switch", ...
    "Secret_Root/Secret_CUT/Secret_a//b"], ...
    ["SubSystem" "Switch" "Switch" "Switch"]), ...
    decision_objectives(1:4, repmat("Unsatisfiable", 1, 4), ones(1, 4), ...
    repmat("Secret false", 1, 4)));
end


function data = fake_data(objects, objectives)
data = struct();
data.ModelInformation = struct('Name', 'Secret_Model', ...
    'SubsystemPath', 'Secret_Model/Secret_CUT');
data.ModelObjects = objects;
data.Objectives = objectives;
end


function objects = model_objects(slPaths, typeDescs)
count = numel(slPaths);
objects = struct('descr', 'Secret block', 'typeDesc', cellstr(typeDescs), ...
    'slPath', cellstr(slPaths), ...
    'sid', cellstr(compose("Secret_Root:%d", 1:count)), 'designSid', '');
end


function objectives = decision_objectives(objectIdx, statuses, outcomeValues, descrs)
objectives = struct('type', 'Decision', 'status', cellstr(statuses), ...
    'descr', cellstr(descrs), 'label', 'Secret label', ...
    'outcomeValue', num2cell(outcomeValues), 'modelObjectIdx', num2cell(objectIdx));
end


function [target, cfg] = prepared_target(testCase)
% A FILE/SLDV row whose manifest profile has three scenarios, and its data
% file with one unsatisfiable Switch outcome. DefectInputScenario "2".
folder = tempname;
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
dataFile = fullfile(folder, 'Secret_sldvdata.mat');
sldvData = fake_data(model_objects("Secret_Root/Secret_CUT/Secret_Switch", "Switch"), ...
    decision_objectives(1, "Unsatisfiable", 1, "Secret false")); %#ok<NASGU>
save(dataFile, 'sldvData');
target = table(1, "Secret_CUT", "Secret_Model/Secret_CUT", "Secret_Harness", ...
    "Secret_Case", "FILE", string(dataFile), "2", "OFF", ...
    'VariableNames', {'No','CUTName','CUTPath','HarnessName', ...
    'TestCaseName','SldvMode','SldvDataFile','DefectInputScenario', ...
    'CoverageFilterMode'});
names = {st_scenario_name('Secret_CUT', 1), st_scenario_name('Secret_CUT', 2), ...
    st_scenario_name('Secret_CUT', 3)};
profile = struct('No', 1, 'CUTName', 'Secret_CUT', ...
    'CUTPath', 'Secret_Model/Secret_CUT', 'HarnessName', 'Secret_Harness', ...
    'TestCaseName', 'Secret_Case', 'Mode', 'FILE', ...
    'RequestedDataFile', dataFile, 'EffectiveDataFile', dataFile, ...
    'ScenarioNames', {names}, 'Status', 'OK', 'Message', '');
manifest = struct('TopModel', 'Secret_Model', 'Profiles', profile); %#ok<NASGU>
manifestFile = fullfile(folder, 'sldv_manifest.mat');
save(manifestFile, 'manifest');
cfg = struct('SldvManifestFile', manifestFile, 'TopModel', 'Secret_Model', ...
    'UnreachableDefectTests', true, 'VerboseLogging', false);
end
