function R = st_find_target_paths()
%ST_FIND_TARGET_PATHS Select one model and resolve CUT paths with anchors.
%
% Workflow:
%   1. Search ModelSearchRoot for .slx / .mdl files.
%   2. Let the user select exactly one target model.
%   3. Load the selected model.
%   4. Search the selected model for every CUTName in TestManagement.xlsx.
%   5. Reserve every existing valid CUTPath and reject duplicate ownership.
%   6. Remove reserved paths from every later row's candidate list.
%   7. Resolve a single unused candidate automatically.
%   8. For duplicated CUTName values, rank remaining candidates by nearby
%      confirmed paths and require explicit user confirmation.
%   9. Show nearby Excel rows in the selection dialog so the user can see
%      which logical section of the sheet is currently being resolved.
%  10. A selected path is immediately reserved for that Excel row.
%  11. Write the CUTPath column only after every row passes validation.
%  12. Save the selected model to runtime_target.mat.
%
% Important:
%   Excel depth/indent is not used. Row order is only a scoring/context hint.
%   It never removes a candidate. One physical subsystem can be assigned to
%   only one enabled Excel row.
%
% Excel does not need a ModelName column. One selected model is shared by
% every CUT in the current automation run.

cfg = st_config();


%% ============================================================
% Search model files
%% ============================================================

modelFiles = ...
    st_find_model_files( ...
        cfg.ModelSearchRoot, ...
        cfg.ModelSearchRecursive, ...
        cfg.ModelSearchExcludeFolders);

if isempty(modelFiles)

    error( ...
        'No .slx or .mdl files found under: %s', ...
        cfg.ModelSearchRoot);
end


%% ============================================================
% Select one model
%% ============================================================

displayNames = ...
    st_relative_display_names( ...
        modelFiles, ...
        cfg.ModelSearchRoot);

[index, ok] = ...
    listdlg( ...
        'PromptString', 'Select the target Simulink model', ...
        'SelectionMode', 'single', ...
        'ListString', displayNames, ...
        'ListSize', [650 320], ...
        'Name', 'Target Model Selection');

if ~ok || isempty(index)

    error('Target model selection was cancelled.');
end

modelFile = ...
    modelFiles{index};

[~, modelName] = ...
    fileparts(modelFile);


%% ============================================================
% Load selected model safely
%% ============================================================

if bdIsLoaded(modelName)

    loadedFile = ...
        get_param(modelName, 'FileName');

    if ~isempty(loadedFile) && ...
            ~st_same_path(loadedFile, modelFile)

        error( ...
            ['A different model with the same name is already loaded. ' ...
             'Loaded=%s, Selected=%s'], ...
            loadedFile, ...
            modelFile);
    end

else

    load_system(modelFile);
end


%% ============================================================
% Save runtime target
%% ============================================================

TopModel = modelName; %#ok<NASGU>
ModelFile = modelFile; %#ok<NASGU>
SelectedAt = char(datetime( ...
    'now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss')); %#ok<NASGU>

save( ...
    cfg.RuntimeTargetFile, ...
    'TopModel', ...
    'ModelFile', ...
    'SelectedAt');


fprintf('\n');
fprintf('============================================\n');
fprintf('Target Model Selected\n');
fprintf('============================================\n');
fprintf('Model : %s\n', modelName);
fprintf('File  : %s\n', modelFile);
fprintf('============================================\n');


%% ============================================================
% Read management Excel without losing physical row numbers
%% ============================================================

if ~isfile(cfg.ManagementExcel)

    error( ...
        'Management Excel not found: %s', ...
        cfg.ManagementExcel);
end

raw = ...
    readcell( ...
        cfg.ManagementExcel, ...
        'Sheet', cfg.ManagementSheet);

if isempty(raw) || size(raw,1) < 2

    error( ...
        'Targets sheet is empty: %s', ...
        cfg.ManagementSheet);
end

headers = ...
    string(raw(1,:));

idxCUTName = ...
    st_find_column( ...
        headers, ...
        {'CUTName','ModelName','모델명','CUT','대상모델명'});

idxCUTPath = ...
    st_find_column( ...
        headers, ...
        {'CUTPath','Path','path','경로','모델경로'});

idxEnabled = ...
    st_find_column_optional( ...
        headers, ...
        {'Enabled','사용','사용여부','활성','활성화'});


%% ============================================================
% Search every subsystem once
%% ============================================================

