function cfg = st_apply_model_profile(cfg)
%ST_APPLY_MODEL_PROFILE Resolve a complete active configuration, never a mix.
cfg.ActiveModelProfile = '';
if ~isfile(cfg.RuntimeTargetFile), return; end
runtime = load(cfg.RuntimeTargetFile);
if ~isfield(runtime, 'ActiveModelProfile') || ...
        isempty(runtime.ActiveModelProfile), return; end
store = st_model_profile_store();
if isempty(store.Profiles)
    error('simtest:ModelProfileMissing','Active profile store is empty.');
end
index = find(strcmp({store.Profiles.Name}, runtime.ActiveModelProfile));
if numel(index) ~= 1
    error('simtest:ModelProfileMissing', 'Active profile is unavailable: %s', ...
        runtime.ActiveModelProfile);
end
profile = store.Profiles(index);
fields = {'ModelFile','ManagementExcel','ManagementSheet','TestFile', ...
    'TestSuiteName','StandaloneCoverageRootDir'};
for i = 1:numel(fields), cfg.(fields{i}) = profile.(fields{i}); end
[~, cfg.TopModel] = fileparts(cfg.ModelFile);
cfg.HasRuntimeTarget = true;
cfg.ActiveModelProfile = profile.Name;
cfg.ResultDir = profile.OutputRoot;
mapping = { ...
    'SldvDir','sldv'; 'SldvManifestFile','sldv/sldv_manifest.mat'; ...
    'WorkflowStateFile','state/workflow_state.mat'; ...
    'WorkflowStateSummaryFile','state/workflow_state.json'; ...
    'CoverageFilterDir','coverage_filters'; 'TestRunRootDir','runs'; ...
    'LatestReportPointer','latest.json'; 'LatestSummaryFile','TestSummary.xlsx'; ...
    'PerCutRunRootDir','per_cut_runs'; 'PerCutLatestPointer','per_cut_latest.json'; ...
    'ExportRootDir','exports'; 'VerificationRootDir','verification'; ...
    'ResultReportDir','reports'};
for i = 1:size(mapping,1)
    cfg.(mapping{i,1}) = fullfile(profile.OutputRoot, mapping{i,2});
end
end
