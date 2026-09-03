function info = st_bind_standalone_test_case(tc, modelInfo, cfg)
%ST_BIND_STANDALONE_TEST_CASE Rebind a Test Case after model re-export.

modelDirectory = fileparts(modelInfo.ModelPath);
pathCleanup = register_model_path(modelDirectory); %#ok<NASGU>
load_system(modelInfo.ModelPath);
modelCleanup = onCleanup(@() close_model(modelInfo.ModelName)); %#ok<NASGU>
actual = get_param(modelInfo.ModelName, 'FileName');
if ~same_path(actual, modelInfo.ModelPath)
    error('simtest:StandaloneModelLoadMismatch', ...
        'MATLAB loaded a different standalone model: %s', actual);
end
assessment = st_find_assessment_block(modelInfo.ModelName);
setProperty(tc, ...
    'Model', modelInfo.ModelName, ...
    'HarnessOwner', '', ...
    'HarnessName', '', ...
    'UseSignalEditorScenarios', false, ...
    'TestSequenceBlock', assessment);
info = struct('ModelName', modelInfo.ModelName, ...
    'ModelPath', modelInfo.ModelPath, ...
    'AssessmentBlock', assessment, 'Status', 'OK');
st_log(cfg, 'DEBUG', ...
    'Standalone Test Case rebound | TestCase=%s | Model=%s', ...
    char(tc.Name), modelInfo.ModelName);
end

function cleanup = register_model_path(directory)
addpath(directory, '-begin');
cleanup = onCleanup(@() remove_path(directory));
end

function remove_path(directory)
try, rmpath(directory); catch, end
end

function close_model(modelName)
if bdIsLoaded(modelName), close_system(modelName, 0); end
end

function tf = same_path(left, right)
left = char(java.io.File(char(left)).getCanonicalPath());
right = char(java.io.File(char(right)).getCanonicalPath());
if ispc, tf = strcmpi(left, right); else, tf = strcmp(left, right); end
end