subsystems = ...
    find_system( ...
        modelName, ...
        'LookUnderMasks', 'all', ...
        'FollowLinks', 'off', ...
        'Type', 'Block', ...
        'BlockType', 'SubSystem');

subsystemNames = ...
    cell(size(subsystems));

for k = 1:numel(subsystems)

    subsystemNames{k} = ...
        get_param(subsystems{k}, 'Name');
end


%% ============================================================
% Prepare CUTPath column update
%% ============================================================

rowCount = ...
    size(raw,1) - 1;

cutPathColumn = ...
    raw(2:end, idxCUTPath);

for k = 1:numel(cutPathColumn)

    if st_cell_is_missing(cutPathColumn{k})
        cutPathColumn{k} = '';
    end
end


%% ============================================================
% Collect enabled target rows and candidate paths
%% ============================================================

items = struct( ...
    'DataRow', {}, ...
    'ExcelRow', {}, ...
    'CUTName', {}, ...
    'CurrentPath', {}, ...
    'Candidates', {}, ...
    'MatchCount', {}, ...
    'SelectedPath', {}, ...
    'Status', {}, ...
    'Resolution', {}, ...
    'Message', {}, ...
    'RecommendationScore', {}, ...
    'ClaimedCandidateCount', {}, ...
    'ContextRoot', {}, ...
    'BestAnchor', {}, ...
    'BestRelation', {}, ...
    'ClaimedByRows', {});

for dataRow = 1:rowCount

    excelRow = ...
        dataRow + 1;

    cutName = ...
        strtrim( ...
            st_cell_text( ...
                raw{excelRow, idxCUTName}));

    if isempty(cutName)
        continue;
    end

    if cfg.OnlyEnabled && ...
            ~isempty(idxEnabled)

        if ~st_enabled_value( ...
                raw{excelRow, idxEnabled})

            continue;
        end
    end

    currentPath = ...
        strtrim( ...
            st_cell_text( ...
                raw{excelRow, idxCUTPath}));

    mask = ...
        strcmp( ...
            subsystemNames, ...
            cutName);

    matches = ...
        subsystems(mask);

    item.DataRow = dataRow;
    item.ExcelRow = excelRow;
    item.CUTName = cutName;
    item.CurrentPath = currentPath;
    item.Candidates = matches;
    item.MatchCount = numel(matches);
    item.SelectedPath = '';
    item.Status = 'PENDING';
    item.Resolution = '';
    item.Message = '';
    item.RecommendationScore = NaN;
    item.ClaimedCandidateCount = 0;
    item.ContextRoot = '';
    item.BestAnchor = '';
    item.BestRelation = '';
    item.ClaimedByRows = '';

    items(end+1) = item; %#ok<AGROW>
end


%% ============================================================
% First pass: reserve existing valid CUT paths
%% ============================================================

for i = 1:numel(items)

    matches = items(i).Candidates;

    %% --------------------------------------------------------
    % Not found
    %% --------------------------------------------------------

    if isempty(matches)

        items(i).Status = 'FAIL';
        items(i).Resolution = 'NOT_FOUND';
        items(i).Message = ...
            'CUT subsystem not found in selected model';

        continue;
    end


    %% --------------------------------------------------------
    % Reuse an existing CUTPath if it still points to a candidate
    %% --------------------------------------------------------

    currentNormalized = '';

    if ~isempty(items(i).CurrentPath)

        try

            currentNormalized = ...
                st_normalize_cut_path( ...
                    items(i).CurrentPath, ...
                    modelName);

        catch

            currentNormalized = '';
        end
    end

    existingIndex = [];

    if ~isempty(currentNormalized)

        existingIndex = ...
            find( ...
                strcmp(matches, currentNormalized), ...
                1, ...
                'first');
    end

    if ~isempty(existingIndex)

        items(i).SelectedPath = matches{existingIndex};
        items(i).Status = 'OK';
        items(i).Resolution = 'EXISTING_PATH';
        items(i).Message = 'Existing valid CUTPath reused';

        continue;
    end


end


%% ============================================================
% Reject duplicate existing ownership before any recommendation
%% ============================================================

claims = st_build_anchor_table(items);
st_assert_unique_path_claims(claims);


%% ============================================================
% Second pass: resolve every currently unique unused candidate
%% ============================================================

