function result = st_validate_sldv_target(targetPath, varargin)
%ST_VALIDATE_SLDV_TARGET Precheck a Subsystem before SLDV analysis.
%   RESULT = ST_VALIDATE_SLDV_TARGET(TARGETPATH) validates the target path,
%   compiles the owning model, runs the SLDV compatibility check, and
%   collects static dependency candidates. It does not run SLDV test
%   generation by default.
%
%   RESULT = ST_VALIDATE_SLDV_TARGET(..., 'CheckParents', true,
%   'MaxParentDepth', 3) repeats the compatibility and dependency checks
%   for parent systems, starting at TARGETPATH (depth 0), and stops after
%   the first analyzable candidate. CheckParents defaults to false and
%   MaxParentDepth defaults to 3.
%
%   RESULT = ST_VALIDATE_SLDV_TARGET(..., 'RunActualSLDV', true) also calls
%   SLDVRUN for each candidate. This can be significantly more expensive and
%   can create the output files configured by the model's SLDV options.
%   RunActualSLDV defaults to false.
%
%   This precheck is intentionally separate from
%   ST_VALIDATE_SLDV_VERIFY_RESULTS. That function validates Verify results
%   after Test Manager execution; this function diagnoses the SLDV CUT
%   before generation.

options = parse_options(targetPath, varargin{:});
targetPath = options.TargetPath;
result = empty_result(targetPath, options);

[pathCheck, modelName] = validate_target_path(targetPath);
result.Path = pathCheck;

if ~pathCheck.Success
    result.Message = pathCheck.Message;
    print_summary(result);
    return;
end

compileCheck = compile_model(modelName);
candidatePaths = build_candidate_paths( ...
    targetPath, options.CheckParents, options.MaxParentDepth);
candidateChecks = repmat(empty_candidate(), numel(candidatePaths), 1);

for i = 1:numel(candidatePaths)
    candidatePath = candidatePaths{i};
    candidate = empty_candidate();
    candidate.Depth = i - 1;
    candidate.Path = candidatePath;
    candidate.Name = system_name(candidatePath);
    candidate.Compile = compileCheck;

    try
        candidate.Dependency = st_inspect_sldv_dependencies(candidatePath);
    catch ME
        candidate.Dependency = empty_dependency_failure(ME.message);
    end

    candidate.Boundary = candidate.Dependency.Boundary;

    if compileCheck.Success
        candidate.Compatibility = check_compatibility( ...
            candidatePath, modelName);
    else
        candidate.Compatibility = skipped_check( ...
            'SKIPPED', 'Compatibility was skipped because compile failed.');
    end

    if options.RunActualSLDV
        if compileCheck.Success && candidate.Compatibility.Success
            candidate.SLDV = run_actual_sldv(candidatePath, modelName);
        else
            candidate.SLDV = skipped_check( ...
                'SKIPPED', ...
                ['SLDV was skipped because compile or compatibility ' ...
                 'checking did not pass.']);
            candidate.SLDV.Executed = false;
        end
    else
        candidate.SLDV = skipped_check( ...
            'NOT_RUN', ['Actual SLDV analysis was not requested. ' ...
             'Set RunActualSLDV=true to run sldvrun.']);
        candidate.SLDV.Executed = false;
    end

    if options.RunActualSLDV
        candidate.AnalyzableCandidate = ...
            candidate.Compile.Success && ...
            candidate.Compatibility.Success && ...
            candidate.SLDV.Success;
    else
        candidate.AnalyzableCandidate = ...
            candidate.Compile.Success && ...
            candidate.Compatibility.Success;
    end

    candidate.Status = candidate_status(candidate, options.RunActualSLDV);
    candidate.Message = candidate_message(candidate, options.RunActualSLDV);
    candidateChecks(i) = candidate;

    % The requested result is the minimum analyzable scope. Avoid extra
    % parent compatibility checks after the first candidate is found.
    if candidate.AnalyzableCandidate && i < numel(candidatePaths)
        candidateChecks = candidateChecks(1:i);
        break;
    end
