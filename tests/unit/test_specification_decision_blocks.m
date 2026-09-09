function tests = test_specification_decision_blocks
%TEST_SPECIFICATION_DECISION_BLOCKS No model or simulation is required.
tests = functiontests(localfunctions);
end

function testJsonListIsUniqueAndSortedByFullPath(testCase)
cfg = struct('VerboseLogging', false);
[text, count, note] = st_specification_decision_blocks( ...
    'Top/CUT', cfg, @fixture_finder, @fixture_name, @fixture_descriptor);
decoded = jsondecode(char(text));
verifyEqual(testCase, count, 4);
verifyEqual(testCase, note, "");
verifyEqual(testCase, string({decoded.Path}).', ...
    ["Top/CUT/A//If"; "Top/CUT/M MinMax"; "Top/CUT/S Switch"; "Top/CUT/Z Switch"]);
verifyEqual(testCase, string({decoded.BlockType}).', ...
    ["If"; "MinMax"; "Switch"; "Switch"]);
verifyEqual(testCase, string({decoded.Name}).', ...
    ["A/If"; "M MinMax"; "S Switch"; "Z Switch"]);
verifyEqual(testCase, string({decoded.Outcome}).', ...
    ["T/F"; "SELECT"; "T/F"; "T/F"]);
verifyEqual(testCase, string({decoded.Expression}).', ...
    ["u1 == 0"; "min; Inputs=2"; "u2 > 0"; "u2 ~= 0"]);
verifyTrue(testCase, all(string({decoded.ExpressionStatus}) == "OK"));
end

function testNoCandidatesProducesEmptyJsonArray(testCase)
cfg = struct('VerboseLogging', false);
[text, count, note] = st_specification_decision_blocks( ...
    'Top/EmptyCUT', cfg, @empty_finder, @(~) "unused");
verifyEqual(testCase, text, "[]");
verifyEqual(testCase, count, 0);
verifyEqual(testCase, note, "");
verifyEmpty(testCase, jsondecode(char(text)));
end

function testSavedBlockParametersProduceStaticDescriptions(testCase)
[outcome, expression] = st_specification_decision_descriptor( ...
    'IfPath', 'If', @fixture_parameter);
verifyEqual(testCase, outcome, "T/F");
verifyEqual(testCase, expression, "u1 == 0; elseif u2 > 1");

[outcome, expression] = st_specification_decision_descriptor( ...
    'SwitchPath', 'Switch', @fixture_parameter);
verifyEqual(testCase, outcome, "T/F");
verifyEqual(testCase, expression, "u2 >= 5");

[outcome, expression] = st_specification_decision_descriptor( ...
    'MinMaxPath', 'MinMax', @fixture_parameter);
verifyEqual(testCase, outcome, "SELECT");
verifyEqual(testCase, expression, "max; Inputs=3");

[outcome, expression] = st_specification_decision_descriptor( ...
    'MultiPortPath', 'MultiPortSwitch', @fixture_parameter);
verifyEqual(testCase, outcome, "SELECT");
verifyEqual(testCase, expression, ...
    "DataPortOrder=Specify indices; DataPortIndices={1,3}");

[outcome, expression] = st_specification_decision_descriptor( ...
    'SwitchCasePath', 'SwitchCase', @fixture_parameter);
verifyEqual(testCase, outcome, "CASE");
verifyEqual(testCase, expression, "u1 in {1,[7,9]}");
end

function testExpressionReadFailureIsRecordedWithoutDroppingBlock(testCase)
cfg = struct('VerboseLogging', false);
[text, count, note] = st_specification_decision_blocks( ...
    'Top/CUT', cfg, @single_if_finder, @(~) "Broken If", ...
    @failing_descriptor);
decoded = jsondecode(char(text));
verifyEqual(testCase, count, 1);
verifyEqual(testCase, string(decoded.Outcome), "T/F");
verifyEqual(testCase, string(decoded.Expression), "조건식 읽기 실패");
verifyEqual(testCase, string(decoded.ExpressionStatus), "WARN");
verifyTrue(testCase, contains(note, "Expression unavailable"));
end

function paths = fixture_finder(~, varargin)
[depth, blockType] = search_options(varargin);
if depth ~= 1
    error('fixture:SearchDepth', 'Expected SearchDepth=1.');
end
switch blockType
    case 'If'
        paths = "Top/CUT/A//If";
    case 'MinMax'
        paths = "Top/CUT/M MinMax";
    case 'Switch'
        paths = ["Top/CUT/Z Switch"; "Top/CUT/S Switch"; "Top/CUT/Z Switch"];
    otherwise
        paths = strings(0,1);
end
end

function paths = empty_finder(~, varargin)
[depth, ~] = search_options(varargin);
if depth ~= 1
    error('fixture:SearchDepth', 'Expected SearchDepth=1.');
end
paths = strings(0,1);
end

function paths = single_if_finder(~, varargin)
[depth, blockType] = search_options(varargin);
if depth ~= 1
    error('fixture:SearchDepth', 'Expected SearchDepth=1.');
end
if strcmp(blockType, 'If')
    paths = "Top/CUT/Broken If";
else
    paths = strings(0,1);
end
end

function [depth, blockType] = search_options(options)
names = string(options(1:2:end));
depthIndex = find(names == "SearchDepth", 1);
typeIndex = find(names == "BlockType", 1);
if isempty(depthIndex) || isempty(typeIndex)
    error('fixture:SearchOptions', 'Required search options are missing.');
end
depth = options{2 * depthIndex};
blockType = options{2 * typeIndex};
end

function name = fixture_name(path)
switch path
    case 'Top/CUT/A//If'
        name = 'A/If';
    case 'Top/CUT/M MinMax'
        name = 'M MinMax';
    case 'Top/CUT/S Switch'
        name = 'S Switch';
    case 'Top/CUT/Z Switch'
        name = 'Z Switch';
    otherwise
        error('fixture:UnknownPath', 'Unknown path: %s', path);
end
end

function [outcome, expression] = fixture_descriptor(path, blockType)
switch path
    case 'Top/CUT/A//If'
        outcome = "T/F";
        expression = "u1 == 0";
    case 'Top/CUT/M MinMax'
        outcome = "SELECT";
        expression = "min; Inputs=2";
    case 'Top/CUT/S Switch'
        outcome = "T/F";
        expression = "u2 > 0";
    case 'Top/CUT/Z Switch'
        outcome = "T/F";
        expression = "u2 ~= 0";
    otherwise
        error('fixture:UnknownPath', ...
            'Unknown descriptor path/type: %s (%s)', path, blockType);
end
end

function [outcome, expression] = failing_descriptor(~, ~) %#ok<STOUT>
error('fixture:Expression', 'Expression unavailable.');
end

function value = fixture_parameter(path, parameter)
key = string(path) + "|" + string(parameter);
switch key
    case "IfPath|IfExpression"
        value = 'u1 == 0';
    case "IfPath|ElseIfExpressions"
        value = 'u2 > 1';
    case "SwitchPath|Criteria"
        value = 'u2 >= Threshold';
    case "SwitchPath|Threshold"
        value = '5';
    case "MinMaxPath|Function"
        value = 'max';
    case "MinMaxPath|Inputs"
        value = '3';
    case "MultiPortPath|DataPortOrder"
        value = 'Specify indices';
    case "MultiPortPath|DataPortIndices"
        value = '{1,3}';
    case "SwitchCasePath|CaseConditions"
        value = '{1,[7,9]}';
    otherwise
        error('fixture:UnknownParameter', 'Unexpected parameter: %s', key);
end
end