for i = 1:numel(items)

    if ~strcmp(items(i).Status, 'PENDING')
        continue;
    end

    [availablePaths, claimedCandidates] = ...
        st_partition_claimed_path_candidates( ...
            items(i).Candidates, ...
            claims);

    items(i).ClaimedCandidateCount = height(claimedCandidates);
    items(i).ClaimedByRows = ...
        st_claimed_rows_text(claimedCandidates);

    if isempty(availablePaths)

        items(i) = ...
            st_mark_no_unused_candidate( ...
                items(i), ...
                claimedCandidates);

        continue;
    end

    if numel(availablePaths) == 1

        items(i).SelectedPath = availablePaths{1};
        items(i).Status = 'OK';
        items(i).Resolution = 'UNIQUE_UNUSED_MATCH';
        items(i).Message = 'Only one unassigned CUT path remains';

        claims = ...
            st_append_anchor( ...
                claims, ...
                items(i).ExcelRow, ...
                items(i).CUTName, ...
                items(i).SelectedPath);
    end
end


%% ============================================================
% Build recommendation anchors from every deterministic assignment
%% ============================================================

anchors = claims;


%% ============================================================
% Third pass: resolve ambiguous CUTs in Excel order
%% ============================================================

for i = 1:numel(items)

    if ~strcmp(items(i).Status, 'PENDING')
        continue;
    end

    cutName = items(i).CUTName;
    [matches, claimedCandidates] = ...
        st_partition_claimed_path_candidates( ...
            items(i).Candidates, ...
            claims);

    items(i).ClaimedCandidateCount = height(claimedCandidates);
    items(i).ClaimedByRows = ...
        st_claimed_rows_text(claimedCandidates);

    st_print_claimed_candidates( ...
        items(i), ...
        claimedCandidates, ...
        modelName);

    if isempty(matches)

        items(i) = ...
            st_mark_no_unused_candidate( ...
                items(i), ...
                claimedCandidates);

        continue;
    end

    if numel(matches) == 1

        items(i).SelectedPath = matches{1};
        items(i).Status = 'OK';
        items(i).Resolution = 'UNIQUE_UNUSED_MATCH';
        items(i).Message = 'Only one unassigned CUT path remains';

        claims = ...
            st_append_anchor( ...
                claims, ...
                items(i).ExcelRow, ...
                items(i).CUTName, ...
                items(i).SelectedPath);

        anchors = claims;
        continue;
    end

    [ranking, ~] = ...
        st_score_path_candidates( ...
            matches, ...
            items(i).ExcelRow, ...
            anchors, ...
            modelName, ...
            cfg.PathFinderAnchorCount);

    if isempty(ranking)

        items(i).Status = 'FAIL';
        items(i).Resolution = 'NO_RANKED_CANDIDATE';
        items(i).Message = 'No candidate was available for ranking';

        fprintf( ...
            '[%d] FAIL %s : no ranked candidate\n', ...
            items(i).ExcelRow, ...
            cutName);

        continue;
    end

    items(i).RecommendationScore = ranking.Score(1);
    items(i).ContextRoot = char(ranking.ContextRoot(1));
    items(i).BestAnchor = char(ranking.BestAnchor(1));
    items(i).BestRelation = char(ranking.BestRelation(1));

    contextLines = ...
        st_build_excel_context_lines( ...
            raw, ...
            idxCUTName, ...
            idxCUTPath, ...
            items, ...
            items(i).ExcelRow, ...
            cfg.PathFinderExcelContextRows, ...
            modelName);

    [selectedPath, selectedRankingRow, selectionOk] = ...
        st_select_ranked_candidate( ...
            cutName, ...
            items(i).ExcelRow, ...
            ranking, ...
            modelName, ...
            cfg.PathFinderHighlightSelection, ...
            contextLines, ...
            claimedCandidates);

    if ~selectionOk

        items(i).Status = 'FAIL';
        items(i).Resolution = 'SELECTION_CANCELLED';
        items(i).Message = 'CUT path selection was cancelled';

        fprintf( ...
            '[%d] FAIL %s : selection cancelled\n', ...
            items(i).ExcelRow, ...
            cutName);

        continue;
    end

    items(i).SelectedPath = selectedPath;
    items(i).Status = 'OK';
    items(i).Resolution = 'ANCHOR_RECOMMENDATION';
    items(i).RecommendationScore = ...
        ranking.Score(selectedRankingRow);
    items(i).ContextRoot = ...
        char(ranking.ContextRoot(selectedRankingRow));
    items(i).BestAnchor = ...
        char(ranking.BestAnchor(selectedRankingRow));
    items(i).BestRelation = ...
        char(ranking.BestRelation(selectedRankingRow));
    items(i).Message = ...
        'Resolved from ranked duplicate candidates';

    % The manually confirmed path immediately becomes an anchor for the
    % next ambiguous CUT.
    claims = ...
        st_append_anchor( ...
            claims, ...
            items(i).ExcelRow, ...
            items(i).CUTName, ...
            items(i).SelectedPath);

    anchors = claims;