end

first = find([candidateChecks.AnalyzableCandidate], 1, 'first');
if ~isempty(first)
    result.FirstAnalyzablePath = candidateChecks(first).Path;
    result.FirstAnalyzableDepth = candidateChecks(first).Depth;
end

targetCheck = candidateChecks(1);
result.Compile = targetCheck.Compile;
result.Compatibility = targetCheck.Compatibility;
result.Dependency = targetCheck.Dependency;
result.Boundary = targetCheck.Boundary;
result.SLDV = targetCheck.SLDV;
result.AnalyzableCandidate = targetCheck.AnalyzableCandidate;
result.ParentChecks = candidateChecks;
result.Status = targetCheck.Status;
result.Message = targetCheck.Message;

print_summary(result);
end


function options = parse_options(targetPath, varargin)

parser = inputParser;
parser.FunctionName = 'st_validate_sldv_target';
addRequired(parser, 'targetPath', @is_scalar_text);
addParameter(parser, 'CheckParents', false, @is_scalar_logical);
addParameter(parser, 'MaxParentDepth', 3, @is_parent_depth);
addParameter(parser, 'RunActualSLDV', false, @is_scalar_logical);
parse(parser, targetPath, varargin{:});

options = struct();
options.TargetPath = strtrim(char(string(parser.Results.targetPath)));
options.CheckParents = logical(parser.Results.CheckParents);
options.MaxParentDepth = double(parser.Results.MaxParentDepth);
options.RunActualSLDV = logical(parser.Results.RunActualSLDV);
end


function tf = is_scalar_text(value)

tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
    (isstring(value) && isscalar(value) && ~ismissing(value));
end


function tf = is_scalar_logical(value)

tf = (islogical(value) || isnumeric(value)) && isscalar(value) && ...
    isfinite(double(value)) && ismember(double(value), [0 1]);
end


function tf = is_parent_depth(value)

tf = isnumeric(value) && isscalar(value) && isfinite(value) && ...
    value >= 0 && value == fix(value);
end


function result = empty_result(targetPath, options)

result = struct();
result.Target = targetPath;
result.Options = rmfield(options, 'TargetPath');
result.Path = base_check();
result.Compile = base_check();
result.Compatibility = base_check();
result.Dependency = empty_dependency_failure('Target was not inspected.');
result.Boundary = result.Dependency.Boundary;
result.SLDV = base_check();
result.SLDV.Executed = false;
result.AnalyzableCandidate = false;
result.FirstAnalyzablePath = '';
result.FirstAnalyzableDepth = NaN;
result.ParentChecks = repmat(empty_candidate(), 0, 1);
result.Status = 'FAIL';
result.Message = '';
end


function candidate = empty_candidate()

candidate = struct();
candidate.Depth = 0;
candidate.Path = '';
candidate.Name = '';
candidate.Compile = base_check();
candidate.Compatibility = base_check();
candidate.Dependency = empty_dependency_failure('Not inspected.');
candidate.Boundary = candidate.Dependency.Boundary;
candidate.SLDV = base_check();
candidate.SLDV.Executed = false;
candidate.AnalyzableCandidate = false;
candidate.Status = 'FAIL';
candidate.Message = '';
end


function check = base_check()

check = struct( ...
    'Success', false, ...
    'Status', 'NOT_RUN', ...
    'Message', '', ...
    'Details', strings(0,1));
end


function dependency = empty_dependency_failure(message)

emptyDataStore = struct( ...
    'AccessBlock', {}, 'AccessType', {}, 'Name', {}, ...
    'DefinitionPath', {}, 'Resolution', {}, 'External', {});
emptyGoto = struct( ...
    'FromBlock', {}, 'Tag', {}, 'GotoPath', {}, ...
    'Visibility', {}, 'Resolution', {}, 'External', {});
emptyCaller = struct( ...
    'CallerBlock', {}, 'FunctionName', {}, 'Prototype', {}, ...
    'DefinitionPath', {}, 'Resolution', {}, 'External', {});
