function tests = test_specification_decision_blocks
%TEST_SPECIFICATION_DECISION_BLOCKS No model or simulation is required.
tests = functiontests(localfunctions);
end

function testJsonListIsUniqueAndSortedByFullPath(testCase)
cfg = struct('VerboseLogging', false);
[text, count, note] = st_specification_decision_blocks( ...
    'Top/CUT', cfg, @fixture_finder, @fixture_name);
decoded = jsondecode(char(text));
verifyEqual(testCase, count, 4);
verifyEqual(testCase, note, "");
verifyEqual(testCase, string({decoded.Path}).', ...
    ["Top/CUT/A//If"; "Top/CUT/M MinMax"; "Top/CUT/S Switch"; "Top/CUT/Z Switch"]);
verifyEqual(testCase, string({decoded.BlockType}).', ...
    ["If"; "MinMax"; "Switch"; "Switch"]);
verifyEqual(testCase, string({decoded.Name}).', ...
    ["A/If"; "M MinMax"; "S Switch"; "Z Switch"]);
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
