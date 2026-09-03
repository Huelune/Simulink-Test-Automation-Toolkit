function [cleanupObj, R, session] = ...
    st_apply_test_case_coverage_filters(tf, testCases, targetConfig, cfg, varargin)
%ST_APPLY_TEST_CASE_COVERAGE_FILTERS Apply managed CVFs through the API.
%
% RUNTIME returns an onCleanup plus a session.Restore function. Call
% session.Restore explicitly whenever restoration failure must be handled as
% a structured execution failure. The onCleanup is only a last-resort guard.
% PERSIST saves the configured per-Test-Case filters and returns [].
% ExistingFilterPolicy=REPLACE temporarily suppresses inherited filters;
% MERGE preserves the legacy behavior of combining them with managed CVFs.

p = inputParser;
addParameter(p, 'FilterFiles', strings(0, 1), ...
    @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'ExistingFilterPolicy', 'MERGE', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(p, 'ApplyManagedFiltersDuringRun', true, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

applicationMode = ...
    st_coverage_filter_application_mode(cfg.CoverageFilterApplicationMode);
existingFilterPolicy = st_coverage_filter_existing_policy( ...
    p.Results.ExistingFilterPolicy);
applyManagedFiltersDuringRun = logical( ...
    p.Results.ApplyManagedFiltersDuringRun);
if strcmp(existingFilterPolicy, 'REPLACE') && ...
        ~strcmp(applicationMode, 'RUNTIME')
    error('simtest:CoverageFilterReplacementRequiresRuntime', ...
        ['ExistingFilterPolicy=REPLACE is transient and requires ' ...
         'CoverageFilterApplicationMode=RUNTIME.']);
end

if isempty(testCases)
    error('simtest:CoverageFilterNoTestCases', ...
        'No Test Cases were supplied for coverage filter application.');
end
caseCells = num2cell(testCases(:));
n = numel(caseCells);
caseNames = strings(n, 1);
coverageObjects = cell(n, 1);
originalFilters = cell(n, 1);
suiteCoverageObjects = cell(n, 1);
suiteOriginalFilters = cell(n, 1);
manualFilters = cell(n, 1);
fileCoverage = [];
fileOriginalFilters = strings(0, 1);

filterFiles = string(p.Results.FilterFiles(:));
if isempty(filterFiles)
    filterFiles = strings(n, 1);
elseif numel(filterFiles) ~= n
    error('simtest:CoverageFilterFileCountMismatch', ...
        'FilterFiles must contain one value per Test Case.');
end

totalTimer = tic;
st_log(cfg, 'INFO', ...
    ['Test Case coverage filter apply start | cases=%d | mode=%s | ' ...
     'existing=%s | managed=%s'], ...
    n, applicationMode, existingFilterPolicy, ...
    managed_application_text(applyManagedFiltersDuringRun));

try
    fileCoverage = getCoverageSettings(tf);
    fileOriginalFilters = normalize_filter_values( ...
        fileCoverage.CoverageFilterFilename);
    fileManualFilters = remove_managed_filters( ...
        fileOriginalFilters, cfg.CoverageFilterDir);

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
        originalFilters{i} = current;
        suiteCoverage = getCoverageSettings(caseCells{i}.Parent);
        suiteCoverageObjects{i} = suiteCoverage;
        suiteOriginalFilters{i} = normalize_filter_values( ...
            suiteCoverage.CoverageFilterFilename);
        suiteFilters = remove_managed_filters(normalize_filter_values( ...
            suiteCoverage.CoverageFilterFilename), cfg.CoverageFilterDir);
        manualFilters{i} = unique([fileManualFilters; suiteFilters; ...
            remove_managed_filters(current, cfg.CoverageFilterDir)], ...
            'stable');
    end

catch ME
    st_log(cfg, 'ERROR', ...
        'Test Case coverage filter setup failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end

restored = false;
restoreResult = table();
session = struct( ...
    'ApplicationMode', applicationMode, ...
    'TestCaseNames', caseNames, ...
    'Restore', @restore_explicit, ...
    'GetRestoreResult', @get_restore_result);

cleanupObj = [];
if strcmp(applicationMode, 'RUNTIME')
    cleanupObj = onCleanup(@restore_fallback);
end

FilterMode = strings(n, 1);
FilterAction = strings(n, 1);
FilterFile = strings(n, 1);
ManualFilterCount = zeros(n, 1);
IgnoredFilterCount = zeros(n, 1);
AppliedFilterCount = zeros(n, 1);
Status = strings(n, 1);
Message = strings(n, 1);

try
    if strcmp(existingFilterPolicy, 'REPLACE')
        ignoredCount = numel(fileOriginalFilters) + ...
            sum(cellfun(@numel, suiteOriginalFilters)) + ...
            sum(cellfun(@numel, originalFilters));
        fileCoverage.CoverageFilterFilename = ...
            filter_property_value(strings(0, 1));
        for i = 1:n
            suiteCoverageObjects{i}.CoverageFilterFilename = ...
                filter_property_value(strings(0, 1));
        end
        st_log(cfg, 'INFO', ...
            ['Existing coverage filters suppressed for isolated run | ' ...
             'cases=%d | references=%d'], n, ignoredCount);
    end

    for i = 1:n
        targetIndex = find(string(targetConfig.TestCaseName) == ...
            caseNames(i), 1);
        row = targetConfig(targetIndex,:);
        FilterMode(i) = row.CoverageFilterMode;
        FilterAction(i) = row.CoverageFilterAction;
        if strcmp(existingFilterPolicy, 'REPLACE')
            existing = unique([fileOriginalFilters; ...
                suiteOriginalFilters{i}; originalFilters{i}], 'stable');
            IgnoredFilterCount(i) = numel(existing);
            filters = strings(0, 1);
        else
            ManualFilterCount(i) = numel(manualFilters{i});
            filters = manualFilters{i};
        end
        if row.CoverageFilterMode ~= "OFF"
            expectedFile = char(filterFiles(i));
            if isempty(expectedFile)
                expectedFile = st_coverage_filter_file(row, cfg);
            end
            if isfile(expectedFile)
                FilterFile(i) = string(expectedFile);
                if applyManagedFiltersDuringRun
                    filters(end+1,1) = string(expectedFile); %#ok<AGROW>
                end
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
            if applyManagedFiltersDuringRun
                Message(i) = "Automatic per-Test-Case filter applied";
            else
                Message(i) = ...
                    "Automatic filter deferred to result coverage data";
            end
        elseif row.CoverageFilterMode == "OFF"
            Message(i) = "Automatic coverage filter disabled";
        else
            Status(i) = "WARN";
            Message(i) = "No generated filter file; manual filters only";
        end

        st_log(cfg, 'DEBUG', ...
            ['[CoverageApply %d/%d] TestCase=%s | auto=%s | ' ...
             'manual=%d | ignored=%d | applied=%d | existing=%s | ' ...
             'managed=%s'], ...
            i, n, char(caseNames(i)), char(FilterFile(i)), ...
            ManualFilterCount(i), IgnoredFilterCount(i), ...
            AppliedFilterCount(i), existingFilterPolicy, ...
            managed_application_text(applyManagedFiltersDuringRun));
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
    try
        restore_explicit();
    catch restoreME
        combined = MException('simtest:CoverageFilterRestoreFailed', ...
            ['Coverage filter application failed and the original filter ' ...
             'state could not be restored. Apply error: %s | Restore error: %s'], ...
            ME.message, restoreME.message);
        combined = addCause(combined, ME);
        combined = addCause(combined, restoreME);
        throw(combined);
    end
    rethrow(ME);
end

ApplicationMode = repmat(string(applicationMode), n, 1);
ExistingFilterPolicy = repmat(string(existingFilterPolicy), n, 1);
ManagedFilterApplication = repmat(string(managed_application_text( ...
    applyManagedFiltersDuringRun)), n, 1);
R = table(caseNames, FilterMode, FilterAction, ApplicationMode, ...
    ExistingFilterPolicy, ManagedFilterApplication, FilterFile, ...
    ManualFilterCount, ...
    IgnoredFilterCount, AppliedFilterCount, Status, Message, ...
    'VariableNames', {'TestCaseName','FilterMode','FilterAction', ...
    'ApplicationMode','ExistingFilterPolicy','ManagedFilterApplication', ...
    'FilterFile', ...
    'ManualFilterCount','IgnoredFilterCount','AppliedFilterCount', ...
    'Status','Message'});
st_write_result('CoverageFilterApplyResult', R);

st_log(cfg, 'INFO', ...
    ['Test Case coverage filter apply complete | OK=%d | WARN=%d | ' ...
     'elapsed=%.3f sec'], ...
    sum(Status == "OK"), sum(Status == "WARN"), toc(totalTimer));

    function result = restore_explicit()
        if restored
            result = restoreResult;
            return;
        end
        result = restore_filters_strict();
        restoreResult = result;
        restored = true;
    end

    function result = get_restore_result()
        result = restoreResult;
    end

    function restore_fallback()
        if restored
            return;
        end
        try
            restore_explicit();
        catch ME
            st_log(cfg, 'ERROR', ...
                'Coverage filter fallback restore failed | %s: %s', ...
                ME.identifier, ME.message);
            warning('simtest:CoverageFilterRestoreFailed', ...
                ['The last-resort cleanup could not restore the original ' ...
                 'coverage filters: %s'], ME.message);
        end
    end

    function result = restore_filters_strict()
        st_log(cfg, 'DEBUG', ...
            'Test Case coverage filter restore start | cases=%d', n);

        Status = repmat("OK", n, 1);
        Message = repmat("Original filter list restored and verified", n, 1);
        OriginalFilterCount = zeros(n, 1);
        RestoredFilterCount = zeros(n, 1);

        for restoreIndex = 1:n
            OriginalFilterCount(restoreIndex) = ...
                numel(originalFilters{restoreIndex});
            try
                if strcmp(existingFilterPolicy, 'REPLACE')
                    suiteCoverageObjects{restoreIndex}.CoverageFilterFilename = ...
                        filter_property_value( ...
                            suiteOriginalFilters{restoreIndex});
                end
                coverageObjects{restoreIndex}.CoverageFilterFilename = ...
                    filter_property_value(originalFilters{restoreIndex});
                actual = normalize_filter_values( ...
                    coverageObjects{restoreIndex}.CoverageFilterFilename);
                RestoredFilterCount(restoreIndex) = numel(actual);
                if ~isequal(actual, originalFilters{restoreIndex})
                    error('simtest:CoverageFilterRestoreMismatch', ...
                        'Restored Test Case filter list does not match its backup.');
                end

                suiteActual = normalize_filter_values( ...
                    suiteCoverageObjects{restoreIndex}.CoverageFilterFilename);
                if ~isequal(suiteActual, suiteOriginalFilters{restoreIndex})
                    error('simtest:CoverageFilterSuiteStateChanged', ...
                        'Test Suite filter list changed during transient application.');
                end
            catch restoreME
                Status(restoreIndex) = "FAIL";
                Message(restoreIndex) = string(restoreME.message);
            end
        end

        try
            if strcmp(existingFilterPolicy, 'REPLACE')
                fileCoverage.CoverageFilterFilename = ...
                    filter_property_value(fileOriginalFilters);
            end
            fileActual = normalize_filter_values( ...
                fileCoverage.CoverageFilterFilename);
            if ~isequal(fileActual, fileOriginalFilters)
                error('simtest:CoverageFilterFileStateChanged', ...
                    'Test File filter list changed during transient application.');
            end
            saveToFile(tf);
        catch saveME
            failedIndex = find(Status == "OK", 1, 'first');
            if isempty(failedIndex)
                failedIndex = 1;
            end
            Status(failedIndex) = "FAIL";
            Message(failedIndex) = string(saveME.message);
        end

        result = table(caseNames, OriginalFilterCount, ...
            RestoredFilterCount, Status, Message, ...
            'VariableNames', {'TestCaseName','OriginalFilterCount', ...
            'RestoredFilterCount','Status','Message'});
        st_write_result('CoverageFilterRestoreResult', result);

        if any(Status == "FAIL")
            failures = result.Message(result.Status == "FAIL");
            st_log(cfg, 'ERROR', ...
                'Test Case coverage filter restore failed | %s', ...
                char(strjoin(failures, ' | ')));
            error('simtest:CoverageFilterRestoreFailed', ...
                'Could not restore and verify coverage filters: %s', ...
                char(strjoin(failures, ' | ')));
        end

        st_log(cfg, 'DEBUG', ...
            'Test Case coverage filter restore done and verified');
    end
end


function value = filter_property_value(filters)
if isempty(filters)
    value = "";
else
    value = filters;
end
end


function value = managed_application_text(applyDuringRun)
if applyDuringRun
    value = 'DURING_RUN';
else
    value = 'RESULT_ONLY';
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
