function rows = st_collect_decision_outcomes(resultObj, targetConfig, runLabel, cfg)
%ST_COLLECT_DECISION_OUTCOMES Which way each two-way branch went, per iteration.
% For every Test Iteration result, or the Test Case result when it has no
% iterations, asks that unit's own coverage how often each true/false
% decision of the CUT's direct children evaluated true and false. The final
% document turns these counts into [T], [F], [T/F] or [-] on the matching
% specification row.
%
% Every scanned unit also gets one Kind="UNIT" row, so the reader can tell
% "this row has no two-way branch" from "this row was never scanned". A
% unit without coverage of its own gets no UNIT row and is logged.
%
% Collection never stops the report: a failure is logged and whatever was
% collected so far is returned.
if nargin < 4, cfg = []; end
rows = empty_rows();
label = string(runLabel);
timer = tic;
units = 0;
st_log(cfg, 'INFO', 'Decision outcome scan start | Run=%s', label);
try
    caseResults = st_collect_test_case_results(resultObj);
    for c = 1:numel(caseResults)
        [found, scanned] = collect_case(caseResults{c}, targetConfig, label, cfg);
        rows = [rows; found]; %#ok<AGROW>
        units = units + scanned;
    end
catch ME
    st_log(cfg, 'WARN', 'Decision outcome scan stopped early | Run=%s | %s', ...
        label, ME.message);
end
st_log(cfg, 'INFO', ...
    'Decision outcome scan end | Run=%s | Units=%d | Rows=%d | elapsed=%.3f sec', ...
    label, units, height(rows), toc(timer));
end


function [rows, scanned] = collect_case(tcResult, targetConfig, label, cfg)
rows = empty_rows();
scanned = 0;
caseName = property_text(tcResult, 'Name');
index = find(string(targetConfig.TestCaseName) == caseName, 1);
if isempty(index)
    st_log(cfg, 'WARN', ...
        'Decision outcome scan skipped a test case not in the target list | TestCase=%s', ...
        caseName);
    return;
end
target = targetConfig(index, :);
root = st_coverage_object_path(target);
cutName = string(target.CUTName);
blocks = direct_children(root, cfg);
[units, names] = result_units(tcResult);
for u = 1:numel(units)
    cvd = unit_coverage(units{u}, root);
    if isempty(cvd)
        st_log(cfg, 'WARN', ...
            'Decision outcome scan found no coverage for a unit | TestCase=%s | Iteration=%s', ...
            caseName, names(u));
        continue;
    end
    scanned = scanned + 1;
    rows = [rows; outcome_row(label, cutName, caseName, names(u), ...
        "UNIT", "", 0, "", 0, 0)]; %#ok<AGROW>
    for b = 1:numel(blocks)
        rows = [rows; block_rows(cvd, blocks(b), root, label, cutName, ...
            caseName, names(u), cfg)]; %#ok<AGROW>
    end
end
end


function blocks = direct_children(root, cfg)
% The same direct children st_collect_decision_points walks. LookUnderMasks
% and FollowLinks stay on: without them a masked or linked CUT has none.
blocks = strings(0,1);
try
    found = find_system(root, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'Type', 'Block');
    blocks = string(found(:));
catch ME
    st_log(cfg, 'WARN', 'Decision outcome scan could not list blocks | Root=%s | %s', ...
        root, ME.message);
end
end


function [units, names] = result_units(tcResult)
% A Test Case without iterations is its own single unit. Its name stays
% empty, the key the verdict fallback uses for the Test Case level.
iterations = [];
try
    iterations = getIterationResults(tcResult);
catch
end
if isempty(iterations)
    units = {tcResult};
    names = "";
    return;
end
units = cell(numel(iterations), 1);
names = strings(numel(iterations), 1);
for i = 1:numel(iterations)
    units{i} = iterations(i);
    names(i) = st_result_iteration_name(iterations(i), i);
end
end


function cvd = unit_coverage(unit, root)
% A unit can carry coverage for several models. The CUT's own is the one
% that answers for the CUT path.
cvd = [];
try
    objects = st_flatten_coverage_results(getCoverageResults(unit));
catch
    return;
end
for i = 1:numel(objects)
    try
        if ~isempty(decisioninfo(objects{i}, root))
            cvd = objects{i};
            return;
        end
    catch
        % A coverage object for another model simply does not answer.
    end
end
end


function rows = block_rows(cvd, blockPath, root, label, cutName, caseName, iterationName, cfg)
rows = empty_rows();
[blockType, objectPath] = st_decision_object_path(char(blockPath), root);
if isempty(blockType), return; end
description = block_description(cvd, objectPath, char(blockPath));
if isempty(description), return; end
[counts, texts] = st_decision_outcome_counts(description);
if isempty(counts)
    st_log(cfg, 'DEBUG', ...
        'Decision outcome scan skipped a block without two-way decisions | Path=%s | BlockType=%s', ...
        blockPath, blockType);
    return;
end
relative = st_cut_relative_path(blockPath, root);
for k = 1:size(counts, 1)
    rows = [rows; outcome_row(label, cutName, caseName, iterationName, ...
        "DECISION", relative, k, texts(k), counts(k,1), counts(k,2))]; %#ok<AGROW>
end
end


function description = block_description(cvd, objectPath, blockPath)
% A conditional CUT's branch sits on its port block on some releases and on
% the subsystem on others, as st_collect_decision_points found. The
% subsystem is asked with descendants ignored so inner blocks stay out.
description = [];
try
    [values, description] = decisioninfo(cvd, objectPath);
    if ~isempty(values), return; end
catch
end
description = [];
if strcmp(objectPath, blockPath), return; end
try
    [values, description] = decisioninfo(cvd, blockPath, 1);
    if isempty(values), description = []; end
catch
    description = [];
end
end


function T = empty_rows()
T = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), zeros(0,1), strings(0,1), zeros(0,1), ...
    zeros(0,1), 'VariableNames', column_names());
end


function T = outcome_row(label, cutName, caseName, iterationName, kind, ...
        relative, index, text, trueCount, falseCount)
T = table(string(label), string(cutName), string(caseName), ...
    string(iterationName), string(kind), string(relative), double(index), ...
    string(text), double(trueCount), double(falseCount), ...
    'VariableNames', column_names());
end


function names = column_names()
names = {'Run','CUTName','TestCaseName','IterationName','Kind', ...
    'RelativePath','DecisionIndex','DecisionText','TrueCount','FalseCount'};
end


function value = property_text(object, name)
value = "";
try
    value = string(object.(name));
catch
end
end
