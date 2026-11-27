function st_setup()
%ST_SETUP Add the automation source and diagnostics folders to MATLAB path.
% Another toolkit clone set up earlier in this MATLAB session (one clone
% per model) comes off the path, so none of its functions can run in place
% of this clone's (st_other_toolkit_path_entries).

rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);

sourceDir = fullfile(rootDir, 'src');
diagnosticsDir = fullfile(rootDir, 'diagnostics', 'matlab');

if ~isfolder(sourceDir)
    error('Automation source folder not found: %s', sourceDir);
end

addpath(genpath(sourceDir));

if isfolder(diagnosticsDir)
    addpath(diagnosticsDir);
end

others = st_other_toolkit_path_entries(rootDir, strsplit(path, pathsep), ...
    which('st_setup', '-all'));
if ~isempty(others)
    rmpath(others{:});
end

resultDir = fullfile(rootDir, 'result');
if ~isfolder(resultDir)
    mkdir(resultDir);
end

fprintf('Automation project path added: %s\n', rootDir);
fprintf('Source path added            : %s\n', sourceDir);
if ~isempty(others)
    fprintf('Other toolkit clone removed  : %d path entries\n', numel(others));
    try
        st_log(st_config(), 'INFO', 'Other toolkit clone taken off the path | Entries=%d', ...
            numel(others));
    catch
        % Logging must never stop the setup.
    end
end
end