end


%% ============================================================
% Result table
%% ============================================================

n = numel(items);

ExcelRow = zeros(n,1);
CUTName = strings(n,1);
MatchCount = zeros(n,1);
SelectedCUTPath = strings(n,1);
Status = strings(n,1);
Resolution = strings(n,1);
RecommendationScore = nan(n,1);
ClaimedCandidateCount = zeros(n,1);
ContextRoot = strings(n,1);
BestAnchor = strings(n,1);
BestRelation = strings(n,1);
ClaimedByRows = strings(n,1);
Message = strings(n,1);
Timestamp = strings(n,1);

for i = 1:n

    ExcelRow(i) = items(i).ExcelRow;
    CUTName(i) = string(items(i).CUTName);
    MatchCount(i) = items(i).MatchCount;
    SelectedCUTPath(i) = string(items(i).SelectedPath);
    Status(i) = string(items(i).Status);
    Resolution(i) = string(items(i).Resolution);
    RecommendationScore(i) = items(i).RecommendationScore;
    ClaimedCandidateCount(i) = items(i).ClaimedCandidateCount;
    ContextRoot(i) = string(items(i).ContextRoot);
    BestAnchor(i) = string(items(i).BestAnchor);
    BestRelation(i) = string(items(i).BestRelation);
    ClaimedByRows(i) = string(items(i).ClaimedByRows);
    Message(i) = string(items(i).Message);
    Timestamp(i) = string(datetime( ...
        'now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss'));

    if strcmp(items(i).Status, 'OK')

        fprintf( ...
            '[%d] OK   %s -> %s [%s]\n', ...
            items(i).ExcelRow, ...
            items(i).CUTName, ...
            items(i).SelectedPath, ...
            items(i).Resolution);

    elseif strcmp(items(i).Status, 'FAIL')

        fprintf( ...
            '[%d] FAIL %s : %s\n', ...
            items(i).ExcelRow, ...
            items(i).CUTName, ...
            items(i).Message);
    end
end

R = table( ...
    ExcelRow, ...
    CUTName, ...
    MatchCount, ...
    SelectedCUTPath, ...
    Status, ...
    Resolution, ...
    RecommendationScore, ...
    ClaimedCandidateCount, ...
    ContextRoot, ...
    BestAnchor, ...
    BestRelation, ...
    ClaimedByRows, ...
    Message, ...
    Timestamp);

fprintf('\n');
fprintf('============================================\n');
fprintf('CUT Path Finder Result\n');
fprintf('============================================\n');
fprintf('OK   : %d\n', sum(Status == 'OK'));
fprintf('FAIL : %d\n', sum(Status == 'FAIL'));
fprintf('Total: %d\n', height(R));
fprintf('============================================\n');

if any(Status == 'FAIL')

    st_write_result( ...
        'PathFinderResult', ...
        R);

    error( ...
        'st_find_target_paths:ResolutionFailed', ...
        ['One or more CUT paths could not be resolved. ' ...
         'The management Excel CUTPath column was not changed.']);
end


%% ============================================================
% Final validation before changing the management Excel
%% ============================================================

st_validate_final_assignments(items, modelName);


%% ============================================================
% Update and write the CUTPath column once
%% ============================================================

for i = 1:numel(items)

    cutPathColumn{items(i).DataRow} = ...
        items(i).SelectedPath;
end

startCell = ...
    sprintf( ...
        '%s2', ...
        st_excel_column_name(idxCUTPath));

writecell( ...
    cutPathColumn, ...
    cfg.ManagementExcel, ...
    'Sheet', cfg.ManagementSheet, ...
    'Range', startCell);

st_write_result( ...
    'PathFinderResult', ...
    R);

fprintf('Runtime target saved: %s\n', cfg.RuntimeTargetFile);
fprintf('============================================\n');

end


%% ============================================================
% Single-assignment helpers
%% ============================================================

function item = ...
    st_mark_no_unused_candidate(item, claimedCandidates)

