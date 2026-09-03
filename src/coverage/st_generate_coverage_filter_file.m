function result = st_generate_coverage_filter_file(targetRow, filterPath, cfg)
%ST_GENERATE_COVERAGE_FILTER_FILE Generate one CVF at an explicit path.

totalTimer = tic;
st_log(cfg, 'INFO', ...
    ['Coverage filter generation start | TestCase=%s | CUT=%s | ' ...
     'Mode=%s | Action=%s | File=%s'], ...
    char(targetRow.TestCaseName), char(targetRow.CUTPath), ...
    char(targetRow.CoverageFilterMode), ...
    char(targetRow.CoverageFilterAction), filterPath);

try
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

    result = struct( ...
        'FilterFile', char(string(filterPath)), ...
        'RuleCount', 1, ...
        'RulePaths', string(ownerPath), ...
        'Status', "OK", ...
        'Message', "");

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

    sid = Simulink.ID.getSID(ownerPath);
    selector = slcoverage.BlockSelector(selectorType, sid);
    rule = slcoverage.FilterRule(selector, ...
        char(targetRow.CoverageFilterRationale), filterMode);
    if ~addRule(filterObj, rule)
        error('simtest:CoverageFilterRuleAddFailed', ...
            'Coverage filter rule was rejected for CUT: %s', ownerPath);
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

    savedFilter = slcoverage.Filter(filterPath);
    savedRules = rules(savedFilter);
    if numel(savedRules) ~= 1
        error('simtest:CoverageFilterValidationFailed', ...
            'Saved CVF must contain exactly one rule: %s', filterPath);
    end
    savedSelector = savedRules(1).Selector;
    if ~isequal(savedRules(1).Mode, filterMode) || ...
            ~isequal(savedSelector.Type, selectorType) || ...
            string(savedSelector.Id) ~= string(sid) || ...
            string(savedRules(1).Rationale) ~= ...
                string(targetRow.CoverageFilterRationale)
        error('simtest:CoverageFilterValidationFailed', ...
            'Saved CVF rule does not match the requested CUT rule: %s', ...
            filterPath);
    end

    result.Message = sprintf('Generated and verified CUT rule: %s', ...
        ownerPath);
    st_log(cfg, 'INFO', ...
        ['Coverage filter generation complete | TestCase=%s | ' ...
         'Rule=%s | elapsed=%.3f sec'], ...
        char(targetRow.TestCaseName), ownerPath, toc(totalTimer));
catch ME
    st_log(cfg, 'ERROR', ...
        'Coverage filter generation failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end
end


function delete_temporary_filter(varargin)
for i = 1:nargin
    if isfile(varargin{i})
        delete(varargin{i});
    end
end
end
