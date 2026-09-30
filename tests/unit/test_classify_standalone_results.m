function tests = test_classify_standalone_results
tests = functiontests(localfunctions);
end


function setup(testCase)
root = tempname;
mkdir(root);
testCase.TestData.Root = root;
testCase.TestData.Pipeline = build_pipeline(root);
testCase.addTeardown(@() rmdir(root, 's'));
end


function testSortsFilesByKindAndSkipsTheRest(testCase)
pipeline = testCase.TestData.Pipeline;

info = st_classify_standalone_results('PipelineRoot', pipeline);

out = fullfile(testCase.TestData.Root, 'TOP');
verifyEqual(testCase, info.OutputDir, out);
verifyEqual(testCase, info.ModelName, 'TOP');
cutA = '001_UT_REQ_Controller_12345';
verifyTrue(testCase, isfile(fullfile(out, '테스트 케이스', cutA, ...
    'TOP_Controller_Harness_HarnessInputs.mat')));
verifyTrue(testCase, isfile(fullfile(out, '프로젝트', cutA, ...
    'Controller_Harness.slx')));
for name = {'UT_REQ_Controller_12345.cvf', 'UT_REQ_Controller_12345.cvt', ...
        'UT_REQ_Controller_12345.html'}
    verifyTrue(testCase, isfile(fullfile(out, '테스트 보고서', cutA, name{1})));
end
verifyTrue(testCase, isfile(fullfile(out, '테스트 보고서', cutA, ...
    'UT_REQ_Controller_12345_files', 'img', 'a.png')));
verifyTrue(testCase, isfile(fullfile(out, '테스트 보고서', 'TOP.mldatx')));
verifyFalse(testCase, isfolder(fullfile(out, '테스트 보고서', cutA, 'scv_images')));
verifyTrue(testCase, ismember([cutA '/scv_images'], info.Skipped));
verifyTrue(testCase, ismember('CoverageSummary.xlsx', info.Skipped));
verifyTrue(testCase, ismember('TestManager/open_standalone_coverage_test_manager.m', ...
    info.Skipped));
% The failed CUT has no report files, so its report category is empty.
verifyTrue(testCase, any(strcmp(info.Empty(:, 1), '002_UT_REQ_Motor_67890') & ...
    strcmp(info.Empty(:, 2), '테스트 보고서')));
verifyTrue(testCase, isfile(fullfile(pipeline, cutA, 'Controller_Harness.slx')));
end


function testExistingTreeStopsUnlessReplaced(testCase)
pipeline = testCase.TestData.Pipeline;
st_classify_standalone_results('PipelineRoot', pipeline);
stale = fullfile(testCase.TestData.Root, 'TOP', '프로젝트', '099_UT_REQ_Old');
mkdir(stale);

verifyError(testCase, ...
    @() st_classify_standalone_results('PipelineRoot', pipeline), ...
    'simtest:StandaloneClassifyOutputExists');

st_classify_standalone_results('PipelineRoot', pipeline, 'Replace', true);
verifyFalse(testCase, isfolder(stale));
end


function testReplaceRefusesAFolderThatIsNotATree(testCase)
pipeline = testCase.TestData.Pipeline;
other = fullfile(testCase.TestData.Root, 'TOP');
mkdir(other);
write_file(fullfile(other, 'notes.txt'));

verifyError(testCase, @() st_classify_standalone_results( ...
    'PipelineRoot', pipeline, 'Replace', true), ...
    'simtest:StandaloneClassifyOutputNotATree');
verifyTrue(testCase, isfile(fullfile(other, 'notes.txt')));
end


function testDryRunCopiesNothing(testCase)
info = st_classify_standalone_results( ...
    'PipelineRoot', testCase.TestData.Pipeline, 'DryRun', true);
verifyTrue(testCase, info.DryRun);
verifyFalse(testCase, isfolder(info.OutputDir));
end


function testOutputInsideThePipelineIsRejected(testCase)
pipeline = testCase.TestData.Pipeline;
verifyError(testCase, @() st_classify_standalone_results( ...
    'PipelineRoot', pipeline, 'OutputDir', fullfile(pipeline, 'tree')), ...
    'simtest:StandaloneClassifyOutputInvalid');
end


function testPipelineAllClassifiesByDefault(testCase)
text = fileread(fullfile(st_project_root(), 'src', 'pipeline', ...
    'st_run_standalone_coverage_pipeline.m'));
verifyTrue(testCase, contains(text, ...
    "addParameter(p, 'ClassifyResults', true"));
verifyTrue(testCase, contains(text, ...
    "if strcmp(action, 'ALL') && p.Results.ClassifyResults"));
verifyTrue(testCase, contains(text, "'PipelineRoot', pipelineRoot, 'Replace', true"));
end


function pipeline = build_pipeline(root)
pipeline = fullfile(root, '20250921_143312_871_3f9a2c1b');
write_file(fullfile(pipeline, 'pipeline-manifest.json'));
write_file(fullfile(pipeline, 'CoverageSummary.xlsx'));
write_file(fullfile(pipeline, 'logs', 'execution.log'));
write_file(fullfile(pipeline, '.work', 'bundle', 'x.txt'));
write_file(fullfile(pipeline, 'TestManager', 'TOP.mldatx'));
write_file(fullfile(pipeline, 'TestManager', ...
    'open_standalone_coverage_test_manager.m'));
cutA = fullfile(pipeline, '001_UT_REQ_Controller_12345');
write_file(fullfile(cutA, 'Controller_Harness.slx'));
write_file(fullfile(cutA, 'TOP_Controller_Harness_HarnessInputs.mat'));
write_file(fullfile(cutA, 'UT_REQ_Controller_12345.cvf'));
write_file(fullfile(cutA, 'UT_REQ_Controller_12345.cvt'));
write_file(fullfile(cutA, 'UT_REQ_Controller_12345.html'));
write_file(fullfile(cutA, 'UT_REQ_Controller_12345_files', 'style.css'));
write_file(fullfile(cutA, 'UT_REQ_Controller_12345_files', 'img', 'a.png'));
write_file(fullfile(cutA, 'scv_images', 'block1.png'));
write_file(fullfile(cutA, 'target-manifest.json'));
cutB = fullfile(pipeline, '002_UT_REQ_Motor_67890');
write_file(fullfile(cutB, 'Motor_Harness.slx'));
write_file(fullfile(cutB, 'TOP_Motor_Harness_HarnessInputs.mat'));
end


function write_file(path)
folder = fileparts(path);
if ~isfolder(folder), mkdir(folder); end
fid = fopen(path, 'w');
fwrite(fid, 'x');
fclose(fid);
end