emptyStateflow = struct( ...
    'ChartPath', {}, 'Name', {}, 'Scope', {}, 'ExternalCandidate', {});
emptyBoundary = struct( ...
    'Type', {}, 'BlockPath', {}, 'Detail', {});

dependency = struct();
dependency.Success = false;
dependency.Message = char(message);
dependency.DataStore = emptyDataStore;
dependency.GotoFrom = emptyGoto;
dependency.FunctionCaller = emptyCaller;
dependency.Stateflow = emptyStateflow;
dependency.Boundary = emptyBoundary;
dependency.ExternalDataStoreCount = 0;
dependency.ExternalGotoCount = 0;
dependency.FunctionCallerCount = 0;
dependency.ExternalFunctionCallerCount = 0;
dependency.StateflowExternalDataCount = 0;
dependency.BoundaryDependencyCount = 0;
dependency.Warnings = string(message);
dependency.DependencyWarnings = dependency.Warnings;
end


function [check, modelName] = validate_target_path(targetPath)

check = base_check();
check.Status = 'FAIL';
modelName = '';

if isempty(targetPath)
    check.Message = 'targetPath must not be empty.';
    return;
end

separator = find(targetPath == '/', 1, 'first');
if isempty(separator)
    modelName = targetPath;
else
    modelName = targetPath(1:separator - 1);
end

try
    if ~bdIsLoaded(modelName)
        load_system(modelName);
    end

    handle = getSimulinkBlockHandle(targetPath);
    if handle == -1
        error('simtest:SldvTargetNotFound', ...
            'Subsystem path not found: %s', targetPath);
    end

    if ~strcmp(get_param(handle, 'Type'), 'block') || ...
            ~strcmp(get_param(handle, 'BlockType'), 'SubSystem')
        error('simtest:SldvTargetNotSubsystem', ...
            'SLDV target must be a Subsystem: %s', targetPath);
    end

    check.Success = true;
    check.Status = 'PASS';
    check.Message = 'Target model and Subsystem path are valid.';
catch ME
    check.Message = ME.message;
end
end


function check = compile_model(modelName)

check = base_check();
check.Status = 'FAIL';

try
    st_force_model_stopped(modelName);
    commandOutput = evalc( ...
        'feval(modelName, [], [], [], ''compile'');');
    cleanup = onCleanup(@() terminate_compile(modelName)); %#ok<NASGU>
    st_force_model_stopped(modelName);

    check.Success = true;
    check.Status = 'PASS';
    check.Message = sprintf('Model compile succeeded: %s', modelName);
    check.Details = nonempty_lines(commandOutput);
catch ME
    terminate_compile(modelName);
    check.Message = ME.message;
    check.Details = string(ME.getReport('basic', 'hyperlinks', 'off'));
end
end


function terminate_compile(modelName)

try
    st_force_model_stopped(modelName);
catch
end
end


function paths = build_candidate_paths(targetPath, checkParents, maxDepth)

paths = {targetPath};
if ~checkParents
    return;
end

current = targetPath;
for depth = 1:maxDepth
    try
        parent = get_param(current, 'Parent');
    catch
        break;
    end

    if isempty(parent) || strcmp(parent, current)
        break;
    end

    paths{end+1,1} = parent; %#ok<AGROW>
    current = parent;

    if strcmp(get_param(current, 'Type'), 'block_diagram')
        break;
    end
end
end


function check = check_compatibility(candidatePath, modelName)

check = base_check();
check.Status = 'FAIL';

if exist('sldvcompat', 'file') == 0
    check.Status = 'UNAVAILABLE';
    check.Message = ['sldvcompat is unavailable. Install/license ' ...
        'Simulink Design Verifier to perform compatibility checking.'];
    return;
end

