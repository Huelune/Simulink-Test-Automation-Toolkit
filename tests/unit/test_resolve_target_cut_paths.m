function tests = test_resolve_target_cut_paths
tests = functiontests(localfunctions);
end


function testRelativePathGetsTopModelPrefix(testCase)
targets = table("Sub/Grp/CUT", 'VariableNames', {'CUTPath'});

resolved = st_resolve_target_cut_paths(targets, test_cfg());

verifyEqual(testCase, resolved.CUTPath, "TOP_UNLOADED_MODEL/Sub/Grp/CUT");
end


function testFullPathIsUnchanged(testCase)
targets = table( ...
    ["TOP_UNLOADED_MODEL/Sub/CUT"; "TOP_UNLOADED_MODEL/TOP_UNLOADED_MODEL/Sub/CUT"], ...
    'VariableNames', {'CUTPath'});

resolved = st_resolve_target_cut_paths(targets, test_cfg());

verifyEqual(testCase, resolved.CUTPath, ...
    ["TOP_UNLOADED_MODEL/Sub/CUT"; "TOP_UNLOADED_MODEL/Sub/CUT"]);
end


function testTableWithoutCutPathIsReturnedAsIs(testCase)
targets = table(1, 'VariableNames', {'No'});

verifyEqual(testCase, st_resolve_target_cut_paths(targets, test_cfg()), targets);
end


function cfg = test_cfg()
cfg = struct('TopModel', 'TOP_UNLOADED_MODEL', 'VerboseLogging', false);
end
