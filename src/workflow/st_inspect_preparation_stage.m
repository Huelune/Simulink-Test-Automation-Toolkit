function evidence = st_inspect_preparation_stage(stage, row, cfg)
%ST_INSPECT_PREPARATION_STAGE Read a single stage, never save or force-stop.
stage = upper(char(string(stage)));
owner = st_normalize_cut_path(row.CUTPath,cfg.TopModel);
harness = char(row.HarnessName);
st_log(cfg,'DEBUG','Preparation readback start | Stage=%s | TC=%s',stage,row.TestCaseName);
guard = [];
if ismember(stage, {'HARNESS_CONFIG','SIGNAL_EDITOR','ASSESSMENT','ALIGNMENT'})
    if bdIsLoaded(harness)
        error('simtest:ReadinessHarnessOpen','Close Harness %s before inspection.',harness);
    end
    info = sltest.harness.find(owner,'SearchDepth',0,'Name',harness);
    if numel(info) ~= 1, error('simtest:ReadinessHarnessMissing','Harness mapping is missing.'); end
    mode = info.synchronizationMode;
    link = st_cut_library_link_state(owner);
    safeSync = (isnumeric(mode) && isscalar(mode) && mode == 1) || ...
        (~isnumeric(mode) && strcmpi(string(mode),'SyncOnOpen'));
    if link.IsLinked && ~safeSync
        error('simtest:ReadinessHarnessSync','Use HARNESS preparation to protect synchronization first.');
    end
    % Closing a read-only inspection must never push a Harness back to CUT.
    sltest.harness.load(owner,harness);
    guard = onCleanup(@() close_inspection(harness));
    if strcmp(get_param(harness,'Dirty'),'on')
        error('simtest:ReadinessHarnessDirty','Harness became dirty on load; inspect/save it manually first.');
    end
end
switch stage
    case 'HARNESS'
        info = sltest.harness.find(owner,'SearchDepth',0,'Name',harness);
        if numel(info) ~= 1, error('simtest:ReadinessHarnessMissing','Harness mapping is missing.'); end
        evidence = struct('Owner',owner,'Name',harness,'Source',source_fingerprint(owner));
    case 'SLDV'
        profile = st_get_sldv_profile(row,cfg);
        evidence = struct('Scenarios',{profile.ScenarioNames},'Tmax',profile.Tmax);
        if ~isempty(profile.EffectiveDataFile)
            evidence.Data = st_file_signature(profile.EffectiveDataFile);
        end
    case 'HARNESS_CONFIG'
        profile = st_get_sldv_profile(row,cfg);
        wanted = cfg.HarnessStopTime;
        if ~strcmp(profile.Mode,'OFF'), wanted = profile.Tmax; end
        actual = get_param(harness,'StopTime');
        if isnumeric(wanted), expected = wanted; else, expected = str2double(wanted); end
        if str2double(actual) ~= expected
            error('simtest:ReadinessStopTime','Harness StopTime does not match preparation settings.');
        end
        evidence = struct('StopTime',actual);
    case 'SIGNAL_EDITOR'
        evidence = signal_state(harness,row,cfg);
    case 'ASSESSMENT'
        profile = st_get_sldv_profile(row,cfg);
        assess = st_find_assessment_block(harness);
        names = cellstr(string(sltest.testsequence.getAllScenarios(assess)));
        require_names(names,profile.ScenarioNames,'Assessment');
        evidence = struct('Scenarios',{names});
        % Read all scenario step actions using the existing specification reader.
        steps = sort(cellstr(string(sltest.testsequence.findStep(assess))));
        definitions = cell(numel(steps),1);
        for k = 1:numel(steps)
            definitions{k} = sltest.testsequence.readStep(assess,steps{k});
        end
        evidence.Steps = steps;
        evidence.Definition = definitions;
    case 'COVERAGE_FILTER'
        inputs = st_stage_inputs(row,cfg);
        evidence = struct('Policy',inputs.COVERAGE_FILTER);
        if ~strcmpi(cfg.ExecutionMode,'PER_CUT') && st_coverage_filter_active(row)
            file = st_coverage_filter_file(row,cfg);
            if ~isfile(file), error('simtest:ReadinessCVFMissing','Prepared CVF is missing.'); end
            evidence.Filter = st_file_signature(file);
        end
    case {'TEST_MANAGER','ALIGNMENT'}
        if ~isfile(cfg.TestFile), error('simtest:ReadinessTestFileMissing','Test File is missing.'); end
        [tf, opened] = get_test_file(cfg.TestFile);
        cleanup = onCleanup(@() close_test_file(tf,opened)); %#ok<NASGU>
        suites = getTestSuiteByName(tf,cfg.TestSuiteName);
        if numel(suites) ~= 1, error('simtest:ReadinessSuiteMissing','Expected one Test Suite.'); end
        tc = getTestCaseByName(suites,char(row.TestCaseName));
        if numel(tc) ~= 1, error('simtest:ReadinessCaseMissing','Expected one Test Case.'); end
        model = char(string(getProperty(tc,'Model')));
        hname = char(string(getProperty(tc,'HarnessName')));
        if ~strcmp(model,cfg.TopModel) || ~strcmp(hname,harness)
            error('simtest:ReadinessSUTMismatch','Test Case Model/Harness connection differs.');
        end
        iterations = getIterations(tc);
        evidence = struct('Model',model,'Harness',hname,'Iterations',struct([]));
        for k = 1:numel(iterations)
            evidence.Iterations(k).Name = char(iterations(k).Name);
            evidence.Iterations(k).Parameters = iterations(k).TestParams;
        end
        if strcmp(stage,'ALIGNMENT')
            profile = st_get_sldv_profile(row,cfg);
            signal = signal_state(harness,row,cfg);
            assess = st_find_assessment_block(harness);
            require_names(sltest.testsequence.getAllScenarios(assess),profile.ScenarioNames,'Assessment');
            expected = profile.ScenarioNames;
            if strcmp(profile.Mode,'OFF'), expected = {'Iteration 1'}; end
            require_names({evidence.Iterations.Name},expected,'Iterations');
            for k = 1:numel(iterations)
                scenario = char(iterations(k).Name);
                if strcmp(profile.Mode,'OFF'), scenario = profile.ScenarioNames{1}; end
                params = iterations(k).TestParams;
                if ~st_iteration_binding_matches(params,{'TestSequenceScenario'},scenario) || ...
                        (signal.Available && ~st_iteration_binding_matches(params, ...
                        {'SignalEditorScenario','SignalBuilderGroup'},scenario))
                    error('simtest:ReadinessIterationBinding','Iteration scenario binding is missing.');
                end
            end
        end
    otherwise
        error('simtest:ReadinessStageInvalid','Unknown preparation stage: %s',stage);