item.Status = 'FAIL';
item.Resolution = 'NO_UNUSED_CANDIDATE';

if isempty(claimedCandidates)

    item.Message = 'No unassigned CUT path candidate remains';

else

    assignments = cell(height(claimedCandidates),1);

    for i = 1:height(claimedCandidates)

        assignments{i} = sprintf( ...
            '%s <- row %d (%s)', ...
            char(claimedCandidates.CandidatePath(i)), ...
            double(claimedCandidates.ClaimedExcelRow(i)), ...
            char(claimedCandidates.ClaimedCUTName(i)));
    end

    item.Message = sprintf( ...
        'All matching CUT paths are already assigned: %s', ...
        strjoin(assignments, '; '));
end

fprintf( ...
    '[%d] FAIL %s : %s\n', ...
    item.ExcelRow, ...
    item.CUTName, ...
    item.Message);

end


function text = st_claimed_rows_text(claimedCandidates)

if isempty(claimedCandidates)

    text = '';
    return;
end

owners = cell(height(claimedCandidates),1);

for i = 1:height(claimedCandidates)

    owners{i} = sprintf( ...
        '%d:%s', ...
        double(claimedCandidates.ClaimedExcelRow(i)), ...
        char(claimedCandidates.ClaimedCUTName(i)));
end

text = strjoin(owners, ', ');

end


function st_print_claimed_candidates(item, claimedCandidates, modelName)

if isempty(claimedCandidates)
    return;
end

fprintf( ...
    '[%d] %s : removed %d already assigned candidate(s)\n', ...
    item.ExcelRow, ...
    item.CUTName, ...
    height(claimedCandidates));

for i = 1:height(claimedCandidates)

    fprintf( ...
        '    ASSIGNED %s | row %d (%s)\n', ...
        st_relative_simulink_path( ...
            char(claimedCandidates.CandidatePath(i)), ...
            modelName), ...
        double(claimedCandidates.ClaimedExcelRow(i)), ...
        char(claimedCandidates.ClaimedCUTName(i)));
end

end


function st_validate_final_assignments(items, modelName)

selectedPaths = strings(numel(items),1);

for i = 1:numel(items)

    selectedPath = items(i).SelectedPath;

    if isempty(selectedPath)

        error( ...
            'st_find_target_paths:FinalValidationFailed', ...
            'Excel row %d has no selected CUTPath.', ...
            items(i).ExcelRow);
    end

    modelPrefix = [char(modelName) '/'];

    if length(selectedPath) < length(modelPrefix) || ...
            ~strncmp(selectedPath, modelPrefix, length(modelPrefix))

        error( ...
            'st_find_target_paths:FinalValidationFailed', ...
            'CUTPath is outside selected Top Model at Excel row %d: %s', ...
            items(i).ExcelRow, ...
            selectedPath);
    end

    try

        blockType = get_param(selectedPath, 'BlockType');
        blockName = get_param(selectedPath, 'Name');

    catch ME

        error( ...
            'st_find_target_paths:FinalValidationFailed', ...
            'CUTPath does not exist at Excel row %d: %s (%s)', ...
            items(i).ExcelRow, ...
            selectedPath, ...
            ME.message);
    end

    if ~strcmp(blockType, 'SubSystem')

        error( ...
            'st_find_target_paths:FinalValidationFailed', ...
            'CUTPath is not a SubSystem at Excel row %d: %s', ...
            items(i).ExcelRow, ...
            selectedPath);
    end

    if ~strcmp(blockName, items(i).CUTName)

        error( ...
            'st_find_target_paths:FinalValidationFailed', ...
            ['CUTName does not match the selected subsystem at Excel ' ...
             'row %d: expected=%s, actual=%s'], ...
            items(i).ExcelRow, ...
            items(i).CUTName, ...
            blockName);
    end

    selectedPaths(i) = string(selectedPath);
end


if numel(unique(selectedPaths)) ~= numel(selectedPaths)

    error( ...
        'st_find_target_paths:FinalValidationFailed', ...
        ['Final CUTPath assignments are not unique. ' ...
         'The management Excel CUTPath column was not changed.']);
end

end


%% ============================================================
% Ranked candidate selection
%% ============================================================

function [selectedPath, selectedRow, ok] = ...
    st_select_ranked_candidate( ...
        cutName, ...
        excelRow, ...
        ranking, ...
        modelName, ...
        highlightSelection, ...
        contextLines, ...
        claimedCandidates)

