function info = st_export_result_set_report( ...
        resultObj, targetConfig, outputDirectory, resultName, varargin)
%ST_EXPORT_RESULT_SET_REPORT Export one selected Test Manager ResultSet.

p = inputParser;
addParameter(p, 'CoverageReportMode', 'SUMMARY', ...
    @(x) ismember(upper(string(x)), ["SUMMARY","FULL"]));
addParameter(p, 'IncludeOfficialReport', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'IncludePortableCoverageDetail', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'LogConfig', struct(), @isstruct);
addParameter(p, 'ResultLabel', 'SELECTED', ...
    @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
coverageReportMode = upper(char(string(p.Results.CoverageReportMode)));
includeOfficialReport = logical(p.Results.IncludeOfficialReport);
includePortableCoverageDetail = logical( ...
    p.Results.IncludePortableCoverageDetail);
logConfig = p.Results.LogConfig;
resultLabel = upper(char(strtrim(string(p.Results.ResultLabel))));
artifactStem = lower(resultLabel);
artifactStem = [upper(artifactStem(1)) artifactStem(2:end)];

if ~isfolder(outputDirectory), mkdir(outputDirectory); end
rawDirectory = fullfile(outputDirectory, 'raw');
officialDirectory = fullfile(outputDirectory, 'official');
coverageDirectory = fullfile(outputDirectory, 'coverage');
mkdir(rawDirectory);
mkdir(officialDirectory);
mkdir(coverageDirectory);

artifacts = empty_artifact_table();
targets = empty_target_table();
iterations = empty_iteration_table();
coverage = empty_coverage_table();

integrityBaseline = table();
integrityBaselineAvailable = false;
integrityTimer = tic;
st_log(logConfig, 'DEBUG', ...
    'Result coverage integrity check start | stage=BEFORE_EXPORT | label=%s', ...
    resultLabel);
try
    integrityBaseline = coverage_integrity_snapshot(resultObj);
    integrityBaselineAvailable = true;
    st_log(logConfig, 'DEBUG', ...
        ['Result coverage integrity check complete | ' ...
         'stage=BEFORE_EXPORT | objects=%d | elapsed=%.3f sec'], ...
        height(integrityBaseline), toc(integrityTimer));
catch ME
    artifacts = record_artifact(artifacts, 'RESULT_INTEGRITY', '', ...
        'FAIL', ['Coverage data was invalid before export: ' ME.message]);
    st_log(logConfig, 'ERROR', ...
        'Result coverage integrity check failed before export | %s: %s', ...
        ME.identifier, ME.message);
end

stepTimer = report_step_start(1, 6, 'Collect Test Result Hierarchy');
try
    [targets, iterations] = st_collect_test_result_summary( ...
        resultObj, targetConfig, resultLabel);
    artifacts = record_artifact(artifacts, 'SUMMARY_DATA', '', ...
        'OK', 'Selected ResultSet hierarchy collected');
    report_step_finish(1, 6, 'Collect Test Result Hierarchy', ...
        stepTimer, 'OK');
catch ME
    artifacts = record_artifact(artifacts, 'SUMMARY_DATA', '', ...
        'FAIL', ME.message);
    report_step_finish(1, 6, 'Collect Test Result Hierarchy', ...
        stepTimer, 'FAIL');
end

rawPath = fullfile(rawDirectory, [artifactStem 'Results.mldatx']);
stepTimer = report_step_start(2, 6, 'Export Selected Results MLDATX');
try
    sltest.testmanager.exportResults(resultObj, rawPath);
    artifacts = record_artifact(artifacts, 'MLDATX', rawPath, ...
        'OK', 'Selected ResultSet exported');
    report_step_finish(2, 6, 'Export Selected Results MLDATX', ...
        stepTimer, 'OK');
catch ME
    artifacts = record_artifact(artifacts, 'MLDATX', rawPath, ...
        'FAIL', ME.message);
    report_step_finish(2, 6, 'Export Selected Results MLDATX', ...
        stepTimer, 'FAIL');
end

stepTimer = report_step_start(3, 6, 'Collect Matched CUT Coverage');
try
    progressFcn = @(phase, current, total) report_progress( ...
        3, 6, phase, current, total);
    coverage = st_collect_coverage_summary(resultObj, targetConfig, ...
        resultLabel, 'IncludeTestDetails', false, ...
        'MatchCoverageObjects', true, ...
        'ProgressFcn', progressFcn);
    if isempty(coverage)
        artifacts = record_artifact(artifacts, 'COVERAGE_DATA', '', ...
            'FAIL', 'Selected ResultSet contains no coverage data');
    elseif any(coverage.Status == "EXTRACTION_FAILED")
        artifacts = record_artifact(artifacts, 'COVERAGE_DATA', '', ...
            'FAIL', 'One or more coverage rows could not be extracted');
    else
        artifacts = record_artifact(artifacts, 'COVERAGE_DATA', '', ...
            'OK', 'Matched CUT coverage collected without test detail');
    end
    report_step_finish(3, 6, 'Collect Matched CUT Coverage', ...
        stepTimer, char(artifacts.Status(end)));
catch ME
    artifacts = record_artifact(artifacts, 'COVERAGE_DATA', '', ...
        'FAIL', ME.message);
    report_step_finish(3, 6, 'Collect Matched CUT Coverage', ...
        stepTimer, 'FAIL');
end

pdfPath = fullfile(officialDirectory, [artifactStem 'TestResults.pdf']);
stepTimer = report_step_start(4, 6, 'Create Official Test Manager PDF');
if includeOfficialReport
    try
        sltest.testmanager.report(resultObj, pdfPath, ...
            'Title', [artifactStem ' Test Results - ' ...
                char(string(resultName))], ...
            'IncludeMLVersion', true, ...
            'IncludeTestResults', int32(0), ...
            'IncludeCoverageResult', strcmp(coverageReportMode, 'FULL'), ...
            'IncludeSimulationMetadata', true, ...
            'LaunchReport', false);
        artifacts = record_artifact(artifacts, 'PDF', pdfPath, ...
            'OK', 'Official Test Manager report created');
        report_step_finish(4, 6, 'Create Official Test Manager PDF', ...
            stepTimer, 'OK');
    catch ME
        artifacts = record_artifact(artifacts, 'PDF', pdfPath, ...
            'FAIL', ME.message);
        report_step_finish(4, 6, 'Create Official Test Manager PDF', ...
            stepTimer, 'FAIL');
    end
else
    artifacts = record_artifact(artifacts, 'PDF', '', ...
        'SKIP', 'Official PDF is available in FULL mode only');
    report_step_finish(4, 6, 'Create Official Test Manager PDF', ...
        stepTimer, 'SKIP');
end

stepTimer = report_step_start(5, 6, 'Create Portable Coverage Artifacts');
artifacts = export_coverage_data( ...
    artifacts, resultObj, coverageDirectory, logConfig);
artifacts = copy_coverage_filters( ...
    artifacts, resultObj, coverageDirectory, logConfig);
artifacts = export_coverage_summary_html( ...
    artifacts, coverage, coverageDirectory);
if strcmp(coverageReportMode, 'FULL') || includePortableCoverageDetail
    detailDirectory = fullfile(coverageDirectory, 'detail');
    mkdir(detailDirectory);
    artifacts = export_coverage_html( ...
        artifacts, resultObj, detailDirectory, 5, 6);
end
coverageArtifactTypes = ismember(artifacts.Type, ...
    ["HTML","CVT","CVF_COPY"]);
coverageArtifactStatus = char(st_report_status( ...
    artifacts.Status(coverageArtifactTypes)));
report_step_finish(5, 6, 'Create Portable Coverage Artifacts', ...
    stepTimer, coverageArtifactStatus);

integrityTimer = tic;
st_log(logConfig, 'DEBUG', ...
    'Result coverage integrity check start | stage=AFTER_EXPORT | label=%s', ...
    resultLabel);
try
    integrityAfter = coverage_integrity_snapshot(resultObj);
    if ~integrityBaselineAvailable
        error('simtest:ResultCoverageIntegrityBaselineMissing', ...
            'The pre-export coverage snapshot was unavailable.');
    end
    if ~isequal(integrityAfter, integrityBaseline)
        error('simtest:ResultCoverageChangedDuringExport', ...
            ['Result coverage ID, root, or filter reference changed while ' ...
             'portable artifacts were created.']);
    end
    artifacts = record_artifact(artifacts, 'RESULT_INTEGRITY', '', ...
        'OK', 'Live ResultSet coverage remained unchanged during export');
    st_log(logConfig, 'DEBUG', ...
        ['Result coverage integrity check complete | ' ...
         'stage=AFTER_EXPORT | objects=%d | elapsed=%.3f sec'], ...
        height(integrityAfter), toc(integrityTimer));
catch ME
    artifacts = record_artifact(artifacts, 'RESULT_INTEGRITY', '', ...
        'FAIL', ME.message);
    st_log(logConfig, 'ERROR', ...
        'Result coverage integrity check failed after export | %s: %s', ...
        ME.identifier, ME.message);
end

summaryPath = fullfile(outputDirectory, 'TestSummary.xlsx');
stepTimer = report_step_start(6, 6, 'Write Test Summary Excel');
try
    write_summary(summaryPath, resultName, ...
        targets, iterations, coverage, artifacts, coverageReportMode);
    artifacts = record_artifact(artifacts, 'EXCEL', summaryPath, ...
        'OK', 'Selected ResultSet workbook created');
    report_step_finish(6, 6, 'Write Test Summary Excel', ...
        stepTimer, 'OK');
catch ME
    artifacts = record_artifact(artifacts, 'EXCEL', summaryPath, ...
        'FAIL', ME.message);
    report_step_finish(6, 6, 'Write Test Summary Excel', ...
        stepTimer, 'FAIL');
end

info = struct( ...
    'Name', char(string(resultName)), ...
    'Directory', outputDirectory, ...
    'Summary', summaryPath, ...
    'Status', char(st_report_status(artifacts.Status)), ...
    'ArtifactFailures', sum(artifacts.Status == "FAIL"), ...
    'CoverageDetail', 'CUT', ...
    'CoverageReportMode', coverageReportMode, ...
    'PortableCoverageDetailIncluded', ...
        includePortableCoverageDetail || strcmp(coverageReportMode, 'FULL'), ...
    'ResultLabel', resultLabel, ...
    'OfficialReportIncluded', includeOfficialReport, ...
    'Artifacts', artifacts, ...
    'Targets', targets, ...
    'Iterations', iterations, ...
    'Coverage', coverage);
end

function artifacts = export_coverage_data( ...
        artifacts, resultObj, folder, cfg)
dataDirectory = fullfile(folder, 'data');
mkdir(dataDirectory);
timer = tic;
st_log(cfg, 'DEBUG', ...
    'Portable coverage CVT save start | directory=%s', dataDirectory);
try
    coverageObjects = getCoverageResults(resultObj);
catch ME
    st_log(cfg, 'ERROR', ...
        'Portable coverage CVT lookup failed | %s: %s', ...
        ME.identifier, ME.message);
    artifacts = record_artifact(artifacts, 'CVT', dataDirectory, ...
        'FAIL', ME.message);
    return;
end
if isempty(coverageObjects)
    message = 'Selected ResultSet contains no coverage objects';
    st_log(cfg, 'WARN', 'Portable coverage CVT save skipped | %s', message);
    artifacts = record_artifact(artifacts, 'CVT', dataDirectory, ...
        'FAIL', message);
    return;
end

for i = 1:numel(coverageObjects)
    root = coverage_root(coverageObjects(i));
    basePath = fullfile(dataDirectory, sprintf('%02d_%s', ...
        i, st_export_safe_name(root)));
    cvtPath = [basePath '.cvt'];
    try
        cvsave(basePath, coverageObjects(i));
        if ~isfile(cvtPath)
            error('simtest:CoverageDataSaveMissing', ...
                'cvsave did not create the expected CVT: %s', cvtPath);
        end
        artifacts = record_artifact(artifacts, 'CVT', cvtPath, ...
            'OK', ['Coverage root: ' root]);
    catch ME
        st_log(cfg, 'ERROR', ...
            'Portable coverage CVT save failed | %s: %s', ...
            ME.identifier, ME.message);
        artifacts = record_artifact(artifacts, 'CVT', cvtPath, ...
            'FAIL', ME.message);
    end
end
st_log(cfg, 'DEBUG', ...
    'Portable coverage CVT save complete | files=%d | elapsed=%.3f sec', ...
    numel(coverageObjects), toc(timer));
end

function artifacts = copy_coverage_filters( ...
        artifacts, resultObj, folder, cfg)
filterDirectory = fullfile(folder, 'filters');
timer = tic;
st_log(cfg, 'DEBUG', ...
    'Portable coverage filter copy start | directory=%s', filterDirectory);
try
    coverageObjects = getCoverageResults(resultObj);
    sources = strings(0,1);
    for i = 1:numel(coverageObjects)
        values = string(coverageObjects(i).filter);
        values = values(:);
        values(ismissing(values)) = "";
        sources = [sources; values(strlength(values) > 0)]; %#ok<AGROW>
    end
    sources = unique(sources, 'stable');
    if isempty(sources)
        st_log(cfg, 'DEBUG', ...
            'Portable coverage filter copy complete | files=0');
        return;
    end
    mkdir(filterDirectory);
    for i = 1:numel(sources)
        source = resolve_filter_source(char(sources(i)));
        [~, name, extension] = fileparts(source);
        destination = fullfile(filterDirectory, [name extension]);
        [ok, message] = copyfile(source, destination, 'f');
        if ~ok || ~isfile(destination)
            error('simtest:CoverageFilterCopyFailed', ...
                'Cannot copy %s to %s: %s', source, destination, message);
        end
        artifacts = record_artifact(artifacts, 'CVF_COPY', destination, ...
            'OK', ['Copied without changing source: ' source]);
    end
    st_log(cfg, 'DEBUG', ...
        ['Portable coverage filter copy complete | files=%d | ' ...
         'elapsed=%.3f sec'], numel(sources), toc(timer));
catch ME
    st_log(cfg, 'ERROR', ...
        'Portable coverage filter copy failed | %s: %s', ...
        ME.identifier, ME.message);
    artifacts = record_artifact(artifacts, 'CVF_COPY', filterDirectory, ...
        'FAIL', ME.message);
end
end

function path = resolve_filter_source(value)
path = value;
if ~isfile(path)
    path = which(value);
end
if isempty(path) && ~endsWith(value, '.cvf', 'IgnoreCase', true)
    path = which([value '.cvf']);
end
if isempty(path) || ~isfile(path)
    error('simtest:CoverageFilterCopySourceMissing', ...
        'Coverage filter copy source cannot be resolved: %s', value);
end
[ok, attributes] = fileattrib(path);
if ok && isstruct(attributes) && isfield(attributes, 'Name')
    path = attributes.Name;
end
end

function artifacts = export_coverage_html( ...
        artifacts, resultObj, folder, step, stepCount)
try
    coverageObjects = getCoverageResults(resultObj);
catch ME
    artifacts = record_artifact(artifacts, 'HTML', folder, ...
        'FAIL', ME.message);
    return;
end
if isempty(coverageObjects)
    artifacts = record_artifact(artifacts, 'HTML', folder, ...
        'FAIL', 'Selected ResultSet contains no coverage objects');
    return;
end

for i = 1:numel(coverageObjects)
    report_progress(step, stepCount, 'Coverage object', ...
        i, numel(coverageObjects));
    root = coverage_root(coverageObjects(i));
    path = fullfile(folder, sprintf('%02d_%s.html', ...
        i, st_export_safe_name(root)));
    try
        report = cvhtml(path, coverageObjects(i), '-sRT=0');
        if isstruct(report) && isfield(report, 'fileName') && ...
                isfield(report, 'path')
            path = fullfile(char(report(1).path), ...
                char(report(1).fileName));
        end
        artifacts = record_artifact(artifacts, 'HTML', path, ...
            'OK', ['Coverage root: ' root]);
    catch ME
        artifacts = record_artifact(artifacts, 'HTML', path, ...
            'FAIL', ME.message);
    end
end
end

function artifacts = export_coverage_summary_html( ...
        artifacts, coverage, folder)
path = fullfile(folder, 'CoverageSummary.html');
try
    columns = {'Level','No','CUTName','CoverageRoot','Metric', ...
        'Covered','Total','Justified','PercentageText','Status','Message'};
    summary = coverage(:, columns);
    write_coverage_html(path, summary);
    artifacts = record_artifact(artifacts, 'HTML', path, 'OK', ...
        'Lightweight OVERALL/CUT coverage summary created');
catch ME
    artifacts = record_artifact(artifacts, 'HTML', path, ...
        'FAIL', ME.message);
end
end

function write_coverage_html(path, summary)
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:AssetCoverageHtmlWriteFailed', ...
        'Cannot write Coverage summary HTML: %s', path);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, ['<!doctype html><html><head><meta charset="utf-8">' ...
    '<title>Selected CUT Coverage Summary</title>' ...
    '<style>body{font-family:sans-serif}table{border-collapse:collapse}' ...
    'th,td{border:1px solid #bbb;padding:4px 7px;text-align:left}' ...
    'th{background:#eee}</style></head><body>' ...
    '<h1>Selected CUT Coverage Summary</h1><table><thead><tr>']);
