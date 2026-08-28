function st_setup()
%ST_SETUP Add this automation folder to the MATLAB path.

rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);

resultDir = fullfile(rootDir, 'result');
if ~isfolder(resultDir)
    mkdir(resultDir);
end

fprintf('Automation path added: %s\n', rootDir);
end