try
    options = precheck_options(modelName);
    compatibilityStatus = false;
    messages = [];
    commandOutput = evalc( ...
        '[compatibilityStatus, messages] = sldvcompat(candidatePath, options);');

    check.Success = logical(compatibilityStatus);
    if check.Success
        check.Status = 'PASS';
    else
        check.Status = 'FAIL';
    end

    messageText = flatten_sldv_messages(messages);
    if isempty(messageText)
        if check.Success
            messageText = 'sldvcompat reported the candidate as compatible.';
        else
            messageText = 'sldvcompat reported incompatibilities.';
        end
    end
    check.Message = messageText;
    check.Details = [nonempty_lines(commandOutput); message_lines(messages)];
catch ME
    check.Message = ME.message;
    check.Details = string(ME.getReport('basic', 'hyperlinks', 'off'));
end
end


function check = run_actual_sldv(candidatePath, modelName)

check = base_check();
check.Executed = true;
check.Status = 'FAIL';

if exist('sldvrun', 'file') == 0
    check.Executed = false;
    check.Status = 'UNAVAILABLE';
    check.Message = ['sldvrun is unavailable. Install/license ' ...
        'Simulink Design Verifier to run actual analysis.'];
    return;
end

try
    options = precheck_options(modelName);
    set_option_if_available(options, 'SaveReport', 'off');
    set_option_if_available(options, 'SaveHarnessModel', 'off');

    runStatus = false;
    files = struct();
    messages = [];
    commandOutput = evalc( ...
        ['[runStatus, files, messages] = ' ...
         'sldvrun(candidatePath, options, false);']);

    check.Success = logical(runStatus);
    if check.Success
        check.Status = 'PASS';
    else
        check.Status = 'FAIL';
    end

    check.Message = flatten_sldv_messages(messages);
    if isempty(check.Message)
        check.Message = sprintf('sldvrun returned status %g.', double(runStatus));
    end
    check.Details = [nonempty_lines(commandOutput); message_lines(messages)];
    check.Files = files;
catch ME
    check.Message = ME.message;
    check.Details = string(ME.getReport('basic', 'hyperlinks', 'off'));
    check.Files = struct();
end
end


function options = precheck_options(modelName)

modelOptions = sldvoptions(modelName);
try
    options = modelOptions.deepCopy;
catch
    % Do not change the model-attached configuration on releases where
    % deepCopy is unavailable.
    options = sldvoptions;
end
set_option_if_available(options, 'Mode', 'TestGeneration');
end


function set_option_if_available(options, name, value)

try
    if isprop(options, name)
        options.(name) = value;
    end
catch
    % SLDV option availability differs by MATLAB release.
end
end


function check = skipped_check(status, message)

check = base_check();
check.Status = status;
check.Message = message;
end


function status = candidate_status(candidate, ranActualSldv)

if candidate.AnalyzableCandidate
    if isempty(candidate.Dependency.Warnings)
        status = 'PASS';
    else
        status = 'PASS_WITH_WARNINGS';
    end
elseif ~candidate.Compile.Success || ...
        strcmp(candidate.Compatibility.Status, 'FAIL') || ...
        (ranActualSldv && strcmp(candidate.SLDV.Status, 'FAIL'))
    status = 'FAIL';
else
    status = 'UNAVAILABLE';
end
end


function message = candidate_message(candidate, ranActualSldv)

parts = strings(0,1);
if ~candidate.Compile.Success
    parts(end+1,1) = "Compile: " + string(candidate.Compile.Message); %#ok<AGROW>
end
if ~candidate.Compatibility.Success
    parts(end+1,1) = ...
        "Compatibility: " + string(candidate.Compatibility.Message); %#ok<AGROW>
end
if ranActualSldv && ~candidate.SLDV.Success
    parts(end+1,1) = "SLDV: " + string(candidate.SLDV.Message); %#ok<AGROW>
end
if candidate.Dependency.Success && ~isempty(candidate.Dependency.Warnings)
    parts(end+1,1) = sprintf('%d dependency warning(s)', ...
        numel(candidate.Dependency.Warnings)); %#ok<AGROW>