end
if ~isempty(guard) && strcmp(get_param(harness,'Dirty'),'on')
    error('simtest:ReadinessHarnessDirty','Harness changed during inspection.');
end
clear guard;
st_log(cfg,'DEBUG','Preparation readback complete | Stage=%s | TC=%s',stage,row.TestCaseName);
end

function value = source_fingerprint(owner)
blocks = sort(find_system(owner,'LookUnderMasks','all','FollowLinks','off','Type','Block'));
value = cell(numel(blocks),1);
for i = 1:numel(blocks)
    block = blocks{i}; params = get_param(block,'DialogParameters');
    fields = {}; if isstruct(params), fields = fieldnames(params); end
    values = struct();
    for k = 1:numel(fields), values.(fields{k}) = get_param(block,fields{k}); end
    value{i} = struct('Path',block,'Type',get_param(block,'BlockType'),'Parameters',values, ...
        'Connectivity',get_param(block,'PortConnectivity'));
    % Numeric block handles are session-local. Store stable paths instead.
    ports = value{i}.Connectivity;
    for k = 1:numel(ports)
        for name = {'SrcBlock','DstBlock'}
            handles = ports(k).(name{1}); paths = strings(size(handles));
            for h = 1:numel(handles)
                if handles(h) > 0, paths(h) = string(getfullname(handles(h))); end
            end
            ports(k).(name{1}) = paths;
        end
    end
    value{i}.Connectivity = ports;
end
end

function value = signal_state(harness,row,cfg)
profile = st_get_sldv_profile(row,cfg);
value = struct('Available',false);
try
    block = st_find_signal_editor_block(harness);
catch ME
    if strcmp(profile.Mode,'OFF') && strcmp(ME.identifier,'simtest:SignalEditorBlockMissing'), return; end
    rethrow(ME);
end
names = st_normalize_options(get_param(block,'options@ActiveScenario'));
require_names(names,profile.ScenarioNames,'Signal Editor');
if ~strcmp(get_param(block,'ActiveScenario'),profile.ScenarioNames{1})
    error('simtest:ReadinessScenario','Signal Editor active scenario differs.');
end
value.Available = true;
value.Scenarios = names;
file = char(string(get_param(block,'Filename')));
if ~isempty(file)
    localFile = fullfile(fileparts(get_param(harness,'FileName')),file);
    if ~isfile(file) && isfile(localFile), file = localFile; end
    file = st_absolute_path(st_resolve_data_file(file,cfg.TopModel));
    if ~isfile(file), error('simtest:ReadinessInputMissing','Harness Input is missing: %s',file); end
    value.File = st_file_signature(file);
end
end

function require_names(actual,expected,label)
actual = sort(string(actual(:))); expected = sort(string(expected(:)));
if ~isequal(actual,expected) || numel(unique(actual)) ~= numel(actual)
    error('simtest:ReadinessScenario','%s scenarios do not match prepared inputs.',label);
end
end

function [tf,opened] = get_test_file(file)
files = sltest.testmanager.getTestFiles(); opened = false;
for i = 1:numel(files)
    if st_same_path(files(i).FilePath,file)
        tf = files(i);
        if tf.Dirty, error('simtest:ReadinessDirtyTestFile','Save Test File before inspection.'); end
        return;
    end
end
tf = sltest.testmanager.TestFile(file); opened = true;
end

function close_test_file(tf,opened)
if opened, close(tf); end
end

function close_inspection(model)
if bdIsLoaded(model), close_system(model,0); end
end
