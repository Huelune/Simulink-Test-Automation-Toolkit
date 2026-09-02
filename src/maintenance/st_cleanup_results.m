function plan = st_cleanup_results(varargin)
%ST_CLEANUP_RESULTS Preview or delete known generated result artifacts.
%
% plan = st_cleanup_results()
% plan = st_cleanup_results('Scope', {'REPORTS','STATE'})
% plan = st_cleanup_results('Scope', 'FILTERS')
% plan = st_cleanup_results('Scope', 'ALL', 'Apply', true)
%
% The default is a dry run. Only known paths below cfg.ResultDir can be
% deleted. Source models, TestManagement.xlsx, runtime_target.mat, Test
% Files, and user-supplied SLDV data outside result/ are never selected.

p = inputParser;
p.FunctionName = 'st_cleanup_results';
addParameter(p, 'Scope', 'ALL', ...
    @(v) ischar(v) || isstring(v) || iscell(v));
addParameter(p, 'Apply', false, ...
    @(v) islogical(v) && isscalar(v));
parse(p, varargin{:});

scopes = normalize_scopes(p.Results.Scope);
applyChanges = logical(p.Results.Apply);
cfg = st_config();
items = cleanup_items(cfg);

if any(scopes == "ALL")
    selected = true(height(items), 1);
else
    selected = ismember(items.Scope, scopes);
end
items = items(selected, :);

count = height(items);
Exists = false(count, 1);
Kind = strings(count, 1);
Action = strings(count, 1);
Status = strings(count, 1);
Message = strings(count, 1);

fprintf('\n============================================\n');
fprintf('Generated Result Cleanup\n');
fprintf('Mode   : %s\n', ternary(applyChanges, 'APPLY', 'DRY-RUN'));
fprintf('Scopes : %s\n', char(strjoin(scopes, ', ')));
fprintf('============================================\n');

for i = 1:count
    path = char(items.Path(i));

    try
        validate_cleanup_path(path, cfg.ResultDir);

        if isfolder(path)
            Exists(i) = true;
            Kind(i) = "FOLDER";
            Action(i) = "DELETE_RECURSIVE";
        elseif isfile(path)
            Exists(i) = true;
            Kind(i) = "FILE";
            Action(i) = "DELETE";
        else
            Kind(i) = "MISSING";
            Action(i) = "NONE";
            Status(i) = "MISSING";
            Message(i) = "Generated artifact does not exist";
        end

        if Exists(i) && ~applyChanges
            Status(i) = "DRY_RUN";
            Message(i) = "Would delete generated artifact";
        elseif Exists(i) && applyChanges
            if Kind(i) == "FOLDER"
                [removed, removeMessage] = rmdir(path, 's');
                if ~removed
                    error('simtest:CleanupDeleteFailed', ...
                        'Cannot remove folder %s: %s', path, removeMessage);
                end
            else
                delete(path);
            end

            Status(i) = "DELETED";
            Message(i) = "Generated artifact deleted";
        end

    catch ME
        Status(i) = "FAIL";
        Message(i) = string(ME.message);
    end

    fprintf('%-12s %-12s %s\n', ...
        char(Status(i)), char(items.Scope(i)), path);
end

plan = table( ...
    items.Scope, items.Path, Exists, Kind, Action, Status, Message, ...
    'VariableNames', { ...
        'Scope','Path','Exists','Kind','Action','Status','Message'});

fprintf('============================================\n');
fprintf('Deleted : %d\n', sum(Status == "DELETED"));
fprintf('Planned : %d\n', sum(Status == "DRY_RUN"));
fprintf('Missing : %d\n', sum(Status == "MISSING"));
fprintf('Failed  : %d\n', sum(Status == "FAIL"));
fprintf('============================================\n');

if any(Status == "FAIL")
    warning('simtest:CleanupIncomplete', ...
        'Some generated artifacts could not be deleted. Inspect plan.');
end
end


function scopes = normalize_scopes(value)
if ischar(value)
    scopes = string({value});
else
    scopes = string(value(:));
end

scopes = upper(strtrim(scopes));
scopes = unique(scopes(strlength(scopes) > 0), 'stable');
allowed = ["ALL","REPORTS","SLDV","STATE", ...
    "RUNS","EXPORTS","VERIFICATION","FILTERS"];

if isempty(scopes) || any(~ismember(scopes, allowed))
    invalid = scopes(~ismember(scopes, allowed));
    if isempty(invalid)
        invalidText = '<empty>';
    else
        invalidText = char(strjoin(invalid, ', '));
    end
    error('simtest:InvalidCleanupScope', ...
        'Invalid cleanup Scope: %s. Allowed: %s.', ...
        invalidText, char(strjoin(allowed, ', ')));
end

if any(scopes == "ALL") && numel(scopes) > 1
    error('simtest:InvalidCleanupScope', ...
        'Scope ALL cannot be combined with another cleanup scope.');
end
end


function items = cleanup_items(cfg)
Scope = [ ...
    "REPORTS"; ...
    "SLDV"; ...
    "STATE"; ...
    "RUNS"; ...
    "RUNS"; ...
    "RUNS"; ...
    "EXPORTS"; ...
    "VERIFICATION"; ...
    "FILTERS"];

Path = string({ ...
    cfg.ResultReportDir; ...
    cfg.SldvDir; ...
    fileparts(cfg.WorkflowStateFile); ...
    cfg.TestRunRootDir; ...
    cfg.LatestReportPointer; ...
    cfg.LatestSummaryFile; ...
    cfg.ExportRootDir; ...
    cfg.VerificationRootDir; ...
    cfg.CoverageFilterDir});

items = table(Scope, Path);
end


function validate_cleanup_path(path, resultRoot)
target = canonical_path(path);
root = canonical_path(resultRoot);

if same_path(target, root)
    error('simtest:UnsafeCleanupPath', ...
        'The result root itself cannot be deleted: %s', target);
end

prefix = [root filesep];
if ispc
    underRoot = startsWith(lower(target), lower(prefix));
else
    underRoot = startsWith(target, prefix);
end

if ~underRoot
    error('simtest:UnsafeCleanupPath', ...
        'Cleanup target is outside the result directory: %s', target);
end
end


function value = canonical_path(value)
value = char(java.io.File(char(value)).getCanonicalPath());
end


function tf = same_path(left, right)
if ispc
    tf = strcmpi(left, right);
else
    tf = strcmp(left, right);
end
end


function value = ternary(condition, yesValue, noValue)
if condition
    value = yesValue;
else
    value = noValue;
end
end
