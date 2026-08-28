function tests = test_sldv_tmax_rounding
tests = functiontests(localfunctions);
end


function testExactGridValueStaysOnGrid(testCase)
actual = st_quantize_sldv_tmax(1.06, 0.01);
verifyEqual(testCase, actual, 1.06, 'AbsTol', 1e-14);
end


function testFloatingPointTailRoundsUp(testCase)
actual = st_quantize_sldv_tmax(1.060000001, 0.01);
verifyEqual(testCase, actual, 1.07, 'AbsTol', 1e-14);
end


function testEmptyResolutionKeepsRawValue(testCase)
actual = st_quantize_sldv_tmax(1.060000001, []);
verifyEqual(testCase, actual, 1.060000001, 'AbsTol', 1e-14);
end
