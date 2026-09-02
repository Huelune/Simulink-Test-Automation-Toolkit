function tests = test_cleanup_results
tests = functiontests(localfunctions);
end


function testDefaultIsDryRunAndTargetsResultOnly(testCase)
cfg = st_config();
plan = st_cleanup_results();

verifyFalse(testCase, any(plan.Status == "DELETED"));
verifyTrue(testCase, all(under_result(plan.Path, cfg.ResultDir)));
verifyFalse(testCase, any(contains(plan.Path, 'runtime_target.mat')));
verifyFalse(testCase, any(endsWith(plan.Path, '.mldatx')));
end


function testScopeSelectsOnlyRequestedArtifacts(testCase)
plan = st_cleanup_results('Scope', {'REPORTS','STATE'});

verifyTrue(testCase, all(ismember(plan.Scope, ["REPORTS","STATE"])));
verifyEqual(testCase, unique(plan.Scope, 'stable'), ["REPORTS";"STATE"]);
end


function testUnknownScopeIsRejected(testCase)
verifyError(testCase, ...
    @() st_cleanup_results('Scope', 'UNKNOWN'), ...
    'simtest:InvalidCleanupScope');
end


function testFilterScopeTargetsManagedCoverageDirectory(testCase)
cfg = st_config();
plan = st_cleanup_results('Scope', 'FILTERS');

verifyEqual(testCase, height(plan), 1);
verifyEqual(testCase, plan.Scope, "FILTERS");
verifyEqual(testCase, plan.Path, string(cfg.CoverageFilterDir));
end


function tf = under_result(paths, root)
root = char(java.io.File(root).getCanonicalPath());
prefix = [root filesep];
tf = false(numel(paths), 1);
for i = 1:numel(paths)
    path = char(java.io.File(char(paths(i))).getCanonicalPath());
    if ispc
        tf(i) = startsWith(lower(path), lower(prefix));
    else
        tf(i) = startsWith(path, prefix);
    end
end
end
