function result = st_generate_coverage_filter_file(targetRow, filterPath, cfg)
%ST_GENERATE_COVERAGE_FILTER_FILE Generate one CVF at an explicit path.

if targetRow.CoverageFilterMode == "OFF"
    error('simtest:CoverageFilterDisabledTarget', ...
        'Cannot generate a CVF for a target whose mode is OFF.');
end

if ~bdIsLoaded(cfg.TopModel)
    load_system(cfg.TopModel);
end

ownerPath = st_normalize_cut_path(targetRow.CUTPath, cfg.TopModel);
ownerHandle = getSimulinkBlockHandle(ownerPath);
if ownerHandle == -1 || ...
        ~strcmp(get_param(ownerHandle, 'BlockType'), 'SubSystem')
    error('simtest:CoverageFilterTargetNotSubsystem', ...
        'Coverage filter CUT is missing or not a Subsystem: %s', ...
        ownerPath);
end

children = find_system(ownerPath, ...
    'SearchDepth', 1, ...
    'FollowLinks', 'on', ...
    'LookUnderMasks', 'all', ...
    'LookInsideSubsystemReference', 'on', ...
    'MatchFilter', @Simulink.match.allVariants, ...
    'Type', 'Block', ...
    'BlockType', 'SubSystem');
children = children(~strcmp(children, ownerPath));
children = unique(children, 'stable');

result = struct( ...
    'FilterFile', char(string(filterPath)), ...
    'RuleCount', numel(children), ...
    'RulePaths', string(strjoin(children, ' | ')), ...
    'Status', "OK", ...
    'Message', "");

if isempty(children)
    result.Status = "WARN";
    result.Message = "No direct child Subsystem; filter not created";
    return;
end

folder = fileparts(filterPath);
if ~isfolder(folder)
    mkdir(folder);
end

filterObj = slcoverage.Filter;
setFilterName(filterObj, sprintf('Auto filter - %s', ...
    char(targetRow.TestCaseName)));
setFilterDescription(filterObj, sprintf( ...
    'Generated from Targets row No=%g, CUT=%s', ...
    double(targetRow.No), char(targetRow.CUTPath)));

if targetRow.CoverageFilterMode == "SUBSYSTEM"
    selectorType = slcoverage.BlockSelectorType.Subsystem;
else
    selectorType = slcoverage.BlockSelectorType.SubsystemAllContent;
end

if targetRow.CoverageFilterAction == "EXCLUDE"
    filterMode = slcoverage.FilterMode.Exclude;
else
    filterMode = slcoverage.FilterMode.Justify;
end

for i = 1:numel(children)
    sid = Simulink.ID.getSID(children{i});
    selector = slcoverage.BlockSelector(selectorType, sid);
    rule = slcoverage.FilterRule(selector, ...
        char(targetRow.CoverageFilterRationale), filterMode);
    addRule(filterObj, rule);
end

temporaryBase = tempname(folder);
temporaryFile = [temporaryBase '.cvf'];
cleanup = onCleanup(@() delete_temporary_filter( ...
    temporaryBase, temporaryFile)); %#ok<NASGU>

st_log(cfg, 'TRACE', ...
    'Coverage filter save start | temporary=%s | final=%s', ...
    temporaryFile, filterPath);
save(filterObj, temporaryBase);
if ~isfile(temporaryFile) && isfile(temporaryBase)
    temporaryFile = temporaryBase;
end
if ~isfile(temporaryFile)
    error('simtest:CoverageFilterSaveFailed', ...
        'Coverage filter API did not create the expected file: %s', ...
        temporaryFile);
end

[moved, moveMessage] = movefile(temporaryFile, filterPath, 'f');
if ~moved
    error('simtest:CoverageFilterSaveFailed', ...
        'Cannot replace coverage filter %s: %s', ...
        filterPath, moveMessage);
end
result.Message = sprintf('Generated %d direct-child rule(s)', ...
    result.RuleCount);
st_log(cfg, 'TRACE', ...
    'Coverage filter save done | final=%s', filterPath);
end


function delete_temporary_filter(varargin)
for i = 1:nargin
    if isfile(varargin{i})
        delete(varargin{i});
    end
end
end