for c = 1:width(summary)
    fprintf(fileId, '<th>%s</th>', ...
        html_escape(summary.Properties.VariableNames{c}));
end
fprintf(fileId, '</tr></thead><tbody>');
for r = 1:height(summary)
    fprintf(fileId, '<tr>');
    for c = 1:width(summary)
        value = summary{r,c};
        if iscell(value), value = value{1}; end
        fprintf(fileId, '<td>%s</td>', html_escape(display_text(value)));
    end
    fprintf(fileId, '</tr>');
end
fprintf(fileId, '</tbody></table></body></html>');
end

function text = display_text(value)
if isnumeric(value)
    if isempty(value) || (isscalar(value) && isnan(value))
        text = '';
    else
        text = char(string(value));
    end
elseif ismissing(string(value))
    text = '';
else
    text = char(string(value));
end
end

function text = html_escape(value)
text = char(string(value));
text = strrep(text, '&', '&amp;');
text = strrep(text, '<', '&lt;');
text = strrep(text, '>', '&gt;');
text = strrep(text, '"', '&quot;');
text = strrep(text, '''', '&#39;');
end

function timer = report_step_start(step, total, label)
timer = tic;
fprintf('[ResultReport %d/%d] START | %s\n', step, total, label);
end

function report_step_finish(step, total, label, timer, status)
fprintf('[ResultReport %d/%d] %s | %s | elapsed=%.3f sec\n', ...
    step, total, upper(char(string(status))), label, toc(timer));
end

function report_progress(step, totalSteps, phase, current, total)
if total <= 0, return; end
interval = max(1, ceil(total / 20));
if current ~= 1 && current ~= total && mod(current, interval) ~= 0
    return;
end
fprintf('[ResultReport %d/%d] %s | %d/%d\n', ...
    step, totalSteps, char(string(phase)), current, total);
end

function write_summary(path, resultName, targets, iterations, coverage, ...
        artifacts, coverageReportMode)
if isfile(path), delete(path); end
overview = { ...
    'Metric','Value'; ...
    'Result Name',char(string(resultName)); ...
    'Created At',timestamp_text(); ...
    'Target Results',height(targets); ...
    'Passed',sum(upper(targets.Outcome) == "PASSED"); ...
    'Failed',sum(upper(targets.Outcome) == "FAILED"); ...
    'Coverage Rows',height(coverage); ...
    'Coverage Detail','CUT'; ...
    'Coverage Report Mode',coverageReportMode; ...
    'Artifact Failures',sum(artifacts.Status == "FAIL")};
writecell(overview, path, 'Sheet', 'Overview');
writetable(targets, path, 'Sheet', 'Targets');
writetable(iterations, path, 'Sheet', 'Iterations');
writetable(coverage, path, 'Sheet', 'Coverage');
Key = ["ResultName";"MATLABRelease";"MATLABVersion"; ...
    "CoverageDetail";"CoverageReportMode"];
Value = [string(resultName);string(version('-release'));string(version()); ...
    "CUT";string(coverageReportMode)];
writetable(table(Key, Value), path, 'Sheet', 'Metadata');
end

function artifacts = record_artifact(artifacts, type, path, status, message)
artifacts(end+1,:) = {string(type), string(path), ...
    string(status), string(message)};
end

function text = coverage_root(cvd)
text = 'coverage';
try
    text = char(cvd.test.rootPath);
catch
end
end

function text = timestamp_text()
text = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
end

function snapshot = coverage_integrity_snapshot(resultObj)
coverageObjects = getCoverageResults(resultObj);
n = numel(coverageObjects);
Id = zeros(n,1);
RootPath = strings(n,1);
FilterReferences = strings(n,1);
for i = 1:n
    Id(i) = double(coverageObjects(i).id);
    testObject = coverageObjects(i).test;
    RootPath(i) = string(testObject.rootPath);
    filters = string(coverageObjects(i).filter);
    filters = filters(:);
    filters(ismissing(filters)) = "";
    filters = filters(strlength(filters) > 0);
    FilterReferences(i) = strjoin(filters, "|");
end
snapshot = table(Id, RootPath, FilterReferences);
end

function T = empty_artifact_table()
T = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'Type','Path','Status','Message'});
end

function T = empty_target_table()
T = table(strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', {'Run','No','CUTName','CUTPath','TestCaseName', ...
     'Outcome','DurationSec','IterationCount'});
end

function T = empty_iteration_table()
T = table(strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), zeros(0,1), 'VariableNames', ...
    {'Run','No','CUTName','TestCaseName','IterationName','Outcome', ...
     'DurationSec'});
end

function T = empty_coverage_table()
T = table(strings(0,1), strings(0,1), zeros(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), 'VariableNames', ...
    {'Run','Level','No','CUTName','TestCaseName','IterationName', ...
     'CoverageRoot','SourceCoverageRoot','Checksum','Metric','Covered', ...
     'Total','Justified','Percentage','PercentageText','Status','Message'});
end
