function info = st_classify_standalone_results(varargin)
%ST_CLASSIFY_STANDALONE_RESULTS Copy a standalone pipeline into the team tree.
%
%   info = st_classify_standalone_results()                 % LATEST pipeline
%   info = st_classify_standalone_results('PipelineId', id)
%   info = st_classify_standalone_results('PipelineRoot', folder)
%   info = st_classify_standalone_results(..., 'OutputDir', folder)
%   info = st_classify_standalone_results(..., 'Replace', false)
%   info = st_classify_standalone_results(..., 'DryRun', true)
%
% The pipeline keeps each CUT's files together in {NUM}_UT_REQ_{TestCase}.
% Team submission sorts them by kind instead, copying without renaming:
%
%   {TopModel}/                         stem of TestManager/{TopModel}.mldatx
%   ├── 테스트 케이스/{CUT 폴더}/       *.mat
%   ├── 테스트 보고서/{TopModel}.mldatx
%   ├── 테스트 보고서/{CUT 폴더}/       *.cvf *.cvt *.html + asset folders
%   └── 프로젝트/{CUT 폴더}/            *.slx
%
% The tree goes next to the pipeline folder unless OutputDir is given. The
% pipeline folder is left as it is. Files outside the three kinds and each
% CUT folder's scv_images are skipped and listed in info.Skipped.
%
% An existing output folder is deleted first (Replace, default true) so CUT
% folders from an earlier run cannot mix in. Only a folder that holds
% nothing but the three category folders is deleted; anything else stops
% the copy. Replace=false stops at any existing output folder.
%
% tools/python/classify_standalone_results.py applies the same rules for
% use without MATLAB. Change both together.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'PipelineId', 'LATEST', @(x) ischar(x) || isstring(x));
addParameter(p, 'PipelineRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputDir', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Replace', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'DryRun', false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

cfg = st_config();
pipelineRoot = strtrim(char(string(p.Results.PipelineRoot)));
if isempty(pipelineRoot)
    [~, manifestPath] = st_load_standalone_pipeline_manifest( ...
        cfg.StandaloneCoverageRootDir, p.Results.PipelineId);
    pipelineRoot = fileparts(manifestPath);
end
timerValue = tic;
st_log(cfg, 'INFO', ...
    'Standalone result classification start | Pipeline=%s | DryRun=%d', ...
    pipelineRoot, p.Results.DryRun);
try
    plan = build_plan(pipelineRoot, ...
        strtrim(char(string(p.Results.OutputDir))), p.Results.Replace);
    if ~p.Results.DryRun
        execute_plan(plan, cfg);
    end
catch ME
    st_log(cfg, 'ERROR', ...
        'Standalone result classification failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end

info = struct( ...
    'ModelName', plan.ModelName, ...
    'PipelineRoot', plan.PipelineRoot, ...
    'OutputDir', plan.OutputRoot, ...
    'CutFolders', {plan.CutFolders}, ...
    'TestCaseFiles', category_count(plan, category_name('TEST_CASE')), ...
    'ReportFiles', category_count(plan, category_name('REPORT')), ...
    'ProjectFiles', category_count(plan, category_name('PROJECT')), ...
    'AssetFolders', size(plan.Trees, 1), ...
    'Empty', {plan.Empty}, ...
    'Skipped', {plan.Skipped}, ...
    'DryRun', p.Results.DryRun);
print_summary(info);
for i = 1:size(plan.Empty, 1)
    st_log(cfg, 'WARN', ...
        'Standalone result classification empty category | CUT=%s | Category=%s', ...
        plan.Empty{i, 1}, plan.Empty{i, 2});
end
st_log(cfg, 'INFO', ...
    ['Standalone result classification complete | Output=%s | CUT=%d | ' ...
     'Skipped=%d | elapsed=%.3f sec'], ...
    plan.OutputRoot, numel(plan.CutFolders), numel(plan.Skipped), ...
    toc(timerValue));
end


function plan = build_plan(pipelineRoot, outputRoot, replace)
if ~isfolder(pipelineRoot)
    error('simtest:StandaloneClassifyInputMissing', ...
        'Pipeline folder does not exist: %s', pipelineRoot);
end
testFile = find_test_file(pipelineRoot);
[~, modelName] = fileparts(testFile);
if isempty(outputRoot)
    outputRoot = fullfile(fileparts(pipelineRoot), modelName);
end
validate_output(outputRoot, pipelineRoot, replace);

reportDir = category_name('REPORT');
plan = struct('PipelineRoot', pipelineRoot, 'ModelName', modelName, ...
    'OutputRoot', outputRoot, 'Replace', replace);
plan.CutFolders = {};
plan.Files = cell(0, 2);
plan.Trees = cell(0, 2);
plan.Directories = fullfile(outputRoot, categories())';
plan.Skipped = {};
plan.Empty = cell(0, 2);
plan.Files(end+1, :) = {testFile, fullfile(outputRoot, reportDir, ...
    [modelName '.mldatx'])};

entries = sorted_entries(pipelineRoot);
testManagerDir = fullfile(pipelineRoot, 'TestManager');
for i = 1:numel(entries)
    entry = entries(i);
    source = fullfile(pipelineRoot, entry.name);
    if entry.isdir && ~isempty(regexp(entry.name, '^\d{3}_UT_REQ_', 'once'))
        plan = add_cut_folder(plan, source, entry.name);
    elseif entry.isdir && strcmp(source, testManagerDir)
        children = sorted_entries(source);
        for j = 1:numel(children)
            child = fullfile(source, children(j).name);
            if ~strcmp(child, testFile)
                plan.Skipped{end+1, 1} = ['TestManager/' children(j).name];
            end
        end
    else
        plan.Skipped{end+1, 1} = entry.name;
    end
end
end

function plan = add_cut_folder(plan, cutRoot, cutName)
plan.CutFolders{end+1, 1} = cutName;
names = categories();
counts = zeros(1, numel(names));
for k = 1:numel(names)
    plan.Directories{end+1, 1} = fullfile(plan.OutputRoot, names{k}, cutName);
end
entries = sorted_entries(cutRoot);
for i = 1:numel(entries)
    name = entries(i).name;
    source = fullfile(cutRoot, name);
    if entries(i).isdir
        if strcmpi(name, 'scv_images')
            plan.Skipped{end+1, 1} = [cutName '/' name];
        else
            % Any other folder is a cvhtml asset folder, which has to sit
            % next to its HTML for the report to render.
            plan.Trees(end+1, :) = {source, fullfile(plan.OutputRoot, ...
                category_name('REPORT'), cutName, name)};
        end
        continue;
    end
    category = category_for(name);
    if isempty(category)
        plan.Skipped{end+1, 1} = [cutName '/' name];
        continue;
    end
    plan.Files(end+1, :) = {source, ...
        fullfile(plan.OutputRoot, category, cutName, name)};
    counts(strcmp(names, category)) = counts(strcmp(names, category)) + 1;
end
for k = find(counts == 0)
    plan.Empty(end+1, :) = {cutName, names{k}};
end
end

function execute_plan(plan, cfg)
if plan.Replace && isfolder(plan.OutputRoot)
    st_log(cfg, 'INFO', ...
        'Standalone result classification replaces %s', plan.OutputRoot);
    [removed, message] = rmdir(plan.OutputRoot, 's');
    if ~removed
        error('simtest:StandaloneClassifyReplaceFailed', ...
            'Cannot remove the previous submission tree %s: %s', ...
            plan.OutputRoot, message);
    end
end
for i = 1:numel(plan.Directories)
    make_folder(plan.Directories{i});
end
for i = 1:size(plan.Files, 1)
    make_folder(fileparts(plan.Files{i, 2}));
    copy_or_fail(plan.Files{i, 1}, plan.Files{i, 2});
end
for i = 1:size(plan.Trees, 1)
    make_folder(plan.Trees{i, 2});
    if ~isempty(sorted_entries(plan.Trees{i, 1}))
        copy_or_fail(fullfile(plan.Trees{i, 1}, '*'), plan.Trees{i, 2});
    end
end
end

function copy_or_fail(source, destination)
[copied, message] = copyfile(source, destination, 'f');
if ~copied
    error('simtest:StandaloneClassifyCopyFailed', ...
        'Cannot copy %s to %s: %s', source, destination, message);
end
end

function make_folder(folder)
if isfolder(folder), return; end
[created, message] = mkdir(folder);
if ~created
    error('simtest:StandaloneClassifyCopyFailed', ...
        'Cannot create %s: %s', folder, message);
end
end

function testFile = find_test_file(pipelineRoot)
folder = fullfile(pipelineRoot, 'TestManager');
if ~isfolder(folder)
    error('simtest:StandaloneClassifyTestFileMissing', ...
        'TestManager folder is missing: %s', folder);
end
listing = dir(fullfile(folder, '*.mldatx'));
listing = listing(~[listing.isdir]);
if numel(listing) ~= 1
    names = strjoin(sort({listing.name}), ', ');
    if isempty(names), names = '(none)'; end
    error('simtest:StandaloneClassifyTestFileMissing', ...
        'TestManager must hold exactly one .mldatx. Found: %s', names);
end
testFile = fullfile(folder, listing(1).name);
end

function validate_output(outputRoot, pipelineRoot, replace)
output = canonical(outputRoot);
input = canonical(pipelineRoot);
if strcmpi(output, input) || startsWith(lower(output), lower([input filesep]))
    error('simtest:StandaloneClassifyOutputInvalid', ...
        'The output folder is inside the pipeline folder: %s', outputRoot);
end
if isfile(outputRoot)
    error('simtest:StandaloneClassifyOutputInvalid', ...
        'A file is in the way of the output folder: %s', outputRoot);
end
if ~isfolder(outputRoot), return; end
if ~replace
    error('simtest:StandaloneClassifyOutputExists', ...
        ['The output folder already exists and Replace is false: %s'], ...
        outputRoot);
end
entries = sorted_entries(outputRoot);
unexpected = setdiff({entries.name}, categories());
if ~isempty(unexpected)
    error('simtest:StandaloneClassifyOutputNotATree', ...
        ['%s holds more than a submission tree (%s), so it is not ' ...
         'deleted. Move it away or pick another OutputDir.'], ...
        outputRoot, strjoin(unexpected, ', '));
end
end

function entries = sorted_entries(folder)
entries = dir(folder);
entries = entries(~ismember({entries.name}, {'.', '..'}));
[~, order] = sort({entries.name});
entries = entries(order);
end

function names = categories()
names = {category_name('TEST_CASE'), category_name('REPORT'), ...
    category_name('PROJECT')};
end

function name = category_name(key)
switch key
    case 'TEST_CASE', name = '테스트 케이스';
    case 'REPORT', name = '테스트 보고서';
    case 'PROJECT', name = '프로젝트';
end
end

function category = category_for(fileName)
[~, ~, extension] = fileparts(fileName);
switch lower(extension)
    case '.mat', category = category_name('TEST_CASE');
    case '.slx', category = category_name('PROJECT');
    case {'.cvf', '.cvt', '.html'}, category = category_name('REPORT');
    otherwise, category = '';
end
end

function count = category_count(plan, category)
marker = [fullfile(plan.OutputRoot, category) filesep];
count = sum(startsWith(plan.Files(:, 2), marker));
end

function value = canonical(path)
value = char(java.io.File(char(path)).getCanonicalPath());
end

function print_summary(info)
fprintf('\n============================================\n');
fprintf('Standalone submission tree\n');
fprintf('Model      : %s\n', info.ModelName);
fprintf('Input      : %s\n', info.PipelineRoot);
fprintf('Output     : %s\n', info.OutputDir);
fprintf('CUT        : %d\n', numel(info.CutFolders));
fprintf('테스트 케이스 : %d files\n', info.TestCaseFiles);
fprintf('테스트 보고서 : %d files (+%d asset folders)\n', ...
    info.ReportFiles, info.AssetFolders);
fprintf('프로젝트     : %d files\n', info.ProjectFiles);
for i = 1:size(info.Empty, 1)
    fprintf('WARN empty : %s / %s\n', info.Empty{i, 1}, info.Empty{i, 2});
end
fprintf('Skipped    : %d\n', numel(info.Skipped));
if info.DryRun
    fprintf('[DRY-RUN] nothing was copied\n');
end
fprintf('============================================\n');
end
