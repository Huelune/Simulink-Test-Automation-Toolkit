function tests = test_create_demo_model
%TEST_CREATE_DEMO_MODEL The demo model compiles and matches its inputs and Excel.
% Generates into a temporary folder, so it needs Simulink but no SLDV and
% runs no test.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
if bdIsLoaded('ST_DemoModel')
    close_system('ST_DemoModel', 0);
end
root = tempname;
testCase.TestData.Root = root;
testCase.TestData.Demo = st_create_demo_model(root);
end

function teardownOnce(testCase)
if bdIsLoaded('ST_DemoModel')
    close_system('ST_DemoModel', 0);
end
if isfolder(testCase.TestData.Root)
    rmdir(testCase.TestData.Root, 's');
end
end

function testFilesAndTargetRowsAreWritten(testCase)
demo = testCase.TestData.Demo;
verifyTrue(testCase, isfile(demo.ModelFile));
verifyTrue(testCase, isfile(demo.ManagementExcel));
T = readtable(demo.ManagementExcel, 'Sheet', 'Targets', 'TextType', 'string');
verifyEqual(testCase, height(T), 7);
verifyEqual(testCase, sum(T.SldvMode == "GENERATE"), 2);
verifyEqual(testCase, sum(T.SldvMode == "FILE"), 5);
verifyTrue(testCase, all(startsWith(T.TestCaseName, T.CUTName + "_")));
fileRows = T(T.SldvMode == "FILE", :);
verifyTrue(testCase, all(isfile(fileRows.SldvDataFile)));
% The standalone pipeline rejects any row without this policy.
verifyTrue(testCase, all(T.CoverageFilterMode == "ALL_CONTENT"));
verifyTrue(testCase, all(T.CoverageBoundaryMode == "CUT_ONLY"));
verifyTrue(testCase, all(T.CoverageFilterAction == "EXCLUDE"));
verifyTrue(testCase, all(strlength(T.CoverageFilterRationale) > 0));
end

function testDatasetElementsMatchCutInportsInPortOrder(testCase)
demo = testCase.TestData.Demo;
load_model(demo);
T = demo.Targets(demo.Targets.SldvMode == "FILE", :);
for k = 1:height(T)
    expected = inport_names(char(T.CUTPath(k)));
    data = load(T.SldvDataFile(k));
    variables = fieldnames(data);
    verifyNotEmpty(testCase, variables);
    for v = 1:numel(variables)
        actual = string(getElementNames(data.(variables{v})));
        verifyEqual(testCase, actual(:).', ...
            expected, sprintf('%s %s', T.CUTName(k), variables{v}));
    end
end
end

function testModelCompiles(testCase)
demo = testCase.TestData.Demo;
load_model(demo);
model = demo.TopModel;
feval(model, [], [], [], 'compile');
feval(model, [], [], [], 'term');
end

function testEveryInputPortIsConnected(testCase)
% A dangling input still compiles (it reads 0), which once left the If of
% ModeSelect always false. Data, enable, trigger and action ports all count.
demo = testCase.TestData.Demo;
load_model(demo);
blocks = find_system(demo.TopModel, 'LookUnderMasks', 'all', 'Type', 'Block');
dangling = strings(0, 1);
for b = 1:numel(blocks)
    ports = get_param(blocks{b}, 'PortHandles');
    inputs = [ports.Inport, ports.Enable, ports.Trigger, ports.Ifaction];
    for p = inputs
        if get_param(p, 'Line') == -1
            dangling(end+1, 1) = string(blocks{b}); %#ok<AGROW>
        end
    end
end
verifyEmpty(testCase, dangling);
end

function testEveryCutListsItsBranchBlocks(testCase)
demo = testCase.TestData.Demo;
load_model(demo);
cfg = struct('ConsoleLogLevel', 'ERROR');
expected = struct( ...
    'ModeSelect', ["If" "Switch"], ...
    'LimitChain', ["Saturate" "RateLimiter" "DeadZone" "Abs" "MinMax"], ...
    'StateKeeper', ["Delay" "DiscreteIntegrator" "Relay"], ...
    'GearSelect', ["MultiPortSwitch" "SwitchCase"], ...
    'EnabledStage', ["EnablePort" "Switch" "Signum"], ...
    'TriggeredStage', ["TriggerPort" "Switch"], ...
    'FilteredParent', "Switch");
cuts = fieldnames(expected);
for k = 1:numel(cuts)
    [text, ~, note] = st_specification_decision_blocks( ...
        [demo.TopModel '/' cuts{k}], cfg);
    verifyEqual(testCase, note, "", cuts{k});
    decoded = jsondecode(char(text));
    verifyEqual(testCase, sort(unique(string({decoded.BlockType}))), ...
        sort(expected.(cuts{k})), cuts{k});
end
end

function testDecisionSplitBlocksGetOneLinePerDecision(testCase)
demo = testCase.TestData.Demo;
load_model(demo);
cfg = struct('ConsoleLogLevel', 'ERROR');
text = st_specification_decision_blocks([demo.TopModel '/StateKeeper'], cfg);
decoded = jsondecode(char(text));
types = string({decoded.BlockType});
verifyEqual(testCase, sum(types == "Delay"), 2);
verifyEqual(testCase, sum(types == "DiscreteIntegrator"), 3);
verifyEqual(testCase, sum(types == "Relay"), 2);
text = st_specification_decision_blocks([demo.TopModel '/ModeSelect'], cfg);
decoded = jsondecode(char(text));
verifyEqual(testCase, sum(string({decoded.BlockType}) == "If"), 2);
end

function testRefusesANonEmptyDestination(testCase)
% The loaded-model check comes first, so close what other tests loaded.
if bdIsLoaded('ST_DemoModel')
    close_system('ST_DemoModel', 0);
end
verifyError(testCase, @() st_create_demo_model(testCase.TestData.Root), ...
    'simtest:DemoDestinationNotEmpty');
end

function testRefusesWhenAnotherDemoModelIsOnThePath(testCase)
if bdIsLoaded('ST_DemoModel')
    close_system('ST_DemoModel', 0);
end
folder = tempname;
mkdir(folder);
fid = fopen(fullfile(folder, 'ST_DemoModel.slx'), 'w');
fclose(fid);
addpath(folder, '-begin');
testCase.addTeardown(@() rmdir(folder, 's'));
testCase.addTeardown(@() rmpath(folder));
verifyError(testCase, @() st_create_demo_model(tempname), 'simtest:DemoModelOnPath');
end

function load_model(demo)
if ~bdIsLoaded(demo.TopModel)
    load_system(demo.ModelFile);
end
end

function names = inport_names(cutPath)
blocks = find_system(cutPath, 'SearchDepth', 1, 'BlockType', 'Inport');
ports = cellfun(@(b) str2double(get_param(b, 'Port')), blocks);
[~, order] = sort(ports);
names = string(get_param(blocks(order), 'Name'));
names = names(:).';
end