selectedPath = '';
selectedRow = [];
ok = false;

if isempty(ranking)
    return;
end

while true

    displayList = ...
        st_ranking_display_list( ...
            ranking);

    prompt = { ...
        sprintf('Target CUT : %s', cutName), ...
        sprintf('Excel Row  : %d', excelRow), ...
        ' ', ...
        'Excel Context'};

    prompt = [ ...
        prompt(:); ...
        contextLines(:); ...
        {' '}; ...
        {sprintf('Recommended context : %s', st_display_context_root(ranking))}; ...
        {sprintf('Already assigned candidates : %d', ...
            height(claimedCandidates))}; ...
        {'Candidates below are sorted by recommendation score.'}];

    [index, listOk] = ...
        listdlg( ...
            'PromptString', prompt, ...
            'SelectionMode', 'single', ...
            'ListString', displayList, ...
            'ListSize', [900 380], ...
            'Name', 'Recommended CUT Path Selection');

    if ~listOk || isempty(index)
        return;
    end

    candidate = ...
        char(ranking.CandidatePath(index));

    if highlightSelection

        st_preview_candidate(candidate, modelName);

        questionText = ...
            sprintf( ...
                'CUTName: %s\nSelected: %s\n\nUse the highlighted subsystem?', ...
                cutName, ...
                char(ranking.RelativePath(index)));

        answer = ...
            questdlg( ...
                questionText, ...
                'Confirm CUT Path', ...
                'Use', ...
                'Choose Again', ...
                'Cancel', ...
                'Use');

        st_clear_highlight(modelName);

        if strcmp(answer, 'Choose Again')
            continue;
        end

        if ~strcmp(answer, 'Use')
            return;
        end
    end

    selectedPath = candidate;
    selectedRow = index;
    ok = true;
    return;
end

end


function displayList = st_ranking_display_list(ranking)

n = height(ranking);
displayList = cell(n,1);

for i = 1:n

    scoreText = sprintf('%7.1f', ranking.Score(i));

    relation = ...
        st_relation_display_name( ...
            char(ranking.BestRelation(i)));

    if strlength(ranking.BestAnchor(i)) > 0

        anchorText = sprintf( ...
            'anchor: %s (%s)', ...
            char(ranking.BestAnchor(i)), ...
            relation);

    else

        anchorText = 'anchor: none';
    end

    displayList{i} = sprintf( ...
        '[%s]  %-18s | %-18s | %s | %s', ...
        scoreText, ...
        char(ranking.Grandparent(i)), ...
        char(ranking.Parent(i)), ...
        char(ranking.RelativePath(i)), ...
        anchorText);
end

end


function text = st_display_context_root(ranking)

text = 'none';

if isempty(ranking) || ...
        ~ismember('ContextRoot', ranking.Properties.VariableNames)

    return;
end

value = ...
    strtrim(char(ranking.ContextRoot(1)));

if ~isempty(value)
    text = value;
end

end


%% ============================================================
% Excel context shown in duplicate-selection dialog
%% ============================================================

function lines = ...
    st_build_excel_context_lines( ...
        raw, ...
        idxCUTName, ...
        idxCUTPath, ...
        items, ...
        currentExcelRow, ...
        contextRows, ...
        modelName)

contextRows = ...
    max(round(double(contextRows)), 0);

startRow = ...
    max(2, currentExcelRow - contextRows);

endRow = ...
    min(size(raw,1), currentExcelRow + contextRows);

lines = {};

for excelRow = startRow:endRow

    cutName = ...
        strtrim( ...
            st_cell_text( ...
                raw{excelRow, idxCUTName}));

    if isempty(cutName)
        continue;
    end

    markerText = '  ';

    if excelRow == currentExcelRow
        markerText = '>>';
    end

    pathText = ...
        st_context_path_for_row( ...
            raw, ...
            idxCUTPath, ...
            items, ...
            excelRow, ...
            modelName);

    lines{end+1,1} = sprintf( ...
        '%s row %-5d  %-30s  %s', ...
        markerText, ...
        excelRow, ...
        cutName, ...
        pathText); %#ok<AGROW>
end

if isempty(lines)

    lines = { ...
        sprintf('>> row %d  [current CUT]', currentExcelRow)};
end

end


function text = ...
    st_context_path_for_row( ...
        raw, ...
        idxCUTPath, ...
        items, ...
        excelRow, ...
        modelName)

