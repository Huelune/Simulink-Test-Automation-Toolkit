function source = st_final_document_run_source(cfg, requested)
%ST_FINAL_DOCUMENT_RUN_SOURCE Pick the executed run that the verdicts come from.
% Resolves ResultRun to exactly one run and reports where its per-iteration
% verdicts and its saved ResultSets live. No workbook and no .mldatx is
% opened here; only the pointers and the run manifest are read.
%
%   requested  '' uses cfg.FinalDocumentResultRun. 'AUTO' picks whichever of
%              the two pointers was updated last. 'BATCH' and 'PER_CUT' force
%              one mode and fail when that history is missing, because an
%              explicit choice must not silently fall back. Anything else is
%              taken as a run directory.
%
% source.Mode is 'PER_CUT', 'BATCH' or 'NONE'. source.Workbooks lists the
% TestSummary.xlsx files to read, source.ResultSets the .mldatx paths to
% quote as the place to look, and source.Notes why anything is missing.
if nargin < 2, requested = ''; end
token = upper(strtrim(char(string(requested))));
if isempty(token)
    token = upper(strtrim(char(string( ...
        config_value(cfg, 'FinalDocumentResultRun', 'AUTO')))));
end
if isempty(token), token = 'AUTO'; end

source = empty_run_source(token);
st_log(cfg, 'INFO', 'Final document run source start | ResultRun=%s', token);
switch token
    case 'AUTO'
        source = resolve_automatically(cfg, source);
    case 'BATCH'
        source = resolve_batch(cfg, source, true);
    case 'PER_CUT'
        source = resolve_per_cut(cfg, source, true);
    otherwise
        source = resolve_directory(cfg, source, strtrim(char(string(requested))));
end
st_log(cfg, 'INFO', ...
    'Final document run source end | Mode=%s | RunId=%s | Workbooks=%d | ResultSets=%d', ...
    source.Mode, source.RunId, height(source.Workbooks), height(source.ResultSets));
end


function source = empty_run_source(token)
source = struct( ...
    'Requested', token, ...
    'Mode', 'NONE', ...
    'RunId', '', ...
    'RunDirectory', '', ...
    'UpdatedAt', '', ...
    'Workbooks', empty_workbook_table(), ...
    'ResultSets', empty_result_set_table(), ...
    'Notes', empty_note_table());
end


function T = empty_workbook_table()
T = table(strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'Stage','No','TestCaseName','File'});
end


function T = empty_result_set_table()
T = table(strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'Stage','No','TestCaseName','File'});
end


