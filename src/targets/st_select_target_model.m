function cfg = st_select_target_model(forceSelectModel)
%ST_SELECT_TARGET_MODEL Select one Simulink model without resolving CUTPath.
%
% Usage:
%   cfg = st_select_target_model();
%       Reuse a valid runtime_target.mat when possible. Otherwise show the
%       model selection dialog.
%
%   cfg = st_select_target_model(true);
%       Always show the selection dialog and replace runtime_target.mat.
%
% This helper only selects the runtime target model. It does not modify
% TestManagement.xlsx and does not resolve any CUT paths.

if nargin < 1
    forceSelectModel = false;
end

cfg = st_config();

if ~logical(forceSelectModel) && ...
        cfg.HasRuntimeTarget && ...
        ~isempty(cfg.ModelFile) && ...
        isfile(cfg.ModelFile)

    cfg = st_require_runtime_target();
    return;
end

modelFiles = ...
    st_select_find_model_files( ...
        cfg.ModelSearchRoot, ...
        cfg.ModelSearchRecursive, ...
        cfg.ModelSearchExcludeFolders);

if isempty(modelFiles)
    error('No .slx or .mdl files found under: %s', cfg.ModelSearchRoot);
end

displayNames = ...
    st_select_relative_display_names( ...
        modelFiles, ...
        cfg.ModelSearchRoot);

[index, ok] = ...
    listdlg( ...
        'PromptString', 'Select the target Simulink model', ...
        'SelectionMode', 'single', ...
        'ListString', displayNames, ...
        'ListSize', [650 320], ...
        'Name', 'Target Model Selection');

if ~ok || isempty(index)
    error('Target model selection was cancelled.');
end

modelFile = modelFiles{index};
[~, modelName] = fileparts(modelFile);

TopModel = modelName; %#ok<NASGU>
ModelFile = modelFile; %#ok<NASGU>
SelectedAt = char(datetime( ...
    'now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss')); %#ok<NASGU>

save( ...
    cfg.RuntimeTargetFile, ...
    'TopModel', ...
    'ModelFile', ...
    'SelectedAt');

cfg = st_require_runtime_target();

fprintf('\n');
fprintf('============================================\n');
fprintf('Target Model Selected\n');
fprintf('Model : %s\n', cfg.TopModel);
fprintf('File  : %s\n', cfg.ModelFile);
fprintf('============================================\n');

end


function modelFiles = st_select_find_model_files(rootDir, recursive, excludeFolders)

if ~isfolder(rootDir)
    error('ModelSearchRoot does not exist: %s', rootDir);
end

if recursive
    slxInfo = dir(fullfile(rootDir, '**', '*.slx'));
    mdlInfo = dir(fullfile(rootDir, '**', '*.mdl'));
else
    slxInfo = dir(fullfile(rootDir, '*.slx'));
    mdlInfo = dir(fullfile(rootDir, '*.mdl'));
end

info = [slxInfo(:); mdlInfo(:)];
modelFiles = {};

for i = 1:numel(info)

    filePath = ...
        fullfile( ...
            info(i).folder, ...
            info(i).name);

    if st_select_path_contains_excluded_folder( ...
            filePath, ...
            excludeFolders)

        continue;
    end

    modelFiles{end+1,1} = filePath; %#ok<AGROW>
end

if ~isempty(modelFiles)
    modelFiles = unique(modelFiles, 'stable');
    modelFiles = sort(modelFiles);
end

end


function tf = st_select_path_contains_excluded_folder(filePath, excludeFolders)

normalized = strrep(char(filePath), char(92), '/');
parts = strsplit(normalized, '/');
tf = false;

for i = 1:numel(excludeFolders)
    if any(strcmpi(parts, excludeFolders{i}))
        tf = true;
        return;
    end
end

end


function names = st_select_relative_display_names(files, rootDir)

names = files;
rootNormalized = st_select_normalize_file_path(rootDir);

for i = 1:numel(files)

    fileNormalized = ...
        st_select_normalize_file_path( ...
            files{i});

    prefix = [rootNormalized '/'];

    if length(fileNormalized) >= length(prefix) && ...
            strncmpi(fileNormalized, prefix, length(prefix))

        names{i} = fileNormalized(length(prefix)+1:end);
    else
        names{i} = fileNormalized;
    end
end

end


function normalized = st_select_normalize_file_path(value)

normalized = strrep(char(value), char(92), '/');

while length(normalized) > 1 && normalized(end) == '/'
    normalized(end) = [];
end

end