text = '[unresolved]';

itemIndex = ...
    find( ...
        [items.ExcelRow] == excelRow, ...
        1, ...
        'first');

if ~isempty(itemIndex)

    if strcmp(items(itemIndex).Status, 'OK') && ...
            ~isempty(items(itemIndex).SelectedPath)

        text = ...
            st_relative_simulink_path( ...
                items(itemIndex).SelectedPath, ...
                modelName);

        return;

    elseif strcmp(items(itemIndex).Status, 'FAIL')

        text = '[FAIL]';
        return;
    end
end

rawPath = ...
    strtrim( ...
        st_cell_text( ...
            raw{excelRow, idxCUTPath}));

if ~isempty(rawPath)

    text = ...
        st_relative_simulink_path( ...
            rawPath, ...
            modelName);
end

end


function relative = ...
    st_relative_simulink_path( ...
        pathValue, ...
        modelName)

pathValue = ...
    strrep(char(pathValue), char(92), '/');

modelName = ...
    strrep(char(modelName), char(92), '/');

pathValue = ...
    strtrim(pathValue);

modelName = ...
    strtrim(modelName);

if isempty(pathValue)

    relative = '[unresolved]';
    return;
end

while ~isempty(pathValue) && pathValue(1) == '/'
    pathValue(1) = [];
end

if strcmp(pathValue, modelName)

    relative = modelName;
    return;
end

prefix = ...
    [modelName '/'];

if length(pathValue) >= length(prefix) && ...
        strncmp(pathValue, prefix, length(prefix))

    relative = ...
        pathValue(length(prefix)+1:end);

else

    relative = ...
        pathValue;
end

end


function text = st_relation_display_name(relation)

switch relation

    case 'DESCENDANT_OF_ANCHOR'
        text = 'inside anchor';

    case 'ANCESTOR_OF_ANCHOR'
        text = 'contains anchor';

    case 'SAME_PARENT'
        text = 'same parent';

    case 'SAME_GRANDPARENT'
        text = 'same grandparent';

    case 'COMMON_ANCESTOR'
        text = 'common ancestor';

    case 'MODEL_ONLY'
        text = 'model only';

    otherwise
        text = relation;
end

end


function st_preview_candidate(candidatePath, modelName)

try

    parentPath = ...
        get_param(candidatePath, 'Parent');

    if ~isempty(parentPath)
        open_system(parentPath);
    else
        open_system(modelName);
    end

    hilite_system( ...
        candidatePath, ...
        'find');

catch ME

    warning( ...
        'Could not preview CUT path %s: %s', ...
        candidatePath, ...
        ME.message);
end

end


function st_clear_highlight(modelName)

try

    hilite_system( ...
        modelName, ...
        'none');

catch
end

end


%% ============================================================
% Anchor helpers
%% ============================================================

function anchors = st_build_anchor_table(items)

ExcelRow = zeros(0,1);
CUTName = strings(0,1);
CUTPath = strings(0,1);

for i = 1:numel(items)

    if strcmp(items(i).Status, 'OK') && ...
            ~isempty(items(i).SelectedPath)

        ExcelRow(end+1,1) = items(i).ExcelRow; %#ok<AGROW>
        CUTName(end+1,1) = string(items(i).CUTName); %#ok<AGROW>
        CUTPath(end+1,1) = string(items(i).SelectedPath); %#ok<AGROW>
    end
end

anchors = table( ...
    ExcelRow, ...
    CUTName, ...
    CUTPath);

end


function anchors = ...
    st_append_anchor( ...
        anchors, ...
        excelRow, ...
        cutName, ...
        cutPath)

newRow = table( ...
    double(excelRow), ...
    string(cutName), ...
    string(cutPath), ...
    'VariableNames', { ...
        'ExcelRow', ...
        'CUTName', ...
        'CUTPath'});

anchors = [anchors; newRow];

end


%% ============================================================
% Find .slx / .mdl files
%% ============================================================

function modelFiles = ...
    st_find_model_files( ...
        rootDir, ...
        recursive, ...
        excludeFolders)

if ~isfolder(rootDir)

    error( ...
        'ModelSearchRoot does not exist: %s', ...
        rootDir);
end

if recursive

    slxInfo = dir(fullfile(rootDir, '**', '*.slx'));
    mdlInfo = dir(fullfile(rootDir, '**', '*.mdl'));

