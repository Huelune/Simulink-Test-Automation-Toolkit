function [specification, outputFile] = st_export_test_specification(varargin)
%ST_EXPORT_TEST_SPECIFICATION Export saved Assessment definitions without running.
%   [T, PATH] = st_export_test_specification('OutputFile', 'specification.xlsx')
%   Default: result/test_specification_<timestamp>.xlsx. Existing output files
%   are refused. This independent command never invokes the test workflow.
%   VerifyMode: 'STEP2' (default), or 'ALL_STEPS_COLUMNS' to put each
%   verify-bearing step in a separate column with its relative step path.
%   MaxTime is the input scenario's maximum stored signal time in seconds.
p = inputParser;
addParameter(p, 'OutputFile', '', @(v) (ischar(v) && isrow(v)) || ...
    (isstring(v) && isscalar(v)) || isempty(v));
addParameter(p, 'VerifyMode', 'STEP2', @(v) ...
    (ischar(v) && isrow(v)) || (isstring(v) && isscalar(v)));
parse(p, varargin{:});
verifyMode = upper(strtrim(char(p.Results.VerifyMode)));
if ~ismember(verifyMode, {'STEP2', 'ALL_STEPS_COLUMNS'})
    error('simtest:SpecificationVerifyMode', 'VerifyMode must be STEP2 or ALL_STEPS_COLUMNS.');
