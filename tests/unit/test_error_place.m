function tests = test_error_place
%TEST_ERROR_PLACE A failure's place on screen names toolkit functions only.
tests = functiontests(localfunctions);
end

function testFirstToolkitFrameAndMissingFunction(testCase)
ME = failure('MATLAB:UndefinedFunction', ...
    "함수 'st_log'은(는) 'struct'형 입력 인수에 대해 정의되지 않았습니다.", ...
    {'Secret_callback', 'run_exported_tests', 'st_run_standalone_coverage_pipeline>run_execute'}, ...
    [5, 239, 392]);
verifyEqual(testCase, st_error_place(ME), 'run_exported_tests 239줄 | 없는 함수 st_log');
end

function testOtherNamesNeverShow(testCase)
ME = failure('MATLAB:UndefinedFunction', ...
    "함수 'Secret_helper'은(는) 정의되지 않았습니다. D:\Secret_Model\x.slx", ...
    {'Secret_callback', 'Secret_model_init'}, [3, 7]);
verifyEqual(testCase, st_error_place(ME), '');
end

function testOtherErrorGivesThePlaceOnly(testCase)
ME = failure('simtest:Secret', 'Secret path D:\Secret_Model', ...
    {'st_export_final_document', 'st_rebuild_all'}, [120, 72]);
verifyEqual(testCase, st_error_place(ME), 'st_export_final_document 120줄');
end

function ME = failure(identifier, message, names, lines)
stack = struct('file', repmat({'Secret.m'}, size(names)), 'name', names, ...
    'line', num2cell(lines));
ME = struct('identifier', identifier, 'message', message, 'stack', stack(:));
end
