function path = st_per_cut_coverage_filter_file(filterDirectory, targetRow)
%ST_PER_CUT_COVERAGE_FILTER_FILE Return a Test Case-named CVF path.

testCaseName = st_export_safe_name(char(string(targetRow.TestCaseName)));
path = fullfile(filterDirectory, [testCaseName '.cvf']);
end
