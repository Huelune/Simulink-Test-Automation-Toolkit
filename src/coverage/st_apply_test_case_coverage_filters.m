function [cleanupObj, R] = ...
    st_apply_test_case_coverage_filters(tf, testCases, targetConfig, cfg)
%ST_APPLY_TEST_CASE_COVERAGE_FILTERS Apply managed CVFs through the API.
%
% RUNTIME returns an onCleanup that restores manual/original settings and
% removes toolkit-managed filter references. PERSIST saves the configured
% per-Test-Case filters and returns [].

applicationMode = ...
    st_coverage_filter_application_mode(cfg.CoverageFilterApplicationMode);

if isempty(testCases)
    error('simtest:CoverageFilterNoTestCases', ...
        'No Test Cases were supplied for coverage filter application.');
end

caseCells = num2cell(testCases(:));
n = numel(caseCells);
caseNames = strings(n, 1);
coverageObjects = cell(n, 1);
restoreFilters = cell(n, 1);
manualFilters = cell(n, 1);

totalTimer = tic;
st_log(cfg, 'INFO', ...
    'Test Case coverage filter apply start | cases=%d | mode=%s', ...
    n, applicationMode);

try
    fileCoverage = getCoverageSettings(tf);
    fileManualFilters = remove_managed_filters(normalize_filter_values( ...
        fileCoverage.CoverageFilterFilename), cfg.CoverageFilterDir);

    for i = 1:n
        caseNames(i) = string(caseCells{i}.Name);
        matches = find(string(targetConfig.TestCaseName) == caseNames(i));
        if numel(matches) ~= 1
            error('simtest:CoverageFilterTargetMappingFailed', ...
                ['Coverage filter application requires exactly one Targets ' ...
                 'row for Test Case %s. Matches=%d'], ...
                char(caseNames(i)), numel(matches));
        end
        coverageObjects{i} = getCoverageSettings(caseCells{i});
        current = normalize_filter_values( ...
            coverageObjects{i}.CoverageFilterFilename);
        restoreFilters{i} = remove_managed_filters( ...
            current, cfg.CoverageFilterDir);
        suiteCoverage = getCoverageSettings(caseCells{i}.Parent);
        suiteFilters = remove_managed_filters(normalize_filter_values( ...
            suiteCoverage.CoverageFilterFilename), cfg.CoverageFilterDir);
        manualFilters{i} = unique([fileManualFilters; suiteFilters; ...
            restoreFilters{i}], 'stable');
    end
