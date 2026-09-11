function result = st_generate_coverage_filter_file(targetRow, filterPath, cfg)
%ST_GENERATE_COVERAGE_FILTER_FILE Generate and verify one context-local CVF.

totalTimer = tic;
boundaryMode = coverage_boundary_mode(targetRow);
st_log(cfg, 'INFO', ...
    ['Coverage filter generation start | TestCase=%s | CUT=%s | ' ...
     'Mode=%s | Boundary=%s | Action=%s | File=%s'], ...
    char(targetRow.TestCaseName), char(targetRow.CUTPath), ...
    char(targetRow.CoverageFilterMode), boundaryMode, ...
    char(targetRow.CoverageFilterAction), filterPath);

try
    if ~st_coverage_filter_active(targetRow)
        error('simtest:CoverageFilterDisabledTarget', ...
            'Cannot generate a CVF when both coverage modes are OFF.');
    end

    [executionRoot, cutPath, contextCleanup] = ...
        resolve_execution_context(targetRow, cfg); %#ok<NASGU>
    cutHandle = getSimulinkBlockHandle(cutPath);
    if cutHandle == -1 || ...
            ~strcmp(get_param(cutHandle, 'BlockType'), 'SubSystem')
        error('simtest:CoverageFilterTargetNotSubsystem', ...
            'Coverage filter CUT is missing or not a Subsystem: %s', ...
            cutPath);
    end

    rulePaths = strings(0,1);
    selectorTypes = cell(0,1);
    filterModes = cell(0,1);
    rationales = strings(0,1);
    categories = strings(0,1);

    if targetRow.CoverageFilterMode ~= "OFF"
        children = direct_blocks(cutPath, 'SubSystem');
        if targetRow.CoverageFilterMode == "SUBSYSTEM"
            childSelector = slcoverage.BlockSelectorType.BlockInstance;
        else
            childSelector = slcoverage.BlockSelectorType.SubsystemAllContent;
        end
        if targetRow.CoverageFilterAction == "EXCLUDE"
            childMode = slcoverage.FilterMode.Exclude;
        else
            childMode = slcoverage.FilterMode.Justify;
        end
        for i = 1:numel(children)
            [rulePaths, selectorTypes, filterModes, rationales, categories] = ...
                append_rule(rulePaths, selectorTypes, filterModes, ...
                rationales, categories, children{i}, childSelector, ...
                childMode, char(targetRow.CoverageFilterRationale), ...
                'CUT_CHILD');
        end
    end

    if strcmp(boundaryMode, 'CUT_ONLY')
        outside = direct_blocks(executionRoot, '');
        outside = outside(~strcmp(outside, cutPath));
        boundaryRationale = ...
            'Automatically excluded because block is outside the CUT coverage boundary.';
        for i = 1:numel(outside)
            if strcmp(get_param(outside{i}, 'BlockType'), 'SubSystem')
                selector = slcoverage.BlockSelectorType.SubsystemAllContent;
            else
                selector = slcoverage.BlockSelectorType.BlockInstance;
            end
            [rulePaths, selectorTypes, filterModes, rationales, categories] = ...
                append_rule(rulePaths, selectorTypes, filterModes, ...
                rationales, categories, outside{i}, selector, ...
                slcoverage.FilterMode.Exclude, boundaryRationale, ...
                'OUTSIDE_CUT');
        end
    end

    folder = fileparts(filterPath);
    if ~isfolder(folder), mkdir(folder); end
    filterObj = slcoverage.Filter;
    setFilterName(filterObj, sprintf('Auto filter - %s', ...
        char(targetRow.TestCaseName)));
    setFilterDescription(filterObj, sprintf( ...
        ['Generated for execution CUT %s; content mode=%s; ' ...
         'boundary mode=%s'], cutPath, ...
        char(targetRow.CoverageFilterMode), boundaryMode));

    ruleSids = strings(numel(rulePaths),1);
    for i = 1:numel(rulePaths)
        ruleSids(i) = string(Simulink.ID.getSID(char(rulePaths(i))));
        selector = slcoverage.BlockSelector( ...
            selectorTypes{i}, char(ruleSids(i)));
        rule = slcoverage.FilterRule(selector, ...
            char(rationales(i)), filterModes{i});
        if ~addRule(filterObj, rule)
            error('simtest:CoverageFilterRuleAddFailed', ...
                'Coverage filter rule was rejected for block: %s', ...
                char(rulePaths(i)));
        end
    end

    temporaryBase = tempname(folder);
    temporaryFile = [temporaryBase '.cvf'];
    cleanup = onCleanup(@() delete_temporary_filter( ...
        temporaryBase, temporaryFile)); %#ok<NASGU>
    st_log(cfg, 'TRACE', ...
        'Coverage filter save start | temporary=%s | final=%s', ...
        temporaryFile, filterPath);
    [saveBase, saveDirectoryCleanup] = ...
        enter_writable_save_directory(cfg); %#ok<NASGU>
    save(filterObj, saveBase);
    saveFile = [saveBase '.cvf'];
    if ~isfile(saveFile) && isfile(saveBase)
        saveFile = saveBase;
    end
    if ~isfile(saveFile)
        error('simtest:CoverageFilterSaveFailed', ...
            'Coverage filter API did not create the expected file: %s', ...
            saveFile);
    end
    [copied, copyMessage] = copyfile(saveFile, temporaryFile, 'f');
    if ~copied
        error('simtest:CoverageFilterSaveFailed', ...
            'Cannot stage coverage filter %s: %s', ...
            temporaryFile, copyMessage);
    end
    clear saveDirectoryCleanup;
    [moved, moveMessage] = movefile(temporaryFile, filterPath, 'f');
    if ~moved
        error('simtest:CoverageFilterSaveFailed', ...
            'Cannot replace coverage filter %s: %s', ...
            filterPath, moveMessage);
    end

    validate_saved_filter(filterPath, ruleSids, selectorTypes, ...
        filterModes, rationales, rulePaths);
    result = struct( ...
        'FilterFile', char(string(filterPath)), ...
        'RuleCount', numel(rulePaths), ...
        'RulePaths', string(strjoin(rulePaths, ' | ')), ...
        'CUTChildRuleCount', sum(categories == "CUT_CHILD"), ...
        'BoundaryRuleCount', sum(categories == "OUTSIDE_CUT"), ...
        'ExecutionCUTPath', cutPath, ...
        'Status', "OK", ...
        'Message', sprintf( ...
            'Generated and verified %d CUT-child and %d boundary rule(s)', ...
            sum(categories == "CUT_CHILD"), ...
            sum(categories == "OUTSIDE_CUT")));
    st_log(cfg, 'INFO', ...
        ['Coverage filter generation complete | TestCase=%s | CUT=%s | ' ...
         'Rules=%d | CUTChild=%d | Boundary=%d | elapsed=%.3f sec'], ...
        char(targetRow.TestCaseName), cutPath, numel(rulePaths), ...
        result.CUTChildRuleCount, result.BoundaryRuleCount, ...
        toc(totalTimer));