elseif ~candidate.Dependency.Success
    parts(end+1,1) = ...
        "Dependency inspection: " + string(candidate.Dependency.Message); %#ok<AGROW>
end

if isempty(parts)
    message = 'Precheck passed.';
else
    message = char(strjoin(parts, ' | '));
end
end


function name = system_name(path)

try
    name = get_param(path, 'Name');
catch
    name = path;
end
end


function lines = nonempty_lines(textValue)

if isempty(textValue)
    lines = strings(0,1);
    return;
end

lines = splitlines(string(textValue));
lines = strtrim(lines);
lines(lines == "") = [];
end


function lines = message_lines(messages)

textValue = flatten_sldv_messages(messages);
lines = nonempty_lines(textValue);
end


function textValue = flatten_sldv_messages(messages)

if isempty(messages)
    textValue = '';
    return;
end

if ischar(messages) || (isstring(messages) && isscalar(messages))
    textValue = char(string(messages));
    return;
end

if iscell(messages)
    parts = strings(0,1);
    for i = 1:numel(messages)
        current = flatten_sldv_messages(messages{i});
        if ~isempty(current)
            parts(end+1,1) = string(current); %#ok<AGROW>
        end
    end
    textValue = char(strjoin(parts, ' | '));
    return;
end

if ~isstruct(messages)
    try
        textValue = char(string(messages));
    catch
        textValue = class(messages);
    end
    return;
end

parts = strings(0,1);
candidateFields = {'msgid', 'msg', 'message', 'Message'};
for i = 1:numel(messages)
    for f = 1:numel(candidateFields)
        field = candidateFields{f};
        if isfield(messages, field) && ~isempty(messages(i).(field))
            parts(end+1,1) = string(messages(i).(field)); %#ok<AGROW>
        end
    end
end
textValue = char(strjoin(unique(parts, 'stable'), ' | '));
end


function print_summary(result)

fprintf('\n=== SLDV Target Precheck ===\n');
fprintf('Target: %s\n\n', result.Target);

if ~result.Path.Success
    fprintf('Path               : FAIL\n');
    fprintf('Reason             : %s\n', result.Path.Message);
    return;
end

fprintf('Compile            : %s\n', display_status(result.Compile.Status));
fprintf('SLDV Compatibility : %s\n', ...
    display_status(result.Compatibility.Status));
fprintf('Actual SLDV        : %s\n\n', display_status(result.SLDV.Status));

fprintf('External DataStore : %d\n', ...
    result.Dependency.ExternalDataStoreCount);
fprintf('External Goto      : %d\n', ...
    result.Dependency.ExternalGotoCount);
fprintf('Function Caller    : %d (external candidates: %d)\n', ...
    result.Dependency.FunctionCallerCount, ...
    result.Dependency.ExternalFunctionCallerCount);
fprintf('Stateflow External : %d\n', ...
    result.Dependency.StateflowExternalDataCount);
fprintf('Boundary candidates: %d\n', ...
    result.Dependency.BoundaryDependencyCount);

if ~isempty(result.Dependency.Warnings)
    fprintf('\nDependency warnings (candidates only):\n');
    for i = 1:numel(result.Dependency.Warnings)
        fprintf('- %s\n', result.Dependency.Warnings(i));
    end
end

fprintf('\nParent checks:\n');
for i = 1:numel(result.ParentChecks)
    check = result.ParentChecks(i);
    fprintf('[%d] %-20s : %s\n', ...
        check.Depth, check.Name, display_status(check.Status));
end

fprintf('\nFirst analyzable candidate:\n');
if isempty(result.FirstAnalyzablePath)
    fprintf('(none found within checked depth)\n');
else
    fprintf('%s\n', result.FirstAnalyzablePath);
end
end


function value = display_status(status)

switch upper(char(status))
    case 'PASS_WITH_WARNINGS'
        value = 'PASS (warnings)';
    case 'NOT_RUN'
        value = 'NOT RUN';
    otherwise
        value = upper(char(status));
end
end
