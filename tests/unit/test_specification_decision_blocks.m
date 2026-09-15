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

function testCatalogIsWellFormedAndUnique(testCase)
catalog = st_specification_decision_catalog();
verifyGreaterThan(testCase, height(catalog), 0);
blockTypes = string(catalog.BlockType);
verifyEqual(testCase, numel(unique(blockTypes)), numel(blockTypes));
verifyTrue(testCase, all(strlength(blockTypes) > 0));
verifyTrue(testCase, all(strlength(string(catalog.Outcome)) > 0));
verifyTrue(testCase, all(strlength(string(catalog.DisplayType)) > 0));
verifyTrue(testCase, all(ismember(string(catalog.Formatter), ["CUSTOM","GENERIC"])));
verifyTrue(testCase, all(ismember(string(catalog.Kind), ["EXPLICIT","IMPLICIT"])));
allowed = ["T/F","SELECT","CASE","LIMIT","BAND","RATE","ON/OFF", ...
    "SIGN","INTERVAL","LOOP","CONDITION"];
verifyTrue(testCase, all(ismember(string(catalog.Outcome), allowed)));
for k = 1:height(catalog)
    label = char(blockTypes(k));
    required = split_names(catalog.Parameters(k));
    optional = split_names(catalog.OptionalParameters(k));
    verifyEmpty(testCase, intersect(required, optional), label);
    if catalog.Formatter(k) == "GENERIC"
        hasSource = ~isempty(required) || ...
            strlength(strtrim(string(catalog.FixedText(k)))) > 0;
        verifyTrue(testCase, hasSource, label);
    end
end
end

function testCatalogPreservesLegacyOutcomeAndDisplayMapping(testCase)
catalog = st_specification_decision_catalog();
legacy = ["If"; "Switch"; "MinMax"; "MultiPortSwitch"; "SwitchCase"];
[found, index] = ismember(legacy, string(catalog.BlockType));
verifyTrue(testCase, all(found));
verifyEqual(testCase, string(catalog.Outcome(index)), ...
    ["T/F"; "T/F"; "SELECT"; "SELECT"; "CASE"]);
verifyEqual(testCase, string(catalog.DisplayType(index)), ...
    ["IF"; "Switch"; "MinMax"; "MultiPortSwitch"; "SwitchCase"]);
verifyTrue(testCase, all(string(catalog.Formatter(index)) == "CUSTOM"));
end

function testCustomFormatterRowsAreExactlyTheDescriptorSwitchCases(testCase)
source = fileread(fullfile(st_project_root(), 'src', 'exporting', ...
    'st_specification_decision_descriptor.m'));
catalog = st_specification_decision_catalog();
for k = 1:height(catalog)
    blockType = string(catalog.BlockType(k));
    pattern = ['case\s+"' regexptranslate('escape', char(blockType)) '"'];
    hasCase = ~isempty(regexp(source, pattern, 'once'));
    if catalog.Formatter(k) == "CUSTOM"
        verifyTrue(testCase, hasCase, char(blockType));
    else
        verifyFalse(testCase, hasCase, char(blockType));
    end
end
end

function testScannerRequestsEveryCatalogTypeAtDepthOne(testCase)
requested = strings(0,1);
depths = zeros(0,1);
cfg = struct('VerboseLogging', false);
[text, count, note] = st_specification_decision_blocks( ...
    'Top/CUT', cfg, @recording_finder, @(~) "unused");
verifyEqual(testCase, text, "[]");
verifyEqual(testCase, count, 0);
verifyEqual(testCase, note, "");
verifyEqual(testCase, requested, ...
    string(st_specification_decision_catalog().BlockType));
verifyTrue(testCase, all(depths == 1));

    function paths = recording_finder(~, varargin)
        [depth, blockType] = search_options(varargin);
        depths(end+1,1) = depth;
        requested(end+1,1) = string(blockType);
        paths = strings(0,1);
    end
end

function testImplicitBlocksUseGenericNameValueExpressions(testCase)
[outcome, expression] = st_specification_decision_descriptor( ...
    'SaturatePath', 'Saturate', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "LIMIT");
verifyEqual(testCase, expression, "UpperLimit=1; LowerLimit=-1");

[outcome, expression] = st_specification_decision_descriptor( ...
    'RelayPath', 'Relay', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "ON/OFF");
verifyEqual(testCase, expression, "OnSwitchValue=1; OffSwitchValue=0");

[outcome, expression] = st_specification_decision_descriptor( ...
    'RateLimiterPath', 'RateLimiter', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "RATE");
verifyEqual(testCase, expression, "RisingSlewLimit=1; FallingSlewLimit=-1");

[outcome, expression] = st_specification_decision_descriptor( ...
    'LogicPath', 'Logic', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "CONDITION");
verifyEqual(testCase, expression, "Operator=AND; Inputs=2");
end

function testParameterlessBlockUsesFixedTextWithoutReadingParameters(testCase)
[outcome, expression] = st_specification_decision_descriptor( ...
    'AbsPath', 'Abs', @refusing_parameter);
