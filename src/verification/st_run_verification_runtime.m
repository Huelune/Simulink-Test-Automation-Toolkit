function checks = st_run_verification_runtime( ...
        cfg, options, runDirectory, workspaceDirectory)
%ST_RUN_VERIFICATION_RUNTIME Run selected targets only in disposable copies.

checks = st_empty_verification_checks();
if any(strcmp(options.Target, {'CURRENT','BOTH'}))
    started = timestamp_text(); timerValue = tic;
    try
        currentRoot = fullfile(workspaceDirectory, 'current');
        mkdir(currentRoot);
        snapshot = st_create_verification_snapshot( ...
            cfg, fullfile(currentRoot, 'snapshots'), false);
        checks = [checks; st_verification_check( ...
            'RUNTIME.CURRENT.SNAPSHOT', 'EXPORT', options.Profile, ...
            'CURRENT', true, 'PASS', ...
            'Source inventory is unchanged and isolated bundle was created', ...
            snapshot.Manifest, toc(timerValue), started, timestamp_text())]; %#ok<AGROW>

        repeatCount = 1 + strcmp(options.Profile, 'CERTIFY');
        [runInfos, duration] = run_bundle( ...
            snapshot.Root, repeatCount, cfg, snapshot.SourceInventory);
        reportStatuses = strings(numel(runInfos),1);
        outcomesPass = true;
        for i = 1:numel(runInfos)
            reportStatuses(i) = string(runInfos{i}.Report.Status);
            outcomesPass = outcomesPass && ...
                report_final_outcomes_pass(runInfos{i}.Report.Summary);
        end
        if all(reportStatuses == "OK") && outcomesPass
            status = 'PASS'; message = sprintf( ...
                'Isolated current Test File ran %d time(s)', repeatCount);
        else
            status = 'FAIL'; message = sprintf( ...
                'Report status=%s, final outcomes pass=%d', ...
                char(strjoin(reportStatuses, ', ')), outcomesPass);
        end
        checks = [checks; st_verification_check( ...
            'RUNTIME.CURRENT.EXECUTION', 'EXECUTION', options.Profile, ...
            'CURRENT', true, status, message, snapshot.Root, duration, ...
            started, timestamp_text())]; %#ok<AGROW>

        [coverageStatus, coverageMessage] = current_coverage_status( ...
            runInfos{end}.Report.Summary);
        checks = [checks; st_verification_check( ...
            'RUNTIME.CURRENT.COVERAGE', 'COVERAGE', options.Profile, ...
            'CURRENT', false, coverageStatus, coverageMessage, ...
            runInfos{end}.Report.Summary)]; %#ok<AGROW>

        if repeatCount == 2
            checks = [checks; st_verification_check( ...
                'CERTIFY.CURRENT.REPEAT', 'EXPORT', options.Profile, ...
                'CURRENT', true, status, ...
                'Export template passed two fresh-workspace reruns', ...
                snapshot.Root)]; %#ok<AGROW>
        end
        after = st_verification_source_inventory(cfg);
        unchanged = isequal(snapshot.SourceInventory.Path, after.Path) && ...
            isequal(snapshot.SourceInventory.SHA256, after.SHA256);
        checks = [checks; st_verification_check( ...
            'RUNTIME.CURRENT.SOURCE_UNCHANGED', 'CORE', options.Profile, ...
            'CURRENT', true, ternary(unchanged, 'PASS', 'FAIL'), ...
            ternary(unchanged, 'Source files are unchanged', ...
            'A source file changed during isolated verification'))]; %#ok<AGROW>
    catch ME
        checks = [checks; st_verification_check( ...
            'RUNTIME.CURRENT', 'EXECUTION', options.Profile, 'CURRENT', ...
            true, st_verification_exception_status(ME), ...
            sprintf('%s: %s', ME.identifier, ME.message), ...
            runDirectory, toc(timerValue), started, timestamp_text())]; %#ok<AGROW>
    end
end

if any(strcmp(options.Target, {'FIXTURE','BOTH'}))
    try
        checks = [checks; st_run_verification_fixture( ...
            options, runDirectory, workspaceDirectory)]; %#ok<AGROW>
    catch ME
        checks = [checks; st_verification_check( ...
            'CERTIFY.FIXTURE', 'CORE', options.Profile, 'FIXTURE', ...
            true, st_verification_exception_status(ME), ...
            sprintf('%s: %s', ME.identifier, ME.message), ...
            workspaceDirectory)]; %#ok<AGROW>
    end
end
end

