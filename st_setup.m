function st_setup()
%ST_SETUP Add the automation source and diagnostics folders to MATLAB path.

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

resultDir = fullfile(rootDir, 'result');
if ~isfolder(resultDir)
    mkdir(resultDir);
end

fprintf('Automation project path added: %s\n', rootDir);
fprintf('Source path added            : %s\n', sourceDir);
end