catch ME
    st_log(cfg, 'ERROR', ...
        'Coverage filter generation failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end
end

function [saveBase, cleanup] = enter_writable_save_directory(cfg)
%ENTER_WRITABLE_SAVE_DIRECTORY Satisfy the Coverage API's pwd check.
% slcoverage.Filter.save validates the current MATLAB directory even when
% fileName is an absolute path. Exported workspaces can be reported as
% read-only or exceed legacy path limits. Save into a short system scratch
% directory first, then let the caller atomically replace the final file.
previousDirectory = pwd;
writableDirectory = tempname(tempdir);
[created, createMessage] = mkdir(writableDirectory);
if ~created
    st_log(cfg, 'ERROR', ...
        'Coverage filter writable directory unavailable | %s | %s', ...
        writableDirectory, createMessage);
    error('simtest:CoverageFilterWritableDirectoryUnavailable', ...
        'Cannot create the Coverage filter scratch directory %s: %s', ...
        writableDirectory, createMessage);
end
st_log(cfg, 'DEBUG', ...
    'Coverage filter writable directory enter | From=%s | To=%s', ...
    previousDirectory, writableDirectory);
cd(writableDirectory);
saveBase = fullfile(writableDirectory, 'coverage_filter');
cleanup = onCleanup(@() restore_save_directory( ...
    previousDirectory, writableDirectory, cfg));
end

function restore_save_directory(previousDirectory, writableDirectory, cfg)
try
    cd(previousDirectory);
    if isfolder(writableDirectory)
        rmdir(writableDirectory, 's');
    end
    st_log(cfg, 'DEBUG', ...
        'Coverage filter writable directory restored | %s', ...
        previousDirectory);
catch ME
    st_log(cfg, 'ERROR', ...
        'Coverage filter directory restore failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end
end

function [root, cut, cleanup] = resolve_execution_context(row, cfg)
cleanup = [];
if ismember('ExecutionModel', row.Properties.VariableNames) && ...
        strlength(strtrim(string(row.ExecutionModel))) > 0
    model = char(row.ExecutionModel);
    loadedHere = ~bdIsLoaded(model);
    if loadedHere
        if ismember('ExecutionModelFile', row.Properties.VariableNames) && ...
                isfile(char(row.ExecutionModelFile))
            load_system(char(row.ExecutionModelFile));
        else
            load_system(model);
        end
    end
    cleanup = onCleanup(@() close_model_if_loaded_here(model, loadedHere));
    root = model;
    cut = char(row.StandaloneCUTPath);
    return;
end

if ~bdIsLoaded(cfg.TopModel), load_system(cfg.TopModel); end
sourceCut = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
harness = char(row.HarnessName);
sltest.harness.load(sourceCut, harness);
cleanup = onCleanup(@() close_harness_quiet(sourceCut, harness));
root = harness;
cut = identify_context_cut(sourceCut, root);
end

function cut = identify_context_cut(sourceCut, root)
sourceName = get_param(sourceCut, 'Name');
sourceSignature = interface_signature(sourceCut);
candidates = direct_blocks(root, 'SubSystem');
matches = strings(0,1);
for i = 1:numel(candidates)
    if strcmp(get_param(candidates{i}, 'Name'), sourceName) && ...
            isequal(interface_signature(candidates{i}), sourceSignature)
        matches(end+1,1) = string(candidates{i}); %#ok<AGROW>
    end
end
if numel(matches) ~= 1
    error('simtest:CoverageExecutionCUTIdentificationFailed', ...
        ['Expected exactly one execution CUT matching name and interface. ' ...
         'Source=%s | Root=%s | Matches=%d'], ...
        sourceCut, root, numel(matches));
end
cut = char(matches(1));
end

function blocks = direct_blocks(root, blockType)
args = {'SearchDepth', 1, 'FollowLinks', 'on', ...
    'LookUnderMasks', 'all', ...
    'LookInsideSubsystemReference', 'on', ...
    'MatchFilter', @Simulink.match.allVariants, 'Type', 'Block'};
if ~isempty(blockType)
    args = [args {'BlockType', blockType}]; %#ok<AGROW>
end
blocks = find_system(root, args{:});
blocks = cellstr(string(blocks(:)));
blocks = blocks(~strcmp(blocks, root));
blocks = unique(blocks, 'stable');
end

function signature = interface_signature(block)
ports = direct_blocks(block, '');
rows = strings(0,1);
for i = 1:numel(ports)
    type = get_param(ports{i}, 'BlockType');
    if ~ismember(type, {'Inport','Outport','EnablePort', ...
            'TriggerPort','ResetPort'})
        continue;
    end
    port = '';
    try, port = get_param(ports{i}, 'Port'); catch, end
    rows(end+1,1) = string(type) + "|" + string(port) + "|" + ...
        string(get_param(ports{i}, 'Name')); %#ok<AGROW>
end
signature = sort(rows);
end

function [paths, selectors, modes, rationales, categories] = ...
        append_rule(paths, selectors, modes, rationales, categories, ...
        path, selector, mode, rationale, category)
paths(end+1,1) = string(path);
selectors{end+1,1} = selector;
modes{end+1,1} = mode;
rationales(end+1,1) = string(rationale);
categories(end+1,1) = string(category);
end

function validate_saved_filter(path, sids, selectors, modes, ...
        rationales, rulePaths)
savedFilter = slcoverage.Filter(path);
savedRules = rules(savedFilter);
if numel(savedRules) ~= numel(rulePaths)
    error('simtest:CoverageFilterValidationFailed', ...
        'Saved CVF rule count differs from the generated count: %s', path);
end
for i = 1:numel(savedRules)
    savedSelector = savedRules(i).Selector;
    expectedIndex = find(sids == string(savedSelector.Id));
    if numel(expectedIndex) ~= 1 || ...
            ~isequal(savedRules(i).Mode, modes{expectedIndex}) || ...
            ~isequal(savedSelector.Type, selectors{expectedIndex}) || ...
            string(savedRules(i).Rationale) ~= rationales(expectedIndex)
        error('simtest:CoverageFilterValidationFailed', ...
            'Saved CVF rule does not match generated policy: %s', path);
    end
end
end

function mode = coverage_boundary_mode(row)
mode = 'OFF';
if ismember('CoverageBoundaryMode', row.Properties.VariableNames)
    mode = char(st_resolve_coverage_boundary_modes(row.CoverageBoundaryMode));
end
end

function close_harness_quiet(owner, harness)
try, sltest.harness.close(owner, harness); catch, end
end

function close_model_if_loaded_here(model, loadedHere)
if loadedHere && bdIsLoaded(model), close_system(model, 0); end
end

function delete_temporary_filter(varargin)
for i = 1:nargin
    if isfile(varargin{i}), delete(varargin{i}); end
end
end
