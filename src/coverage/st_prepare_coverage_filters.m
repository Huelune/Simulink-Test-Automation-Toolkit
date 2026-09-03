function R = st_prepare_coverage_filters(stageSelection)
%ST_PREPARE_COVERAGE_FILTERS Generate one managed CVF per Targets row.
%
% Each active target gets one rule for the CUT subsystem itself.

cfg = st_require_runtime_target();
T = st_load_targets(cfg.OnlyEnabled);
applicationMode = ...
    st_coverage_filter_application_mode(cfg.CoverageFilterApplicationMode);

if nargin < 1
    stageSelection = [];
end
selection = st_normalize_stage_selection(T, stageSelection);

n = height(T);
FilterFile = strings(n, 1);
RuleCount = zeros(n, 1);
RulePaths = strings(n, 1);
ApplicationMode = repmat(string(applicationMode), n, 1);
PreparationAction = selection.Action;
PreparationReason = selection.Reason;
Status = strings(n, 1);
Message = strings(n, 1);
ElapsedSec = zeros(n, 1);
Timestamp = strings(n, 1);

totalTimer = tic;
st_log(cfg, 'INFO', ...
    'Coverage filter generation start | rows=%d | application=%s', ...
    n, applicationMode);

if any(T.CoverageFilterMode ~= "OFF") && ~bdIsLoaded(cfg.TopModel)
    try
        st_log(cfg, 'DEBUG', ...
            'Coverage filter model load start | Model=%s', cfg.TopModel);
        load_system(cfg.TopModel);
        st_log(cfg, 'DEBUG', ...
            'Coverage filter model load done | Model=%s', cfg.TopModel);
    catch ME
        st_log(cfg, 'ERROR', ...
            'Coverage filter model load failed | %s: %s', ...
            ME.identifier, ME.message);
        rethrow(ME);
    end
end

for i = 1:n
    rowTimer = tic;
    mode = T.CoverageFilterMode(i);
    filterPath = st_coverage_filter_file(T(i,:), cfg);

    try
        if ~selection.Run(i)
            if mode ~= "OFF" && isfile(filterPath)
                FilterFile(i) = string(filterPath);
            end
            Status(i) = "CACHED";
            Message(i) = selection.Reason(i);
            ElapsedSec(i) = toc(rowTimer);
            continue;
        end

        st_log(cfg, 'DEBUG', ...
            ['[CoverageFilter %d/%d] start | TestCase=%s | ' ...
             'Mode=%s | Action=%s'], ...
            i, n, char(T.TestCaseName(i)), char(mode), ...
            char(T.CoverageFilterAction(i)));

        if mode == "OFF"
            delete_managed_file_quiet(filterPath, cfg.CoverageFilterDir);
            Status(i) = "OK";
            Message(i) = "Coverage filter disabled";
            ElapsedSec(i) = toc(rowTimer);
            continue;
        end

        generated = st_generate_coverage_filter_file( ...
            T(i,:), filterPath, cfg);
        RuleCount(i) = generated.RuleCount;
        RulePaths(i) = generated.RulePaths;

        if generated.Status == "WARN"
            delete_managed_file_quiet(filterPath, cfg.CoverageFilterDir);
            Status(i) = "WARN";
            Message(i) = generated.Message;
            st_log(cfg, 'WARN', ...
                ['[CoverageFilter %d/%d] generation warning | ' ...
                 'CUT=%s | TestCase=%s | %s'], ...
                i, n, char(T.CUTPath(i)), char(T.TestCaseName(i)), ...
                char(generated.Message));
            ElapsedSec(i) = toc(rowTimer);
            continue;
        end

        FilterFile(i) = string(filterPath);
        Status(i) = "OK";
        Message(i) = generated.Message;

        st_log(cfg, 'DEBUG', ...
            ['[CoverageFilter %d/%d] generated | rules=%d | ' ...
             'File=%s | elapsed=%.3f sec'], ...
            i, n, RuleCount(i), filterPath, toc(rowTimer));
    catch ME
        Status(i) = "FAIL";
        Message(i) = string(ME.message);
        st_log(cfg, 'ERROR', ...
            '[CoverageFilter %d/%d] failed | %s: %s', ...
            i, n, ME.identifier, ME.message);
    end

    ElapsedSec(i) = toc(rowTimer);
    Timestamp(i) = string(datetime('now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
end

% continue paths above still need result timing metadata
missingTimestamp = strlength(Timestamp) == 0;
Timestamp(missingTimestamp) = string(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));

R = table(T.No, T.CUTName, T.CUTPath, T.TestCaseName, ...
    T.CoverageFilterMode, T.CoverageFilterAction, ...
    T.CoverageFilterRationale, ApplicationMode, FilterFile, RuleCount, ...
    RulePaths, PreparationAction, PreparationReason, Status, Message, ...
    ElapsedSec, Timestamp, ...
    'VariableNames', {'No','CUTName','CUTPath','TestCaseName', ...
    'FilterMode','FilterAction','Rationale','ApplicationMode', ...
    'FilterFile','RuleCount','RulePaths','PreparationAction', ...
    'PreparationReason','Status','Message','ElapsedSec','Timestamp'});

st_write_result('CoverageFilterResult', R);
st_log(cfg, 'INFO', ...
    ['Coverage filter generation complete | OK=%d | WARN=%d | ' ...
     'FAIL=%d | elapsed=%.3f sec'], ...
    sum(Status == "OK"), sum(Status == "WARN"), ...
    sum(Status == "FAIL"), toc(totalTimer));
end


function delete_managed_file_quiet(path, managedRoot)
if ~isfile(path)
    return;
end
target = char(java.io.File(path).getCanonicalPath());
root = char(java.io.File(managedRoot).getCanonicalPath());
prefix = [root filesep];
if ispc
    managed = startsWith(lower(target), lower(prefix));
else
    managed = startsWith(target, prefix);
end
if ~managed
    error('simtest:UnsafeCoverageFilterDelete', ...
        'Refusing to delete a filter outside the managed directory: %s', ...
        target);
end
delete(target);
end