function T = empty_note_table()
T = table(zeros(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','TestCaseName','Reason','Message'});
end


function source = add_note(source, no, testCaseName, reason, message)
source.Notes = [source.Notes; table(no, string(testCaseName), ...
    string(reason), string(message), 'VariableNames', ...
    {'No','TestCaseName','Reason','Message'})];
end


function value = config_value(cfg, name, fallback)
% A config written before this option exists has no field, so fall back to
% the documented default instead of failing.
value = fallback;
if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
    value = cfg.(name);
end
end


function source = resolve_automatically(cfg, source)
% Both pointers carry an UpdatedAt, so the newer one is the run the user
% last finished. Falling back to result/TestSummary.xlsx would be wrong:
% that copy is refreshed by BATCH only and goes stale after a PER_CUT run.
batch = read_pointer(pointer_path(cfg, 'LatestReportPointer', 'latest.json'));
perCut = read_pointer(pointer_path(cfg, 'PerCutLatestPointer', 'per_cut_latest.json'));
batchTime = pointer_time(batch);
perCutTime = pointer_time(perCut);
if isempty(batch) && isempty(perCut)
    source = add_note(source, 0, "", "NO_RESULT_RUN", ...
        'No BATCH or PER_CUT run history exists. Run the tests first.');
    st_log(cfg, 'WARN', 'Final document run source | No run history');
    return;
end
if isempty(perCut) || (~isempty(batch) && batchTime >= perCutTime)
    source = resolve_batch(cfg, source, false);
    return;
end
source = resolve_per_cut(cfg, source, false);
end


function source = resolve_directory(cfg, source, requested)
% An explicit directory still has to say which layout it holds, because the
% two runners write completely different manifests.
if ~isfolder(requested)
    error('simtest:FinalDocumentResultRunMissing', ...
        'ResultRun is not AUTO, BATCH, PER_CUT or an existing run directory: %s', ...
        requested);
end
manifestPath = fullfile(requested, 'manifest.json');
if ~isfile(manifestPath)
    error('simtest:FinalDocumentResultRunMissing', ...
        'Run directory has no manifest.json: %s', requested);
end
manifest = decode_json(manifestPath);
mode = upper(strtrim(char(string(field_value(manifest, 'ExecutionMode', '')))));
if strcmp(mode, 'PER_CUT')
    source = collect_per_cut(cfg, source, manifest, requested, manifestPath);
else
    source = collect_batch(cfg, source, requested, ...
        char(string(field_value(manifest, 'RunId', ''))), '');
end
end


function source = resolve_batch(cfg, source, explicit)
pointerFile = pointer_path(cfg, 'LatestReportPointer', 'latest.json');
pointer = read_pointer(pointerFile);
if isempty(pointer)
    if explicit
        error('simtest:FinalDocumentResultRunMissing', ...
            'No BATCH report exists yet. Run st_generate_test_report first: %s', ...
            pointerFile);
    end
    source = add_note(source, 0, "", "NOT_REPORTED", ...
        'No BATCH report exists yet. Run st_generate_test_report first.');
    return;
end
runDirectory = char(string(field_value(pointer, 'RunDirectory', '')));
source = collect_batch(cfg, source, runDirectory, ...
    char(string(field_value(pointer, 'RunId', ''))), ...
    char(string(field_value(pointer, 'UpdatedAt', ''))));
source = warn_when_report_is_stale(cfg, source, pointer);
end


function source = warn_when_report_is_stale(cfg, source, pointer)
% The execution writes run_record_latest.json and the report writes
% latest.json. A record newer than the report means the last BATCH run was
% never reported, so its verdicts are simply not on disk yet.
record = read_pointer(pointer_path(cfg, 'LatestRunRecordPointer', ...
    'run_record_latest.json'));
if isempty(record), return; end
if pointer_time(record) <= pointer_time(pointer), return; end
source = add_note(source, 0, "", "NOT_REPORTED", ...
    'A newer BATCH run has no report. Run st_generate_test_report to include it.');
st_log(cfg, 'WARN', ...
    'Final document run source | Newer BATCH run is unreported | Record=%s | Report=%s', ...
    char(string(field_value(record, 'UpdatedAt', ''))), ...
    char(string(field_value(pointer, 'UpdatedAt', ''))));
end


function source = collect_batch(cfg, source, runDirectory, runId, updatedAt)
source.Mode = 'BATCH';
source.RunId = runId;
source.RunDirectory = runDirectory;
source.UpdatedAt = updatedAt;
workbook = fullfile(runDirectory, 'TestSummary.xlsx');
if isfile(workbook)
    % One workbook holds both stages. The reader prefers the FINAL rows.
    source.Workbooks = [source.Workbooks; table("ANY", 0, "", string(workbook), ...
        'VariableNames', {'Stage','No','TestCaseName','File'})];
else
    source = add_note(source, 0, "", "NOT_REPORTED", ...
        sprintf('Run directory has no TestSummary.xlsx: %s', runDirectory));
end
source = collect_batch_result_sets(cfg, source);
end


function source = collect_batch_result_sets(cfg, source)
% The saved ResultSets are named by the run record, not by the report.
record = read_pointer(pointer_path(cfg, 'LatestRunRecordPointer', ...
    'run_record_latest.json'));
if isempty(record)
    source = add_note(source, 0, "", "NO_RESULT_SET", ...
        'No run record exists, so no saved ResultSet path can be quoted.');
    return;
end
recordFile = char(string(field_value(record, 'Record', '')));
if ~isfile(recordFile)
    source = add_note(source, 0, "", "NO_RESULT_SET", ...
        sprintf('Run record file is missing: %s', recordFile));
    return;
end
try
    loaded = load(recordFile, 'record');
catch ME
    source = add_note(source, 0, "", "NO_RESULT_SET", ME.message);
    st_log(cfg, 'WARN', 'Final document run record unreadable | File=%s | %s', ...
        recordFile, ME.message);
    return;
end
entry = loaded.record;
% With no rerun the runner stores the same path twice, so one row is right.
source = append_result_set(source, "INITIAL", 0, "", ...
    field_value(entry, 'InitialFile', ''));
finalFile = char(string(field_value(entry, 'FinalFile', '')));
if ~isempty(finalFile) && ~strcmp(finalFile, char(string(field_value(entry, 'InitialFile', ''))))
    source = append_result_set(source, "FINAL", 0, "", finalFile);
end
end


function source = append_result_set(source, stage, no, testCaseName, file)
file = string(file);
if strlength(file) == 0, return; end
source.ResultSets = [source.ResultSets; table(string(stage), no, ...
    string(testCaseName), file, ...
    'VariableNames', {'Stage','No','TestCaseName','File'})];
end


function source = resolve_per_cut(cfg, source, explicit)
pointerFile = pointer_path(cfg, 'PerCutLatestPointer', 'per_cut_latest.json');
pointer = read_pointer(pointerFile);
if isempty(pointer)
    if explicit
        error('simtest:FinalDocumentResultRunMissing', ...
            'No PER_CUT run exists yet: %s', pointerFile);
    end
    source = add_note(source, 0, "", "NO_RESULT_RUN", ...
        'No PER_CUT run exists yet. Run the tests first.');
    return;
end
manifestPath = char(string(field_value(pointer, 'Manifest', '')));
runDirectory = char(string(field_value(pointer, 'RunDirectory', '')));
if ~isfile(manifestPath)
    % The pointer can outlive a moved or cleaned run directory.
    candidate = fullfile(runDirectory, 'manifest.json');
    if isfile(candidate), manifestPath = candidate; end
end
if ~isfile(manifestPath)
    if explicit
        error('simtest:FinalDocumentResultRunMissing', ...
            'PER_CUT manifest is missing: %s', manifestPath);
    end
    source = add_note(source, 0, "", "NO_RESULT_RUN", ...
        sprintf('PER_CUT manifest is missing: %s', manifestPath));
    return;
end
source.UpdatedAt = char(string(field_value(pointer, 'UpdatedAt', '')));
manifest = decode_json(manifestPath);
source = collect_per_cut(cfg, source, manifest, runDirectory, manifestPath);
end


function source = collect_per_cut(cfg, source, manifest, runDirectory, manifestPath)
source.Mode = 'PER_CUT';
source.RunId = char(string(field_value(manifest, 'RunId', '')));
if isempty(runDirectory)
    runDirectory = char(string(field_value(manifest, 'RunDirectory', '')));
end
if isempty(runDirectory)
    runDirectory = fileparts(manifestPath);
end
source.RunDirectory = runDirectory;
targets = struct_array(field_value(manifest, 'Targets', []));
artifacts = struct_array(field_value(manifest, 'Artifacts', []));
if isempty(targets)
    source = add_note(source, 0, "", "NOT_COLLECTED", ...
        'The PER_CUT manifest lists no targets.');
    return;
end
for i = 1:numel(targets)
    source = collect_per_cut_target(cfg, source, targets(i), artifacts, runDirectory);
end
end


function source = collect_per_cut_target(cfg, source, target, artifacts, runDirectory)
no = double(field_value(target, 'No', 0));
testCaseName = string(field_value(target, 'TestCaseName', ""));
directory = per_cut_target_directory(target, runDirectory);
if isempty(directory)
    source = add_note(source, no, testCaseName, "NOT_COLLECTED", ...
        'The target directory could not be located from the manifest.');
    return;
end
% final/ exists only when a rerun happened. Without one the initial run is
% the final result, so using it is exact rather than a substitution.
stage = "FINAL";
workbook = fullfile(directory, 'final', 'TestSummary.xlsx');
if ~isfile(workbook)
    stage = "INITIAL";
    workbook = fullfile(directory, 'initial', 'TestSummary.xlsx');
    if isfile(workbook)
        source = add_note(source, no, testCaseName, "NO_FINAL_RUN_USED_INITIAL", ...
            'No rerun happened, so the initial run is the final result.');
    end
end
if ~isfile(workbook)
    source = add_note(source, no, testCaseName, "NOT_COLLECTED", ...
        'Run st_collect_per_cut_results to write this target workbook.');
    st_log(cfg, 'WARN', ...
        'Final document target not collected | No=%g | Case=%s | Directory=%s', ...
        no, testCaseName, directory);
    return;
end
source.Workbooks = [source.Workbooks; table(stage, no, testCaseName, ...
    string(workbook), 'VariableNames', {'Stage','No','TestCaseName','File'})];
source = append_result_set(source, stage, no, testCaseName, ...
    result_set_path(artifacts, no, stage, directory));
end


function path = per_cut_target_directory(target, runDirectory)
% Prefer the recorded path. The folder name carries a hash of the target
% identity, so it is recomputed only when the record is unusable.
path = '';
recorded = char(string(field_value(target, 'TargetManifest', '')));
if ~isempty(recorded)
    candidate = fileparts(recorded);
    if isfolder(candidate)
        path = candidate;
        return;
    end
end
try
    candidate = st_per_cut_target_directory(runDirectory, target);
    if isfolder(candidate), path = candidate; end
catch
    % Keep the empty path so the caller records the missing target.
end
end


function file = result_set_path(artifacts, no, stage, directory)
file = "";
for i = 1:numel(artifacts)
    if ~strcmp(char(string(field_value(artifacts(i), 'Type', ''))), 'MLDATX')
        continue;
    end
    if double(field_value(artifacts(i), 'No', -1)) ~= no, continue; end
    if ~strcmpi(char(string(field_value(artifacts(i), 'Stage', ''))), char(stage))
        continue;
    end
    file = string(field_value(artifacts(i), 'Path', ""));
    return;
end
% The runner always saves it next to the target workbook, so fall back to
% that rather than leaving the reader with nowhere to look.
candidate = fullfile(directory, lower(char(stage)), 'Results.mldatx');
if isfile(candidate), file = string(candidate); end
end


function file = pointer_path(cfg, name, fallbackName)
if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
    file = char(string(cfg.(name)));
    return;
end
file = fullfile(char(string(config_value(cfg, 'ResultDir', pwd))), fallbackName);
end


function pointer = read_pointer(file)
pointer = [];
if isempty(file) || ~isfile(file), return; end
try
    pointer = decode_json(file);
catch
    % A truncated or half-written pointer is treated as no pointer at all.
    pointer = [];
end
end


function t = pointer_time(pointer)
% The two report pointers write milliseconds and the run record pointer does
% not, so both spellings have to parse.
t = NaT;
if isempty(pointer), return; end
text = strtrim(char(string(field_value(pointer, 'UpdatedAt', ''))));
if isempty(text), return; end
formats = {'yyyy-MM-dd HH:mm:ss.SSS', 'yyyy-MM-dd HH:mm:ss'};
for i = 1:numel(formats)
    try
        t = datetime(text, 'InputFormat', formats{i});
        return;
    catch
        % Try the next documented spelling.
    end
end
end


function value = decode_json(file)
value = jsondecode(fileread(file));
end


function value = field_value(item, name, fallback)
value = fallback;
if isstruct(item) && isscalar(item) && isfield(item, name)
    value = item.(name);
end
end


function items = struct_array(value)
% jsondecode collapses a one-element array into a scalar struct and returns
% a cell array when the entries do not share their fields.
items = struct([]);
if isempty(value), return; end
if isstruct(value)
    items = value(:)';
    return;
end
if iscell(value)
    keep = value(cellfun(@isstruct, value));
    for i = 1:numel(keep)
        entry = keep{i};
        if isempty(items)
            items = entry(1);
        else
            items(end+1) = entry(1); %#ok<AGROW>
        end
    end
end
end