catch ME
    st_log(cfg, 'ERROR', ...
        'Test Case coverage filter setup failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end

cleanupObj = [];
if strcmp(applicationMode, 'RUNTIME')
    cleanupObj = onCleanup(@() restore_filters( ...
        tf, coverageObjects, restoreFilters, cfg));
end

FilterMode = strings(n, 1);
FilterAction = strings(n, 1);
FilterFile = strings(n, 1);
ManualFilterCount = zeros(n, 1);
AppliedFilterCount = zeros(n, 1);
Status = strings(n, 1);
Message = strings(n, 1);

try
    for i = 1:n
        targetIndex = find(string(targetConfig.TestCaseName) == ...
            caseNames(i), 1);
        row = targetConfig(targetIndex,:);
        FilterMode(i) = row.CoverageFilterMode;
        FilterAction(i) = row.CoverageFilterAction;
        ManualFilterCount(i) = numel(manualFilters{i});

        filters = manualFilters{i};
        if row.CoverageFilterMode ~= "OFF"
            expectedFile = st_coverage_filter_file(row, cfg);
            if isfile(expectedFile)
                FilterFile(i) = string(expectedFile);
                filters(end+1,1) = string(expectedFile); %#ok<AGROW>
            else
                st_log(cfg, 'WARN', ...
                    ['Coverage filter file is absent; Test Case will run ' ...
                     'without an automatic filter | TestCase=%s | File=%s'], ...
                    char(caseNames(i)), expectedFile);
            end
        end

        filters = unique(filters(strlength(filters) > 0), 'stable');
        coverageObjects{i}.CoverageFilterFilename = ...
            filter_property_value(filters);
        AppliedFilterCount(i) = numel(filters);
        Status(i) = "OK";
        if strlength(FilterFile(i)) > 0
            Message(i) = "Automatic per-Test-Case filter applied";
        elseif row.CoverageFilterMode == "OFF"
            Message(i) = "Automatic coverage filter disabled";
        else
            Status(i) = "WARN";
            Message(i) = "No generated filter file; manual filters only";
        end

        st_log(cfg, 'DEBUG', ...
            ['[CoverageApply %d/%d] TestCase=%s | auto=%s | ' ...
             'manual=%d | applied=%d'], ...
            i, n, char(caseNames(i)), char(FilterFile(i)), ...
            ManualFilterCount(i), AppliedFilterCount(i));
    end

    if strcmp(applicationMode, 'PERSIST')
        st_log(cfg, 'DEBUG', ...
            'Persistent coverage filter saveToFile start');
        saveToFile(tf);
        st_log(cfg, 'DEBUG', ...
            'Persistent coverage filter saveToFile done');
    end
catch ME
    st_log(cfg, 'ERROR', ...
        'Test Case coverage filter apply failed | %s: %s', ...
        ME.identifier, ME.message);
    if strcmp(applicationMode, 'RUNTIME')
        clear cleanupObj;
    else
        restore_filters(tf, coverageObjects, restoreFilters, cfg);
    end
    rethrow(ME);
end

ApplicationMode = repmat(string(applicationMode), n, 1);
R = table(caseNames, FilterMode, FilterAction, ApplicationMode, ...
    FilterFile, ManualFilterCount, AppliedFilterCount, Status, Message, ...
    'VariableNames', {'TestCaseName','FilterMode','FilterAction', ...
    'ApplicationMode','FilterFile','ManualFilterCount', ...
    'AppliedFilterCount','Status','Message'});
st_write_result('CoverageFilterApplyResult', R);

st_log(cfg, 'INFO', ...
    ['Test Case coverage filter apply complete | OK=%d | WARN=%d | ' ...
     'elapsed=%.3f sec'], ...
    sum(Status == "OK"), sum(Status == "WARN"), toc(totalTimer));
end


function value = filter_property_value(filters)
if isempty(filters)
    value = "";
else
    value = filters;
end
end


function values = normalize_filter_values(value)
if iscell(value)
    values = string(value(:));
else
    values = string(value(:));
end
values(ismissing(values)) = "";
values = values(strlength(values) > 0);
end


function values = remove_managed_filters(values, managedRoot)
keep = true(numel(values), 1);
for i = 1:numel(values)
    keep(i) = ~is_managed_filter(values(i), managedRoot);
end
values = values(keep);
end


function tf = is_managed_filter(value, managedRoot)
try
    target = char(java.io.File(char(value)).getCanonicalPath());
    root = char(java.io.File(managedRoot).getCanonicalPath());
    prefix = [root filesep];
    if ispc
        tf = startsWith(lower(target), lower(prefix));
    else
        tf = startsWith(target, prefix);
    end
catch
    tf = false;
end
end


function restore_filters(tf, coverageObjects, restoreFilters, cfg)
st_log(cfg, 'DEBUG', ...
    'Test Case coverage filter restore start | cases=%d', ...
    numel(coverageObjects));
failures = strings(0, 1);
for i = 1:numel(coverageObjects)
    try
        coverageObjects{i}.CoverageFilterFilename = ...
            filter_property_value(restoreFilters{i});
    catch ME
        failures(end+1,1) = string(ME.message); %#ok<AGROW>
    end
end
try
    saveToFile(tf);
catch ME
    failures(end+1,1) = string(ME.message); %#ok<AGROW>
end
if isempty(failures)
    st_log(cfg, 'DEBUG', ...
        'Test Case coverage filter restore done');
else
    st_log(cfg, 'ERROR', ...
        'Test Case coverage filter restore failed | %s', ...
        char(strjoin(failures, ' | ')));
    warning('simtest:CoverageFilterRestoreFailed', ...
        'Could not fully restore Test Case coverage filters: %s', ...
        char(strjoin(failures, ' | ')));
end
end
