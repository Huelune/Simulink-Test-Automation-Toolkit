function demo = st_setup_demo(destination)
%ST_SETUP_DEMO Generate the demo model and make it the toolkit's current target.
%
% demo = st_setup_demo()
% demo = st_setup_demo(destination)
%
% Runs st_create_demo_model in DESTINATION (default: a new folder under
% tempdir), then prepares this toolkit to run it:
%   - copies the demo workbook over <repo>/TestManagement.xlsx, the one
%     place the toolkit reads, after backing up the existing file as
%     TestManagement.backup_<timestamp>.xlsx;
%   - backs up runtime_target.mat the same way, then selects the demo model
%     (TopModel, ModelFile) and sets the standalone coverage root to
%     <destination>/model_result.
% After this, st_pre_validate_targets and st_run_from_harness run the demo.
% The demo's results land in this repository's result folder next to the
% real ones; to keep them apart, run the demo from a copy of the toolkit.
% Restore the real target by copying the backups in demo.Backups back.
cfg = struct('ConsoleLogLevel','INFO');
st_log(cfg,'INFO','Demo setup start');
if nargin < 1 || isempty(destination)
    destination = fullfile(tempdir,['st_demo_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
end
try
    demo = st_create_demo_model(destination);
    root = st_project_root();
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
    backups = strings(0,1);
    workbook = fullfile(root,'TestManagement.xlsx');
    backups = [backups; backup(workbook,stamp,cfg)];
    copyfile(demo.ManagementExcel,workbook);
    st_log(cfg,'INFO','Demo workbook installed | File=%s',workbook);
    targetFile = fullfile(root,'runtime_target.mat');
    backups = [backups; backup(targetFile,stamp,cfg)];
    st_save_runtime_target_fields(targetFile, ...
        struct('TopModel',demo.TopModel,'ModelFile',demo.ModelFile));
    st_set_standalone_coverage_root(fullfile(demo.Root,'model_result'));
    demo.Backups = backups;
    demo.StandaloneCoverageRoot = fullfile(demo.Root,'model_result');
    st_log(cfg,'INFO','Demo setup complete | TopModel=%s | Backups=%d | Next: st_pre_validate_targets, st_run_from_harness', ...
        demo.TopModel,numel(backups));
catch ME
    st_log(cfg,'ERROR','Demo setup failed | %s',ME.message);
    rethrow(ME);
end
end

function saved = backup(file,stamp,cfg)
% Returns the backup path, or nothing when there was no file to back up.
saved = strings(0,1);
if ~isfile(file), return; end
[folder,name,extension] = fileparts(file);
saved = string(fullfile(folder,[name '.backup_' stamp extension]));
copyfile(file,saved);
st_log(cfg,'INFO','Backed up before the demo replaces it | File=%s | Backup=%s',file,saved);
end
