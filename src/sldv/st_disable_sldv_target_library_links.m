function R = st_disable_sldv_target_library_links(T, cfg)
%ST_DISABLE_SLDV_TARGET_LIBRARY_LINKS Disable links before Harnesses exist.
%
% Runs before the HARNESS stage when cfg.DisableLibraryLinkForSldvTargets
% is true. Simulink refuses to disable a library link once any block
% inside it has a test harness, so the link of every FILE+SLDV/GENERATE
% target that is still library-linked and not atomic is disabled here,
% while the model has no Harness inside that link yet. The SLDV stage then
% finds the link already inactive and only sets TreatAsAtomicUnit.

n = height(T);
Status = repmat("SKIP", n, 1);
Message = strings(n,1);
LinkOwner = strings(n,1);
Changed = false(n,1);

if ~isfield(cfg, 'DisableLibraryLinkForSldvTargets') || ...
        ~cfg.DisableLibraryLinkForSldvTargets
    Message(:) = "cfg.DisableLibraryLinkForSldvTargets is false";
    R = result_table(T, LinkOwner, Changed, Status, Message);
    return;
end

if ~bdIsLoaded(cfg.TopModel)
    load_system(cfg.ModelFile);
end

timerValue = tic;
st_log(cfg, 'INFO', ...
    'SLDV target library-link disable start | Targets=%d', n);

for i = 1:n
    try
        if ~needs_atomic_cut(T(i,:))
            Message(i) = "SldvMode does not need an atomic CUT";
            continue;
        end
        cutPath = st_normalize_cut_path(T.CUTPath(i), cfg.TopModel);
        if getSimulinkBlockHandle(cutPath) == -1
            Message(i) = "CUT not found; HARNESS pre-validation reports it";
            continue;
        end
        if ~strcmp(get_param(cutPath, 'BlockType'), 'SubSystem')
            Message(i) = "CUT is not a Subsystem";
            continue;
        end
        if strcmp(get_param(cutPath, 'TreatAsAtomicUnit'), 'on')
            Message(i) = "CUT is already atomic";
            continue;
        end
        linkState = st_cut_library_link_state(cutPath);
        if ~linkState.IsLinked
            Message(i) = "CUT is not library-linked";
            continue;
        end
        info = st_disable_cut_library_link(cfg, cutPath);
        LinkOwner(i) = string(info.LinkOwner);
        Changed(i) = info.Changed;
        Status(i) = "OK";
        if info.Changed
            Message(i) = "Library link disabled";
        else
            Message(i) = "Library link already inactive";
        end
    catch ME
        Status(i) = "FAIL";
        Message(i) = string(ME.message);
        st_log(cfg, 'ERROR', ...
            ['SLDV target library-link disable failed | CUT=%s | ' ...
             '%s: %s'], ...
            char(T.CUTPath(i)), ME.identifier, ME.message);
    end
end

if any(Changed) && ~any(Status == "FAIL")
    save_system(cfg.TopModel);
    st_log(cfg, 'INFO', ...
        'SLDV target library-link disable saved the model | Model=%s', ...
        cfg.TopModel);
elseif any(Changed)
    st_log(cfg, 'WARN', ...
        ['SLDV target library-link disable made in-memory changes but ' ...
         'did not save because another target failed | Model=%s'], ...
        cfg.TopModel);
end

R = result_table(T, LinkOwner, Changed, Status, Message);
st_write_result('SldvLibraryLinkDisableResult', R);
st_log(cfg, 'INFO', ...
    ['SLDV target library-link disable end | Changed=%d | Fail=%d | ' ...
     'Elapsed=%.3f sec'], ...
    sum(Changed), sum(Status == "FAIL"), toc(timerValue));

end


function tf = needs_atomic_cut(row)
mode = upper(strtrim(char(string(row.SldvMode))));
if strcmp(mode, 'GENERATE')
    tf = true;
    return;
end
tf = false;
if strcmp(mode, 'FILE')
    format = 'SLDV';
    if ismember('DataFileFormat', row.Properties.VariableNames)
        format = upper(strtrim(char(string(row.DataFileFormat))));
        if isempty(format)
            format = 'SLDV';
        end
    end
    tf = ~strcmp(format, 'MAT');
end
end


function R = result_table(T, LinkOwner, Changed, Status, Message)
R = table(double(T.No), string(T.CUTName), string(T.CUTPath), ...
    LinkOwner, Changed, Status, Message, ...
    'VariableNames', {'No','CUTName','CUTPath','LinkOwner', ...
    'Changed','Status','Message'});
end