end
cfg = st_config();
outputFile = char(p.Results.OutputFile);
if isempty(outputFile)
    outputFile = fullfile(cfg.ResultDir, ['test_specification_' ...
        char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS')) '.xlsx']);
end
outputFile = canonical(outputFile);
[~, ~, extension] = fileparts(outputFile);
if ~strcmpi(extension, '.xlsx')
    error('simtest:SpecificationOutput', 'OutputFile must have an .xlsx extension.');
end
if isfile(outputFile)
    error('simtest:SpecificationOutputExists', 'Output already exists: %s', outputFile);
end
st_log(cfg, 'INFO', 'Specification export start | VerifyMode=%s | Output=%s', verifyMode, outputFile);
timer = tic;
initialModels = string(find_system('SearchDepth', 0, 'Type', 'block_diagram'));
initialModels = initialModels(:);
testFile = [];
cleanupTestFile = [];
sources = strings(0,1);
hashes = strings(0,1);
% Capture values in callbacks to local (not nested) functions. On error,
% MATLAB can clear shared parent variables before a nested cleanup runs.
cleanupModels = onCleanup(@() cleanup_models(initialModels, cfg));
try
    if ~cfg.HasRuntimeTarget
        error('simtest:SpecificationTarget', 'Select and save a runtime target first.');
    end
    track_source(cfg.ModelFile);
    track_source(cfg.TestFile);
    track_source(cfg.ManagementExcel);
    targets = st_load_targets(cfg.OnlyEnabled);
    check_model(cfg.TopModel, cfg.ModelFile);
    for i = 1:height(targets)
        check_model(char(targets.HarnessName(i)), '');
    end

    openFiles = sltest.testmanager.getTestFiles;
    for i = 1:numel(openFiles)
        if same_path(openFiles(i).FilePath, cfg.TestFile)
            testFile = openFiles(i);
            break;
        end
    end
    if isempty(testFile)
        st_log(cfg, 'DEBUG', 'Specification Test File load start | File=%s', cfg.TestFile);
        testFile = sltest.testmanager.TestFile(cfg.TestFile, false);
        cleanupTestFile = onCleanup(@() close_test_file(testFile, cfg));
        st_log(cfg, 'DEBUG', 'Specification Test File load end | File=%s', cfg.TestFile);
    end
    if testFile.Dirty
        error('simtest:SpecificationUnsaved', 'Save or discard Test File changes first: %s', cfg.TestFile);
    end
    if ~bdIsLoaded(cfg.TopModel)
        st_log(cfg, 'DEBUG', 'Specification model load start | Model=%s', cfg.TopModel);
        load_system(cfg.ModelFile);
        st_log(cfg, 'DEBUG', 'Specification model load end | Model=%s', cfg.TopModel);
    end
    check_model(cfg.TopModel, cfg.ModelFile);
    associated = sltest.harness.find(cfg.TopModel);
    for i = 1:numel(associated)
        check_model(associated(i).name, '');
    end
    suite = getTestSuiteByName(testFile, cfg.TestSuiteName);
    if numel(suite) > 1
        error('simtest:SpecificationSuite', 'Configured Test Suite name is ambiguous.');
    end

    rows = strings(0,13);
    details = strings(0,10);
    verifyCells = cell(0,1);
    maxTimes = zeros(0,1);
    for i = 1:height(targets)
        target = targets(i,:);
        harness = char(target.HarnessName);
        owner = st_normalize_cut_path(target.CUTPath, cfg.TopModel);
        loadedHere = ~bdIsLoaded(harness);
        st_log(cfg, 'INFO', 'Specification target start | Case=%s | Harness=%s', ...
            target.TestCaseName, harness);
        harnessCleanup = onCleanup(@() close_harness(harness, loadedHere, cfg));
        try
            harnessInfo = sltest.harness.find(owner, 'Name', harness);
            if numel(harnessInfo) ~= 1
                error('simtest:SpecificationHarness', 'Expected exactly one matching harness.');
            end
            if isfield(harnessInfo, 'harnessFilePath') && ~isempty(harnessInfo.harnessFilePath)
                track_source(harnessInfo.harnessFilePath);
            end
            if loadedHere
                st_log(cfg, 'DEBUG', 'Specification harness.load start | Harness=%s', harness);
                sltest.harness.load(owner, harness);
                st_log(cfg, 'DEBUG', 'Specification harness.load end | Harness=%s', harness);
            end
            check_model(harness, '');
            if harnessInfo.saveExternally
                track_source(get_param(harness, 'FileName'));
            end
            [targetRows, targetDetails, inputFiles, targetVerifyCells, targetMaxTimes] = ...
                st_collect_specification_target(target, cfg, suite, verifyMode);
            check_model(harness, '');
            for f = 1:numel(inputFiles), track_source(inputFiles(f)); end
            rows = [rows; targetRows]; %#ok<AGROW>
            details = [details; targetDetails]; %#ok<AGROW>
            verifyCells = [verifyCells; targetVerifyCells]; %#ok<AGROW>
            maxTimes = [maxTimes; targetMaxTimes]; %#ok<AGROW>
        catch ME
            if any(strcmp(ME.identifier, {'simtest:SpecificationUnsaved', ...
                    'simtest:SpecificationSourceChanged'}))
                rethrow(ME);
            end
            failed = strings(1,13);
            failed([1 2 3 8 9 12 13]) = [target.TestCaseName target.CUTName ...
                target.HarnessName string(cfg.TopModel) string(owner) "FAIL" string(ME.message)];
            rows(end+1,:) = failed; %#ok<AGROW>
            verifyCells{end+1,1} = "<verify 읽기 실패>"; %#ok<AGROW>
            maxTimes(end+1,1) = NaN; %#ok<AGROW>
            st_log(cfg, 'ERROR', 'Specification target failed | Case=%s | Harness=%s | %s', ...
                target.TestCaseName, harness, ME.message);
        end
        clear harnessCleanup;
        st_log(cfg, 'INFO', 'Specification target end | Case=%s', target.TestCaseName);
    end
    check_model(cfg.TopModel, cfg.ModelFile);
    if testFile.Dirty
        error('simtest:SpecificationUnsaved', 'Test File became dirty during inspection.');
    end
    clear cleanupTestFile;
    clear cleanupModels;
    verify_sources();
    specification = st_specification_table(rows, verifyCells, maxTimes);
    detailTable = array2table(details, 'VariableNames', {'TestCaseName', ...
        'HarnessName','AssessmentBlock','ScenarioName','StepPath', ...
        'OriginalAction','Transitions','VerifySummary','ReadStatus','Message'});
    st_log(cfg, 'INFO', 'Specification workbook write start | Rows=%d | File=%s', ...
        height(specification), outputFile);
    st_write_specification_workbook(specification, detailTable, outputFile);
    st_log(cfg, 'INFO', 'Specification workbook write end | File=%s', outputFile);
    st_log(cfg, 'INFO', 'Specification export end | Rows=%d | Elapsed=%.3fs', ...
        height(specification), toc(timer));
    fprintf('Test specification exported: %s\n', outputFile);
catch ME
    st_log(cfg, 'ERROR', 'Specification export failed | Elapsed=%.3fs | %s', toc(timer), ME.message);
    rethrow(ME);
end

    function track_source(path)
        path = string(canonical(path));
        if any(sources == path), return; end
        st_log(cfg, 'DEBUG', 'Specification source hash start | File=%s', path);
        signature = st_file_signature(path);
        if ~signature.Exists
            error('simtest:SpecificationSourceMissing', 'Required saved file missing: %s', path);
        end
        sources(end+1,1) = path;
        hashes(end+1,1) = string(signature.SHA256);
        st_log(cfg, 'DEBUG', 'Specification source hash end | File=%s', path);
    end

    function verify_sources()
        st_log(cfg, 'DEBUG', 'Specification source verification start | Files=%d', numel(sources));
        for n = 1:numel(sources)
            signature = st_file_signature(sources(n));
            if string(signature.SHA256) ~= hashes(n)
                error('simtest:SpecificationSourceChanged', 'Source changed during export: %s', sources(n));
            end
        end
        st_log(cfg, 'DEBUG', 'Specification source verification end | Files=%d', numel(sources));
    end

end

function close_test_file(testFile, cfg)
try
    close(testFile);
catch ME
    st_log(cfg, 'WARN', 'Specification Test File cleanup failed | %s', ME.message);
end
end

function cleanup_models(initialModels, cfg)
st_log(cfg, 'DEBUG', 'Specification model cleanup start');
try
    loaded = string(find_system('SearchDepth', 0, 'Type', 'block_diagram'));
    created = setdiff(loaded(:), initialModels(:), 'stable');
    for n = numel(created):-1:1
        close_harness(char(created(n)), true, cfg);
    end
    st_log(cfg, 'DEBUG', 'Specification model cleanup end | Models=%d', numel(created));
catch ME
    st_log(cfg, 'WARN', 'Specification model cleanup failed | %s', ME.message);
end
end

function check_model(model, expectedFile)
if ~bdIsLoaded(model), return; end
if strcmp(get_param(model, 'Dirty'), 'on')
    error('simtest:SpecificationUnsaved', 'Save or discard model/harness changes first: %s', model);
end
if ~strcmp(get_param(model, 'SimulationStatus'), 'stopped')
    error('simtest:SpecificationRunning', 'Stop the model before inspection: %s', model);
end
if ~isempty(expectedFile) && ~same_path(get_param(model, 'FileName'), expectedFile)
    error('simtest:SpecificationModelCollision', 'Loaded model differs from selected saved file: %s', model);
end
end

function close_harness(model, loadedHere, cfg)
if ~loadedHere || ~bdIsLoaded(model), return; end
try
    close_system(model, 0);
catch ME
    st_log(cfg, 'WARN', 'Specification model cleanup failed | Model=%s | %s', model, ME.message);
end
end

function path = canonical(path)
path = char(java.io.File(char(path)).getCanonicalPath());
end

function tf = same_path(a, b)
if ispc, tf = strcmpi(canonical(a), canonical(b));
else, tf = strcmp(canonical(a), canonical(b)); end
end