else

    slxInfo = dir(fullfile(rootDir, '*.slx'));
    mdlInfo = dir(fullfile(rootDir, '*.mdl'));
end

info = [ ...
    slxInfo(:); ...
    mdlInfo(:)];

modelFiles = {};

for i = 1:numel(info)

    filePath = ...
        fullfile( ...
            info(i).folder, ...
            info(i).name);

    if st_path_contains_excluded_folder( ...
            filePath, ...
            excludeFolders)

        continue;
    end

    modelFiles{end+1,1} = ...
        filePath; %#ok<AGROW>
end

if ~isempty(modelFiles)

    modelFiles = ...
        unique( ...
            modelFiles, ...
            'stable');

    modelFiles = ...
        sort(modelFiles);
end

end


function tf = ...
    st_path_contains_excluded_folder( ...
        filePath, ...
        excludeFolders)

normalized = ...
    strrep( ...
        char(filePath), ...
        char(92), ...
        '/');

parts = ...
    strsplit(normalized, '/');

tf = false;

for i = 1:numel(excludeFolders)

    if any(strcmpi( ...
            parts, ...
            excludeFolders{i}))

        tf = true;
        return;
    end
end

end


%% ============================================================
% Display paths relative to search root
%% ============================================================

function names = ...
    st_relative_display_names( ...
        files, ...
        rootDir)

names = files;

rootNormalized = ...
    st_normalize_file_path(rootDir);

for i = 1:numel(files)

    fileNormalized = ...
        st_normalize_file_path(files{i});

    prefix = ...
        [rootNormalized '/'];

    if length(fileNormalized) >= length(prefix) && ...
            strncmpi(fileNormalized, prefix, length(prefix))

        names{i} = ...
            fileNormalized(length(prefix)+1:end);

    else

        names{i} = ...
            fileNormalized;
    end
end

end


%% ============================================================
% Header helpers
%% ============================================================

function idx = ...
    st_find_column( ...
        headers, ...
        aliases)

idx = ...
    st_find_column_optional( ...
        headers, ...
        aliases);

if isempty(idx)

    error( ...
        'Required Excel column not found: %s', ...
        strjoin(aliases, ', '));
end

end


function idx = ...
    st_find_column_optional( ...
        headers, ...
        aliases)

idx = [];

normalizedHeaders = ...
    lower(strtrim(headers));

for i = 1:numel(aliases)

    alias = ...
        lower(strtrim(string(aliases{i})));

    match = ...
        find( ...
            normalizedHeaders == alias, ...
            1, ...
            'first');

    if ~isempty(match)

        idx = match;
        return;
    end
end

end


%% ============================================================
% Cell helpers
%% ============================================================

function text = ...
    st_cell_text(value)

if st_cell_is_missing(value)

    text = '';
    return;
end

if ischar(value)

    text = value;

elseif isstring(value)

    if isempty(value) || ismissing(value)
        text = '';
    else
        text = char(value(1));
    end

else

    text = char(string(value));
end

end


function tf = ...
    st_cell_is_missing(value)

tf = isempty(value);

if tf
    return;
end

try

    missingMask = ...
        ismissing(value);

    tf = ...
        all(missingMask(:));

catch

    tf = false;
end

end


function tf = ...
    st_enabled_value(value)

if st_cell_is_missing(value)

    tf = false;
    return;
end

if islogical(value)

    tf = value(1);

elseif isnumeric(value)

    tf = ...
        isfinite(value(1)) && ...
        value(1) ~= 0;

else

    s = ...
        lower(strtrim(string(value)));

    tf = ...
        ismember( ...
            s, ...
            {'true','1','yes','y','on','사용','o'});
end

end


%% ============================================================
% Excel column number -> A / B / AA ...
%% ============================================================

function name = ...
    st_excel_column_name(index)

name = '';

while index > 0

    remainder = ...
        mod(index - 1, 26);

    name = ...
        [char(double('A') + remainder) name]; %#ok<AGROW>

    index = ...
        floor((index - 1) / 26);
end

end


%% ============================================================
% File path helpers
%% ============================================================

function tf = ...
    st_same_path(a, b)

tf = ...
    strcmpi( ...
        st_normalize_file_path(a), ...
        st_normalize_file_path(b));

end


function out = ...
    st_normalize_file_path(value)

out = ...
    strrep( ...
        char(value), ...
        char(92), ...
        '/');

while length(out) > 1 && ...
        out(end) == '/'

    out(end) = [];
end

end