function pass = report_final_outcomes_pass(summaryPath)
targets = readtable(summaryPath, 'Sheet', 'Targets', ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
final = targets(targets.Run == "FINAL", :);
pass = ~isempty(final) && all(upper(final.Outcome) == "PASSED");
end

function [status, message] = current_coverage_status(summaryPath)
coverage = readtable(summaryPath, 'Sheet', 'Coverage', ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
rows = coverage.Run == "FINAL" & coverage.Total > 0 & ...
    ismember(coverage.Metric, ["Decision","Execution"]);
if ~any(rows)
    status = 'WARN';
    message = 'No non-empty current-model Decision/Execution rows were returned';
elseif any(coverage.Percentage(rows) < 100)
    status = 'WARN';
    message = sprintf('%d current-model coverage row(s) are below 100%%', ...
        sum(coverage.Percentage(rows) < 100));
else
    status = 'PASS';
    message = 'Current-model coverage was collected for reporting';
end
end

function [infos, duration] = run_bundle( ...
        bundleRoot, count, cfg, sourceInventory)
oldPath = path;
oldDirectory = pwd;
sourceSession = suspend_source_models(cfg, sourceInventory);
cleanup = onCleanup(@() restore_environment( ...
    oldDirectory, oldPath, bundleRoot, sourceSession)); %#ok<NASGU>
cd(bundleRoot);
addpath(bundleRoot, '-begin');
clear run_exported_tests
infos = cell(count,1);
timerValue = tic;
for i = 1:count
    infos{i} = run_exported_tests();
end
duration = toc(timerValue);
end

function session = suspend_source_models(cfg, inventory)
session = struct('Files', {{}}, 'OpenHarnesses', struct( ...
    'Owner', {}, 'Name', {}));
try
    targets = st_load_targets(cfg.OnlyEnabled);
    for i = 1:height(targets)
        harnessName = char(targets.HarnessName(i));
        if bdIsLoaded(harnessName)
            session.OpenHarnesses(end+1) = struct( ...
                'Owner', st_normalize_cut_path( ...
                targets.CUTPath(i), cfg.TopModel), ...
                'Name', harnessName); %#ok<AGROW>
        end
    end
catch
end

paths = cellstr(inventory.Path);
diagrams = find_system('Type', 'block_diagram');
for i = 1:numel(diagrams)
    try
        file = get_param(diagrams{i}, 'FileName');
        if isempty(file) || ~any(cellfun(@(p) same_path(p, file), paths))
            continue;
        end
        [~,~,extension] = fileparts(file);
        if ~ismember(lower(extension), {'.slx','.mdl'}), continue; end
        if strcmp(get_param(diagrams{i}, 'Dirty'), 'on')
            error('simtest:VerificationUnsavedSourceModel', ...
                'Source dependency model is dirty: %s', file);
        end
        session.Files{end+1,1} = file; %#ok<AGROW>
    catch ME
        if strcmp(ME.identifier, 'simtest:VerificationUnsavedSourceModel')
            rethrow(ME);
        end
    end
end
for i = 1:numel(session.OpenHarnesses)
    try
        sltest.harness.close(session.OpenHarnesses(i).Owner, ...
            session.OpenHarnesses(i).Name);
    catch
    end
end
for i = numel(session.Files):-1:1
    [~, model] = fileparts(session.Files{i});
    if bdIsLoaded(model), close_system(model, 0); end
end
end

function restore_environment( ...
        directory, pathValue, bundleRoot, sourceSession)
close_bundle_session(bundleRoot);
try, cd(directory); catch, end
path(pathValue);
clear run_exported_tests st_setup st_config st_project_root
for i = 1:numel(sourceSession.Files)
    try, load_system(sourceSession.Files{i}); catch, end
end
for i = 1:numel(sourceSession.OpenHarnesses)
    try
        sltest.harness.load(sourceSession.OpenHarnesses(i).Owner, ...
            sourceSession.OpenHarnesses(i).Name);
    catch
    end
end
end

function close_bundle_session(bundleRoot)
try
    files = sltest.testmanager.getTestFiles;
    for i = 1:numel(files)
        try
            if is_under_root(files(i).FilePath, bundleRoot)
                if files(i).Dirty, saveToFile(files(i)); end
                close(files(i));
            end
        catch
        end
    end
catch
end
diagrams = find_system('Type', 'block_diagram');
for i = numel(diagrams):-1:1
    try
        file = get_param(diagrams{i}, 'FileName');
        if ~isempty(file) && is_under_root(file, bundleRoot)
            close_system(diagrams{i}, 0);
        end
    catch
    end
end
end

function tf = is_under_root(value, root)
value = canonical_path(value);
root = canonical_path(root);
prefix = [root filesep];
if ispc
    tf = strcmpi(value, root) || startsWith(lower(value), lower(prefix));
else
    tf = strcmp(value, root) || startsWith(value, prefix);
end
end

function tf = same_path(left, right)
left = canonical_path(left);
right = canonical_path(right);
if ispc, tf = strcmpi(left, right); else, tf = strcmp(left, right); end
end

function value = canonical_path(value)
value = char(java.io.File(char(string(value))).getCanonicalPath());
end

function value = ternary(condition, yesValue, noValue)
if condition, value = yesValue; else, value = noValue; end
end

function text = timestamp_text()
text = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
