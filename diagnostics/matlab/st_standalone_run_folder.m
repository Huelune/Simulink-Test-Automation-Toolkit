function [outputRoot, pipelineId] = st_standalone_run_folder(folder)
%ST_STANDALONE_RUN_FOLDER Turn a chosen folder into the opener's OutputRoot and PipelineId.
%
% [outputRoot, pipelineId] = st_standalone_run_folder(folder)
%
% A standalone pipeline run folder holds pipeline-manifest.json: its parent
% is the OutputRoot and its name the PipelineId. The standalone root holds
% latest.json and stands for its latest run (PipelineId 'LATEST'). Error
% messages carry no path, since the caller may print them.
if ~(ischar(folder) || isstring(folder)) || strlength(strtrim(string(folder))) == 0 ...
        || ~isfolder(folder)
    error('simtest:StandaloneFolderMissing', 'The chosen folder does not exist.');
end
folder = st_absolute_path(folder);
if isfile(fullfile(folder, 'pipeline-manifest.json'))
    [outputRoot, name, extension] = fileparts(folder);
    pipelineId = [name extension];
elseif isfile(fullfile(folder, 'latest.json'))
    outputRoot = folder;
    pipelineId = 'LATEST';
else
    error('simtest:StandaloneFolderUnknown', ...
        'The folder is neither a standalone run folder nor the standalone root.');
end
end
