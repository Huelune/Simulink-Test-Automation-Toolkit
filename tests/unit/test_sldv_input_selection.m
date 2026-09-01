function tests = test_sldv_input_selection
tests = functiontests(localfunctions);
end


function testStrictModeRejectsUnexpectedInputs(testCase)
verifyError(testCase, ...
    @() st_select_sldv_input_indices( ...
        {'Requested'; 'NewSignal'}, {'Requested'}, false), ...
    'simtest:UnexpectedSldvInputs');
end


function testIgnoreModeKeepsOnlyHarnessInputs(testCase)
[indices, selected, ignored] = ...
    st_select_sldv_input_indices( ...
        {'InputA'; 'NewSignal'; 'InputB'}, ...
        {'InputB'; 'InputA'; 'HarnessOnly'}, ...
        true);

verifyEqual(testCase, indices, [1; 3]);
verifyEqual(testCase, selected, {'InputA'; 'InputB'});
verifyEqual(testCase, ignored, {'NewSignal'});
end


function testDuplicateSldvInputsStillFailInIgnoreMode(testCase)
verifyError(testCase, ...
    @() st_select_sldv_input_indices( ...
        {'InputA'; 'InputA'}, {'InputA'}, true), ...
    'simtest:DuplicateSldvInputNames');
end


function testIgnoreModeAllowsNoCommonInputs(testCase)
[indices, selected, ignored] = ...
    st_select_sldv_input_indices( ...
        {'NewA'; 'NewB'}, {'HarnessA'}, true);

verifyEmpty(testCase, indices);
verifyEmpty(testCase, selected);
verifyEqual(testCase, ignored, {'NewA'; 'NewB'});
end


function testIgnoreOptionMustBeScalar(testCase)
verifyError(testCase, ...
    @() st_select_sldv_input_indices( ...
        {'InputA'}, {'InputA'}, [true false]), ...
    'simtest:InvalidIgnoreUnexpectedSldvInputs');
end