verifyEqual(testCase, outcome, "SIGN");
verifyEqual(testCase, expression, "u < 0");
end

function testOptionalParameterAbsenceKeepsTheRowHealthy(testCase)
[outcome, expression] = st_specification_decision_descriptor( ...
    'LookupPath', 'Lookup_n-D', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "INTERVAL");
verifyEqual(testCase, expression, ...
    "NumberOfTableDimensions=2; InterpMethod=Linear point-slope; " + ...
    "ExtrapMethod=Clip; BreakpointsSpecification=Explicit values");
verifyFalse(testCase, contains(expression, "BreakpointsForDimension1"));
end

function testRequiredParameterFailureStillFallsBackToCatalogOutcome(testCase)
cfg = struct('VerboseLogging', false);
[text, count, note] = st_specification_decision_blocks( ...
    'Top/CUT', cfg, @single_relay_finder, @(~) "Broken Relay", ...
    @failing_descriptor);
decoded = jsondecode(char(text));
verifyEqual(testCase, count, 1);
verifyEqual(testCase, string(decoded.BlockType), "Relay");
verifyEqual(testCase, string(decoded.Outcome), "ON/OFF");
verifyEqual(testCase, string(decoded.Expression), "조건식 읽기 실패");
verifyEqual(testCase, string(decoded.ExpressionStatus), "WARN");
verifyTrue(testCase, contains(note, "Expression unavailable"));
end

function testIntegratorListsParameterStateInsteadOfBeingSkipped(testCase)
cfg = struct('VerboseLogging', false);
descriptor = @(path, blockType) st_specification_decision_descriptor( ...
    path, blockType, @fixture_implicit_parameter);
[text, count, ~] = st_specification_decision_blocks( ...
    'Top/CUT', cfg, @single_integrator_finder, @(~) "Integrator", descriptor);
decoded = jsondecode(char(text));
verifyEqual(testCase, count, 1);
verifyEqual(testCase, string(decoded.Outcome), "LIMIT");
verifyEqual(testCase, string(decoded.Expression), ...
    "LimitOutput=off; ExternalReset=none");
verifyEqual(testCase, string(decoded.ExpressionStatus), "OK");
end

function testUnknownBlockTypeIsRejectedByTheCatalogLookup(testCase)
verifyError(testCase, @() st_specification_decision_descriptor( ...
    'GainPath', 'Gain', @fixture_implicit_parameter), ...
    'simtest:SpecificationDecisionBlockType');
end

function names = split_names(text)
names = strtrim(split(string(text), ","));
names = names(:);
names = names(strlength(names) > 0);
end

function paths = single_relay_finder(~, varargin)
[depth, blockType] = search_options(varargin);
if depth ~= 1
    error('fixture:SearchDepth', 'Expected SearchDepth=1.');
end
if strcmp(blockType, 'Relay')
    paths = "Top/CUT/Broken Relay";
else
    paths = strings(0,1);
end
end

function paths = single_integrator_finder(~, varargin)
[depth, blockType] = search_options(varargin);
if depth ~= 1
    error('fixture:SearchDepth', 'Expected SearchDepth=1.');
end
if strcmp(blockType, 'Integrator')
    paths = "IntegratorOffPath";
else
    paths = strings(0,1);
end
end

function value = refusing_parameter(path, parameter) %#ok<STOUT>
error('fixture:NoParameterAllowed', ...
    'This block must not read parameters: %s|%s', path, parameter);
end

function value = fixture_implicit_parameter(path, parameter)
key = string(path) + "|" + string(parameter);
switch key
    case "SaturatePath|UpperLimit"
        value = '1';
    case "SaturatePath|LowerLimit"
        value = '-1';
    case "RelayPath|OnSwitchValue"
        value = '1';
    case "RelayPath|OffSwitchValue"
        value = '0';
    case "RateLimiterPath|RisingSlewLimit"
        value = '1';
    case "RateLimiterPath|FallingSlewLimit"
        value = '-1';
    case "LogicPath|Operator"
        value = 'AND';
    case "LogicPath|Inputs"
        value = '2';
    case "LookupPath|NumberOfTableDimensions"
        value = '2';
    case "LookupPath|InterpMethod"
        value = 'Linear point-slope';
    case "LookupPath|ExtrapMethod"
        value = 'Clip';
    case "LookupPath|BreakpointsSpecification"
        value = 'Explicit values';
    case "LookupPath|BreakpointsForDimension1"
        error('fixture:AbsentParameter', ...
            'Parameter is absent in this dialog state: %s', key);
    case "IntegratorOffPath|LimitOutput"
        value = 'off';
    case "IntegratorOffPath|ExternalReset"
        value = 'none';
    case "IntegratorOffPath|UpperSaturationLimit"
        value = '';
    case "IntegratorOffPath|LowerSaturationLimit"
        value = '';
    otherwise
        error('fixture:UnknownParameter', 'Unexpected parameter: %s', key);
end
end
